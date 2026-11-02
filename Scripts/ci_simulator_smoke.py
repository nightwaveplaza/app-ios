"""Launch the real bundled SPA on two iOS 27 simulators; require its bridge handshake."""

import json
from pathlib import Path
import subprocess
import sys
import time


BOOT_TIMEOUT = 600
BOOT_ATTEMPTS = 2
INSTALL_TIMEOUT = 300
HANDSHAKE_TIMEOUT = 300


def simctl(*args, **kwargs):
    return subprocess.run(["xcrun", "simctl", *args], check=True, **kwargs)


class SimulatorMigrationError(RuntimeError):
    pass


def boot_simulator(name, udid, log_path):
    print(f"{name}: waiting up to {BOOT_TIMEOUT} seconds for simulator boot ({udid})", flush=True)
    with log_path.open("w") as log:
        try:
            simctl("boot", udid, stdout=log, stderr=subprocess.STDOUT, timeout=60)
            simctl("bootstatus", udid, "-b", stdout=log, stderr=subprocess.STDOUT, timeout=BOOT_TIMEOUT)
        except subprocess.TimeoutExpired as error:
            raise RuntimeError(f"{name}: simulator boot timed out; see {log_path}") from error
    # Bootstatus can exit successfully after a failed data migration
    boot_status = log_path.read_text()
    if "Data Migration Failed" in boot_status:
        raise SimulatorMigrationError(f"{name}: simulator data migration failed; see {log_path}")
    finished = any(line.strip() == "Finished" for line in boot_status.splitlines())
    if not finished and "Device already booted" not in boot_status:
        raise RuntimeError(f"{name}: simulator boot did not report Finished; see {log_path}")


def install_app(name, udid, app, log_path):
    print(f"{name}: installing app (timeout {INSTALL_TIMEOUT} seconds)", flush=True)
    started = time.monotonic()
    with log_path.open("w") as log:
        try:
            simctl("install", udid, str(app), stdout=log, stderr=subprocess.STDOUT, timeout=INSTALL_TIMEOUT)
        except subprocess.TimeoutExpired as error:
            raise RuntimeError(f"{name}: app installation timed out; see {log_path}") from error
    print(f"{name}: app installed in {time.monotonic() - started:.1f} seconds", flush=True)


def wait_for_handshake(name, process, log_path):
    print(f"{name}: waiting up to {HANDSHAKE_TIMEOUT} seconds for web bridge handshake", flush=True)
    started = time.monotonic()
    deadline = started + HANDSHAKE_TIMEOUT
    next_progress = started + 30
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError(f"{name}: app exited before completing smoke check")
        if "Vue App is ready!" in log_path.read_text(errors="replace"):
            time.sleep(3)
            if process.poll() is not None:
                raise RuntimeError(f"{name}: app exited after web UI initialization")
            print(f"{name}: web bridge ready in {time.monotonic() - started:.1f} seconds", flush=True)
            return
        now = time.monotonic()
        if now >= next_progress:
            print(f"{name}: still waiting for web bridge ({now - started:.0f} seconds)", flush=True)
            next_progress = now + 30
        time.sleep(1)
    raise RuntimeError(f"{name}: no web bridge handshake within {HANDSHAKE_TIMEOUT} seconds")


def capture_screenshot(name, udid, path, timeout):
    displays = (("small", 1), ("large", 3)) if name == "iPhone Duo" else ((None, None),)
    failure = None
    for suffix, display_id in displays:
        screenshot_path = path if suffix is None else path.with_name(f"{path.stem}-{suffix}{path.suffix}")
        display_args = [] if display_id is None else [f"--display={display_id}"]
        try:
            simctl("io", udid, "screenshot", *display_args, str(screenshot_path), timeout=timeout)
        except (OSError, subprocess.SubprocessError) as error:
            print(f"Warning: could not capture {screenshot_path}: {error}", flush=True)
            if failure is None:
                failure = error
    if failure is not None:
        raise failure


def collect_diagnostics(name, udid, diagnostics, screenshots=False):
    if screenshots:
        try:
            capture_screenshot(name, udid, diagnostics / f"{name}-failure.png", timeout=60)
        except (OSError, subprocess.SubprocessError):
            pass
    commands = (
        ("state.json", ["xcrun", "simctl", "list", "devices", "--json"]),
        ("processes.log", ["ps", "-axo", "pid,ppid,state,etime,comm"]),
        ("system.log", [
            "xcrun", "simctl", "spawn", udid, "log", "show", "--last", "5m", "--style", "compact",
            "--predicate", 'process == "installd" OR process == "SpringBoard" OR process == "launchd_sim"',
        ]),
    )
    for suffix, command in commands:
        path = diagnostics / f"{name}-{suffix}"
        print(f"{name}: collecting {path.name}", flush=True)
        try:
            with path.open("w") as log:
                subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=False, timeout=20)
        except (OSError, subprocess.TimeoutExpired) as error:
            print(f"Warning: could not collect {path.name}: {error}", flush=True)


def cleanup_simctl(*args, timeout):
    try:
        result = subprocess.run(["xcrun", "simctl", *args], check=False, timeout=timeout)
        if result.returncode:
            print(f"Warning: simctl {' '.join(args)} exited with {result.returncode}", flush=True)
    except (OSError, subprocess.TimeoutExpired) as error:
        # Cleanup must preserve the original smoke check failure
        print(f"Warning: simulator cleanup failed: {error}", flush=True)


def cleanup_simulator(udid, bundle_id, process):
    if process is not None:
        cleanup_simctl("terminate", udid, bundle_id, timeout=30)
        try:
            if process.poll() is None:
                process.terminate()
            try:
                process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=15)
        except (OSError, subprocess.TimeoutExpired) as error:
            print(f"Warning: launch process cleanup failed: {error}", flush=True)
    cleanup_simctl("shutdown", udid, timeout=60)
    cleanup_simctl("delete", udid, timeout=60)


def main(screenshots=False):
    print(f"Smoke check interpreter: {sys.executable} ({sys.version.split()[0]})", flush=True)
    app = Path("build/DerivedData/Build/Products/Debug-iphonesimulator/Nightwave Plaza.app")
    diagnostics = Path("build/diagnostics")
    diagnostics.mkdir(parents=True, exist_ok=True)
    inventory = json.loads(simctl("list", "--json", capture_output=True, timeout=60).stdout)
    (diagnostics / "devices.json").write_text(json.dumps(inventory, indent=2))
    runtimes = [
        runtime for runtime in inventory["runtimes"]
        if runtime["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS-27-")
        and runtime.get("isAvailable", False)
    ]
    if not runtimes:
        raise RuntimeError("Required iOS 27 simulator runtime missing")
    runtime = max(runtimes, key=lambda entry: tuple(int(part) for part in entry["version"].split(".")))
    device_types = {entry["name"]: entry["identifier"] for entry in inventory["devicetypes"]}
    bundle_id = "com.nightwaveplaza.NightwavePlaza"

    for name in ("iPhone Duo", "iPhone 18 Pro"):
        if name not in device_types:
            raise RuntimeError(f"Required simulator device type missing: {name}")
        for attempt in range(1, BOOT_ATTEMPTS + 1):
            print(f"{name}: creating a clean simulator with {runtime['identifier']}", flush=True)
            udid = simctl(
                "create", f"Nightwave Plaza smoke - {name}", device_types[name], runtime["identifier"],
                capture_output=True, text=True, timeout=60,
            ).stdout.strip()
            if not udid:
                raise RuntimeError(f"{name}: simulator creation returned no UDID")
            log_path = diagnostics / f"{name}-attempt-{attempt}.log"
            boot_log_path = diagnostics / f"{name}-boot-attempt-{attempt}.log"
            install_log_path = diagnostics / f"{name}-install-attempt-{attempt}.log"
            process = None
            try:
                boot_simulator(name, udid, boot_log_path)
                install_app(name, udid, app, install_log_path)
                with log_path.open("w") as log:
                    process = subprocess.Popen(
                        ["xcrun", "simctl", "launch", "--console-pty", "--terminate-running-process", udid, bundle_id],
                        stdout=log,
                        stderr=subprocess.STDOUT,
                    )
                    wait_for_handshake(name, process, log_path)
                    if screenshots:
                        capture_screenshot(name, udid, diagnostics / f"{name}.png", timeout=30)
                    print(f"{name}: native launch and web bridge handshake passed", flush=True)
            except SimulatorMigrationError:
                if attempt == BOOT_ATTEMPTS:
                    collect_diagnostics(name, udid, diagnostics, screenshots=screenshots)
                    raise
                print(f"{name}: recreating simulator after data migration failure", flush=True)
            except Exception:
                collect_diagnostics(name, udid, diagnostics, screenshots=screenshots)
                raise
            else:
                break
            finally:
                cleanup_simulator(udid, bundle_id, process)
                for path in (boot_log_path, install_log_path, log_path):
                    if path.exists():
                        print(f"--- {path.name} ---\n{path.read_text()}", flush=True)


if __name__ == "__main__":
    main(screenshots="--screenshots" in sys.argv[1:])
