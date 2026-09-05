"""Versioned, renderer-neutral recipes. Standard-library validation is fail-closed.

Species facts are inherited study inputs, not verified nursery or calendar predictions.
No Blender, Godot, network, or AI imports belong in this module.
"""
from __future__ import annotations

from dataclasses import dataclass
import hashlib
import json
import math
from pathlib import Path
import re
from typing import Any

SCHEMA = 'plant-recipe/1'
RECIPE_DIR = Path(__file__).resolve().parents[2] / 'plant_lab' / 'recipes'
FAMILIES = ('open_vase_tree', 'basal_woody_shrub')
ID_PATTERN = re.compile(r'^[a-z][a-z0-9_]{0,63}$')


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False,
                      allow_nan=False).encode('utf-8')


def content_hash(value: Any) -> str:
    return hashlib.sha256(canonical_bytes(value)).hexdigest()


def _reject_duplicates(pairs: list[tuple[str, Any]]) -> dict:
    result: dict = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f'Duplicate JSON key: {key}')
        result[key] = value
    return result


def parse_json(text: str) -> Any:
    def invalid_constant(value: str) -> None:
        raise ValueError(f'Non-finite JSON number: {value}')
    return json.loads(text, object_pairs_hook=_reject_duplicates, parse_constant=invalid_constant)


def _object(value: Any, fields: set[str], path: str) -> None:
    if not isinstance(value, dict):
        raise ValueError(f'{path}: expected object')
    if set(value) != fields:
        raise ValueError(f'{path}: missing {sorted(fields - set(value))}; unknown {sorted(set(value) - fields)}')


def _number(value: Any, low: float, high: float, path: str, integer: bool = False) -> None:
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
        raise ValueError(f'{path}: expected finite number')
    if integer and not isinstance(value, int):
        raise ValueError(f'{path}: expected integer')
    if not low <= value <= high:
        raise ValueError(f'{path}: must be in [{low}, {high}]')


def validate_seed(seed: Any) -> int:
    _number(seed, 0, 2**31 - 1, 'seed', integer=True)
    return seed


def validate_maturity(value: Any) -> float:
    _number(value, 0, 1, 'maturity')
    return float(value)


def _text(value: Any, path: str, nullable: bool = False) -> None:
    if nullable and value is None:
        return
    if not isinstance(value, str) or not value.strip() or len(value) > 2048:
        raise ValueError(f'{path}: expected nonempty text (max 2048 characters)')


def validate_recipe(data: dict) -> None:
    _object(data, {'schema', 'id', 'revision', 'family', 'profile', 'growth', 'architecture',
                   'foliage', 'render', 'signature', 'seasonal', 'approval'}, 'recipe')
    if data['schema'] != SCHEMA:
        raise ValueError('Unsupported recipe schema')
    if not isinstance(data['id'], str) or not ID_PATTERN.fullmatch(data['id']):
        raise ValueError('Invalid recipe id')
    _number(data['revision'], 1, 2**31 - 1, 'revision', True)
    if data['family'] not in FAMILIES:
        raise ValueError('Unsupported plant family; add a backend before adding a recipe')
    profile = data['profile']
    _object(profile, {'name', 'botanical', 'cultivar', 'family', 'installed_m', 'mature_m',
                      'dimension_status', 'leaves', 'wood', 'flowers', 'source', 'phenology'}, 'profile')
    if profile['family'] != data['family']:
        raise ValueError('profile.family must match recipe.family')
    for key in ('name', 'botanical', 'dimension_status', 'source', 'phenology'):
        _text(profile[key], 'profile.' + key)
    _text(profile['cultivar'], 'profile.cultivar', nullable=True)
    if not profile['source'].startswith('https://'):
        raise ValueError('profile.source must identify an HTTPS source')
    for key in ('installed_m', 'mature_m'):
        values = profile[key]
        if not isinstance(values, list) or len(values) != 2:
            raise ValueError(f'profile.{key}: expected [height, spread] in metres')
        for value in values:
            _number(value, .01, 100, 'profile.' + key)
    if any(a > b for a, b in zip(profile['installed_m'], profile['mature_m'])):
        raise ValueError('Installed dimensions cannot exceed mature target dimensions')
    for key in ('wood', 'leaves', 'flowers'):
        palette = profile[key]
        if not isinstance(palette, list) or len(palette) != 3:
            raise ValueError(f'profile.{key}: expected three tonal RGB colors')
        for color in palette:
            if not isinstance(color, list) or len(color) != 3:
                raise ValueError(f'profile.{key}: invalid RGB color')
            for value in color:
                _number(value, 0, 1, 'profile.' + key)
    growth = data['growth']
    _object(growth, {'domain', 'calibrated_years', 'height_exponent', 'spread_exponent', 'stages'}, 'growth')
    if growth['domain'] != 'illustrative_maturity_0_to_1' or growth['calibrated_years'] is not False:
        raise ValueError('This backend supports illustrative maturity, not calibrated years')
    for key in ('height_exponent', 'spread_exponent'):
        _number(growth[key], .1, 5, 'growth.' + key)
    if growth['stages'] != [{'key': 'installed', 'value': 0.0}, {'key': 'growing', 'value': .5},
                            {'key': 'mature', 'value': 1.0}]:
        raise ValueError('Compiler/1 requires installed, growing and mature baked stages')
    for stage in growth['stages']:
        _number(stage['value'], 0, 1, 'growth.stages.value')
    arch = data['architecture']
    _object(arch, {'leader_count', 'secondary_activation'}, 'architecture')
    # The two proven grammars have fixed primary arrangements. Reject pretend generality.
    expected = 3 if data['family'] == 'open_vase_tree' else 7
    if type(arch['leader_count']) is not int or arch['leader_count'] != expected:
        raise ValueError(f'This family backend currently requires {expected} leaders')
    _number(arch['secondary_activation'], .01, .99, 'architecture.secondary_activation')
    foliage = data['foliage']
    _object(foliage, {'samples_per_lobe', 'brush_installed_m', 'brush_growth_m', 'brush_aspect',
                      'normal_local_weight', 'flower_every_n'}, 'foliage')
    _number(foliage['samples_per_lobe'], 12, 160, 'foliage.samples_per_lobe', True)
    _number(foliage['brush_installed_m'], .01, 2, 'foliage.brush_installed_m')
    _number(foliage['brush_growth_m'], 0, 2, 'foliage.brush_growth_m')
    _number(foliage['brush_aspect'], .1, 2, 'foliage.brush_aspect')
    _number(foliage['normal_local_weight'], 0, 1, 'foliage.normal_local_weight')
    _number(foliage['flower_every_n'], 1, 20, 'foliage.flower_every_n', True)
    render = data['render']
    _object(render, {'lods', 'pipeline', 'visual_status', 'far_shadow_policy'}, 'render')
    if render['pipeline'] != 'fixed_center_brush/1':
        raise ValueError('Unsupported shader stream contract')
    if render['visual_status'] != 'retune_required' or render['far_shadow_policy'] != 'off_legacy_study':
        raise ValueError('Unreviewed renderer claims must not be silently promoted')
    if not isinstance(render['lods'], list) or len(render['lods']) != 3:
        raise ValueError('Expected three LOD specifications')
    previous = None
    for i, lod in enumerate(render['lods']):
        _object(lod, {'index', 'card_stride', 'card_inflate', 'wood_sides', 'wood_segments', 'triangle_cap'}, f'lod[{i}]')
        if type(lod['index']) is not int or lod['index'] != i:
            raise ValueError('LODs must be ordered 0, 1, 2')
        for key, lo, hi in [('card_stride', 1, 16), ('wood_sides', 3, 12),
                            ('wood_segments', 2, 16), ('triangle_cap', 1, 20000)]:
            _number(lod[key], lo, hi, f'lod[{i}].{key}', True)
        _number(lod['card_inflate'], 1, 3, f'lod[{i}].card_inflate')
        if i == 0 and (lod['card_stride'] != 1 or lod['card_inflate'] != 1):
            raise ValueError('LOD0 must preserve the original card set and sizes')
        if previous:
            if lod['card_stride'] % previous['card_stride']:
                raise ValueError('LOD strides must form nested subsets')
            if lod['card_inflate'] < previous['card_inflate']:
                raise ValueError('Reduced detail cannot shrink foliage coverage')
            for key in ('wood_sides', 'wood_segments', 'triangle_cap'):
                if lod[key] > previous[key]:
                    raise ValueError(f'LOD {key} cannot increase with distance')
        previous = lod
    signature = data['signature']
    if not isinstance(signature, list) or not 1 <= len(signature) <= 16:
        raise ValueError('signature must list 1–16 identifying traits')
    for item in signature:
        _text(item, 'signature')
    if len(set(signature)) != len(signature):
        raise ValueError('Duplicate signature trait')
    _object(data['seasonal'], {'status', 'scenarios', 'litter_rate_calibrated'}, 'seasonal')
    if data['seasonal'] != {'status': 'illustrative_scenarios_only',
                             'scenarios': ['foliage', 'bloom_pulse', 'post_bloom'],
                             'litter_rate_calibrated': False}:
        raise ValueError('Only illustrative seasonal scenarios are implemented')
    _object(data['approval'], {'art', 'android_device', 'calendar_growth', 'production'}, 'approval')
    if any(value is not False for value in data['approval'].values()):
        raise ValueError('This unreviewed study cannot assert art, device, calendar or production approval')


@dataclass(frozen=True)
class PlantRecipe:
    """Store canonical immutable bytes; callers receive copies, not mutable shared state."""
    _payload: bytes

    @classmethod
    def from_dict(cls, value: dict) -> 'PlantRecipe':
        validate_recipe(value)
        return cls(canonical_bytes(value))

    @classmethod
    def load(cls, path: Path | str) -> 'PlantRecipe':
        path = Path(path)
        if path.stat().st_size > 128 * 1024:
            raise ValueError('Recipe exceeds 128 KiB input limit')
        return cls.from_dict(parse_json(path.read_text(encoding='utf-8')))

    @property
    def data(self) -> dict:
        return json.loads(self._payload)

    @property
    def id(self) -> str:
        return self.data['id']

    @property
    def digest(self) -> str:
        return hashlib.sha256(self._payload).hexdigest()

    def envelope(self, maturity: float) -> dict:
        maturity = validate_maturity(maturity)
        d = self.data
        start, end = d['profile']['installed_m'], d['profile']['mature_m']
        h = start[0] + (end[0] - start[0]) * maturity ** d['growth']['height_exponent']
        w = start[1] + (end[1] - start[1]) * maturity ** d['growth']['spread_exponent']
        return {'height_m': h, 'spread_m': w, 'mature_height_m': end[0], 'mature_spread_m': end[1],
                'status': d['profile']['dimension_status'], 'calendar_calibrated': False}


def load_recipes(directory: Path = RECIPE_DIR) -> dict[str, PlantRecipe]:
    result: dict[str, PlantRecipe] = {}
    for path in sorted(directory.glob('*.json')):
        recipe = PlantRecipe.load(path)
        if recipe.id in result:
            raise ValueError(f'Duplicate species id: {recipe.id}')
        if path.stem != recipe.id:
            raise ValueError(f'Recipe filename must match id: {path.name}')
        result[recipe.id] = recipe
    if not result:
        raise ValueError(f'No recipes in {directory}')
    return result
