from __future__ import annotations
import copy
from dataclasses import asdict
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from plant_engine.recipe import PlantRecipe, load_recipes, canonical_bytes, content_hash, parse_json, validate_seed
from plant_engine.topology import PlantBlueprint
from plant_engine.lod import BudgetGroup, LodPolicy, allocate_budget, projected_fraction
from plant_engine.catalog import build_catalog, safe_file, atomic_write, artifact_key
from species_lab_core import compile_plant, RECIPES, metrics


class RecipeTests(unittest.TestCase):
    def setUp(self):
        self.value = RECIPES['desert_museum'].data

    def invalid(self, change):
        change(self.value)
        with self.assertRaises(ValueError):
            PlantRecipe.from_dict(self.value)

    def test_two_explicit_family_backends(self):
        self.assertEqual({r.data['family'] for r in RECIPES.values()}, {'open_vase_tree', 'basal_woody_shrub'})

    def test_canonical_hash_ignores_object_key_order(self):
        self.assertEqual(PlantRecipe.from_dict(self.value).digest,
                         PlantRecipe.from_dict(dict(reversed(list(self.value.items())))).digest)

    def test_recipe_returns_defensive_copies(self):
        r = PlantRecipe.from_dict(self.value)
        self.value['profile']['name'] = 'Changed outside'
        a = r.data
        a['profile']['name'] = 'Changed copy'
        self.assertEqual(r.data['profile']['name'], 'Desert Museum palo verde')

    def test_unknown_top_level_field_rejected(self):
        self.invalid(lambda d: d.update({'mystery': 1}))

    def test_unknown_parameter_rejected_not_silently_ignored(self):
        self.invalid(lambda d: d['architecture'].update({'unsupported_branch_angle': 45}))

    def test_new_family_requires_backend(self):
        self.invalid(lambda d: d.update({'family': 'agave_rosette'}))

    def test_schema_version_rejected(self):
        self.invalid(lambda d: d.update({'schema': 'plant-recipe/999'}))

    def test_unsupported_leader_configuration_rejected(self):
        self.invalid(lambda d: d['architecture'].update({'leader_count': 9}))

    def test_bool_not_a_seed_or_integer_parameter(self):
        self.invalid(lambda d: d['foliage'].update({'samples_per_lobe': True}))
        for seed in (True, False, -1, 2**31, 1.5, '41'):
            with self.subTest(seed=seed), self.assertRaises(ValueError):
                validate_seed(seed)

    def test_finite_values_required(self):
        for bad in (math.nan, math.inf, -math.inf):
            value = copy.deepcopy(self.value)
            value['foliage']['brush_installed_m'] = bad
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                PlantRecipe.from_dict(value)

    def test_hard_generation_work_limit(self):
        self.invalid(lambda d: d['foliage'].update({'samples_per_lobe': 10000000}))

    def test_no_false_calendar_age_certification(self):
        self.invalid(lambda d: d['growth'].update({'calibrated_years': True}))

    def test_no_false_device_or_art_approval(self):
        for flag in self.value['approval']:
            value = copy.deepcopy(self.value)
            value['approval'][flag] = True
            with self.subTest(flag=flag), self.assertRaises(ValueError):
                PlantRecipe.from_dict(value)

    def test_installed_dimensions_cannot_exceed_mature(self):
        self.invalid(lambda d: d['profile'].update({'installed_m': [20.0, 20.0]}))

    def test_growth_stages_are_not_arbitrary_years(self):
        self.invalid(lambda d: d['growth'].update({'stages': [1, 3, 5]}))

    def test_json_duplicate_keys_rejected(self):
        with self.assertRaises(ValueError):
            parse_json('{"seed": 41, "seed": 73}')

    def test_json_nan_rejected(self):
        with self.assertRaises(ValueError):
            parse_json('{"maturity": NaN}')

    def test_nested_lod_subset_contract(self):
        self.invalid(lambda d: d['render']['lods'][2].update({'card_stride': 3}))

    def test_reversed_lod_costs_rejected(self):
        self.invalid(lambda d: d['render']['lods'][2].update({'triangle_cap': 9999}))

    def test_id_cannot_traverse_directories(self):
        self.invalid(lambda d: d.update({'id': '../other'}))

    def test_unknown_cultivar_remains_unknown(self):
        self.assertIsNone(RECIPES['texas_sage'].data['profile']['cultivar'])

    def test_recipe_parameters_actually_drive_geometry(self):
        original = compile_plant('desert_museum', 41, .5)
        self.value['foliage']['brush_growth_m'] = .1
        changed_recipe = PlantRecipe.from_dict(self.value)
        changed = compile_plant('desert_museum', 41, .5, recipe=changed_recipe)
        self.assertEqual(original.branches, changed.branches)
        self.assertNotEqual(original.cards[0].size, changed.cards[0].size)

    def test_height_growth_curve_controls_dimensions(self):
        self.value['growth']['height_exponent'] = 2.0
        r = PlantRecipe.from_dict(self.value)
        self.assertLess(r.envelope(.5)['height_m'], RECIPES['desert_museum'].envelope(.5)['height_m'])

    @unittest.skipUnless(importlib.util.find_spec('jsonschema'), 'Optional editor-schema validator unavailable')
    def test_json_schema_matches_both_shipped_recipes(self):
        import jsonschema
        schema = json.loads((ROOT / 'schemas/plant_recipe.schema.json').read_text())
        validator = jsonschema.Draft202012Validator(schema)
        for recipe in RECIPES.values():
            validator.validate(recipe.data)
        malformed = copy.deepcopy(self.value)
        malformed['foliage']['samples_per_lobe'] = True
        with self.assertRaises(jsonschema.ValidationError):
            validator.validate(malformed)

    def test_family_backend_not_species_name_controls_structure(self):
        self.value['id'] = 'experimental_tree_variant'
        r = PlantRecipe.from_dict(self.value)
        plant = compile_plant(r.id, 41, 1.0, recipe=r)
        self.assertEqual(plant.branches, compile_plant('desert_museum').branches)
        with self.assertRaises(ValueError):
            compile_plant('desert_museum', recipe=r)


class TopologyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.blueprints = {name: PlantBlueprint.create(recipe, 41) for name, recipe in RECIPES.items()}

    def test_lifetime_ids_preserved_through_all_stages(self):
        for bp in self.blueprints.values():
            ids = [b.id for b in bp.branches]
            for maturity in (0.0, .10, .179, .18, .199, .20, .5, .8, 1.0):
                state = bp.evaluate(maturity)
                self.assertEqual([b['id'] for b in state['branches']], ids)
                self.assertEqual(state['blueprint_id'], bp.id)

    def test_inactive_branches_are_explicit_not_deleted_identity(self):
        for bp in self.blueprints.values():
            young = bp.evaluate(0.0)
            inactive = [b for b in young['branches'] if not b['active']]
            self.assertTrue(inactive)
            self.assertTrue(all(b['geometry'] is None for b in inactive))
            self.assertTrue(all(b['active'] for b in bp.evaluate(1.0)['branches']))

    def test_parent_active_before_child(self):
        for bp in self.blueprints.values():
            for maturity in (0.0, .19, .5, 1.0):
                nodes = {b['id']: b for b in bp.evaluate(maturity)['branches']}
                for b in nodes.values():
                    if b['active'] and b['parent']:
                        self.assertTrue(nodes[b['parent']]['active'])

    def test_branch_activation_matches_recipe_at_boundary(self):
        for bp in self.blueprints.values():
            threshold = bp.recipe.data['architecture']['secondary_activation']
            before = bp.evaluate(threshold - 1e-6)['diagnostics']['active_branch_count']
            after = bp.evaluate(threshold)['diagnostics']['active_branch_count']
            self.assertGreater(after, before)

    def test_seed_changes_blueprint_identity(self):
        for bp in self.blueprints.values():
            self.assertNotEqual(bp.id, PlantBlueprint.create(bp.recipe, 73).id)

    def test_recipe_change_changes_blueprint_identity(self):
        bp = self.blueprints['desert_museum']
        value = bp.recipe.data
        value['foliage']['brush_growth_m'] = .1
        other = PlantBlueprint.create(PlantRecipe.from_dict(value), bp.seed)
        self.assertNotEqual(bp.id, other.id)

    def test_growth_envelope_is_monotonic(self):
        for recipe in RECIPES.values():
            previous = recipe.envelope(0)
            for i in range(1, 101):
                current = recipe.envelope(i / 100)
                self.assertGreaterEqual(current['height_m'], previous['height_m'])
                self.assertGreaterEqual(current['spread_m'], previous['spread_m'])
                self.assertEqual(current['mature_spread_m'], previous['mature_spread_m'])
                previous = current

    def test_no_render_or_engine_types_in_core_output(self):
        state = self.blueprints['texas_sage'].evaluate(.5)
        self.assertEqual(json.loads(canonical_bytes(state))['schema'], 'plant-topology/1')
        self.assertFalse(state['calendar_calibrated'])
        for key in ('Node3D', 'MeshInstance', 'Godot', 'bpy'):
            self.assertNotIn(key, canonical_bytes(state).decode())

    def test_bad_growth_inputs_fail(self):
        for bad in (-.1, 1.1, math.nan, math.inf, True, '3 years'):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                self.blueprints['texas_sage'].evaluate(bad)

    def test_process_hash_seed_does_not_change_output(self):
        source = "import sys;sys.path.insert(0,'tools');from species_lab_core import RECIPES;from plant_engine.topology import PlantBlueprint;from plant_engine.recipe import content_hash;print(content_hash(PlantBlueprint.create(RECIPES['texas_sage'],41).evaluate(.5)))"
        results = []
        for seed in ('10', '123456'):
            result = subprocess.run([sys.executable, '-c', source], cwd=ROOT,
                                    env={**os.environ, 'PYTHONHASHSEED': seed}, capture_output=True, text=True, check=True)
            results.append(result.stdout)
        self.assertEqual(*results)


class LodAndBudgetTests(unittest.TestCase):
    def test_near_and_far_hysteresis(self):
        p = LodPolicy()
        self.assertEqual(p.choose(.26, 0), 0)
        self.assertEqual(p.choose(.26, 1), 1)
        self.assertEqual(p.choose(.09, 2), 2)
        self.assertEqual(p.choose(.09, 1), 1)

    def test_no_toggle_around_hysteresis_middle(self):
        p = LodPolicy()
        state = 0
        for value in [.26, .27, .28, .25] * 50:
            state = p.choose(value, state)
            self.assertEqual(state, 0)

    def test_teleport_gets_correct_lod_immediately(self):
        self.assertEqual(LodPolicy().choose(1.0, 2), 0)
        self.assertEqual(LodPolicy().choose(.01, 0), 2)

    def test_larger_plant_gets_more_screen_coverage(self):
        self.assertGreater(projected_fraction(3, 20, 2), projected_fraction(.6, 20, 2))

    def test_camera_depth_not_euclidean_distance(self):
        # Off-axis Euclidean distance would incorrectly lower detail for a plant at
        # the same camera-space depth. The corrected contract accepts depth.
        correct = projected_fraction(1, 10, 2)
        old_approximation = projected_fraction(1, math.hypot(10, 20), 2)
        self.assertGreater(correct, old_approximation * 2)

    def test_projection_zoom_increases_detail(self):
        self.assertGreater(projected_fraction(1, 10, 3), projected_fraction(1, 10, 1))

    def test_orthographic_detail_independent_of_distance(self):
        self.assertEqual(projected_fraction(2, 10, .2, orthographic=True),
                         projected_fraction(2, 100, .2, orthographic=True))

    def test_near_plane_intersection_keeps_high_detail(self):
        self.assertEqual(projected_fraction(3, 2, 2), 100.0)

    def test_wholly_behind_camera_returns_zero(self):
        self.assertEqual(projected_fraction(1, -5, 2), 0.0)

    def test_invalid_projection_rejected(self):
        for values in ((0, 10, 2), (1, math.nan, 2), (1, 10, -2)):
            with self.assertRaises(ValueError):
                projected_fraction(*values)

    def test_lod_inputs_rejected(self):
        for fraction, previous in ((math.nan, 1), (-1, 0), (.2, 8)):
            with self.assertRaises(ValueError):
                LodPolicy().choose(fraction, previous)

    def test_budget_reduces_cost_without_hiding_plants(self):
        groups = [BudgetGroup('tree', .4, 0, (4504, 2080, 1132), 12),
                  BudgetGroup('sage', .15, 0, (1692, 992, 562), 96)]
        result = allocate_budget(groups, 140000)
        self.assertTrue(result['target_met'])
        self.assertEqual(result['hidden_plants'], 0)
        self.assertEqual(result['lods'], {'tree': 1, 'sage': 1})

    def test_budget_not_affected_by_input_order(self):
        groups = [BudgetGroup('b', .2, 0, (500, 300, 100)), BudgetGroup('a', .2, 0, (500, 300, 100))]
        self.assertEqual(allocate_budget(groups, 500), allocate_budget(reversed(groups), 500))

    def test_unachievable_budget_reported_not_faked(self):
        group = BudgetGroup('specimen', 1, 0, (1000, 500, 250), protected=True)
        result = allocate_budget([group], 100)
        self.assertFalse(result['target_met'])
        self.assertEqual(result['estimated_primary_triangles'], 1000)
        self.assertEqual(result['lods']['specimen'], 0)

    def test_equal_cost_step_does_not_block_cheaper_lod(self):
        result = allocate_budget([BudgetGroup('plant', .2, 0, (500, 500, 100))], 100)
        self.assertTrue(result['target_met'])
        self.assertEqual(result['lods']['plant'], 2)

    def test_duplicate_group_identity_rejected(self):
        g = BudgetGroup('a', .2, 0, (500, 300, 100))
        with self.assertRaises(ValueError):
            allocate_budget([g, g], 100)

    def test_empty_scene_is_valid(self):
        result = allocate_budget([], 0)
        self.assertEqual(result['estimated_primary_triangles'], 0)
        self.assertTrue(result['target_met'])

    def test_godot_reference_fixture_is_current(self):
        fixture = json.loads((ROOT / 'plant_lab/engine/tests/lod_contract.json').read_text())
        for row in fixture['choice_cases']:
            self.assertEqual(LodPolicy().choose(row['fraction'], row['previous']), row['expected'])
        for row in fixture['budget_cases']:
            groups = [BudgetGroup(**{**g, 'triangles': tuple(g['triangles'])}) for g in row['groups']]
            self.assertEqual(allocate_budget(groups, row['target']), row['expected'])

    def test_costs_must_decrease(self):
        with self.assertRaises(ValueError):
            BudgetGroup('bad', .2, 0, (100, 300, 500))


class CacheContractTests(unittest.TestCase):
    def test_safe_asset_path(self):
        self.assertEqual(safe_file(ROOT, 'plant_lab/assets/a.glb'), ROOT / 'plant_lab/assets/a.glb')

    def test_path_traversal_absolute_and_windows_paths_rejected(self):
        for path in ('../secret', '/tmp/file', 'a/../b', 'a//b', 'C:\\file', 'a\\b', './a', 'a/'):
            with self.subTest(path=path), self.assertRaises(ValueError):
                safe_file(ROOT, path)

    def test_symlink_escape_rejected(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            (root / 'escape').symlink_to('/tmp', target_is_directory=True)
            with self.assertRaises(ValueError):
                safe_file(root, 'escape/secret')

    def test_atomic_write_is_idempotent(self):
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / 'catalog.json'
            atomic_write(path, b'one')
            before = path.stat().st_mtime_ns
            atomic_write(path, b'one')
            self.assertEqual(path.stat().st_mtime_ns, before)
            atomic_write(path, b'two')
            self.assertEqual(path.read_bytes(), b'two')
            self.assertEqual([p.name for p in Path(td).iterdir()], ['catalog.json'])

    def test_cache_key_includes_every_geometry_dependency(self):
        args = dict(recipe_hash='a'*64, source_hash='b'*64, shader_hash='c'*64,
                    mesh_sha256='d'*64, seed=41, stage=0, lod=0)
        base = artifact_key(**args)
        for key in ('recipe_hash', 'source_hash', 'shader_hash', 'mesh_sha256', 'seed', 'stage', 'lod'):
            changed = args.copy()
            changed[key] = ('e'*64) if key.endswith('hash') or key.endswith('sha256') else (73 if key == 'seed' else 1)
            self.assertNotEqual(base, artifact_key(**changed), key)

    def test_bad_cache_keys_fail(self):
        with self.assertRaises(ValueError):
            artifact_key(recipe_hash='bad', source_hash='b'*64, shader_hash='c'*64,
                         mesh_sha256='d'*64, seed=41, stage=0, lod=0)


@unittest.skipUnless((ROOT / 'plant_lab/assets/manifest.json').exists(), 'Generated assets not present in source-only checkout')
class BakedArtifactTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = build_catalog(ROOT)

    def test_all_blender_exports_audited(self):
        self.assertEqual(self.catalog['validation']['assets_checked'], 36)
        self.assertTrue(self.catalog['validation']['independent_glb_check'])

    def test_all_baked_source_plants_match_refactored_generator(self):
        for species in RECIPES:
            for seed in (41, 73):
                for stage, maturity in enumerate((0, .5, 1)):
                    actual = json.loads(canonical_bytes(asdict(compile_plant(species, seed, maturity))))
                    path = ROOT / f'plant_lab/assets/{species}_s{seed}_g{stage}.json'
                    self.assertEqual(actual, json.loads(path.read_text()))

    def test_catalog_build_is_bit_reproducible(self):
        self.assertEqual(canonical_bytes(self.catalog), canonical_bytes(build_catalog(ROOT)))

    def test_identity_shared_across_stages_but_asset_keys_distinct(self):
        ids = {}
        hashes = set()
        for variant in self.catalog['variants']:
            ids.setdefault((variant['species'], variant['seed']), set()).add(variant['blueprint_id'])
            for level in variant['lods']:
                hashes.add(level['asset_key'])
        self.assertTrue(all(len(value) == 1 for value in ids.values()))
        self.assertEqual(len(hashes), 36)

    def test_design_envelope_is_separate_from_render_bounds(self):
        for variant in self.catalog['variants']:
            self.assertNotIn('lod', variant['design_envelope'])
            for level in variant['lods']:
                low = level['render_aabb_y_up']['min']
                high = level['render_aabb_y_up']['max']
                self.assertTrue(all(a < b for a, b in zip(low, high)))

    def test_topology_payload_hashes_match_catalog(self):
        for variant in self.catalog['variants']:
            payload = (ROOT / 'plant_lab' / variant['topology_path']).read_bytes()
            self.assertEqual(hashlib.sha256(payload).hexdigest(), variant['topology_sha256'])

    def test_surface_atlases_are_part_of_provenance(self):
        atlas_hashes = self.catalog['provenance']['atlas_sha256']
        self.assertEqual(len(atlas_hashes), 4)
        for name, digest in atlas_hashes.items():
            self.assertEqual(hashlib.sha256((ROOT / 'plant_lab/assets' / name).read_bytes()).hexdigest(), digest)

    def test_no_false_new_render_or_tablet_claim(self):
        self.assertFalse(self.catalog['validation']['godot_runtime_executed_this_build'])
        self.assertFalse(self.catalog['validation']['tablet_tested'])
        self.assertTrue(all(v is False for v in self.catalog['approval'].values()))

    def test_source_only_core_has_no_runtime_ai_or_engine_dependencies(self):
        for path in (ROOT / 'tools/plant_engine').glob('*.py'):
            text = path.read_text()
            for forbidden in ('import bpy', 'import godot', 'import openai', 'import requests', 'import torch'):
                self.assertNotIn(forbidden, text)

    def test_corrupt_mesh_cannot_replace_valid_catalog(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            shutil.copytree(ROOT / 'tools', root / 'tools', ignore=shutil.ignore_patterns('__pycache__'))
            for folder in ('recipes', 'shaders', 'assets'):
                shutil.copytree(ROOT / 'plant_lab' / folder, root / 'plant_lab' / folder)
            output = root / 'plant_lab/engine_data/catalog.json'
            output.parent.mkdir(parents=True)
            output.write_bytes(b'previous-good-catalog')
            model = next((root / 'plant_lab/assets').glob('*.glb'))
            model.write_bytes(b'corrupted')
            with self.assertRaises(ValueError):
                build_catalog(root)
            self.assertEqual(output.read_bytes(), b'previous-good-catalog')

    def test_changed_recipe_rejects_stale_models(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            shutil.copytree(ROOT / 'tools', root / 'tools', ignore=shutil.ignore_patterns('__pycache__'))
            for folder in ('recipes', 'shaders', 'assets'):
                shutil.copytree(ROOT / 'plant_lab' / folder, root / 'plant_lab' / folder)
            recipe_path = root / 'plant_lab/recipes/desert_museum.json'
            recipe = json.loads(recipe_path.read_text())
            recipe['foliage']['brush_installed_m'] += .02
            recipe_path.write_text(json.dumps(recipe))
            with self.assertRaisesRegex(ValueError, 'no longer matches baked source'):
                build_catalog(root)
            self.assertFalse((root / 'plant_lab/engine_data/catalog.json').exists())


if __name__ == '__main__':
    unittest.main()
