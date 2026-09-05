"""Offline source/math checks are not Godot parsing, shader or visual acceptance."""
import json
import math
from pathlib import Path
import random
import tempfile
import unittest
from unittest.mock import patch
from tools import run_water_reflection_review as runner

ROOT = Path(__file__).resolve().parents[1]

def source(path):
    return (ROOT / path).read_text()

def mirror(matrix, origin, level):
    # Columns: -R*right, R*up, R*back. Mirrors twice to the original camera.
    basis = [[v * (-1 if axis == 0 else 1) * (-1 if i == 1 else 1)
              for i, v in enumerate(column)] for axis, column in enumerate(matrix)]
    return basis, [origin[0], 2 * level - origin[1], origin[2]]

def det(c):
    return (c[0][0]*(c[1][1]*c[2][2]-c[1][2]*c[2][1])
            - c[1][0]*(c[0][1]*c[2][2]-c[0][2]*c[2][1])
            + c[2][0]*(c[0][1]*c[1][2]-c[0][2]*c[1][1]))

class MathTests(unittest.TestCase):
    def test_camera_mirror_is_involution(self):
        rng = random.Random(25)
        for _ in range(50):
            matrix = [[rng.uniform(-1, 1) for _ in range(3)] for _ in range(3)]
            origin = [rng.uniform(-15, 15) for _ in range(3)]
            level = rng.uniform(-3, 3)
            b, p = mirror(*mirror(matrix, origin, level), level)
            for before, after in zip(sum(matrix, []), sum(b, [])):
                self.assertAlmostEqual(before, after)
            for before, after in zip(origin, p):
                self.assertAlmostEqual(before, after)
    def test_handedness_is_retained(self):
        b, _ = mirror([[1,0,0],[0,1,0],[0,0,1]], [4,3.3,10], .3225)
        self.assertAlmostEqual(det(b), 1)
    def test_known_mirrored_height(self):
        _, p = mirror([[1,0,0],[0,1,0],[0,0,1]], [4,3.3,10], .3225)
        self.assertAlmostEqual(p[1], -2.655)
    def test_analytic_wave_derivatives(self):
        # Check the mathematical implementation used by the shared GLSL modes.
        d = (1/math.sqrt(1.31**2), .31/math.sqrt(1.31**2))
        length = math.hypot(*d)
        d = tuple(x/length for x in d)
        a, k, speed, phase, t = .0055, 5.17, 1.23, .3, 2.4
        def h(x, z): return a*math.sin((x*d[0]+z*d[1])*k-speed*t+phase)
        x,z,e = 1.72,-3.1,1e-4
        q = (x*d[0]+z*d[1])*k-speed*t+phase
        self.assertAlmostEqual((h(x+e,z)-h(x-e,z))/(2*e), a*k*d[0]*math.cos(q), places=7)
        self.assertAlmostEqual((h(x+e,z)-2*h(x,z)+h(x-e,z))/e**2, -a*k*k*d[0]**2*math.sin(q), places=6)
    def test_fresnel_energy_weights(self):
        for index in range(101):
            cosine=index/100
            f=.02037+(1-.02037)*(1-cosine)**5
            self.assertGreaterEqual(f,0)
            self.assertLessEqual(f,1)
            self.assertAlmostEqual(f+(1-f),1)

class SourceTests(unittest.TestCase):
    def test_original_entrypoints_are_preserved(self):
        self.assertNotIn('water_reflections',source('godot/project.godot'))
        self.assertNotIn('planar_',source('godot/courtyard_hero_water.gd'))
    def test_uses_linear_hdr_without_color_decode(self):
        self.assertIn('viewport.use_hdr_2d = true',source('godot/planar_water_reflection.gd'))
        shader=source('godot/shaders/planar_pool_water.gdshader')
        sampler=next(s for s in shader.splitlines() if s.startswith('uniform sampler2D planar_texture'))
        self.assertNotIn('source_color',sampler.split('//')[0])
        self.assertIn('TONE_MAPPER_LINEAR',source('godot/planar_water_reflection.gd'))
    def test_clipping_is_specific_and_shadow_safe(self):
        helper=source('godot/planar_water_reflection.gd')
        for token in ['CAMERA_VISIBLE_LAYERS & 262144u','!IN_SHADOW_PASS','reflected_world.y < reflection_plane_y','source_camera.cull_mask &= ~REFLECTION_LAYER']:
            self.assertIn(token,helper)
    def test_sampler_lifetime_is_broken(self):
        helper=source('godot/planar_water_reflection.gd')
        for token in ['"planar_texture", null','SubViewport.UPDATE_DISABLED','viewport.world_3d = null','func _exit_tree()']:
            self.assertIn(token,helper)
    def test_unsupported_camera_disables_capture(self):
        helper=source('godot/planar_water_reflection.gd')
        self.assertIn('Camera3D.PROJECTION_FRUSTUM',helper)
        self.assertIn('source_camera.global_position.y > plane_y + 0.01',helper)
    def test_shared_explicit_clock_not_wall_time(self):
        for name in ['planar_pool_water.gdshader','caustic_basin.gdshader','falling_water_film.gdshader']:
            s=source('godot/shaders/'+name)
            self.assertIn('water_time',s)
            self.assertNotIn('TIME',s)
    def test_receiver_pattern_is_not_emission(self):
        s=source('godot/shaders/caustic_basin.gdshader')
        self.assertNotIn('EMISSION=',s.replace(' ',''))
        for token in ['ATTENUATION','fwidth','detail_hessian','caustic_daylight']:
            self.assertIn(token,s)
    def test_refraction_foreground_guards_retained(self):
        s=source('godot/shaders/planar_pool_water.gdshader')
        for token in ['receiver_world.y>water_level+0.002','refracted_receiver.z>VERTEX.z','exp(-absorption_per_metre*path_length)']:
            self.assertIn(token,s)
    def test_film_top_comes_from_source_geometry(self):
        s=source('godot/courtyard_water_reflections.gd')
        self.assertIn('mesh.global_transform * mesh.get_aabb()',s)
        self.assertIn('"sheet_top",bounds.end.y',s)
    def test_clip_proof_has_positive_control(self):
        s=source('godot/tests/capture_water_reflections.gd')
        for token in ['level if clip else -100.0','maximum_linear_value>1.1','below_magenta_pixels==0','below_magenta_pixels>4']:
            self.assertIn(token,s)
    def test_capture_size_uses_render_texture_not_window(self):
        helper=source('godot/planar_water_reflection.gd')
        self.assertIn('source_camera.get_viewport().get_texture().get_size()',helper)
        self.assertNotIn('get_visible_rect()',helper)
    def test_foliage_pose_is_shared_with_reflection(self):
        helper=source('godot/planar_water_reflection.gd')
        self.assertIn('code.replace("MAIN_CAM_INV_VIEW_MATRIX","reflection_foliage_camera")',helper)
        self.assertIn('"reflection_foliage_camera", source_camera.get_camera_transform()',helper)
        self.assertIn('fixed_foliage.size()==12',source('godot/tests/capture_water_reflections.gd'))
    def test_shader_spectrum_and_hessian_share_modes(self):
        s=source('godot/shaders/water_detail_common.gdshaderinc')
        import re
        waves=re.findall(r'detail_wave\(p,t,([^\n]+)\)',s)
        hess=re.findall(r'detail_curvature\(p,t,([^\n]+)\)',s)
        self.assertEqual(len(waves),7)
        self.assertEqual(waves,hess)

class EvidenceTests(unittest.TestCase):
    def fixture(self, directory):
        rows=[]
        for name in sorted(runner.EXPECTED):
            size=(600,450) if name.startswith('diagnostic-clip-') else (1200,900)
            (directory/name).touch()
            rows.append({'file':name,'width':size[0],'height':size[1], 'camera':[1,2,3], 'aim':[0,0,0],
                         'water':{'time_seconds':2,'flow_enabled':True,'impact_segments_xz':[[1,2,3,4],[5,6,7,8]]},
                         'study':{'reflection_ready':True}})
        data={'images':rows,'errors':[], 'witnesses':{'final_surface':{'mean_rgb_difference':.1,'changed_pixels':20000},'clip_and_hdr':{
            'diagnostic-clip-on':{'below_magenta_pixels':0,'above_green_pixels':20},
            'diagnostic-clip-off':{'below_magenta_pixels':10,'above_green_pixels':20,'maximum_linear_value':3}}}}
        self.write(directory,data)
        return data
    def write(self,directory,data):
        (directory/'water-reflection-review.json').write_text(json.dumps(data))
    @patch.object(runner.review,'validate_png',side_effect=lambda p: (600,450) if p.name.startswith('diagnostic-clip-') else (1200,900))
    def test_complete_synthetic_manifest(self,_mock):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d);self.fixture(p)
            self.assertEqual(len(runner.validate_manifest(p)['images']),30)
    def test_expected_count_is_exact(self):
        self.assertEqual(len(runner.EXPECTED),30)
    def test_duplicate_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d);data=self.fixture(p)
            data['images'][-1]=data['images'][0];self.write(p,data)
            with self.assertRaisesRegex(ValueError,'uniquely'):
                runner.validate_manifest(p)
    def test_runtime_errors_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d);data=self.fixture(p)
            data['errors']=['Broken shader'];self.write(p,data)
            with self.assertRaisesRegex(ValueError,'Runtime contract'):
                runner.validate_manifest(p)
    @patch.object(runner.review,'validate_png',side_effect=lambda p: (600,450) if p.name.startswith('diagnostic-clip-') else (1200,900))
    def test_camera_mismatch_rejected(self,_mock):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d);data=self.fixture(p)
            next(r for r in data['images'] if r['file']=='after-pool.png')['camera']=[9,2,3]
            self.write(p,data)
            with self.assertRaisesRegex(ValueError,'Camera mismatch'):
                runner.validate_manifest(p)
    @patch.object(runner.review,'validate_png',side_effect=lambda p: (600,450) if p.name.startswith('diagnostic-clip-') else (1200,900))
    def test_missing_positive_control_rejected(self,_mock):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d);data=self.fixture(p)
            data['witnesses']['clip_and_hdr']['diagnostic-clip-off']['below_magenta_pixels']=0
            self.write(p,data)
            with self.assertRaisesRegex(ValueError,'positive control'):
                runner.validate_manifest(p)
    @patch.object(runner.review,'validate_png',side_effect=lambda p: (600,450) if p.name.startswith('diagnostic-clip-') else (1200,900))
    def test_inert_reflection_buffer_rejected(self,_mock):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d);data=self.fixture(p)
            data['witnesses']['final_surface']['mean_rgb_difference']=0
            self.write(p,data)
            with self.assertRaisesRegex(ValueError,'final water pixels'):
                runner.validate_manifest(p)
    def test_warning_detection_preserves_texture_leaks(self):
        text='OK\nWARNING: 7 leaked Texture RIDs\nERROR: 2 RID allocations remain\n'
        self.assertEqual(len(runner.engine_warnings(text)),2)
    def test_warnings_are_not_clean_success(self):
        s=source('tools/run_water_reflection_review.py')
        self.assertIn("'diagnostic' if errors or warnings else 'captured'",s)
        self.assertIn('return 1 if errors or warnings else 0',s)

if __name__=='__main__':
    unittest.main()
