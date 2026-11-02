"""Launch the real bundled SPA on two iOS 27 simulators; require its bridge handshake."""

import json
from pathlib import Path
import subprocess
import time


BOOT_TIMEOUT = 600


def simctl(*args, **kwargs):
    return subprocess.run(["xcrun", "simctl", *args], check=True, **kwargs)


def boot_simulator(name, udid, log_path):
    print(f"{name}: waiting up to {BOOT_TIMEOUT} seconds for simulator boot ({udid})", flush=True)
    with log_path.open("w") as log:
        try:
            simctl("boot", udid, stdout=log, stderr=subprocess.STDOUT, timeout=60)
            simctl("bootstatus", udid, "-b", stdout=log, stderr=subprocess.STDOUT, timeout=BOOT_TIMEOUT)
        except subprocess.TimeoutExpired as error:
            raise RuntimeError(f"{name}: simulator boot timed out; see {log_path}") from error
    # Bootstatus can exit successfully after a failed data migration
    if "Data Migration Failed" in log_path.read_text():
        raise RuntimeError(f"{name}: simulator data migration failed; see {log_path}")


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


def main():
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
        print(f"{name}: creating a clean simulator with {runtime['identifier']}", flush=True)
        udid = simctl(
            "create", f"Nightwave Plaza smoke - {name}", device_types[name], runtime["identifier"],
            capture_output=True, text=True, timeout=60,
        ).stdout.strip()
        if not udid:
            raise RuntimeError(f"{name}: simulator creation returned no UDID")
        log_path = diagnostics / f"{name}.log"
        boot_log_path = diagnostics / f"{name}-boot.log"
        process = None
        try:
            boot_simulator(name, udid, boot_log_path)
            simctl("install", udid, str(app), timeout=60)
            with log_path.open("w") as log:
                process = subprocess.Popen(
                    ["xcrun", "simctl", "launch", "--console-pty", "--terminate-running-process", udid, bundle_id],
                    stdout=log,
                    stderr=subprocess.STDOUT,
                )
                deadline = time.monotonic() + 90
                while time.monotonic() < deadline:
                    if process.poll() is not None:
                        raise RuntimeError(f"{name}: app exited before completing smoke check")
                    if "Vue App is ready!" in log_path.read_text():
                        time.sleep(3)
                        if process.poll() is not None:
                            raise RuntimeError(f"{name}: app exited after web UI initialization")
                        break
                    time.sleep(1)
                else:
                    raise RuntimeError(f"{name}: no web bridge handshake within 90 seconds")
                simctl("io", udid, "screenshot", str(diagnostics / f"{name}.png"), timeout=30)
                print(f"{name}: native launch and web bridge handshake passed", flush=True)
        finally:
            cleanup_simulator(udid, bundle_id, process)
            for path in (boot_log_path, log_path):
                if path.exists():
                    print(f"--- {path.name} ---\n{path.read_text()}", flush=True)


if __name__ == "__main__":
    main()
