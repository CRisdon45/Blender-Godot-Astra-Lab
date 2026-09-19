#!/usr/bin/env python3
"""Verify, stage, and export the retained planting Android debug probe."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent.parent
BRUSH = ROOT.parent / "yardscape-plant-brush-profile-probe"
SHRUB = ROOT.parent / "yardscape-plant-brush-shrub-probe"
PROFILE = ROOT.parent / "yardscape-plant-form-profile-probe"
PIN = "4.7.1.stable.official.a13da4feb"
ENGINE_SHA = "32f8d7596c4b41185512b1c49d69f2da3be018fd784a53e349fa92a98a97bcde"
PACKAGE = "studio.yardscape.plantingprobe"
APK_NAME = "yardscape-retained-planting-debug.apk"
DEVICE_KIT_FILES = ("DEVICE_TEST.md", "run_physical_device.py", "run_emulator.py")

PROJECT_FILES = {
    "export_presets.cfg",
    "northstar-profile-brush-android.tscn",
    "project.godot",
    "presentation/northstar/android_brush_benchmark.gd",
    "tests/configure_android_export.gd",
}

DEPENDENCIES = {
    BRUSH / "project/presentation/northstar/foliage/profiled_batched_brush_tree.gd": "presentation/northstar/foliage/profiled_batched_brush_tree.gd",
    BRUSH / "project/presentation/northstar/foliage/brush_cloud_group.gd": "presentation/northstar/foliage/brush_cloud_group.gd",
    BRUSH / "project/presentation/northstar/foliage/batched_brush_cloud.gdshader": "presentation/northstar/foliage/batched_brush_cloud.gdshader",
    PROFILE / "project/presentation/northstar/foliage/plant_form_profiles.gd": "presentation/northstar/foliage/plant_form_profiles.gd",
    PROFILE / "project/presentation/northstar/foliage/plant_form_layout.gd": "presentation/northstar/foliage/plant_form_layout.gd",
    SHRUB / "project/presentation/northstar/foliage/shrub_form_profile.gd": "presentation/northstar/foliage/shrub_form_profile.gd",
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify() -> None:
    spec = importlib.util.spec_from_file_location("shrub_verify", SHRUB / "run_shrub.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.verify()
    actual = {
        path.relative_to(ROOT / "project").as_posix()
        for path in (ROOT / "project").rglob("*")
        if path.is_file()
    }
    if actual != PROJECT_FILES:
        raise ValueError(f"Unexpected Android probe source expansion: {sorted(actual ^ PROJECT_FILES)}")
    for relative in sorted(actual):
        path = ROOT / "project" / relative
        if path.is_symlink() or ".." in Path(relative).parts:
            raise ValueError(f"Invalid source path: {relative}")
        text = path.read_text(encoding="utf-8")
        if re.search(r"https?://|BEGIN .*PRIVATE KEY|gh[pousr]_|github_pat_|sk-proj-|res://(?:core|application)/", text):
            raise ValueError(f"Forbidden dependency in {relative}")
    for source in DEPENDENCIES:
        if not source.is_file() or source.is_symlink():
            raise ValueError(f"Missing retained dependency: {source}")


def stage_project(destination: Path) -> None:
    verify()
    if destination.exists():
        raise FileExistsError(f"Fresh stage required: {destination}")
    shutil.copytree(ROOT / "project", destination)
    for source, relative in DEPENDENCIES.items():
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)


def run_logged(command: list[str], log_path: Path, env: dict[str, str], timeout: int) -> str:
    with log_path.open("w", encoding="utf-8") as log:
        result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=timeout, check=False)
    text = log_path.read_text(encoding="utf-8", errors="replace")
    print(text[-16000:])
    if result.returncode:
        raise RuntimeError(f"Command failed ({result.returncode}): {' '.join(command)}")
    if re.search(r"SCRIPT ERROR:|SHADER ERROR:", text):
        raise RuntimeError(f"Godot source failure in {log_path.name}")
    return text


def build() -> None:
    verify()
    if os.environ.get("GITHUB_ACTIONS") != "true" or sys.platform != "linux":
        raise RuntimeError("Android export is restricted to the clean Linux CI worker")
    engine = Path(os.environ["GODOT_BIN"]).resolve()
    if sha(engine) != ENGINE_SHA:
        raise ValueError("Engine mismatch")
    version = subprocess.run(
        [str(engine), "--version"], capture_output=True, text=True, check=True, timeout=20
    ).stdout.strip()
    if version != PIN:
        raise ValueError(f"Version mismatch: {version}")
    for variable in ("ANDROID_SDK_ROOT", "JAVA_HOME", "GODOT_TEMPLATE_ARCHIVE_SHA256"):
        if not os.environ.get(variable):
            raise RuntimeError(f"Missing required environment variable: {variable}")
    stage = Path(os.environ["RUNNER_TEMP"]) / "plant-brush-android-stage"
    stage_project(stage)
    output = Path(os.environ["RUNNER_TEMP"]) / "plant-brush-android-build"
    output.mkdir(exist_ok=False)
    apk = output / APK_NAME
    env = {key: value for key, value in os.environ.items() if not key.startswith(("PLAN_TRACE_", "YARDSCAPE_", "GODOT_MCP_"))}
    env.update(GODOT_SILENCE_ROOT_WARNING="1", LANG="C.UTF-8")
    status = "failed"
    failure = ""
    manifest = {
        "status": status,
        "public_commit": os.environ.get("GITHUB_SHA"),
        "engine": version,
        "engine_sha256": ENGINE_SHA,
        "template_archive_sha256": os.environ["GODOT_TEMPLATE_ARCHIVE_SHA256"],
        "package": PACKAGE,
        "architectures": ["arm64-v8a", "x86_64"],
        "source_sha256": {
            source.relative_to(REPO).as_posix(): sha(source) for source in sorted(DEPENDENCIES)
        },
        "probe_source_sha256": {
            path.relative_to(ROOT).as_posix(): sha(path)
            for path in sorted((ROOT / "project").rglob("*"))
            if path.is_file()
        },
    }
    try:
        run_logged(
            [str(engine), "--headless", "--path", str(stage), "--script", "res://presentation/northstar/android_brush_benchmark.gd", "--check-only"],
            output / "preflight.log",
            env,
            90,
        )
        settings_log = run_logged(
            [str(engine), "--headless", "--editor", "--path", str(stage), "--script", "res://tests/configure_android_export.gd"],
            output / "configure.log",
            env,
            90,
        )
        if "YARDSCAPE_ANDROID_EXPORT_SETTINGS=configured" not in settings_log:
            raise RuntimeError("Android editor settings were not confirmed")
        run_logged(
            [str(engine), "--headless", "--path", str(stage), "--export-debug", "Android benchmark", str(apk)],
            output / "export.log",
            env,
            480,
        )
        if not apk.is_file() or apk.stat().st_size < 1_000_000:
            raise RuntimeError("Expected non-empty Android APK")
        with zipfile.ZipFile(apk) as package:
            names = set(package.namelist())
        required_members = {
            "AndroidManifest.xml",
            "lib/arm64-v8a/libgodot_android.so",
            "lib/x86_64/libgodot_android.so",
        }
        missing = sorted(required_members - names)
        if missing:
            raise RuntimeError(f"APK missing required members: {missing}")
        for file_name in DEVICE_KIT_FILES:
            source = ROOT / file_name
            if not source.is_file():
                raise FileNotFoundError(source)
            shutil.copyfile(source, output / file_name)
        kit_hashes = {file_name: sha(output / file_name) for file_name in DEVICE_KIT_FILES}
        status = "android_debug_export_passed"
        manifest.update(
            status=status,
            apk=APK_NAME,
            apk_bytes=apk.stat().st_size,
            apk_sha256=sha(apk),
            physical_device_test_kit=list(DEVICE_KIT_FILES),
            physical_device_test_kit_sha256=kit_hashes,
        )
    except Exception as error:
        failure = f"{type(error).__name__}: {error}"
        manifest.update(status="failed", failure=failure)
        raise
    finally:
        manifest["status"] = status
        if failure:
            manifest["failure"] = failure
        (output / "build-report.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--verify-only", action="store_true")
    parser.add_argument("--stage-only", type=Path)
    args = parser.parse_args()
    if args.verify_only:
        verify()
        print("Android planting probe source boundary verified")
    elif args.stage_only:
        stage_project(args.stage_only.resolve())
        print(args.stage_only.resolve())
    else:
        build()


if __name__ == "__main__":
    main()
