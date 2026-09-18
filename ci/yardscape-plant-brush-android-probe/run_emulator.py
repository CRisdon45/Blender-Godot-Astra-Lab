#!/usr/bin/env python3
"""Install and measure the retained planting probe on one clean Android AVD."""
import hashlib
import json
import os
from pathlib import Path
import re
import statistics
import subprocess
import time

PACKAGE = "studio.yardscape.plantingprobe"
APK_NAME = "yardscape-retained-planting-debug.apk"
AVD_NAME = "yardscape-planting-api35"
SERIAL = "emulator-5554"
RUN_COUNT = 3
MARKER = "YARDSCAPE_BENCHMARK_JSON="


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def command(arguments: list[str], *, timeout: int = 60, check: bool = True, binary: bool = False):
    result = subprocess.run(
        arguments,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=timeout,
        check=False,
        text=not binary,
    )
    if check and result.returncode:
        output = result.stdout if isinstance(result.stdout, str) else result.stdout.decode("utf-8", "replace")
        raise RuntimeError(f"Command failed ({result.returncode}): {' '.join(arguments)}\n{output[-4000:]}")
    return result.stdout


def main() -> None:
    if os.environ.get("GITHUB_ACTIONS") != "true":
        raise RuntimeError("Emulator evidence is restricted to the clean CI worker")
    sdk = Path(os.environ["ANDROID_SDK_ROOT"])
    adb_path = sdk / "platform-tools/adb"
    emulator_path = sdk / "emulator/emulator"
    for path in (adb_path, emulator_path):
        if not path.is_file():
            raise FileNotFoundError(path)
    build = Path(os.environ["RUNNER_TEMP"]) / "plant-brush-android-build"
    apk = build / APK_NAME
    if not apk.is_file():
        raise FileNotFoundError(apk)
    output = Path(os.environ["RUNNER_TEMP"]) / "plant-brush-android-evidence"
    output.mkdir(exist_ok=False)
    emulator_log_path = output / "emulator.log"
    adb = lambda *parts, timeout=60, check=True, binary=False: command(
        [str(adb_path), "-s", SERIAL, *parts], timeout=timeout, check=check, binary=binary
    )
    report = {
        "status": "failed",
        "scope": "hosted_android_emulator_only",
        "physical_device": False,
        "physical_device_gate": "unrun",
        "run_count": RUN_COUNT,
        "apk_sha256": sha(apk),
        "public_commit": os.environ.get("GITHUB_SHA"),
        "caveat": "Emulator timings do not establish Galaxy Tab S10 FE performance, thermals, touch quality, or S Pen behavior.",
    }
    emulator_process = None
    emulator_log = emulator_log_path.open("w", encoding="utf-8")
    try:
        command([str(adb_path), "start-server"], timeout=30)
        emulator_process = subprocess.Popen(
            [
                str(emulator_path),
                "-avd", AVD_NAME,
                "-port", "5554",
                "-no-window",
                "-noaudio",
                "-no-boot-anim",
                "-no-snapshot",
                "-gpu", "swiftshader_indirect",
                "-camera-back", "none",
                "-camera-front", "none",
                "-netdelay", "none",
                "-netspeed", "full",
            ],
            stdout=emulator_log,
            stderr=subprocess.STDOUT,
            env=os.environ.copy(),
            start_new_session=True,
        )
        deadline = time.monotonic() + 300
        booted = False
        while time.monotonic() < deadline:
            if emulator_process.poll() is not None:
                raise RuntimeError(f"Emulator exited during boot with {emulator_process.returncode}")
            devices = command([str(adb_path), "devices"], timeout=20)
            if f"{SERIAL}\tdevice" in devices:
                completed = adb("shell", "getprop", "sys.boot_completed", timeout=20, check=False).strip()
                if completed == "1":
                    booted = True
                    break
            time.sleep(2)
        if not booted:
            raise TimeoutError("Android emulator did not complete boot in 300 seconds")
        adb("shell", "settings", "put", "global", "window_animation_scale", "0")
        adb("shell", "settings", "put", "global", "transition_animation_scale", "0")
        adb("shell", "settings", "put", "global", "animator_duration_scale", "0")
        adb("shell", "wm", "size", "1920x1200")
        adb("shell", "wm", "density", "240")
        adb("shell", "settings", "put", "system", "accelerometer_rotation", "0")
        adb("shell", "settings", "put", "system", "user_rotation", "1")
        install_log = adb("install", "-r", str(apk), timeout=180)
        (output / "install.log").write_text(install_log, encoding="utf-8")
        if "Success" not in install_log:
            raise RuntimeError("ADB did not confirm APK installation")
        package_dump = adb("shell", "dumpsys", "package", PACKAGE, timeout=60)
        (output / "package.txt").write_text(package_dump, encoding="utf-8")
        debuggable = bool(re.search(r"\bDEBUGGABLE\b", package_dump))
        if not debuggable:
            raise RuntimeError("Installed benchmark package is not debuggable")
        resolved = adb(
            "shell", "cmd", "package", "resolve-activity", "--brief",
            "-a", "android.intent.action.MAIN",
            "-c", "android.intent.category.LAUNCHER",
            PACKAGE,
        )
        components = [line.strip() for line in resolved.splitlines() if "/" in line]
        if not components:
            raise RuntimeError(f"Could not resolve launch activity: {resolved}")
        component = components[-1]
        device = {
            "serial": SERIAL,
            "avd": AVD_NAME,
            "model": adb("shell", "getprop", "ro.product.model").strip(),
            "android_release": adb("shell", "getprop", "ro.build.version.release").strip(),
            "api": adb("shell", "getprop", "ro.build.version.sdk").strip(),
            "abi": adb("shell", "getprop", "ro.product.cpu.abi").strip(),
            "hardware": adb("shell", "getprop", "ro.hardware").strip(),
            "egl": adb("shell", "getprop", "ro.hardware.egl").strip(),
            "wm_size": adb("shell", "wm", "size").strip(),
            "wm_density": adb("shell", "wm", "density").strip(),
            "launch_component": component,
            "debuggable": debuggable,
        }
        runs = []
        for run_number in range(1, RUN_COUNT + 1):
            label = f"run-{run_number:02d}"
            adb("shell", "am", "force-stop", PACKAGE)
            adb("logcat", "-c")
            adb("shell", "dumpsys", "gfxinfo", PACKAGE, "reset", check=False)
            launch = adb("shell", "am", "start", "-W", "-n", component, timeout=60)
            (output / f"{label}-launch.txt").write_text(launch, encoding="utf-8")
            if "Status: ok" not in launch:
                raise RuntimeError(f"Launch was not confirmed for {label}")
            deadline = time.monotonic() + 55
            benchmark = None
            screenshot_taken = False
            while time.monotonic() < deadline:
                logs = adb("logcat", "-d", "-v", "threadtime", timeout=30)
                if not screenshot_taken and time.monotonic() > deadline - 49:
                    screenshot = adb("exec-out", "screencap", "-p", timeout=30, binary=True)
                    if not screenshot.startswith(b"\x89PNG\r\n\x1a\n"):
                        raise RuntimeError(f"Invalid measuring screenshot for {label}")
                    (output / f"{label}-measuring.png").write_bytes(screenshot)
                    screenshot_taken = True
                marked = [line.split(MARKER, 1)[1] for line in logs.splitlines() if MARKER in line]
                if marked:
                    benchmark = json.loads(marked[-1].strip())
                    break
                time.sleep(2)
            logs = adb("logcat", "-d", "-v", "threadtime", timeout=30)
            (output / f"{label}-logcat.txt").write_text(logs, encoding="utf-8")
            if benchmark is None:
                raise TimeoutError(f"No in-app benchmark report for {label}")
            fatal = re.search(r"FATAL EXCEPTION|Fatal signal|SCRIPT ERROR:|SHADER ERROR:", logs, re.IGNORECASE)
            if fatal:
                raise RuntimeError(f"Crash or Godot source failure in {label}: {fatal.group(0)}")
            if benchmark.get("recipe") != "fixed-center-brush-card-cloud/2":
                raise RuntimeError(f"Wrong retained recipe in {label}")
            expected = {"trees": 6, "shrubs": 12, "plantings": 18, "visible_meshes": 36}
            for key, value in expected.items():
                if benchmark.get(key) != value:
                    raise RuntimeError(f"Unexpected {key} in {label}: {benchmark.get(key)}")
            if int(benchmark.get("sample_count", 0)) < 10:
                raise RuntimeError(f"Insufficient rendered frame samples in {label}")
            if int(benchmark.get("viewport_width", 0)) <= int(benchmark.get("viewport_height", 0)):
                raise RuntimeError(f"Expected landscape viewport in {label}")
            if int(benchmark.get("visible_triangles", 0)) < 40_000:
                raise RuntimeError(f"Unexpectedly small planting workload in {label}")
            meminfo = adb("shell", "dumpsys", "meminfo", PACKAGE, timeout=60)
            gfxinfo = adb("shell", "dumpsys", "gfxinfo", PACKAGE, "framestats", timeout=60)
            (output / f"{label}-meminfo.txt").write_text(meminfo, encoding="utf-8")
            (output / f"{label}-gfxinfo.txt").write_text(gfxinfo, encoding="utf-8")
            adb("shell", "uiautomator", "dump", "/sdcard/yardscape-window.xml", timeout=30, check=False)
            ui_tree = adb("exec-out", "cat", "/sdcard/yardscape-window.xml", timeout=30, check=False)
            (output / f"{label}-window.xml").write_text(ui_tree, encoding="utf-8")
            screenshot = adb("exec-out", "screencap", "-p", timeout=30, binary=True)
            if not screenshot.startswith(b"\x89PNG\r\n\x1a\n"):
                raise RuntimeError(f"Invalid completion screenshot for {label}")
            (output / f"{label}-complete.png").write_bytes(screenshot)
            runs.append({
                "run": run_number,
                "in_app": benchmark,
                "gfxinfo_has_frame_summary": "Total frames rendered" in gfxinfo,
                "meminfo_process_present": "No process found" not in meminfo,
            })
        fps_values = [float(item["in_app"]["average_fps"]) for item in runs]
        p95_values = [float(item["in_app"]["p95_ms"]) for item in runs]
        report.update(
            status="android_emulator_plumbing_passed",
            device=device,
            runs=runs,
            aggregate={
                "median_average_fps": round(statistics.median(fps_values), 2),
                "minimum_average_fps": round(min(fps_values), 2),
                "worst_p95_ms": round(max(p95_values), 3),
                "threshold_applied": False,
            },
        )
    except Exception as error:
        report["failure"] = f"{type(error).__name__}: {error}"
        raise
    finally:
        (output / "evidence-report.json").write_text(
            json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        if emulator_process is not None:
            try:
                adb("emu", "kill", timeout=20, check=False)
            except Exception:
                pass
            try:
                emulator_process.wait(timeout=20)
            except subprocess.TimeoutExpired:
                emulator_process.terminate()
        emulator_log.close()


if __name__ == "__main__":
    main()
