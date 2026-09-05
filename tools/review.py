#!/usr/bin/env python3
"""Run local Godot review checks. Python 3.10+, standard library only.

A successful run proves capture completeness, not visual quality or animation
correctness. The shaders still use live TIME; this is not a pixel-diff harness.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import tempfile
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


def capture_command(engine: str, project: Path, output: Path, scene: str) -> list[str]:
    return [engine, "--path", str(project), "--rendering-method", "forward_plus",
            "--scene", SCENES[scene], "--", "--review", f"--capture-dir={output}"]


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


def validate_manifest(path: Path, output_root: Path) -> dict[str, Any]:
    """Validate names, pairs, file presence, and PNG headers. Not a visual test."""
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
            with image_path.open("rb") as image:
                header = image.read(33)
            if len(header) != 33 or header[:16] != b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR":
                raise ValueError("missing PNG signature/IHDR")
            width, height = struct.unpack(">II", header[16:24])
            if not width or not height or [width, height] != [record["width"], record["height"]]:
                raise ValueError("PNG dimensions do not match manifest")
        return manifest
    except (OSError, ValueError, KeyError, TypeError, struct.error) as exc:
        raise ReviewError(f"Incomplete/invalid capture manifest {path}: {exc}") from exc


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
    parser.add_argument("--scene", choices=SCENES, default="editable")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--timeout", type=float, default=240.0, help="Per-process timeout in seconds")
    parser.add_argument("--tests-only", action="store_true", help="Run the Godot navigation tests without rendering")
    args = parser.parse_args(argv)
    repo = Path(__file__).resolve().parents[1]
    project = repo / "godot"
    run: Path | None = None
    report: dict[str, Any] = {"status": "failed", "visual_acceptance": "not_evaluated", "scene": args.scene}
    try:
        if args.timeout <= 0:
            raise ReviewError("--timeout must be positive")
        engine = resolve_engine(args.godot)
        report["source"] = revision(repo)
        output = (args.output or repo / ".review-output").resolve()
        output.mkdir(parents=True, exist_ok=True)
        run = Path(tempfile.mkdtemp(prefix="run-", dir=output))
        report["engine_executable"] = engine
        run_stage([engine, "--headless", "--path", str(project), "--script", "res://tests/test_navigation.gd"],
                  run / "navigation.log", args.timeout, "NAVIGATION_TESTS_OK ")
        if args.tests_only:
            report["status"] = "navigation_tests_passed"
        else:
            run_stage([engine, "--headless", "--path", str(project), "--editor", "--import"],
                      run / "import.log", args.timeout)
            output_text = run_stage(capture_command(engine, project, run, args.scene),
                                    run / "render.log", args.timeout, "REVIEW_OK ")
            manifest_path = manifest_from_output(output_text)
            manifest = validate_manifest(manifest_path, run)
            report.update(status="capture_complete", manifest=str(manifest_path),
                          capture_count=len(manifest["images"]))
    except (ReviewError, OSError) as exc:
        report["error"] = str(exc)
        print(f"REVIEW_FAILED: {exc}", file=sys.stderr)
    if run is not None:
        try:
            (run / "runner-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        except OSError as exc:
            print(f"REVIEW_FAILED: cannot save runner report: {exc}", file=sys.stderr)
            return 1
    if report["status"] == "failed":
        return 1
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
