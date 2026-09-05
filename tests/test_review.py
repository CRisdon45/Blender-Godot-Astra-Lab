"""Tests for the Python review runner using fixtures, not rendered evidence."""
from __future__ import annotations

import contextlib
import importlib.util
import io
import json
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest
from unittest import mock
import zlib

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("review", ROOT / "tools" / "review.py")
review = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(review)


def fixture_png() -> bytes:
    def chunk(name: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + name + data + struct.pack(">I", zlib.crc32(name + data))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 2, 1, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(b"\x00\x00\x00\x00\xff\xff\xff")) + chunk(b"IEND", b""))


class ManifestTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.path = self.root / "capture" / "manifest.json"
        self.path.parent.mkdir()
        self.data = {"schema_version": 1, "mode": "review", "status": "captured",
                     "animation": "live", "pixel_deterministic": False,
                     "visual_acceptance": "not_evaluated", "images": []}
        for view in review.VIEWS:
            for enabled in (True, False):
                filename = f"{view}-{'illustrated' if enabled else 'plain'}.png"
                (self.path.parent / filename).write_bytes(fixture_png())
                self.data["images"].append({"file": filename, "view": view, "illustration": enabled,
                                            "width": 2, "height": 1})
        self.save()

    def save(self) -> None:
        self.path.write_text(json.dumps(self.data), encoding="utf-8")

    def reject(self) -> None:
        self.save()
        with self.assertRaises(review.ReviewError):
            review.validate_manifest(self.path, self.root)

    def test_complete_fixture(self) -> None:
        self.assertEqual(len(review.validate_manifest(self.path, self.root)["images"]), 12)

    def test_missing_pair(self) -> None:
        self.data["images"].pop()
        self.reject()

    def test_duplicate_pair(self) -> None:
        self.data["images"][-1] = self.data["images"][0]
        self.reject()

    def test_unknown_view(self) -> None:
        self.data["images"][0]["view"] = "unregistered"
        self.reject()

    def test_non_boolean_style(self) -> None:
        self.data["images"][0]["illustration"] = 1
        self.reject()

    def test_path_traversal(self) -> None:
        self.data["images"][0]["file"] = "../../baseline.png"
        self.reject()

    def test_missing_image(self) -> None:
        (self.path.parent / self.data["images"][0]["file"]).unlink()
        self.reject()

    def test_truncated_png_header(self) -> None:
        (self.path.parent / self.data["images"][0]["file"]).write_bytes(b"\x89PNG")
        self.reject()

    def test_non_png(self) -> None:
        (self.path.parent / self.data["images"][0]["file"]).write_bytes(b"x" * 40)
        self.reject()

    def test_wrong_dimensions(self) -> None:
        self.data["images"][0]["width"] = 99
        self.reject()

    def test_false_determinism(self) -> None:
        self.data["pixel_deterministic"] = True
        self.reject()

    def test_false_visual_acceptance(self) -> None:
        self.data["visual_acceptance"] = "accepted"
        self.reject()

    def test_wrong_capture_mode(self) -> None:
        self.data["mode"] = "capture"
        self.reject()

    def test_incomplete_status(self) -> None:
        self.data["status"] = "failed"
        self.reject()

    def test_manifest_outside_run(self) -> None:
        with self.assertRaises(review.ReviewError):
            review.validate_manifest(self.path, self.root / "different-run")

    def test_manifest_not_object(self) -> None:
        self.data = []
        self.reject()

    def test_malformed_json(self) -> None:
        self.path.write_text("{not json", encoding="utf-8")
        with self.assertRaises(review.ReviewError):
            review.validate_manifest(self.path, self.root)


class RunnerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.log = Path(self.temp.name) / "stage.log"

    def test_success_marker(self) -> None:
        result = subprocess.CompletedProcess(["godot"], 0, "NAVIGATION_TESTS_OK checks=30\n", "")
        with mock.patch.object(review.subprocess, "run", return_value=result):
            self.assertIn("NAVIGATION_TESTS_OK", review.run_stage(["godot"], self.log, 1, "NAVIGATION_TESTS_OK "))
        self.assertTrue(self.log.is_file())

    def test_zero_exit_with_error_is_failure(self) -> None:
        for error in ["SCRIPT ERROR: invalid call", "SHADER ERROR: failed", "ERROR: import failed", "\x1b[31mERROR:\x1b[0m failed"]:
            with self.subTest(error=error):
                result = subprocess.CompletedProcess(["godot"], 0, "REVIEW_OK {}\n", error)
                with mock.patch.object(review.subprocess, "run", return_value=result):
                    with self.assertRaises(review.ReviewError):
                        review.run_stage(["godot"], self.log, 1, "REVIEW_OK ")

    def test_nonzero_exit(self) -> None:
        result = subprocess.CompletedProcess(["godot"], 1, "REVIEW_OK {}\n", "")
        with mock.patch.object(review.subprocess, "run", return_value=result):
            with self.assertRaises(review.ReviewError):
                review.run_stage(["godot"], self.log, 1)

    def test_missing_completion_marker(self) -> None:
        result = subprocess.CompletedProcess(["godot"], 0, "startup only", "")
        with mock.patch.object(review.subprocess, "run", return_value=result):
            with self.assertRaises(review.ReviewError):
                review.run_stage(["godot"], self.log, 1, "REVIEW_OK ")

    def test_timeout_saves_log(self) -> None:
        error = subprocess.TimeoutExpired(["godot"], 1, output=b"partial output")
        with mock.patch.object(review.subprocess, "run", side_effect=error):
            with self.assertRaises(review.ReviewError):
                review.run_stage(["godot"], self.log, 1)
        self.assertIn("partial output", self.log.read_text())

    def test_os_error_saves_log(self) -> None:
        with mock.patch.object(review.subprocess, "run", side_effect=OSError("launch failed")):
            with self.assertRaises(review.ReviewError):
                review.run_stage(["godot"], self.log, 1)
        self.assertIn("launch failed", self.log.read_text())

    def test_missing_engine(self) -> None:
        with mock.patch.object(review.shutil, "which", return_value=None):
            with self.assertRaises(review.ReviewError):
                review.resolve_engine("missing")

    def test_engine_path_resolved(self) -> None:
        with mock.patch.object(review.shutil, "which", return_value="/apps/Godot"):
            self.assertEqual(review.resolve_engine("godot"), "/apps/Godot")

    def test_both_scenes_use_graphics_and_same_suite(self) -> None:
        for scene in review.SCENES:
            command = review.capture_command("godot", Path("/project with spaces"), Path("/capture with spaces"), scene)
            self.assertNotIn("--headless", command)
            self.assertNotIn("--save-editable", command)
            self.assertIn("--review", command)
            self.assertIn("forward_plus", command)
            self.assertIn(review.SCENES[scene], command)
            self.assertEqual(command[-1], "--capture-dir=/capture with spaces")

    def test_valid_pointer_with_spaces(self) -> None:
        self.assertEqual(review.manifest_from_output('REVIEW_OK {"manifest":"/a b/manifest.json"}'), Path("/a b/manifest.json"))

    def test_bad_pointers(self) -> None:
        for value in ["", "REVIEW_OK nope", "REVIEW_OK {}", "REVIEW_OK null", 'REVIEW_OK {"manifest":false}',
                      'REVIEW_OK {"manifest":"/x"}\nREVIEW_OK {"manifest":"/x"}']:
            with self.subTest(value=value), self.assertRaises(review.ReviewError):
                review.manifest_from_output(value)

    def test_missing_engine_cli_exits_failure(self) -> None:
        with mock.patch.object(review.shutil, "which", return_value=None), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(review.main(["--godot", "not-installed"]), 1)

    def test_invalid_timeout(self) -> None:
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(review.main(["--timeout", "0"]), 1)


class SourceContractTests(unittest.TestCase):
    """Text-level integration checks; these do not parse or execute GDScript."""
    def test_builder_delegates_navigation(self) -> None:
        source = (ROOT / "godot" / "courtyard.gd").read_text()
        self.assertTrue(source.startswith('extends "res://navigation.gd"'))
        self.assertIn("super._ready()", source)
        self.assertNotIn("func _unhandled_input", source)
        self.assertNotIn("capture_after_frames", source)

    def test_no_runtime_capture_targets_baseline(self) -> None:
        for name in ["navigation.gd", "courtyard.gd"]:
            source = (ROOT / "godot" / name).read_text()
            self.assertNotIn('"res://captures/', source)
            self.assertNotIn("godot_courtyard.png", source)

    def test_controller_declares_same_six_views(self) -> None:
        source = (ROOT / "godot" / "navigation.gd").read_text()
        for view in review.VIEWS:
            self.assertIn(f'"{view}"', source)
        self.assertIn('"pixel_deterministic": false', source)

    def test_failed_scene_save_stops_before_capture(self) -> None:
        source = (ROOT / "godot" / "courtyard.gd").read_text()
        self.assertIn('func save_editable_scene() -> Error:', source)
        self.assertLess(source.index('get_tree().quit(1)'), source.index('super._ready()'))
        self.assertIn('\troot.free()\n\treturn result', source)


if __name__ == "__main__":
    unittest.main()
