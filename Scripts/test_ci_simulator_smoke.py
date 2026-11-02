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
    def test_boot_waits_for_readiness_even_when_already_booted(self):
        with tempfile.TemporaryDirectory() as directory:
            for state in ("Shutdown", "Booted"):
                with self.subTest(state=state), patch.object(smoke, "simctl") as simctl:
                    smoke.boot_simulator("iPhone", "device-id", state, Path(directory) / "boot.log")
                    commands = [call.args for call in simctl.call_args_list]
                    expected = [] if state == "Booted" else [("boot", "device-id")]
                    self.assertEqual(commands, expected + [("bootstatus", "device-id", "-b")])
                    self.assertEqual(simctl.call_args.kwargs["timeout"], 600)

    def test_boot_timeout_retains_output_and_cause(self):
        error = subprocess.TimeoutExpired(["xcrun", "simctl", "bootstatus"], 600)

        def timeout(*args, **kwargs):
            kwargs["stdout"].write("Waiting on system app\n")
            raise error

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "boot.log"
            with patch.object(smoke, "simctl", side_effect=timeout):
                with self.assertRaisesRegex(RuntimeError, "simulator boot timed out") as raised:
                    smoke.boot_simulator("iPhone", "device-id", "Booted", path)
            self.assertIs(raised.exception.__cause__, error)
            self.assertIn("Waiting on system app", path.read_text())

    def test_shutdown_timeout_does_not_replace_boot_failure(self):
        devices = {"devices": {"com.apple.CoreSimulator.SimRuntime.iOS-27-1": [
            {"name": "iPhone Duo", "udid": "device-id", "state": "Shutdown", "isAvailable": True},
        ]}}
        failure = RuntimeError("Original boot failure")
        with tempfile.TemporaryDirectory() as directory, contextlib.chdir(directory):
            with (
                patch.object(smoke, "simctl", return_value=Mock(stdout=json.dumps(devices))),
                patch.object(smoke, "boot_simulator", side_effect=failure),
                patch.object(smoke.subprocess, "run", side_effect=subprocess.TimeoutExpired("shutdown", 60)),
                contextlib.redirect_stdout(io.StringIO()) as output,
            ):
                with self.assertRaises(RuntimeError) as raised:
                    smoke.main()
            self.assertIs(raised.exception, failure)
            self.assertIn("simulator cleanup failed", output.getvalue())
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
        self.assertEqual(cleanup.call_args.args, ("shutdown", "device-id"))

    def test_success_requires_handshake_and_screenshot_on_both_devices(self):
        names = ("iPhone Duo", "iPhone 18 Pro")
        devices = {"devices": {"com.apple.CoreSimulator.SimRuntime.iOS-27-1": [
            {"name": name, "udid": name, "state": "Shutdown", "isAvailable": True} for name in names
        ]}}
        process = Mock()
        process.poll.return_value = None

        def launch(*args, **kwargs):
            kwargs["stdout"].write("Vue App is ready!\n")
            kwargs["stdout"].flush()
            return process

        with tempfile.TemporaryDirectory() as directory, contextlib.chdir(directory):
            with (
                patch.object(smoke, "simctl", return_value=Mock(stdout=json.dumps(devices))) as simctl,
                patch.object(smoke.subprocess, "Popen", side_effect=launch),
                patch.object(smoke, "cleanup_simulator") as cleanup,
                patch.object(smoke.time, "sleep"),
                contextlib.redirect_stdout(io.StringIO()) as output,
            ):
                smoke.main()
            commands = [call.args for call in simctl.call_args_list]
            for name in names:
                self.assertIn(("install", name, "build/DerivedData/Build/Products/Debug-iphonesimulator/Nightwave Plaza.app"), commands)
                self.assertIn(("io", name, "screenshot", f"build/diagnostics/{name}.png"), commands)
                self.assertIn(f"{name}: native launch and web bridge handshake passed", output.getvalue())
            self.assertEqual(cleanup.call_count, 2)


if __name__ == "__main__":
    unittest.main()
