#!/usr/bin/env python3
"""Run local Godot review checks. Python 3.10+, standard library only.

Import, run runtime suites, then capture matched flow-on/off review sets.
Capture integrity and runtime checks are not visual acceptance, animation proof,
or GPU/device performance evidence. Captures remain live, not pixel-deterministic.
"""
from __future__ import annotations

import argparse
import json
import math
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import time
import zlib
from typing import Any

VIEWS = ("reference", "left", "right", "elevated", "close", "reverse")
SCENES = {"editable": "res://courtyard_editable.tscn", "builder": "res://courtyard.tscn"}
ERROR_LINE = re.compile(r"^\s*(?:SCRIPT ERROR|SHADER ERROR|ERROR|FATAL):", re.MULTILINE)
ANSI = re.compile(r"\x1b\[[0-9;]*m")


class ReviewError(RuntimeError):
    """A missing, failed, or incomplete review witness."""


def resolve_engine(value: str) -> str:
    found = shutil.which(value)
    if not found:
        raise ReviewError(f"Godot executable not found: {value}. Supply --godot with its full path.")
    return found


def run_stage(command: list[str], log: Path, timeout: float, marker: str | None = None) -> str:
    """Do not trust exit zero when Godot logged script/shader/import errors."""
    try:
        completed = subprocess.run(command, capture_output=True, text=True,
                                   encoding="utf-8", errors="replace", timeout=timeout)
    except subprocess.TimeoutExpired as exc:
        def text(value: bytes | str | None) -> str:
            return value.decode("utf-8", "replace") if isinstance(value, bytes) else value or ""
        log.write_text(text(exc.stdout) + text(exc.stderr) + "\nREVIEW_RUNNER_TIMEOUT\n", encoding="utf-8")
        raise ReviewError(f"Godot timed out; see {log}") from exc
    except OSError as exc:
        log.write_text(str(exc), encoding="utf-8")
        raise ReviewError(f"Could not run Godot; see {log}") from exc
    output = completed.stdout + "\n" + completed.stderr
    log.write_text(output, encoding="utf-8")
    clean = ANSI.sub("", output)
    if completed.returncode != 0 or ERROR_LINE.search(clean):
        raise ReviewError(f"Godot stage failed (exit {completed.returncode}); see {log}")
    if marker and not any(line.startswith(marker) for line in clean.splitlines()):
        raise ReviewError(f"Missing {marker!r} completion marker; see {log}")
    return clean


def capture_command(engine: str, project: Path, output: Path, scene: str,
                    flow_enabled: bool = True) -> list[str]:
    command = [engine, "--path", str(project), "--rendering-method", "forward_plus",
               "--scene", SCENES[scene], "--", "--review"]
    if not flow_enabled:
        command.append("--water-off")
    return command + [f"--capture-dir={output}"]


def manifest_from_output(output: str) -> Path:
    rows = [line.removeprefix("REVIEW_OK ") for line in output.splitlines() if line.startswith("REVIEW_OK ")]
    if len(rows) != 1:
        raise ReviewError("Expected exactly one REVIEW_OK manifest pointer")
    try:
        payload = json.loads(rows[0])
        value = payload["manifest"]
        if not isinstance(value, str) or not value:
            raise ValueError("manifest must be a nonempty path")
        return Path(value)
    except (ValueError, KeyError, TypeError) as exc:
        raise ReviewError("Malformed REVIEW_OK manifest pointer") from exc


# Deliberately limited to the RGB/RGBA8, non-interlaced PNGs produced by this
# viewport capture path. Bounds prevent corrupt files from exhausting memory.
MAX_PNG_BYTES = 64 * 1024 * 1024
MAX_PNG_PIXELS = 16 * 1024 * 1024
COURTYARD_IMPACTS = 2
MIN_ENGINE_VERSION = (4, 7, 1)  # Repository baseline; not a claim of a new runtime validation.


def validate_png(path: Path) -> tuple[int, int]:
    """Check chunks/CRCs, complete zlib data and scanlines, not visible quality."""
    with path.open("rb") as stream:
        data = stream.read(MAX_PNG_BYTES + 1)
    if len(data) > MAX_PNG_BYTES or not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError("invalid or oversized PNG")
    offset = 8
    width = height = channels = 0
    compressed = bytearray()
    have_idat = idat_closed = ended = False
    while offset < len(data):
        if len(data) - offset < 12:
            raise ValueError("truncated PNG chunk")
        size = struct.unpack_from(">I", data, offset)[0]
        name = data[offset + 4:offset + 8]
        end = offset + 12 + size
        if end > len(data):
            raise ValueError("truncated PNG payload")
        body = data[offset + 8:offset + 8 + size]
        crc = struct.unpack_from(">I", data, offset + 8 + size)[0]
        if zlib.crc32(name + body) != crc:
            raise ValueError("PNG chunk CRC mismatch")
        if not all(65 <= char <= 90 or 97 <= char <= 122 for char in name):
            raise ValueError("invalid PNG chunk name")
        if not width and name != b"IHDR":
            raise ValueError("IHDR must be first")
        if name == b"IHDR":
            if width or size != 13:
                raise ValueError("duplicate or malformed IHDR")
            width, height, depth, color, compression, filtering, interlace = struct.unpack(">IIBBBBB", body)
            if (not width or not height or width > 8192 or height > 8192 or width * height > MAX_PNG_PIXELS
                    or depth != 8 or color not in (2, 6)
                    or compression or filtering or interlace):
                raise ValueError("expected bounded, non-interlaced RGB/RGBA8 PNG")
            channels = 3 if color == 2 else 4
        elif name == b"IDAT":
            if idat_closed:
                raise ValueError("nonconsecutive IDAT chunks")
            have_idat = True
            compressed.extend(body)
        elif name == b"IEND":
            if size or not have_idat or end != len(data):
                raise ValueError("invalid IEND or trailing PNG data")
            ended = True
            break
        else:
            # Ancillary chunks may be ignored. PLTE is optional for RGB/RGBA.
            if name == b"PLTE":
                if have_idat or not size or size > 768 or size % 3:
                    raise ValueError("invalid PLTE")
            elif not (name[0] & 32):
                raise ValueError("unsupported critical PNG chunk")
            if have_idat:
                idat_closed = True
        offset = end
    if not ended:
        raise ValueError("missing PNG IEND")
    stride = width * channels + 1
    expected = height * stride
    inflater = zlib.decompressobj()
    try:
        pixels = inflater.decompress(compressed, expected + 1)
    except zlib.error as exc:
        raise ValueError("invalid PNG zlib stream") from exc
    if (len(pixels) != expected or not inflater.eof
            or inflater.unused_data or inflater.unconsumed_tail):
        raise ValueError("incomplete, excess or truncated PNG scanline data")
    if any(pixels[index] > 4 for index in range(0, expected, stride)):
        raise ValueError("invalid PNG scanline filter")
    return width, height


def validate_manifest(path: Path, output_root: Path) -> dict[str, Any]:
    """Validate capture pairs and complete PNG structure. Not a visual test."""
    path = path.resolve()
    if not path.is_relative_to(output_root.resolve()):
        raise ReviewError("Manifest is outside this run's output directory")
    try:
        manifest = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(manifest, dict):
            raise ValueError("manifest must be an object")
        if manifest.get("schema_version") != 1 or manifest.get("mode") != "review" or manifest.get("status") != "captured":
            raise ValueError("wrong schema, mode, or capture status")
        if manifest.get("pixel_deterministic") is not False or manifest.get("animation") != "live":
            raise ValueError("live animation must not claim pixel determinism")
        if manifest.get("visual_acceptance") != "not_evaluated":
            raise ValueError("capture completeness must not claim visual acceptance")
        images = manifest["images"]
        if not isinstance(images, list) or len(images) != len(VIEWS) * 2:
            raise ValueError("expected all 12 view/style captures")
        expected = {(view, enabled) for view in VIEWS for enabled in (True, False)}
        seen: set[tuple[str, bool]] = set()
        for record in images:
            view, enabled = record["view"], record["illustration"]
            if not isinstance(view, str) or type(enabled) is not bool:
                raise ValueError("invalid view/style types")
            pair = (view, enabled)
            if pair not in expected or pair in seen:
                raise ValueError("unexpected or duplicate view/style")
            seen.add(pair)
            expected_name = f"{view}-{'illustrated' if enabled else 'plain'}.png"
            if record["file"] != expected_name:
                raise ValueError("unexpected filename or traversal")
            image_path = path.parent / expected_name
            if not image_path.resolve().is_relative_to(path.parent):
                raise ValueError("capture symlink escapes its run directory")
            width, height = validate_png(image_path)
            if (type(record["width"]) is not int or type(record["height"]) is not int
                    or (width, height) != (record["width"], record["height"])):
                raise ValueError("PNG dimensions do not match manifest")
        return manifest
    except (OSError, ValueError, KeyError, TypeError, struct.error) as exc:
        raise ReviewError(f"Incomplete/invalid capture manifest {path}: {exc}") from exc


def marked_json(output: str, marker: str) -> dict[str, Any]:
    rows = [line[len(marker):] for line in output.splitlines() if line.startswith(marker)]
    try:
        if len(rows) != 1:
            raise ValueError("expected exactly one completion marker")
        value = json.loads(rows[0])
        if not isinstance(value, dict):
            raise ValueError("completion payload must be an object")
        return value
    except (ValueError, TypeError) as exc:
        raise ReviewError(f"Invalid {marker.strip()} payload: {exc}") from exc


def finite_number(value: Any) -> bool:
    try:
        return type(value) in (float, int) and math.isfinite(value)
    except OverflowError:
        return False


def vector(value: Any, size: int) -> bool:
    return isinstance(value, list) and len(value) == size and all(finite_number(v) for v in value)


def close_vector(left: list[Any], right: list[Any]) -> bool:
    return len(left) == len(right) and all(
        math.isclose(a, b, rel_tol=1e-6, abs_tol=1e-5) for a, b in zip(left, right))


def validate_water_state(state: Any, flow_enabled: bool) -> dict[str, Any]:
    """This gate targets the unchanged courtyard's two full-width sheers."""
    try:
        if not isinstance(state, dict) or state.get("active") is not True or state.get("error") != "":
            raise ValueError("water binding missing, inactive or reporting an error")
        if state.get("flow_enabled") is not flow_enabled:
            raise ValueError("wrong water flow state")
        for field in ("time_seconds", "water_level", "contact_band"):
            if not finite_number(state.get(field)):
                raise ValueError(f"invalid water {field}")
        if state["time_seconds"] < 0 or not 0 < state["contact_band"] < 0.02:
            raise ValueError("invalid clock/contact band")
        spans = state.get("impact_segments_xz")
        if not isinstance(spans, list) or len(spans) != COURTYARD_IMPACTS:
            raise ValueError("unchanged courtyard must bind exactly two impact spans")
        for span in spans:
            if not vector(span, 4) or math.hypot(span[2] - span[0], span[3] - span[1]) <= 0.0001:
                raise ValueError("invalid or zero-length water span")
        if close_vector(spans[0], spans[1]) or close_vector(spans[0], spans[1][2:] + spans[1][:2]):
            raise ValueError("duplicate water spans")
        return state
    except (ValueError, TypeError, KeyError, OverflowError) as exc:
        raise ReviewError(f"Invalid water witness: {exc}") from exc


def validate_water_manifest(manifest: dict[str, Any], ready: dict[str, Any],
                            flow_enabled: bool) -> None:
    """Require per-frame water/camera evidence after general manifest validation."""
    initial = validate_water_state(ready, flow_enabled)
    if not isinstance(manifest.get("engine"), dict) or manifest["engine"].get("major") != 4:
        raise ReviewError("Missing Godot 4 engine metadata")
    display = manifest.get("display_server")
    if not isinstance(display, str) or not display or display.lower() == "headless":
        raise ReviewError("Capture must identify a graphics-capable display")
    previous_time = initial["time_seconds"]
    cameras: dict[str, tuple[Any, ...]] = {}
    dimensions = None
    for record in manifest["images"]:
        state = validate_water_state(record.get("water"), flow_enabled)
        if (state["time_seconds"] < previous_time
                or not math.isclose(state["water_level"], initial["water_level"], abs_tol=1e-5)
                or not math.isclose(state["contact_band"], initial["contact_band"], abs_tol=1e-6)
                or any(not close_vector(a, b) for a, b in zip(
                    state["impact_segments_xz"], initial["impact_segments_xz"]))):
            raise ReviewError("Water clock moved backward or stationary scene contacts changed")
        previous_time = state["time_seconds"]
        position, rotation, fov = (record.get(key) for key in ("camera_position", "camera_rotation", "camera_fov"))
        if not vector(position, 3) or not vector(rotation, 3) or not finite_number(fov) or not 0 < fov < 180:
            raise ReviewError("Invalid camera metadata")
        camera = (position, rotation, fov)
        previous = cameras.setdefault(record["view"], camera)
        if (not close_vector(position, previous[0]) or not close_vector(rotation, previous[1])
                or not math.isclose(fov, previous[2], abs_tol=1e-5)):
            raise ReviewError("Illustrated/plain camera pair does not match")
        size = (record["width"], record["height"])
        if dimensions is not None and size != dimensions:
            raise ReviewError("Capture viewport dimensions changed during the review")
        dimensions = size


def validate_flow_pair(on: dict[str, Any], off: dict[str, Any]) -> None:
    """Match state/pose metadata, not pixels: live animation times may differ."""
    records = {(record["view"], record["illustration"]): record for record in off["images"]}
    for left in on["images"]:
        right = records[(left["view"], left["illustration"])]
        for key in ("camera_position", "camera_rotation"):
            if not close_vector(left[key], right[key]):
                raise ReviewError("Flow-on/off camera pair does not match")
        if (not math.isclose(left["camera_fov"], right["camera_fov"], abs_tol=1e-5)
                or (left["width"], left["height"]) != (right["width"], right["height"])):
            raise ReviewError("Flow-on/off projection or viewport changed")
        if any(not close_vector(a, b) for a, b in zip(
                left["water"]["impact_segments_xz"], right["water"]["impact_segments_xz"])):
            raise ReviewError("Flow-off capture lost or moved source contacts")


def revision(repo: Path) -> dict[str, Any]:
    try:
        sha = subprocess.run(["git", "-C", str(repo), "rev-parse", "HEAD"], check=True,
                             capture_output=True, text=True, timeout=10).stdout.strip()
        state = subprocess.run(["git", "-C", str(repo), "status", "--porcelain", "--untracked-files=all"],
                               check=True, capture_output=True, text=True, timeout=10).stdout
        return {"commit": sha, "dirty": bool(state.strip())}
    except (OSError, subprocess.SubprocessError):
        return {"commit": None, "dirty": None}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--scene", choices=(*SCENES, "both"), default="editable")
    parser.add_argument("--water", choices=("on", "off", "both"), default="both")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--timeout", type=float, default=240.0, help="Per-process timeout in seconds")
    parser.add_argument("--tests-only", action="store_true",
                        help="Import, then navigation, water and real-scene tests; no graphics captures")
    args = parser.parse_args(argv)
    repo = Path(__file__).resolve().parents[1]
    project = repo / "godot"
    scenes = tuple(SCENES) if args.scene == "both" else (args.scene,)
    flows = (True, False) if args.water == "both" else (args.water == "on",)
    run: Path | None = None
    report: dict[str, Any] = {
        "status": "failed", "visual_acceptance": "not_evaluated", "scene": args.scene,
        "water": args.water, "runtime_validation": "not_run", "graphics_validation": "not_run",
        "pixel_deterministic": False, "stages": [], "captures": [],
    }

    def stage(name: str, command: list[str], marker: str | None = None) -> str:
        assert run is not None
        record: dict[str, Any] = {"name": name, "status": "running", "command": command,
                                  "log": str(run / f"{name}.log")}
        report["stages"].append(record)
        start = time.monotonic()
        try:
            output = run_stage(command, Path(record["log"]), args.timeout, marker)
            record["status"] = "passed"
            return output
        except (ReviewError, OSError) as exc:
            record.update(status="failed", error=str(exc))
            raise
        finally:
            # Process wall time is diagnostic, never GPU/frame timing.
            record["elapsed_seconds"] = round(time.monotonic() - start, 3)

    try:
        output = (args.output or repo / ".review-output").resolve()
        output.mkdir(parents=True, exist_ok=True)
        run = Path(tempfile.mkdtemp(prefix="run-", dir=output))
        report["report_path"] = str(run / "runner-report.json")
        if not math.isfinite(args.timeout) or args.timeout <= 0:
            raise ReviewError("--timeout must be finite and positive")
        report["source"] = revision(repo)
        engine = resolve_engine(args.godot)
        report["engine_executable"] = engine
        report["engine_version"] = stage("version", [engine, "--version"]).strip()
        version = re.match(r"^(\d+)\.(\d+)\.(\d+)(?:[.\s-]|$)", report["engine_version"])
        if (not version or int(version[1]) != 4
                or tuple(map(int, version.groups())) < MIN_ENGINE_VERSION):
            raise ReviewError("Use Godot 4.7.1 or newer within Godot 4, matching the repository baseline")
        # Import first: scripts may preload shaders or imported resources on a fresh clone.
        stage("import", [engine, "--headless", "--path", str(project), "--editor", "--import"])
        report["runtime_validation"] = "running"
        for name, script, marker in (
            ("navigation", "test_navigation.gd", "NAVIGATION_TESTS_OK "),
            ("water", "test_water_interaction.gd", "WATER_TESTS_OK "),
        ):
            stage(name, [engine, "--headless", "--path", str(project), "--script", f"res://tests/{script}"], marker)
        for scene in scenes:
            text = stage(f"binding-{scene}", [engine, "--headless", "--path", str(project),
                         "--script", "res://tests/test_scene_water.gd", "--", f"--test-scene={SCENES[scene]}"],
                         "SCENE_WATER_TESTS_OK ")
            evidence = marked_json(text, "SCENE_WATER_TESTS_OK ")
            if (evidence.get("scene") != SCENES[scene]
                    or type(evidence.get("checks")) is not int or evidence["checks"] <= 0
                    or evidence.get("impact_count") != COURTYARD_IMPACTS
                    or evidence.get("graphics_validated") is not False):
                raise ReviewError("Invalid real-scene test completion payload")
        report["runtime_validation"] = "passed"
        if args.tests_only:
            report["status"] = "runtime_tests_passed"
        else:
            report["graphics_validation"] = "running"
            for scene in scenes:
                manifests: dict[bool, dict[str, Any]] = {}
                for enabled in flows:
                    name = f"{scene}-flow-{'on' if enabled else 'off'}"
                    capture_root = run / name
                    capture_root.mkdir()
                    text = stage(name, capture_command(engine, project, capture_root, scene, enabled), "REVIEW_OK ")
                    manifest_path = manifest_from_output(text)
                    manifest = validate_manifest(manifest_path, capture_root)
                    validate_water_manifest(manifest, marked_json(text, "WATER_READY "), enabled)
                    manifests[enabled] = manifest
                    report["captures"].append({"scene": scene, "flow_enabled": enabled,
                                               "manifest": str(manifest_path), "count": len(manifest["images"])})
                if len(manifests) == 2:
                    validate_flow_pair(manifests[True], manifests[False])
            report.update(status="capture_complete", graphics_validation="capture_complete",
                          capture_count=sum(item["count"] for item in report["captures"]))
    except (ReviewError, OSError) as exc:
        report["error"] = str(exc)
        for field in ("runtime_validation", "graphics_validation"):
            if report[field] == "running":
                report[field] = "failed"
        print(f"REVIEW_FAILED: {exc}", file=sys.stderr)
    if run is not None:
        try:
            (run / "runner-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        except OSError as exc:
            print(f"REVIEW_FAILED: cannot save runner report: {exc}", file=sys.stderr)
            return 1
        print(f"REVIEW_REPORT {run / 'runner-report.json'}")
    if report["status"] == "failed":
        return 1
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
