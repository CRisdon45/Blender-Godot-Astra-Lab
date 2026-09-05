"""Persistent structural identity over the study's normalized growth domain.

Activation is a stage threshold, NOT a biological birth year. This facade retains
inactive branches in a lifetime plan and evaluates the existing proven grammar.
Continuous meristem growth and calibrated years are intentionally not claimed.
"""
from __future__ import annotations
from dataclasses import asdict, dataclass
import math
from typing import Any
from .recipe import PlantRecipe, content_hash, validate_maturity, validate_seed

TOPOLOGY_VERSION = 'plant-topology/1'


@dataclass(frozen=True)
class BranchIdentity:
    id: str
    parent: str | None
    order: int
    attach_t: float
    activation_stage: float


@dataclass(frozen=True)
class PlantBlueprint:
    recipe: PlantRecipe
    seed: int
    branches: tuple[BranchIdentity, ...]

    @classmethod
    def create(cls, recipe: PlantRecipe, seed: int) -> 'PlantBlueprint':
        from species_lab_core import compile_plant
        seed = validate_seed(seed)
        mature = compile_plant(recipe.id, seed, 1.0, recipe=recipe)
        installed = compile_plant(recipe.id, seed, 0.0, recipe=recipe)
        early_ids = {b.id for b in installed.branches}
        threshold = recipe.data['architecture']['secondary_activation']
        identities = tuple(BranchIdentity(b.id, b.parent, b.order, b.attach_t,
                                          0.0 if b.id in early_ids else threshold)
                           for b in mature.branches)
        result = cls(recipe, seed, identities)
        result._validate()
        return result

    @property
    def id(self) -> str:
        return content_hash({'schema': TOPOLOGY_VERSION, 'recipe': self.recipe.digest,
                             'seed': self.seed})

    def _validate(self) -> None:
        seen: set[str] = set()
        for branch in self.branches:
            if branch.id in seen:
                raise ValueError(f'Duplicate branch id: {branch.id}')
            if branch.parent is not None and branch.parent not in seen:
                raise ValueError(f'Parent missing or not topologically ordered: {branch.id}')
            seen.add(branch.id)
        if sum(b.parent is None for b in self.branches) != 1:
            raise ValueError('Expected a single connected plant root')

    def evaluate(self, maturity: float) -> dict[str, Any]:
        from species_lab_core import compile_plant, bezier
        maturity = validate_maturity(maturity)
        plant = compile_plant(self.recipe.id, self.seed, maturity, recipe=self.recipe)
        actual = {b.id: b for b in plant.branches}
        branches = []
        for identity in self.branches:
            active = maturity >= identity.activation_stage
            if active != (identity.id in actual):
                raise ValueError(f'Growth activation diverged from blueprint: {identity.id}')
            row = asdict(identity)
            row['active'] = active
            row['geometry'] = asdict(actual[identity.id]) if active else None
            if active and identity.parent:
                b = actual[identity.id]
                parent = actual[identity.parent]
                if math.dist(b.points[0], bezier(parent.points, b.attach_t)) > 1e-8:
                    raise ValueError(f'Detached branch: {b.id}')
            branches.append(row)
        return {'schema': TOPOLOGY_VERSION, 'blueprint_id': self.id,
                'species': self.recipe.id, 'seed': self.seed, 'maturity': maturity,
                'coordinate_system': 'metres_z_up',
                'growth_domain': 'illustrative_maturity_0_to_1',
                'calendar_calibrated': False,
                'design_envelope': self.recipe.envelope(maturity),
                'branches': branches,
                'foliage_anchors': [asdict(lobe) for lobe in plant.lobes],
                'diagnostics': {'lifetime_branch_count': len(self.branches),
                                'active_branch_count': len(actual),
                                'active_leaf_brushes': len(plant.cards),
                                'active_flower_brushes': len(plant.flowers)}}
