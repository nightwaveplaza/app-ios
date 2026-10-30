"""Launch the real bundled SPA on two iOS 27 simulators; require its bridge handshake."""

import json
from pathlib import Path
import subprocess
import time


def simctl(*args, **kwargs):
    return subprocess.run(["xcrun", "simctl", *args], check=True, **kwargs)


def main():
    app = Path("build/DerivedData/Build/Products/Debug-iphonesimulator/Nightwave Plaza.app")
    diagnostics = Path("build/diagnostics")
    diagnostics.mkdir(parents=True, exist_ok=True)
    devices = json.loads(simctl("list", "devices", "available", "--json", capture_output=True).stdout)
    bundle_id = "com.nightwaveplaza.NightwavePlaza"

    for name in ("iPhone Duo", "iPhone 18 Pro"):
        candidates = [
            device
            for runtime, entries in devices["devices"].items()
            if "iOS-27-" in runtime
            for device in entries
            if device["name"] == name and device.get("isAvailable", False)
        ]
        if not candidates:
            raise RuntimeError(f"Required iOS 27 simulator missing: {name}")
        device = candidates[0]
        udid = device["udid"]
        log_path = diagnostics / f"{name}.log"
        process = None
        try:
            if device["state"] != "Booted":
                simctl("boot", udid, timeout=60)
            simctl("bootstatus", udid, "-b", timeout=180)
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
            if process is not None:
                subprocess.run(["xcrun", "simctl", "terminate", udid, bundle_id], check=False, timeout=30)
                if process.poll() is None:
                    process.terminate()
                process.wait(timeout=15)
            subprocess.run(["xcrun", "simctl", "shutdown", udid], check=False, timeout=60)
            if log_path.exists():
                print(log_path.read_text(), flush=True)


if __name__ == "__main__":
    main()
