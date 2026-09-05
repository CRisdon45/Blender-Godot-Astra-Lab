"""Numerical/source contracts; these are not substitutes for actual Godot validation."""
from pathlib import Path
import math
import random
import unittest
ROOT=Path(__file__).resolve().parents[1]

def source(name):
    return (ROOT/name).read_text()

class WaterV2Contracts(unittest.TestCase):
    def test_reflection_is_involutory_about_any_level(self):
        rng=random.Random(207)
        for _ in range(100):
            level=rng.uniform(-10,10); y=rng.uniform(-100,100)
            mirrored=2*level-y
            self.assertAlmostEqual(2*level-mirrored,y)
            self.assertAlmostEqual(mirrored-level,-(y-level))

    def test_reflected_view_ray_hits_same_surface_point(self):
        for level in (-2,.3225,8):
            eye=(2,level+3,5); target=(0,level,-3)
            reflected_eye=(eye[0],2*level-eye[1],eye[2])
            v=tuple(target[i]-eye[i] for i in range(3))
            reflected_ray=(v[0],-v[1],v[2])
            hit=tuple(reflected_eye[i]+reflected_ray[i] for i in range(3))
            for a,b in zip(hit,target):
                self.assertAlmostEqual(a,b)

    def test_slope_upper_bound_is_calm(self):
        waves=[(3.1,.01),(5.7,.004),(9.2,.0021),(15.3,.0007),(21.7,.0004),(29.9,.00022)]
        self.assertLess(sum(k*a for k,a in waves)*.35,.04)
        for k,a in waves:
            self.assertLess(a,.011)

    def test_scene_is_opt_in(self):
        self.assertIn('courtyard_editable.tscn',source('godot/project.godot'))
        self.assertIn('extends "res://courtyard_hero_water.gd"',source('godot/courtyard_water_v2.gd'))

    def test_no_recursive_reflection_and_bounded_buffer(self):
        text=source('godot/courtyard_water_v2.gd')
        for token in ('reflection_camera.cull_mask=4','mesh!=water._pool','if not receiver:',
                      'mini(768','planar_view_projection','affine_inverse()',
                      'reflection_view.world_3d=null','set_shader_parameter("planar_color",null)'):
            self.assertIn(token,text)

    def test_clip_and_foliage_pose_shared_between_views(self):
        text=source('godot/courtyard_water_v2.gd')
        for token in ('CAMERA_VISIBLE_LAYERS==4u','world_pos.y<reflection_clip_y',
                      'reflected_foliage_position.y<reflection_clip_y',
                      'camera.global_basis.x.normalized()','camera.global_basis.y.normalized()'):
            self.assertIn(token,text)

    def test_refraction_safety_and_radiance_integration(self):
        text=source('godot/shaders/water_v2.gdshader')
        for token in ('RADIANCE=vec4','reflected_clip.w>0.0','receiver_world.y>water_level',
                      'refracted_receiver.z>VERTEX.z','EMISSION = transmitted','SPECULAR = 0.25'):
            self.assertIn(token,text)

    def test_caustics_are_bounded_lit_receivers_not_emissive_paint(self):
        text=source('godot/shaders/basin_v2.gdshader')
        for token in ('fwidth(gap)','exp(-depth*0.26)','smoothstep(0.015,0.16,depth)',
                      'ATTENUATION','LIGHT_IS_DIRECTIONAL','refract('):
            self.assertIn(token,text)
        self.assertNotIn('EMISSION',text)
        self.assertIn('NOT photon tracing',source('godot/shaders/water_v2_common.gdshaderinc'))

    def test_slot_pinned_and_flow_stops_film(self):
        text=source('godot/shaders/spillway_v2.gdshader')
        for token in ('flow_strength<=0.0','smoothstep(0.0,0.18,drop)*flow_strength','0.007','0.003'):
            self.assertIn(token,text)
        self.assertNotIn('TIME',text)

    def test_full_shader_clock_contract(self):
        for name in ('water_v2','basin_v2','spillway_v2'):
            text=source('godot/shaders/'+name+'.gdshader')
            self.assertIn('uniform float water_time',text)
            self.assertNotIn('TIME',text)

    def test_capture_is_real_and_checks_binding(self):
        text=source('godot/tests/capture_water_v2.gd')
        for token in ('packed.instantiate()','set_water_phase','impact_count',
                      'diagnostic-receiver-no-caustics','diagnostic-probe-fallback',
                      'planar-source.png','scene=null','expected_images":22'):
            self.assertIn(token,text)
