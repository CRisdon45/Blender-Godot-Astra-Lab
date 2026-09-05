from __future__ import annotations
import dataclasses
import json
import math
from pathlib import Path
import sys
import unittest
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from species_lab_core import PROFILES, compile_plant, cards_for_lod, wood_mesh, metrics, bezier

class SpeciesWitnessTests(unittest.TestCase):
    def test_reproducibility(self):
        for name in PROFILES:
            self.assertEqual(dataclasses.asdict(compile_plant(name,41,.5)),dataclasses.asdict(compile_plant(name,41,.5)))
    def test_seed_changes_shape(self):
        for name in PROFILES:
            self.assertNotEqual(compile_plant(name,41).cards,compile_plant(name,73).cards)
    def test_branch_parent_attachment(self):
        for name in PROFILES:
            for age in (0,.5,1):
                p=compile_plant(name,41,age);branches={b.id:b for b in p.branches}
                for b in p.branches:
                    if b.parent:
                        self.assertEqual(b.points[0],bezier(branches[b.parent].points,b.attach_t))
                        self.assertLess(b.radius,branches[b.parent].radius)
    def test_all_lobes_supported(self):
        for name in PROFILES:
            p=compile_plant(name)
            branches={b.id:b for b in p.branches}
            for lobe in p.lobes:self.assertEqual(lobe.center,branches[lobe.branch_id].points[-1])
    def test_lod_subsets_and_all_lobes_preserved(self):
        for name in PROFILES:
            p=compile_plant(name)
            for source in (p.cards,p.flowers):
                low={c.id for c in cards_for_lod(source,2)};medium={c.id for c in cards_for_lod(source,1)}
                high={c.id for c in cards_for_lod(source,0)}
                self.assertTrue(low<=medium<=high)
                self.assertEqual({c.lobe_id for c in source},{c.lobe_id for c in cards_for_lod(source,2)})
    def test_finite_geometry_and_triangle_budget(self):
        for name in PROFILES:
            for seed in (41,73,97):
                for age in (0,.5,1):
                    p=compile_plant(name,seed,age)
                    for lod,cap in enumerate((5000,2500,1400)):
                        vertices,faces=wood_mesh(p,lod)
                        self.assertLessEqual(metrics(p,lod)['total_triangles'],cap)
                        for v in vertices:self.assertTrue(all(math.isfinite(x) for x in v))
                        for f in faces:self.assertTrue(all(0<=i<len(vertices) for i in f))
    def test_volumetric_canopies(self):
        for name in PROFILES:
            for age in (0,.5,1):
                p=compile_plant(name,41,age)
                for axis in range(3):
                    span=max(c.center[axis] for c in p.cards)-min(c.center[axis] for c in p.cards)
                    self.assertGreater(span,.1)
    def test_normal_unit_length_and_positive_card_size(self):
        for name in PROFILES:
            p=compile_plant(name)
            for c in p.cards+p.flowers:
                self.assertAlmostEqual(sum(x*x for x in c.normal),1.0,places=5)
                self.assertGreater(min(c.size),0)
                self.assertTrue(0<=c.rank<=1)
    def test_growth_changes_branch_graph_and_dimensions(self):
        for name in PROFILES:
            installed=compile_plant(name,41,0);mature=compile_plant(name,41,1)
            self.assertGreater(len(mature.branches),len(installed.branches))
            self.assertGreater(mature.height,installed.height)
            self.assertGreater(mature.spread,installed.spread)
    def test_invalid_input_fails(self):
        for name,age in [('bad',.5),('texas_sage',-1),('texas_sage',math.nan),('texas_sage',2)]:
            with self.assertRaises(ValueError):compile_plant(name,41,age)
    def test_projection_settings_not_forward_plus(self):
        text=(ROOT/'plant_lab/project.godot').read_text()
        self.assertIn('renderer/rendering_method="mobile"',text)
        self.assertNotIn('forward_plus',text)
        self.assertIn('scaling_3d/scale=0.8',text)
    def test_shader_no_expensive_screen_dependencies(self):
        shader=(ROOT/'plant_lab/shaders/foliage.gdshader').read_text()
        self.assertNotIn('hint_screen_texture',shader)
        self.assertNotIn('hint_normal_roughness_texture',shader)
        self.assertIn('MAIN_CAM_INV_VIEW_MATRIX',shader)
        self.assertIn('discard',shader)
    def test_runtime_no_whole_plant_billboarding(self):
        text=(ROOT/'plant_lab/plant_lab.gd').read_text()
        self.assertIn('MultiMesh.new()',text)
        self.assertNotIn('billboard_mode',text)
        self.assertIn('floori(pos.x/8.0)',text)
    def test_manifest_growth_truth(self):
        self.assertIsNone(PROFILES['texas_sage']['cultivar'])
        for p in PROFILES.values():self.assertTrue(p['source'].startswith('https://'))

if __name__=='__main__':unittest.main()
