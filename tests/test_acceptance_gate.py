"""Synthetic runner/PNG regression tests, not Godot runtime or visual evidence."""
from __future__ import annotations

import contextlib
import copy
import io
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
import zlib

from test_review import review, fixture_png

ROOT = Path(__file__).resolve().parents[1]
SIGNATURE = b"\x89PNG\r\n\x1a\n"


def chunk(name: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + name + data + struct.pack(">I", zlib.crc32(name + data))


def png(raw: bytes = b"\x00\x00\x00\x00\xff\xff\xff", *,
        width: int = 2, height: int = 1, color: int = 2,
        compressed: bytes | None = None) -> bytes:
    header = chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, color, 0, 0, 0))
    return SIGNATURE + header + chunk(b"IDAT", zlib.compress(raw) if compressed is None else compressed) + chunk(b"IEND", b"")


def water(enabled: bool = True) -> dict:
    return {"active": True, "error": "", "flow_enabled": enabled,
            "time_seconds": 0.0, "water_level": 0.3225, "contact_band": 0.012,
            "impact_segments_xz": [[-3.0, -5.0, -2.06, -5.0], [0.0, -5.0, 0.94, -5.0]]}


def capture(root: Path, enabled: bool = True) -> tuple[Path, dict]:
    root.mkdir(parents=True, exist_ok=True)
    data = {"schema_version": 1, "mode": "review", "status": "captured",
            "animation": "live", "pixel_deterministic": False,
            "visual_acceptance": "not_evaluated", "engine": {"major": 4, "minor": 7},
            "display_server": "x11", "images": []}
    for index, view in enumerate(review.VIEWS):
        for style in (True, False):
            filename = f"{view}-{'illustrated' if style else 'plain'}.png"
            (root / filename).write_bytes(fixture_png())
            state = water(enabled)
            state["time_seconds"] = float(len(data["images"]) + 1)
            data["images"].append({"file": filename, "view": view, "illustration": style,
                                   "width": 2, "height": 1, "water": state,
                                   "camera_position": [float(index), 3.0, 10.0],
                                   "camera_rotation": [0.0, 0.0, 0.0], "camera_fov": 55.0})
    path = root / "manifest.json"
    path.write_text(json.dumps(data), encoding="utf-8")
    return path, data


class PNGIntegrityTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.path = Path(temporary.name) / "frame.png"

    def reject(self, contents: bytes):
        self.path.write_bytes(contents)
        with self.assertRaises(ValueError):
            review.validate_png(self.path)

    def test_valid_rgb(self):
        self.path.write_bytes(png())
        self.assertEqual(review.validate_png(self.path), (2, 1))

    def test_valid_rgba(self):
        self.path.write_bytes(png(b"\x00" + b"\xff" * 8, color=6))
        self.assertEqual(review.validate_png(self.path), (2, 1))

    def test_header_only_regression(self):
        self.reject(fixture_png()[:33])

    def test_crc_mismatch(self):
        corrupted = bytearray(png())
        corrupted[29] ^= 1
        self.reject(bytes(corrupted))

    def test_missing_iend(self):
        self.reject(png()[:-12])

    def test_truncated_chunk(self):
        self.reject(png()[:-3])

    def test_invalid_zlib_with_valid_crc(self):
        self.reject(png(compressed=b"not zlib"))

    def test_truncated_zlib_with_valid_crc(self):
        self.reject(png(compressed=zlib.compress(b"\x00" * 7)[:-2]))

    def test_extra_zlib_stream(self):
        self.reject(png(compressed=zlib.compress(b"\x00" * 7) + zlib.compress(b"extra")))

    def test_too_few_pixels(self):
        self.reject(png(b"\x00" * 6))

    def test_too_many_pixels(self):
        self.reject(png(b"\x00" * 8))

    def test_invalid_row_filter(self):
        self.reject(png(b"\x05" + b"\x00" * 6))

    def test_trailing_bytes(self):
        self.reject(png() + b"junk")

    def test_oversized_dimensions(self):
        self.reject(png(width=1000000, height=1000000))

    def test_zero_dimensions(self):
        self.reject(png(width=0))

    def test_unsupported_color(self):
        self.reject(png(color=3))

    def test_duplicate_header(self):
        self.reject(png()[:33] + png()[8:])

    def test_unknown_critical_chunk(self):
        self.reject(png()[:33] + chunk(b"ABCD", b"") + png()[33:])

    def test_consecutive_idat_chunks(self):
        body = zlib.compress(b"\x00" * 7)
        data = png()[:33] + chunk(b"IDAT", body[:3]) + chunk(b"IDAT", body[3:]) + chunk(b"IEND", b"")
        self.path.write_bytes(data)
        self.assertEqual(review.validate_png(self.path), (2, 1))

    def test_nonconsecutive_idat_chunks(self):
        body = zlib.compress(b"\x00" * 7)
        self.reject(png()[:33] + chunk(b"IDAT", body[:3]) + chunk(b"tEXt", b"a\0b")
                    + chunk(b"IDAT", body[3:]) + chunk(b"IEND", b""))

    def test_iend_without_idat(self):
        self.reject(png()[:33] + chunk(b"IEND", b""))

    def test_header_only_manifest_no_longer_passes(self):
        path, data = capture(self.path.parent / "capture")
        for record in data["images"]:
            (path.parent / record["file"]).write_bytes(fixture_png()[:33])
        with self.assertRaises(review.ReviewError):
            review.validate_manifest(path, self.path.parent)


class WaterEvidenceTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.path, self.data = capture(self.root / "capture")
        self.state = water()

    def check(self):
        review.validate_water_manifest(self.data, self.state, True)

    def reject(self):
        with self.assertRaises(review.ReviewError):
            self.check()

    def test_valid_evidence(self):
        self.check()

    def test_missing_frame_water(self):
        del self.data["images"][0]["water"]
        self.reject()

    def test_inactive_binding(self):
        self.state["active"] = False
        self.reject()

    def test_binding_error(self):
        self.state["error"] = "missing pool"
        self.reject()

    def test_wrong_flow_state(self):
        self.data["images"][0]["water"]["flow_enabled"] = False
        self.reject()

    def test_fragmented_contacts(self):
        self.state["impact_segments_xz"] *= 4
        self.reject()

    def test_degenerate_contact(self):
        self.state["impact_segments_xz"][0] = [0, 0, 0, 0]
        self.reject()

    def test_duplicate_reversed_contacts(self):
        span = self.state["impact_segments_xz"][0]
        self.state["impact_segments_xz"][1] = span[2:] + span[:2]
        self.reject()

    def test_nonfinite_and_nonnumeric_contacts(self):
        for value in (float("nan"), float("inf"), True, "1", 10 ** 400):
            with self.subTest(value=str(value)[:20]):
                self.state["impact_segments_xz"][0][0] = value
                self.reject()

    def test_backwards_clock(self):
        self.data["images"][-1]["water"]["time_seconds"] = 0.0
        self.reject()

    def test_negative_clock(self):
        self.state["time_seconds"] = -1
        self.reject()

    def test_changed_contact(self):
        self.data["images"][-1]["water"]["impact_segments_xz"][0][0] += 1.0
        self.reject()

    def test_changed_water_level(self):
        self.data["images"][0]["water"]["water_level"] += 0.1
        self.reject()

    def test_invalid_contact_band(self):
        self.state["contact_band"] = 0.0
        self.reject()

    def test_camera_pair_mismatch(self):
        self.data["images"][1]["camera_position"][0] += 1.0
        self.reject()

    def test_bad_camera_values(self):
        self.data["images"][0]["camera_rotation"][0] = float("nan")
        self.reject()

    def test_bad_fov(self):
        self.data["images"][0]["camera_fov"] = 180.0
        self.reject()

    def test_headless_not_graphics_evidence(self):
        self.data["display_server"] = "headless"
        self.reject()

    def test_missing_engine(self):
        del self.data["engine"]
        self.reject()

    def test_viewport_resized(self):
        self.data["images"][1]["height"] += 1
        self.reject()

    def test_flow_pairs_allow_different_live_times(self):
        _, off = capture(self.root / "off", False)
        for record in off["images"]:
            record["water"]["time_seconds"] += 10
        review.validate_water_manifest(off, water(False), False)
        review.validate_flow_pair(self.data, off)

    def test_flow_pair_camera_mismatch(self):
        _, off = capture(self.root / "off", False)
        off["images"][0]["camera_position"][0] += 1
        with self.assertRaises(review.ReviewError):
            review.validate_flow_pair(self.data, off)

    def test_flow_pair_lost_contact(self):
        _, off = capture(self.root / "off", False)
        off["images"][0]["water"]["impact_segments_xz"][0][0] += 2
        with self.assertRaises(review.ReviewError):
            review.validate_flow_pair(self.data, off)

    def test_water_ready_marker_requires_one_object(self):
        for output in ("", "WATER_READY null", "WATER_READY []", "WATER_READY {}\nWATER_READY {}"):
            with self.subTest(output=output), self.assertRaises(review.ReviewError):
                review.marked_json(output, "WATER_READY ")


class GateOrchestrationTests(unittest.TestCase):
    """Fake stage outputs prove orchestration, never claim an engine was run."""
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.calls = []
        self.fail_stage = None
        self.bad_binding = False
        self.missing_water = False
        self.corrupt_png = False
        self.version = "4.7.1.stable.synthetic-test\n"

    def stage(self, command, log, timeout, marker=None):
        self.calls.append((log.stem, command))
        log.write_text("SYNTHETIC TEST STAGE\n", encoding="utf-8")
        if log.stem == self.fail_stage:
            raise review.ReviewError("synthetic stage failed")
        if "--version" in command:
            return self.version
        if "--import" in command:
            return "synthetic import\n"
        if "res://tests/test_navigation.gd" in command:
            return "NAVIGATION_TESTS_OK checks=30\n"
        if "res://tests/test_water_interaction.gd" in command:
            return "WATER_TESTS_OK checks=80\n"
        if "res://tests/test_scene_water.gd" in command:
            scene = next(arg.split("=", 1)[1] for arg in command if arg.startswith("--test-scene="))
            data = {"scene": "wrong" if self.bad_binding else scene,
                    "checks": 45, "impact_count": 2, "graphics_validated": False}
            return "SCENE_WATER_TESTS_OK " + json.dumps(data) + "\n"
        root = Path(next(arg.split("=", 1)[1] for arg in command if arg.startswith("--capture-dir=")))
        enabled = "--water-off" not in command
        path, data = capture(root / "capture", enabled)
        if self.corrupt_png:
            (path.parent / data["images"][0]["file"]).write_bytes(fixture_png()[:33])
        ready = "" if self.missing_water else "WATER_READY " + json.dumps(water(enabled)) + "\n"
        return ready + "REVIEW_OK " + json.dumps({"manifest": str(path)}) + "\n"

    def run_gate(self, *args):
        with mock.patch.object(review, "resolve_engine", return_value="synthetic-godot"), \
                mock.patch.object(review, "revision", return_value={"commit": "synthetic", "dirty": False}), \
                mock.patch.object(review, "run_stage", side_effect=self.stage), \
                contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            result = review.main(["--output", str(self.root), *args])
        reports = list(self.root.glob("run-*/runner-report.json"))
        self.assertEqual(len(reports), 1)
        return result, json.loads(reports[0].read_text())

    def test_import_precedes_all_runtime_suites(self):
        result, report = self.run_gate("--tests-only")
        self.assertEqual(result, 0)
        self.assertEqual([name for name, _ in self.calls], ["version", "import", "navigation", "water", "binding-editable"])
        self.assertEqual(report["status"], "runtime_tests_passed")
        self.assertEqual(report["graphics_validation"], "not_run")
        self.assertEqual(report["visual_acceptance"], "not_evaluated")

    def test_default_captures_24_with_both_flow_states(self):
        result, report = self.run_gate()
        self.assertEqual(result, 0)
        self.assertEqual(report["capture_count"], 24)
        self.assertEqual([item["flow_enabled"] for item in report["captures"]], [True, False])
        self.assertIn("--water-off", self.calls[-1][1])
        self.assertNotIn("--headless", self.calls[-1][1])
        self.assertEqual(report["visual_acceptance"], "not_evaluated")
        self.assertFalse(report["pixel_deterministic"])

    def test_both_scenes_capture_48(self):
        result, report = self.run_gate("--scene", "both")
        self.assertEqual(result, 0)
        self.assertEqual(report["capture_count"], 48)
        self.assertEqual(len(report["captures"]), 4)
        self.assertIn("binding-builder", [name for name, _ in self.calls])
        self.assertTrue(all("--save-editable" not in command for _, command in self.calls))

    def test_single_flow_state_preserves_12_image_mode(self):
        result, report = self.run_gate("--water", "on")
        self.assertEqual(result, 0)
        self.assertEqual(report["capture_count"], 12)
        self.assertTrue(all("--water-off" not in command for _, command in self.calls))

    def test_water_failure_stops_before_capture(self):
        self.fail_stage = "water"
        result, report = self.run_gate()
        self.assertEqual(result, 1)
        self.assertEqual(report["runtime_validation"], "failed")
        self.assertEqual(report["graphics_validation"], "not_run")
        self.assertEqual(report["stages"][-1]["status"], "failed")
        self.assertFalse(report["captures"])

    def test_import_failure_stops_before_tests(self):
        self.fail_stage = "import"
        result, report = self.run_gate()
        self.assertEqual(result, 1)
        self.assertEqual(len(self.calls), 2)
        self.assertFalse(report["captures"])

    def test_wrong_scene_binding_marker_rejected(self):
        self.bad_binding = True
        result, report = self.run_gate()
        self.assertEqual(result, 1)
        self.assertEqual(report["runtime_validation"], "failed")
        self.assertEqual(report["graphics_validation"], "not_run")

    def test_missing_water_ready_not_masked_by_review_ok(self):
        self.missing_water = True
        result, report = self.run_gate()
        self.assertEqual(result, 1)
        self.assertEqual(report["runtime_validation"], "passed")
        self.assertEqual(report["graphics_validation"], "failed")

    def test_corrupt_capture_fails_after_process_success(self):
        self.corrupt_png = True
        result, report = self.run_gate()
        self.assertEqual(result, 1)
        self.assertEqual(report["graphics_validation"], "failed")
        self.assertIn("IEND", report["error"])

    def test_old_engine_rejected(self):
        self.version = "3.6.stable\n"
        result, report = self.run_gate()
        self.assertEqual(result, 1)
        self.assertEqual(len(self.calls), 1)
        self.assertEqual(report["runtime_validation"], "not_run")

    def test_engine_below_documented_baseline_rejected(self):
        self.version = "4.6.2.stable\n"
        result, report = self.run_gate()
        self.assertEqual(result, 1)
        self.assertEqual(len(self.calls), 1)
        self.assertIn("4.7.1", report["error"])

    def test_missing_engine_still_writes_report(self):
        with mock.patch.object(review.shutil, "which", return_value=None), \
                contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            result = review.main(["--output", str(self.root), "--godot", "missing-engine"])
        self.assertEqual(result, 1)
        report = json.loads(next(self.root.glob("run-*/runner-report.json")).read_text())
        self.assertEqual(report["status"], "failed")
        self.assertEqual(report["runtime_validation"], "not_run")
        self.assertIn("not found", report["error"])

    def test_nonfinite_timeout_rejected(self):
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            for timeout in ("nan", "inf", "-inf"):
                with self.subTest(timeout=timeout):
                    result = review.main(["--output", str(self.root), f"--timeout={timeout}"])
                    self.assertEqual(result, 1)

    def test_real_subprocess_error_not_hidden_by_zero_exit(self):
        with self.assertRaises(review.ReviewError):
            review.run_stage([sys.executable, "-c", 'print("ERROR: synthetic failure")'], self.root / "error.log", 5)

    def test_real_subprocess_success_is_captured(self):
        text = review.run_stage([sys.executable, "-c", 'print("TEST_OK real subprocess")'],
                                self.root / "success.log", 5, "TEST_OK ")
        self.assertIn("TEST_OK", text)


class RuntimeSourceContracts(unittest.TestCase):
    """Source contracts only: this test class does not parse GDScript."""
    def test_water_member_has_explicit_script_type(self):
        source = (ROOT / "godot/navigation.gd").read_text()
        self.assertIn("var water: WaterInteraction = WaterInteraction.new()", source)

    def test_scene_test_loads_actual_resources_and_real_input(self):
        source = (ROOT / "godot/tests/test_scene_water.gd").read_text()
        for text in ("courtyard_editable.tscn", "courtyard.tscn", "load(path) as PackedScene",
                     "root.add_child(scene)", "scene._unhandled_input(event)",
                     "sheet.global_position +=", "scene.water.advance(0.0)",
                     '"graphics_validated": false', "SCENE_WATER_TESTS_OK"):
            self.assertIn(text, source)
        self.assertNotIn("ResourceSaver", source)
        self.assertNotIn("save_editable_scene", source)
        self.assertNotIn("ArrayMesh.new()", source)


if __name__ == "__main__":
    unittest.main()
