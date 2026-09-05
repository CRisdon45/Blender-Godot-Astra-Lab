"""Text/interface checks only. These do not parse GDScript or render Godot shaders."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class WaterSourceContracts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binding = (ROOT / "godot/water_interaction.gd").read_text(encoding="utf-8")
        cls.water = (ROOT / "godot/shaders/water.gdshader").read_text(encoding="utf-8")
        cls.spill = (ROOT / "godot/shaders/spillway.gdshader").read_text(encoding="utf-8")
        cls.nav = (ROOT / "godot/navigation.gd").read_text(encoding="utf-8")

    def test_impact_capacity_agrees(self):
        limit = int(re.search(r"const MAX_IMPACTS := (\d+)", self.binding)[1])
        array = int(re.search(r"impact_segments\[(\d+)\]", self.water)[1])
        loop = int(re.search(r"index < (\d+)", self.water)[1])
        self.assertEqual(limit, array)
        self.assertEqual(array, loop)

    def test_all_written_uniforms_exist(self):
        written = set(re.findall(r'set_shader_parameter\("([^"]+)"', self.binding))
        declared = set(re.findall(r"uniform\s+\w+\s+(\w+)", self.water + self.spill))
        self.assertFalse(written - declared)

    def test_shared_clock_and_flow_uniforms(self):
        for source in (self.water, self.spill):
            self.assertRegex(source, r"uniform float water_time\s*=")
            self.assertRegex(source, r"uniform float flow_strength")
            self.assertNotRegex(source, r"\bTIME\b")
        self.assertIn('set_shader_parameter("water_time", water_time)', self.binding)

    def test_contact_geometry_not_camera_coordinates(self):
        self.assertIn("surface_get_arrays", self.binding)
        self.assertIn("triangle_contact(triangle, contact_height)", self.binding)
        self.assertNotIn("Camera3D", self.binding)
        self.assertNotIn("-2.65", self.binding)
        self.assertNotIn("5.48", self.binding)

    def test_contact_band_covers_original_water_motion(self):
        band = float(re.search(r"const CONTACT_BAND := ([\d.]+)", self.binding)[1])
        self.assertGreater(band, 0.007)
        self.assertLess(band, 0.02)

    def test_materials_are_duplicated(self):
        self.assertIn("material.duplicate() as ShaderMaterial", self.binding)
        self.assertIn("set_surface_override_material(surface, local)", self.binding)

    def test_transform_refresh_is_guarded(self):
        self.assertIn("global_transform.is_equal_approx(_transforms[index])", self.binding)
        self.assertIn("var result := rebuild_contacts()", self.binding)
        self.assertIn("is_instance_valid(_watched[index])", self.binding)

    def test_flow_off_does_not_erase_sources_on_rebuild(self):
        self.assertIn("entry.visible = entry.node.visible", self.binding)
        self.assertIn("if not _source_visible(instance):", self.binding)
        self.assertNotIn("if not instance.is_visible_in_tree():", self.binding)

    def test_failures_clear_impacts_and_report(self):
        self.assertIn('set_shader_parameter("impact_count", 0)', self.binding)
        self.assertIn("_segments.size() > MAX_IMPACTS", self.binding)
        self.assertIn("WATER_SETUP_FAILED", self.nav)
        self.assertIn("WATER_UPDATE_FAILED", self.nav)

    def test_world_normal_is_transformed_to_view(self):
        self.assertIn("MODEL_NORMAL_MATRIX * NORMAL", self.water)
        self.assertIn("VIEW_MATRIX * vec4(normal_world, 0.0)", self.water)
        self.assertNotIn("normalize(NORMAL+", self.water)

    def test_segment_distance_has_zero_length_guards(self):
        self.assertIn("max(dot(axis, axis), 0.000001)", self.water)
        self.assertIn("max(distance_to_sheet, 0.001)", self.water)
        self.assertIn("clamp(flow_strength, 0.0, 1.0) * top", self.water)

    def test_water_key_respects_capture_lock(self):
        handler = self.nav.split("func _unhandled_input", 1)[1].split("func _new_capture_directory", 1)[0]
        self.assertLess(handler.index("if _capturing:"), handler.index("KEY_W"))
        self.assertIn("not event.echo", handler)
        self.assertIn("water.set_flow(not water.flow_enabled)", handler)

    def test_capture_records_water_state(self):
        self.assertIn('"water": water.snapshot()', self.nav)
        self.assertIn('"impact_segments_xz": sources', self.binding)
        self.assertIn('"pixel_deterministic": false', self.nav)
        self.assertIn('"--water-off" in args', self.nav)

    def test_runtime_suite_calls_real_implementation(self):
        tests = (ROOT / "godot/tests/test_water_interaction.gd").read_text(encoding="utf-8")
        self.assertIn('preload("res://water_interaction.gd")', tests)
        for method in ("triangle_contact", "clip_contact", "merge_contacts"):
            self.assertIn("Water." + method, tests)
        self.assertIn("binding.setup(fixture.scene)", tests)
        self.assertIn("WATER_TESTS_OK", tests)


if __name__ == "__main__":
    unittest.main()
