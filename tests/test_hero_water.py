"""Source/math regressions only. Actual shader validation requires Godot captures."""
from pathlib import Path
import math
import unittest
ROOT=Path(__file__).resolve().parents[1]

class HeroWaterContracts(unittest.TestCase):
    def test_all_shaders_share_explicit_clock(self):
        for name in ('hero_water.gdshader','hero_basin.gdshader','hero_spillway.gdshader'):
            text=(ROOT/'godot/shaders'/name).read_text()
            self.assertIn('uniform float water_time',text)
            self.assertNotIn('TIME',text)

    def test_surface_and_receiver_share_spectrum(self):
        for name in ('hero_water.gdshader','hero_basin.gdshader'):
            self.assertIn('#include "res://shaders/hero_water_common.gdshaderinc"',
                          (ROOT/'godot/shaders'/name).read_text())

    def test_refraction_guards_and_no_double_lighting(self):
        text=(ROOT/'godot/shaders/hero_water.gdshader').read_text()
        for required in ('receiver_world.y>water_level','valid_uv','refracted_receiver.z>VERTEX.z',
                         'EMISSION = transmitted','exp(-absorption_per_metre*path_length)',
                         'RENDERER_COMPATIBILITY','face_normal.y < 0.8'):
            self.assertIn(required,text)
        self.assertNotIn('43.0',text) # old high-frequency horizontal fine pattern
        self.assertNotIn('METALLIC = 0.08',text)

    def test_caustics_on_lit_receiver(self):
        text=(ROOT/'godot/shaders/hero_basin.gdshader').read_text()
        self.assertIn('LIGHT_COLOR*ATTENUATION',text)
        self.assertIn('pool_hessian',text)
        self.assertNotIn('EMISSION',text)

    def test_absorption_is_monotone_bounded_and_clear_at_zero(self):
        for coefficient in (0.85,0.20,0.095):
            values=[math.exp(-coefficient*d) for d in (0,.05,.25,.5,1,3,12)]
            self.assertEqual(values[0],1)
            self.assertTrue(all(0<v<=1 for v in values))
            self.assertTrue(all(a>=b for a,b in zip(values,values[1:])))

    def test_water_fresnel_not_plastic(self):
        f0=((1.333-1)/(1.333+1))**2
        self.assertAlmostEqual(f0,0.02037,places=4)
        values=[f0+(1-f0)*(1-c)**5 for c in (1,.8,.5,.1,0)]
        self.assertTrue(all(a<=b for a,b in zip(values,values[1:])))

    def test_original_entrypoints_preserved(self):
        config=(ROOT/'godot/project.godot').read_text()
        self.assertIn('run/main_scene="res://courtyard_editable.tscn"',config)
        self.assertIn('extends "res://courtyard_anime.gd"',
                      (ROOT/'godot/courtyard_hero_water.gd').read_text())

    def test_no_shader_or_contact_simulation_replaced_by_images(self):
        text=(ROOT/'godot/courtyard_hero_water.gd').read_text()
        self.assertIn('super._ready()',text)
        self.assertIn('ReflectionProbe.UPDATE_ONCE',text)
        self.assertIn('water._pool.layers = 2',text)
        self.assertIn('probe.cull_mask = 1',text)

    def test_godot_probe_class_and_explicit_rebind(self):
        text=(ROOT/'godot/courtyard_hero_water.gd').read_text()
        self.assertNotIn('ReflectionProbe3D',text)
        self.assertIn('ReflectionProbe.new()',text)
        self.assertIn('water.rebuild_contacts()',text)

    def test_painted_night_control_preserves_day_default(self):
        text=(ROOT/'godot/shaders/anime_foliage.gdshader').read_text()
        self.assertIn('paint_illumination : hint_range(0.0, 2.0) = 1.0',text)
        self.assertIn('paint * 0.82 * paint_illumination',text)
        hero=(ROOT/'godot/courtyard_hero_water.gd').read_text()
        self.assertIn('"paint_illumination",0.10 if enabled else 1.0',hero)
        self.assertIn('lamp.light_cull_mask = 2',hero)

    def test_runtime_preflight_loads_actual_study(self):
        text=(ROOT/'godot/tests/test_hero_preflight.gd').read_text()
        self.assertIn('preload("res://courtyard_hero_water.gd")',text)
        self.assertIn('preload("res://tests/capture_hero_water.gd")',text)
        capture=(ROOT/'godot/tests/capture_hero_water.gd').read_text()
        self.assertIn('scene.has_method("set_illustration")',capture)
        self.assertIn('get_shader_parameter("impact_count")',capture)

if __name__=='__main__': unittest.main()
