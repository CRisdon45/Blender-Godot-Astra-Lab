#!/usr/bin/env python3
"""Collect reproducible retained-planting evidence from one physical Android device."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import shutil
import statistics
import subprocess
import time

from run_emulator import (
    MARKER,
    MEASURING_MARKER,
    PACKAGE,
    READY_MARKER,
    capture_device_screenshot,
    pull_app_screenshot,
    sha,
)

RUN_COUNT = 3
EXPECTED_RECIPE = "fixed-center-brush-card-cloud/2"
EXPECTED_SURFACE_STYLE = "northstar-illustrated-mass/2"
EXPECTED_WORKLOAD = {
    "fan_tex_trees": 3,
    "palo_verde_trees": 3,
    "trees": 6,
    "shrubs": 12,
    "plantings": 18,
    "visible_meshes": 36,
    "visible_triangles": 44_718,
}
PROVISIONAL_MINIMUM_AVERAGE_FPS = 30.0
PROVISIONAL_MAXIMUM_P95_MS = 50.0
SOFTWARE_RENDERER_PATTERN = re.compile(
    r"swiftshader|llvmpipe|lavapipe|software rasterizer",
    re.IGNORECASE,
)
FATAL_PATTERN = re.compile(
    r"FATAL EXCEPTION|Fatal signal|SCRIPT ERROR:|SHADER ERROR:|Program linking failed|"
    r"shader failed to compile|unable to bind shader|OutOfMemoryError",
    re.IGNORECASE,
)


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


def parse_adb_devices(output: str) -> list[str]:
    devices = []
    for line in output.splitlines()[1:]:
        fields = line.strip().split()
        if len(fields) >= 2 and fields[1] == "device":
            devices.append(fields[0])
    return devices


def choose_serial(adb_path: Path, requested: str | None) -> str:
    connected = parse_adb_devices(command([str(adb_path), "devices"], timeout=30))
    if requested:
        if requested not in connected:
            raise RuntimeError(f"Requested device is not connected and authorized: {requested}")
        return requested
    if len(connected) != 1:
        raise RuntimeError(
            "Connect and authorize exactly one physical device, or pass --serial. "
            f"Authorized devices found: {len(connected)}"
        )
    return connected[0]


def model_matches(expected: str, facts: dict[str, str]) -> bool:
    needle = expected.strip().casefold()
    if not needle:
        return False
    searchable = " | ".join(
        facts.get(key, "")
        for key in ("manufacturer", "brand", "model", "market_name", "device", "product")
    ).casefold()
    return needle in searchable


def parse_battery(text: str) -> dict[str, float | int]:
    result: dict[str, float | int] = {}
    level = re.search(r"^\s*level:\s*(\d+)\s*$", text, re.MULTILINE)
    temperature = re.search(r"^\s*temperature:\s*(-?\d+)\s*$", text, re.MULTILINE)
    if level:
        result["level_percent"] = int(level.group(1))
    if temperature:
        result["temperature_c"] = round(int(temperature.group(1)) / 10.0, 1)
    return result


def validate_benchmark(benchmark: dict) -> None:
    if benchmark.get("recipe") != EXPECTED_RECIPE:
        raise RuntimeError(f"Wrong retained recipe: {benchmark.get('recipe')}")
    if benchmark.get("surface_style") != EXPECTED_SURFACE_STYLE:
        raise RuntimeError(f"Wrong Northstar surface: {benchmark.get('surface_style')}")
    for key, expected in EXPECTED_WORKLOAD.items():
        if benchmark.get(key) != expected:
            raise RuntimeError(f"Unexpected {key}: {benchmark.get(key)} (expected {expected})")
    if int(benchmark.get("sample_count", 0)) < 10:
        raise RuntimeError("Insufficient rendered frame samples")
    if benchmark.get("rendering_method") != "gl_compatibility":
        raise RuntimeError(f"Expected Compatibility renderer: {benchmark.get('rendering_method')}")
    if int(benchmark.get("viewport_width", 0)) <= int(benchmark.get("viewport_height", 0)):
        raise RuntimeError("Expected a landscape render viewport")
    visual_capture = benchmark.get("visual_capture", {})
    if int(visual_capture.get("sampled_colors", 0)) < 32:
        raise RuntimeError(f"Invalid completion capture: {visual_capture}")
    renderer = " ".join(
        str(benchmark.get(key, ""))
        for key in ("video_adapter", "video_vendor")
    )
    if SOFTWARE_RENDERER_PATTERN.search(renderer):
        raise RuntimeError(f"Physical-device run unexpectedly used a software renderer: {renderer}")


def marker_payload(logs: str, marker: str) -> dict | None:
    matches = [line.split(marker, 1)[1] for line in logs.splitlines() if marker in line]
    return json.loads(matches[-1].strip()) if matches else None


def filter_logcat_since(logs: str, minimum_epoch: float) -> str:
    kept = []
    for line in logs.splitlines():
        timestamp = re.match(r"^\s*(\d+(?:\.\d+)?)\s", line)
        if timestamp and float(timestamp.group(1)) >= minimum_epoch:
            kept.append(line)
    return "\n".join(kept) + ("\n" if kept else "")


def write_manual_review(path: Path) -> None:
    review = {
        "schema": "yardscape-planting-manual-review/1",
        "status": "unreviewed",
        "instructions": "Wait for MEASUREMENT COMPLETE, then drag horizontally to inspect the planting crowns.",
        "checks": {
            "fan_tex_reads_as_a_full_shade_tree": None,
            "palo_verde_reads_as_an_open_distinct_tree": None,
            "shrub_reads_as_a_low_mound_not_a_small_tree": None,
            "no_distracting_card_shingling_or_popping": None,
            "no_missing_or_corrupted_foliage": None,
            "acceptable_northstar_direction_for_further_art_work": None,
        },
        "out_of_scope": [
            "Selection, transforms, S Pen behavior, and sustained thermals require later app-level tests.",
        ],
        "notes": "",
    }
    path.write_text(json.dumps(review, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Measure the retained planting Android probe on one authorized physical device."
    )
    parser.add_argument("--apk", required=True, type=Path, help="Path to the exported debug APK")
    parser.add_argument("--adb", type=Path, help="Path to adb; defaults to adb on PATH")
    parser.add_argument("--serial", help="ADB serial when more than one authorized device is connected")
    parser.add_argument(
        "--expected-model",
        help="Required model or market-name substring, such as the value from 'adb shell getprop ro.product.model'",
    )
    parser.add_argument("--runs", type=int, default=RUN_COUNT, choices=range(1, 6))
    parser.add_argument("--output", type=Path, help="Fresh evidence directory to create")
    args = parser.parse_args()

    adb_candidate = args.adb or (Path(shutil.which("adb")) if shutil.which("adb") else None)
    if adb_candidate is None or not adb_candidate.is_file():
        raise FileNotFoundError("adb was not found; install Android SDK Platform-Tools or pass --adb")
    adb_path = adb_candidate.resolve()
    apk = args.apk.resolve()
    if not apk.is_file():
        raise FileNotFoundError(apk)
    if args.runs < 1:
        raise ValueError("At least one run is required")

    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%SZ")
    output = (args.output or Path.cwd() / f"yardscape-physical-device-evidence-{timestamp}").resolve()
    output.mkdir(parents=True, exist_ok=False)
    report = {
        "schema": "yardscape-physical-device-evidence/1",
        "status": "failed",
        "scope": "physical_android_device",
        "physical_device": True,
        "physical_device_gate": "unrun",
        "manual_visual_gate": "unreviewed",
        "expected_model": args.expected_model,
        "run_count": args.runs,
        "apk_sha256": sha(apk),
        "started_utc": datetime.now(timezone.utc).isoformat(),
        "caveat": "Automated evidence does not certify Northstar art quality, touch quality, S Pen behavior, or sustained thermals.",
    }
    serial = None
    adb = None
    try:
        command([str(adb_path), "start-server"], timeout=30)
        serial = choose_serial(adb_path, args.serial)
        adb = lambda *parts, timeout=60, check=True, binary=False: command(
            [str(adb_path), "-s", serial, *parts], timeout=timeout, check=check, binary=binary
        )
        if adb("shell", "getprop", "ro.kernel.qemu").strip() == "1":
            raise RuntimeError("A physical device is required; the selected ADB target is an emulator")

        facts = {
            "manufacturer": adb("shell", "getprop", "ro.product.manufacturer").strip(),
            "brand": adb("shell", "getprop", "ro.product.brand").strip(),
            "model": adb("shell", "getprop", "ro.product.model").strip(),
            "market_name": adb("shell", "getprop", "ro.product.marketname").strip(),
            "device": adb("shell", "getprop", "ro.product.device").strip(),
            "product": adb("shell", "getprop", "ro.product.name").strip(),
            "android_release": adb("shell", "getprop", "ro.build.version.release").strip(),
            "api": adb("shell", "getprop", "ro.build.version.sdk").strip(),
            "abi": adb("shell", "getprop", "ro.product.cpu.abi").strip(),
            "hardware": adb("shell", "getprop", "ro.hardware").strip(),
            "egl": adb("shell", "getprop", "ro.hardware.egl").strip(),
            "wm_size": adb("shell", "wm", "size").strip(),
            "wm_density": adb("shell", "wm", "density").strip(),
        }
        report["device"] = facts
        report["adb_serial_sha256"] = hashlib.sha256(serial.encode("utf-8")).hexdigest()
        if args.expected_model and not model_matches(args.expected_model, facts):
            raise RuntimeError(
                f"Connected device does not match --expected-model {args.expected_model!r}: "
                f"model={facts['model']!r}, market_name={facts['market_name']!r}"
            )
        report["physical_device_gate"] = (
            "expected_model_confirmed" if args.expected_model else "physical_device_confirmed_model_not_asserted"
        )

        install_log = adb("install", "-r", str(apk), timeout=180)
        (output / "install.log").write_text(install_log, encoding="utf-8")
        if "Success" not in install_log:
            raise RuntimeError("ADB did not confirm APK installation")

        package_dump = adb("shell", "dumpsys", "package", PACKAGE, timeout=60)
        (output / "package.txt").write_text(package_dump, encoding="utf-8")
        if not re.search(r"\bDEBUGGABLE\b", package_dump):
            raise RuntimeError("Installed planting probe is not the expected debuggable package")
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
        report["device"]["launch_component"] = component

        (output / "battery-before.txt").write_text(
            adb("shell", "dumpsys", "battery", timeout=30), encoding="utf-8"
        )
        (output / "thermal-before.txt").write_text(
            adb("shell", "dumpsys", "thermalservice", timeout=30, check=False), encoding="utf-8"
        )
        runs = []
        for run_number in range(1, args.runs + 1):
            label = f"run-{run_number:02d}"
            adb("shell", "am", "force-stop", PACKAGE)
            adb("shell", "dumpsys", "gfxinfo", PACKAGE, "reset", check=False)
            log_start_epoch = float(adb("shell", "date", "+%s", timeout=30).strip()) - 1.0
            launch = adb("shell", "am", "start", "-W", "-n", component, timeout=60)
            (output / f"{label}-launch.txt").write_text(launch, encoding="utf-8")
            if "Status: ok" not in launch:
                raise RuntimeError(f"Launch was not confirmed for {label}")
            pid = adb("shell", "pidof", "-s", PACKAGE, timeout=30).strip()
            if not pid.isdigit():
                raise RuntimeError(f"Could not resolve the planting probe process for {label}: {pid!r}")

            deadline = time.monotonic() + 120
            benchmark = ready = measuring = measuring_dimensions = None
            while time.monotonic() < deadline:
                raw_logs = adb("logcat", "-d", "-v", "epoch", f"--pid={pid}", timeout=30)
                logs = filter_logcat_since(raw_logs, log_start_epoch)
                ready = ready or marker_payload(logs, READY_MARKER)
                measuring = measuring or marker_payload(logs, MEASURING_MARKER)
                if ready and measuring and measuring_dimensions is None:
                    measuring_dimensions = pull_app_screenshot(
                        adb,
                        str(ready.get("user_data_dir", "")),
                        str(measuring.get("file", "")),
                        output / f"{label}-measuring.png",
                        f"physical in-app measuring {label}",
                    )
                benchmark = marker_payload(logs, MARKER)
                if benchmark:
                    break
                time.sleep(1)

            raw_logs = adb("logcat", "-d", "-v", "epoch", f"--pid={pid}", timeout=30)
            logs = filter_logcat_since(raw_logs, log_start_epoch)
            (output / f"{label}-logcat.txt").write_text(logs, encoding="utf-8")
            fatal = FATAL_PATTERN.search(logs)
            if fatal:
                raise RuntimeError(f"Crash or renderer failure in {label}: {fatal.group(0)}")
            if benchmark is None or ready is None or measuring is None or measuring_dimensions is None:
                raise RuntimeError(f"Incomplete benchmark evidence in {label}")
            validate_benchmark(benchmark)

            visual_capture = benchmark["visual_capture"]
            completion_dimensions = pull_app_screenshot(
                adb,
                str(ready.get("user_data_dir", "")),
                str(visual_capture.get("file", "")),
                output / f"{label}-complete.png",
                f"physical in-app completion {label}",
            )
            device_dimensions = capture_device_screenshot(
                adb, output / f"{label}-device.png", f"physical device {label}"
            )
            meminfo = adb("shell", "dumpsys", "meminfo", PACKAGE, timeout=60)
            gfxinfo = adb("shell", "dumpsys", "gfxinfo", PACKAGE, "framestats", timeout=60)
            window_dump = adb("shell", "dumpsys", "window", "windows", timeout=60)
            window = "\n".join(line for line in window_dump.splitlines() if PACKAGE in line) + "\n"
            (output / f"{label}-meminfo.txt").write_text(meminfo, encoding="utf-8")
            (output / f"{label}-gfxinfo.txt").write_text(gfxinfo, encoding="utf-8")
            (output / f"{label}-window.txt").write_text(window, encoding="utf-8")
            if PACKAGE not in window:
                raise RuntimeError(f"Planting probe was not present in the window state for {label}")
            runs.append({
                "run": run_number,
                "in_app": benchmark,
                "ready": ready,
                "measuring_capture": measuring,
                "measuring_screenshot": measuring_dimensions,
                "completion_screenshot": completion_dimensions,
                "device_screenshot": device_dimensions,
                "gfxinfo_has_frame_summary": "Total frames rendered" in gfxinfo,
                "meminfo_process_present": "No process found" not in meminfo,
            })

        battery_after_text = adb("shell", "dumpsys", "battery", timeout=30)
        (output / "battery-after.txt").write_text(battery_after_text, encoding="utf-8")
        (output / "thermal-after.txt").write_text(
            adb("shell", "dumpsys", "thermalservice", timeout=30, check=False), encoding="utf-8"
        )
        battery_before_text = (output / "battery-before.txt").read_text(encoding="utf-8")
        fps_values = [float(item["in_app"]["average_fps"]) for item in runs]
        p95_values = [float(item["in_app"]["p95_ms"]) for item in runs]
        minimum_fps = min(fps_values)
        worst_p95 = max(p95_values)
        provisional_pass = (
            minimum_fps >= PROVISIONAL_MINIMUM_AVERAGE_FPS
            and worst_p95 <= PROVISIONAL_MAXIMUM_P95_MS
        )
        report.update(
            status="physical_device_evidence_collected",
            completed_utc=datetime.now(timezone.utc).isoformat(),
            runs=runs,
            battery={
                "before": parse_battery(battery_before_text),
                "after": parse_battery(battery_after_text),
            },
            aggregate={
                "median_average_fps": round(statistics.median(fps_values), 2),
                "minimum_average_fps": round(minimum_fps, 2),
                "worst_p95_ms": round(worst_p95, 3),
            },
            provisional_performance_gate={
                "minimum_average_fps": PROVISIONAL_MINIMUM_AVERAGE_FPS,
                "maximum_p95_ms": PROVISIONAL_MAXIMUM_P95_MS,
                "passed": provisional_pass,
                "status": "pass" if provisional_pass else "needs_optimization",
                "note": "This short renderer probe is not a sustained thermal or full-app performance certification.",
            },
        )
        write_manual_review(output / "manual-review.json")
    except Exception as error:
        report["failure"] = f"{type(error).__name__}: {error}"
        raise
    finally:
        report["finished_utc"] = datetime.now(timezone.utc).isoformat()
        (output / "physical-device-report.json").write_text(
            json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        archive = shutil.make_archive(str(output), "zip", root_dir=output.parent, base_dir=output.name)
        print(f"Evidence directory: {output}")
        print(f"Evidence archive: {archive}")


if __name__ == "__main__":
    main()
