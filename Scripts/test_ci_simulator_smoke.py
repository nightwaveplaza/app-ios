import contextlib
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

import ci_simulator_smoke as smoke


class SimulatorSmokeTests(unittest.TestCase):
    def setUp(self):
        self.runtime_id = "com.apple.CoreSimulator.SimRuntime.iOS-27-1"
        self.names = ("iPhone Duo", "iPhone 18 Pro")
        self.inventory = {
            "runtimes": [
                {"identifier": "com.apple.CoreSimulator.SimRuntime.iOS-27-0", "version": "27.0", "isAvailable": True},
                {"identifier": self.runtime_id, "version": "27.1", "isAvailable": True},
                {"identifier": "com.apple.CoreSimulator.SimRuntime.iOS-27-2", "version": "27.2", "isAvailable": False},
            ],
            "devicetypes": [{"name": name, "identifier": f"type-{name}"} for name in self.names],
            "devices": {self.runtime_id: [
                {"name": name, "udid": f"stale-{name}", "state": "Shutdown", "isAvailable": True}
                for name in self.names
            ]},
        }

    def simctl_result(self, *args, **kwargs):
        if args[0] == "list":
            return subprocess.CompletedProcess(args, 0, stdout=json.dumps(self.inventory))
        if args[0] == "create":
            return subprocess.CompletedProcess(args, 0, stdout=f"fresh-{args[2].removeprefix('type-')}\n")
        return subprocess.CompletedProcess(args, 0)

    def test_boot_waits_for_readiness(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(smoke, "simctl") as simctl:
                smoke.boot_simulator("iPhone", "device-id", Path(directory) / "boot.log")
                commands = [call.args for call in simctl.call_args_list]
                self.assertEqual(commands, [("boot", "device-id"), ("bootstatus", "device-id", "-b")])
                self.assertEqual(simctl.call_args.kwargs["timeout"], 600)

    def test_boot_timeout_retains_output_and_cause(self):
        error = subprocess.TimeoutExpired(["xcrun", "simctl", "bootstatus"], 600)

        def timeout(*args, **kwargs):
            if args[0] == "bootstatus":
                kwargs["stdout"].write("Waiting on system app\n")
                raise error

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "boot.log"
            with patch.object(smoke, "simctl", side_effect=timeout):
                with self.assertRaisesRegex(RuntimeError, "simulator boot timed out") as raised:
                    smoke.boot_simulator("iPhone", "device-id", path)
            self.assertIs(raised.exception.__cause__, error)
            self.assertIn("Waiting on system app", path.read_text())

    def test_zero_exit_with_migration_failure_prevents_install(self):
        def simctl_result(*args, **kwargs):
            if args[0] == "bootstatus":
                kwargs["stdout"].write("Status=3, isTerminal=YES\n\tData Migration Failed\n")
            return self.simctl_result(*args, **kwargs)

        with tempfile.TemporaryDirectory() as directory, contextlib.chdir(directory):
            with (
                patch.object(smoke, "simctl", side_effect=simctl_result) as simctl,
                patch.object(smoke, "cleanup_simulator") as cleanup,
                patch.object(smoke.subprocess, "Popen") as launch,
                contextlib.redirect_stdout(io.StringIO()),
            ):
                with self.assertRaisesRegex(RuntimeError, "simulator data migration failed"):
                    smoke.main()
            self.assertNotIn("install", [call.args[0] for call in simctl.call_args_list])
            launch.assert_not_called()
            cleanup.assert_called_once_with("fresh-iPhone Duo", "com.nightwaveplaza.NightwavePlaza", None)
            self.assertIn("Data Migration Failed", Path("build/diagnostics/iPhone Duo-boot.log").read_text())

    def test_shutdown_timeout_does_not_replace_boot_failure(self):
        failure = RuntimeError("Original boot failure")
        with tempfile.TemporaryDirectory() as directory, contextlib.chdir(directory):
            with (
                patch.object(smoke, "simctl", side_effect=self.simctl_result),
                patch.object(smoke, "boot_simulator", side_effect=failure),
                patch.object(smoke.subprocess, "run", side_effect=subprocess.TimeoutExpired("shutdown", 60)) as run,
                contextlib.redirect_stdout(io.StringIO()) as output,
            ):
                with self.assertRaises(RuntimeError) as raised:
                    smoke.main()
            self.assertIs(raised.exception, failure)
            self.assertIn("simulator cleanup failed", output.getvalue())
            self.assertEqual(run.call_args.args[0], ["xcrun", "simctl", "delete", "fresh-iPhone Duo"])
            self.assertTrue(Path("build/diagnostics/devices.json").is_file())

    def test_hung_launch_process_is_killed_before_shutdown(self):
        process = Mock()
        process.poll.return_value = None
        process.wait.side_effect = [subprocess.TimeoutExpired("launch", 15), 0]
        with patch.object(smoke, "cleanup_simctl") as cleanup:
            smoke.cleanup_simulator("device-id", "bundle-id", process)
        process.terminate.assert_called_once()
        process.kill.assert_called_once()
        self.assertEqual(process.wait.call_count, 2)
        self.assertEqual([call.args for call in cleanup.call_args_list][-2:], [
            ("shutdown", "device-id"), ("delete", "device-id"),
        ])

    def test_success_requires_handshake_and_screenshot_on_both_devices(self):
        process = Mock()
        process.poll.return_value = None

        def launch(*args, **kwargs):
            kwargs["stdout"].write("Vue App is ready!\n")
            kwargs["stdout"].flush()
            return process

        with tempfile.TemporaryDirectory() as directory, contextlib.chdir(directory):
            with (
                patch.object(smoke, "simctl", side_effect=self.simctl_result) as simctl,
                patch.object(smoke.subprocess, "Popen", side_effect=launch),
                patch.object(smoke, "cleanup_simulator") as cleanup,
                patch.object(smoke.time, "sleep"),
                contextlib.redirect_stdout(io.StringIO()) as output,
            ):
                smoke.main()
            commands = [call.args for call in simctl.call_args_list]
            for name in self.names:
                self.assertIn(("create", f"Nightwave Plaza smoke - {name}", f"type-{name}", self.runtime_id), commands)
                self.assertIn(("install", f"fresh-{name}", "build/DerivedData/Build/Products/Debug-iphonesimulator/Nightwave Plaza.app"), commands)
                self.assertIn(("io", f"fresh-{name}", "screenshot", f"build/diagnostics/{name}.png"), commands)
                self.assertIn(f"{name}: native launch and web bridge handshake passed", output.getvalue())
            self.assertFalse(any("stale-" in str(command) for command in commands))
            self.assertEqual(cleanup.call_count, 2)

    def test_missing_runtime_does_not_create_or_delete_devices(self):
        self.inventory["runtimes"] = []
        with tempfile.TemporaryDirectory() as directory, contextlib.chdir(directory):
            with (
                patch.object(smoke, "simctl", side_effect=self.simctl_result) as simctl,
                patch.object(smoke, "cleanup_simulator") as cleanup,
            ):
                with self.assertRaisesRegex(RuntimeError, "simulator runtime missing"):
                    smoke.main()
            self.assertEqual([call.args[0] for call in simctl.call_args_list], ["list"])
            cleanup.assert_not_called()


if __name__ == "__main__":
    unittest.main()
