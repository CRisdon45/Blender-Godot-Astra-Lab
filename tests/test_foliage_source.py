"""Narrow source regressions. Runtime mesh/visual evidence comes from Godot, not these checks."""
import ast
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class FoliageSourceContracts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = (ROOT/'tools/build_anime_foliage.py').read_text()
        cls.shader = (ROOT/'godot/shaders/anime_foliage.gdshader').read_text()
        cls.capture = (ROOT/'godot/tests/capture_foliage.gd').read_text()

    def test_literal_unpack_arity(self):
        # The first remote run caught an extra list absent from the local copy.
        for node in ast.walk(ast.parse(self.build)):
            if isinstance(node, ast.Assign) and isinstance(node.value, (ast.Tuple, ast.List)):
                for target in node.targets:
                    if isinstance(target, (ast.Tuple, ast.List)) and not any(isinstance(x, ast.Starred) for x in target.elts):
                        self.assertEqual(len(target.elts), len(node.value.elts), f'line {node.lineno}')

    def test_explicit_named_color_export(self):
        self.assertIn("export_vertex_color='NAME'", self.build)
        self.assertIn("export_vertex_color_name='BrushData'", self.build)
        self.assertIn('export_all_vertex_colors=False', self.build)

    def test_source_not_overwritten(self):
        self.assertIn("SOURCE = ROOT / 'pool_godot_source.blend'", self.build)
        self.assertIn("authoring/'courtyard_anime.blend'", self.build)
        self.assertNotIn('save_as_mainfile(filepath=str(SOURCE))', self.build)
        self.assertIn("OUT/'courtyard_anime.glb'", self.build)

    def test_not_whole_plant_billboard(self):
        self.assertIn('vec3 center = VERTEX - vec3(offset, 0.0)', self.shader)
        self.assertIn('MAIN_CAM_INV_VIEW_MATRIX', self.shader)
        self.assertIn('MODEL_NORMAL_MATRIX * NORMAL', self.shader)
        self.assertNotIn('ALPHA =', self.shader)
        self.assertIn('discard;', self.shader)

    def test_reference_entrypoints_preserved(self):
        baseline = (ROOT/'godot/courtyard.gd').read_text()
        study = (ROOT/'godot/courtyard_anime.gd').read_text()
        self.assertIn('return "res://assets/backyard.glb"', baseline)
        self.assertIn('return "res://assets/anime/courtyard_anime.glb"', study)
        self.assertIn('run/main_scene="res://courtyard_editable.tscn"', (ROOT/'godot/project.godot').read_text())

    def test_real_captures_and_full_orbit(self):
        self.assertIn('root.get_texture().get_image()', self.capture)
        self.assertIn('for mode in ["before", "after"]', self.capture)
        self.assertIn('range(12)', self.capture)
        self.assertIn('Exporter/shader card-center contract failed', self.capture)
        self.assertIn('visual_acceptance', self.capture)
        self.assertIn('not_approved', self.capture)

if __name__ == '__main__':
    unittest.main()
