import contextlib
import io
import json
from pathlib import Path
import subprocess
import sys
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

        for runtime in self.inventory["runtimes"]:
            runtime["supportedDeviceTypes"] = self.inventory["devicetypes"]

    def test_runtime_selected_per_device_not_globally(self):
        older, newer, unavailable = self.inventory["runtimes"]
        older["supportedDeviceTypes"] = [self.inventory["devicetypes"][1]]
        newer["supportedDeviceTypes"] = [self.inventory["devicetypes"][0]]
        self.assertEqual(smoke.select_runtime(self.inventory, "type-iPhone Duo"), newer)
        self.assertEqual(smoke.select_runtime(self.inventory, "type-iPhone 18 Pro"), older)

    def test_incompatible_runtime_fails_before_creating_device(self):
        for runtime in self.inventory["runtimes"]:
            runtime["supportedDeviceTypes"] = []
        with tempfile.TemporaryDirectory() as directory, contextlib.chdir(directory):
            with patch.object(smoke, "simctl", side_effect=self.simctl_result) as simctl:
                with self.assertRaisesRegex(RuntimeError, "Compatible iOS 27 simulator runtime missing"):
                    smoke.main(devices=("iPhone 18 Pro",))
            self.assertEqual([call.args[0] for call in simctl.call_args_list], ["list"])

    def test_selected_device_does_not_launch_other_model(self):
        with tempfile.TemporaryDirectory() as directory, contextlib.chdir(directory):
            with (
                patch.object(smoke, "simctl", side_effect=self.simctl_result) as simctl,
                patch.object(smoke, "boot_simulator"),
                patch.object(smoke, "install_app"),
                patch.object(smoke, "wait_for_handshake"),
                patch.object(smoke.subprocess, "Popen"),
                patch.object(smoke, "cleanup_simulator"),
                contextlib.redirect_stdout(io.StringIO()),
            ):
                smoke.main(devices=("iPhone 18 Pro",))
            creates = [call.args for call in simctl.call_args_list if call.args[0] == "create"]
            self.assertEqual(len(creates), 1)
            self.assertEqual(creates[0][2], "type-iPhone 18 Pro")

    def simctl_result(self, *args, **kwargs):
        if args[0] == "list":
            return subprocess.CompletedProcess(args, 0, stdout=json.dumps(self.inventory))
        if args[0] == "create":
            return subprocess.CompletedProcess(args, 0, stdout=f"fresh-{args[2].removeprefix('type-')}\n")
        if args[0] == "bootstatus":
            kwargs["stdout"].write("Status=4294967295, isTerminal=YES\n\tFinished\n")
        return subprocess.CompletedProcess(args, 0)

    def test_boot_waits_for_readiness(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(smoke, "simctl", side_effect=self.simctl_result) as simctl:
                smoke.boot_simulator("iPhone", "device-id", Path(directory) / "boot.log")
                commands = [call.args for call in simctl.call_args_list]
                self.assertEqual(commands, [("boot", "device-id"), ("bootstatus", "device-id", "-b")])
                self.assertEqual(simctl.call_args.kwargs["timeout"], 600)

    def test_already_booted_device_does_not_need_finished_status(self):
        def simctl_result(*args, **kwargs):
            if args[0] == "boot":
                kwargs["stdout"].write("Device already booted, nothing to do.\n")
            return subprocess.CompletedProcess(args, 0)

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "boot.log"
            with patch.object(smoke, "simctl", side_effect=simctl_result):
                smoke.boot_simulator("iPhone", "device-id", path)
            self.assertIn("Device already booted", path.read_text())

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

    def test_persistent_migration_failure_recreates_device_then_fails(self):
        def simctl_result(*args, **kwargs):
            if args[0] == "bootstatus":
                kwargs["stdout"].write("Status=3, isTerminal=YES\n\tData Migration Failed\n")
            return self.simctl_result(*args, **kwargs)

        with tempfile.TemporaryDirectory() as directory, contextlib.chdir(directory):
            with (
                patch.object(smoke, "simctl", side_effect=simctl_result) as simctl,
                patch.object(smoke, "cleanup_simulator") as cleanup,
                patch.object(smoke, "collect_diagnostics") as diagnostics,
                patch.object(smoke.subprocess, "Popen") as launch,
                contextlib.redirect_stdout(io.StringIO()),
            ):
                with self.assertRaisesRegex(RuntimeError, "simulator data migration failed"):
                    smoke.main()
            commands = [call.args for call in simctl.call_args_list]
            create = ("create", "Nightwave Plaza smoke - iPhone Duo", "type-iPhone Duo", self.runtime_id)
            self.assertEqual(commands.count(create), smoke.BOOT_ATTEMPTS)
            self.assertNotIn("install", [call.args[0] for call in simctl.call_args_list])
            launch.assert_not_called()
            diagnostics.assert_called_once()
            self.assertEqual(cleanup.call_count, smoke.BOOT_ATTEMPTS)
            for attempt in range(1, smoke.BOOT_ATTEMPTS + 1):
                log = Path(f"build/diagnostics/iPhone Duo-boot-attempt-{attempt}.log").read_text()
                self.assertIn("Data Migration Failed", log)

    def test_migration_failure_recreates_device_and_recovers(self):
        boot_count = 0

        def simctl_result(*args, **kwargs):
            nonlocal boot_count
            if args[0] == "bootstatus":
                boot_count += 1
                if boot_count == 1:
                    kwargs["stdout"].write("Status=3, isTerminal=YES\n\tData Migration Failed\n")
                else:
                    kwargs["stdout"].write("Status=4294967295, isTerminal=YES\n\tFinished\n")
            return self.simctl_result(*args, **kwargs)

        process = Mock()
        process.poll.return_value = None

        def launch(*args, **kwargs):
            kwargs["stdout"].write("Vue App is ready!\n")
            kwargs["stdout"].flush()
            return process

        with tempfile.TemporaryDirectory() as directory, contextlib.chdir(directory):
            with (
                patch.object(smoke, "simctl", side_effect=simctl_result) as simctl,
                patch.object(smoke.subprocess, "Popen", side_effect=launch),
                patch.object(smoke, "cleanup_simulator") as cleanup,
                patch.object(smoke, "collect_diagnostics") as diagnostics,
                patch.object(smoke.time, "sleep"),
                contextlib.redirect_stdout(io.StringIO()) as output,
            ):
                smoke.main()
            commands = [call.args for call in simctl.call_args_list]
            create = ("create", "Nightwave Plaza smoke - iPhone Duo", "type-iPhone Duo", self.runtime_id)
            self.assertEqual(commands.count(create), 2)
            self.assertIn("install", [call.args[0] for call in simctl.call_args_list])
            self.assertIn("iPhone Duo: recreating simulator after data migration failure", output.getvalue())
            self.assertIn("iPhone Duo: native launch and web bridge handshake passed", output.getvalue())
            diagnostics.assert_not_called()
            self.assertEqual(cleanup.call_count, 3)

    def test_incomplete_boot_prevents_install(self):
        def simctl_result(*args, **kwargs):
            if args[0] == "bootstatus":
                kwargs["stdout"].write("Status=2, isTerminal=NO\n\tWaiting on Data Migration\n")
                return subprocess.CompletedProcess(args, 0)
            return self.simctl_result(*args, **kwargs)

        with tempfile.TemporaryDirectory() as directory, contextlib.chdir(directory):
            with (
                patch.object(smoke, "simctl", side_effect=simctl_result) as simctl,
                patch.object(smoke, "cleanup_simulator"),
                patch.object(smoke, "collect_diagnostics"),
                contextlib.redirect_stdout(io.StringIO()),
            ):
                with self.assertRaisesRegex(RuntimeError, "boot did not report Finished"):
                    smoke.main()
            self.assertNotIn("install", [call.args[0] for call in simctl.call_args_list])

    def test_install_timeout_retains_output_and_cause(self):
        error = subprocess.TimeoutExpired("install", 300)

        def timeout(*args, **kwargs):
            kwargs["stdout"].write("Waiting for installation service\n")
            raise error

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "install.log"
            with patch.object(smoke, "simctl", side_effect=timeout) as simctl:
                with self.assertRaisesRegex(RuntimeError, "app installation timed out") as raised:
                    smoke.install_app("iPhone", "device-id", Path("App.app"), path)
            self.assertEqual(simctl.call_args.kwargs["timeout"], 300)
            self.assertIs(raised.exception.__cause__, error)
            self.assertIn("Waiting for installation service", path.read_text())

    def test_failed_install_collects_diagnostics_before_cleanup(self):
        events = []
        failure = RuntimeError("Installation failed")
        with tempfile.TemporaryDirectory() as directory, contextlib.chdir(directory):
            with (
                patch.object(smoke, "simctl", side_effect=self.simctl_result),
                patch.object(smoke, "install_app", side_effect=failure),
                patch.object(smoke, "collect_diagnostics", side_effect=lambda *args, **kwargs: events.append("diagnostics")),
                patch.object(smoke, "cleanup_simulator", side_effect=lambda *args: events.append("cleanup")),
                contextlib.redirect_stdout(io.StringIO()),
            ):
                with self.assertRaises(RuntimeError) as raised:
                    smoke.main()
            self.assertIs(raised.exception, failure)
            self.assertEqual(events, ["diagnostics", "cleanup"])

    def test_diagnostics_timeouts_do_not_stop_collection(self):
        with tempfile.TemporaryDirectory() as directory:
            with (
                patch.object(smoke.subprocess, "run", side_effect=subprocess.TimeoutExpired("diagnostic", 20)) as run,
                contextlib.redirect_stdout(io.StringIO()),
            ):
                smoke.collect_diagnostics("iPhone", "device-id", Path(directory))
            self.assertEqual(run.call_count, 3)
            self.assertEqual(len(list(Path(directory).iterdir())), 3)

    def test_shutdown_timeout_does_not_replace_boot_failure(self):
        failure = RuntimeError("Original boot failure")
        with tempfile.TemporaryDirectory() as directory, contextlib.chdir(directory):
            with (
                patch.object(smoke, "simctl", side_effect=self.simctl_result),
                patch.object(smoke, "boot_simulator", side_effect=failure),
                patch.object(smoke, "collect_diagnostics"),
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

    def test_duo_screenshots_use_both_displays(self):
        with patch.object(smoke, "simctl") as simctl:
            smoke.capture_screenshot("iPhone Duo", "device-id", Path("Duo.png"), timeout=30)
        self.assertEqual([command.args for command in simctl.call_args_list], [
            ("io", "device-id", "screenshot", "--display=1", "Duo-small.png"),
            ("io", "device-id", "screenshot", "--display=3", "Duo-large.png"),
        ])
        self.assertTrue(all(command.kwargs["timeout"] == 30 for command in simctl.call_args_list))

    def test_screenshot_timeout_does_not_skip_other_display(self):
        def simctl_result(*args, **kwargs):
            if "--display=1" in args:
                raise subprocess.TimeoutExpired("screenshot", 30)
            return subprocess.CompletedProcess(args, 0)

        with (
            patch.object(smoke, "simctl", side_effect=simctl_result) as simctl,
            contextlib.redirect_stdout(io.StringIO()) as output,
        ):
            with self.assertRaises(subprocess.TimeoutExpired):
                smoke.capture_screenshot("iPhone Duo", "device-id", Path("Duo.png"), timeout=30)
        self.assertEqual([command.args for command in simctl.call_args_list], [
            ("io", "device-id", "screenshot", "--display=1", "Duo-small.png"),
            ("io", "device-id", "screenshot", "--display=3", "Duo-large.png"),
        ])
        self.assertIn("Warning: could not capture Duo-small.png", output.getvalue())

    def run_successful_main(self, screenshots):
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
                smoke.main(screenshots=screenshots)
            commands = [call.args for call in simctl.call_args_list]
            for name in self.names:
                self.assertIn(("create", f"Nightwave Plaza smoke - {name}", f"type-{name}", self.runtime_id), commands)
                self.assertIn(("install", f"fresh-{name}", "build/DerivedData/Build/Products/Debug-iphonesimulator/Nightwave Plaza.app"), commands)
                self.assertIn(f"{name}: native launch and web bridge handshake passed", output.getvalue())
            self.assertFalse(any("stale-" in str(command) for command in commands))
            self.assertEqual(cleanup.call_count, 2)
            return commands

    def test_default_smoke_skips_screenshots(self):
        commands = self.run_successful_main(screenshots=False)
        self.assertFalse(any("screenshot" in str(command) for command in commands))

    def test_screenshot_run_captures_both_devices(self):
        commands = self.run_successful_main(screenshots=True)
        self.assertIn(
            ("io", "fresh-iPhone Duo", "screenshot", "--display=1", "build/diagnostics/iPhone Duo-small.png"),
            commands,
        )
        self.assertIn(
            ("io", "fresh-iPhone Duo", "screenshot", "--display=3", "build/diagnostics/iPhone Duo-large.png"),
            commands,
        )
        self.assertIn(
            ("io", "fresh-iPhone 18 Pro", "screenshot", "build/diagnostics/iPhone 18 Pro.png"),
            commands,
        )

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


class HandshakeTests(unittest.TestCase):
    def wait_for_app(self, ready_after=None, exits_after=None):
        elapsed = 0
        process = Mock()
        process.poll.side_effect = lambda: 0 if exits_after is not None and elapsed >= exits_after else None
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "app.log"
            path.write_text("Local server started on port 8080\n")

            def advance(seconds):
                nonlocal elapsed
                elapsed += seconds
                if ready_after is not None and elapsed >= ready_after:
                    path.write_text("Vue App is ready!\n")

            with (
                patch.object(smoke.time, "monotonic", side_effect=lambda: elapsed),
                patch.object(smoke.time, "sleep", side_effect=advance),
                contextlib.redirect_stdout(io.StringIO()),
            ):
                smoke.wait_for_handshake("iPhone", process, path)
        return elapsed

    def test_slow_web_startup_can_complete_after_ninety_seconds(self):
        elapsed = self.wait_for_app(ready_after=120)
        self.assertEqual(elapsed, 123)

    def test_native_startup_without_bridge_still_fails(self):
        with self.assertRaisesRegex(RuntimeError, "no web bridge handshake within 300 seconds"):
            self.wait_for_app()

    def test_app_exit_before_handshake_fails_immediately(self):
        with self.assertRaisesRegex(RuntimeError, "app exited before completing smoke check"):
            self.wait_for_app(exits_after=1)

    def test_app_exit_after_handshake_still_fails(self):
        with self.assertRaisesRegex(RuntimeError, "app exited after web UI initialization"):
            self.wait_for_app(ready_after=120, exits_after=121)


class SubprocessTests(unittest.TestCase):
    def test_wait_with_redirected_output_observes_real_child_exit(self):
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / "finished"
            with (Path(directory) / "child.log").open("w") as log:
                result = subprocess.run(
                    [sys.executable, "-c", (
                        "import pathlib, sys, time; time.sleep(0.05); "
                        "pathlib.Path(sys.argv[1]).write_text('done'); sys.exit(7)"
                    ), str(marker)],
                    stdout=log, stderr=subprocess.STDOUT, check=False, timeout=5,
                )
            self.assertEqual(result.returncode, 7)
            self.assertEqual(marker.read_text(), "done")

    def test_real_child_timeout_is_enforced(self):
        with self.assertRaises(subprocess.TimeoutExpired):
            subprocess.run([sys.executable, "-c", "import time; time.sleep(5)"], timeout=0.1, check=True)


if __name__ == "__main__":
    unittest.main()
