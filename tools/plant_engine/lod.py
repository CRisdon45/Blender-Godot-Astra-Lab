"""Reference implementation for the Godot LOD/budget contract.

Uses normalized projected diameter, not metres or internal render-resolution pixels.
Budget is a deterministic primary-pass triangle target, not a GPU time guarantee.
"""
from __future__ import annotations
from dataclasses import dataclass
import math
from typing import Iterable


@dataclass(frozen=True)
class LodPolicy:
    near_enter: float = .30
    near_exit: float = .24
    far_enter: float = .08
    far_exit: float = .11

    def __post_init__(self) -> None:
        values = (self.far_enter, self.far_exit, self.near_exit, self.near_enter)
        if not all(math.isfinite(v) and v > 0 for v in values) or tuple(sorted(values)) != values:
            raise ValueError('Invalid LOD hysteresis thresholds')

    def choose(self, fraction: float, previous: int = -1) -> int:
        if not math.isfinite(fraction) or fraction < 0 or previous not in (-1, 0, 1, 2):
            raise ValueError('Invalid projected fraction or previous LOD')
        if previous == -1:
            return 0 if fraction >= self.near_enter else (2 if fraction <= self.far_enter else 1)
        # Evaluate a full transition so teleports do not spend a frame at the wrong LOD.
        if previous == 0:
            return 2 if fraction <= self.far_enter else (1 if fraction < self.near_exit else 0)
        if previous == 2:
            return 0 if fraction >= self.near_enter else (1 if fraction > self.far_exit else 2)
        return 0 if fraction >= self.near_enter else (2 if fraction <= self.far_enter else 1)


def projected_fraction(radius_m: float, depth_m: float, projection_y: float,
                       near_m: float = .1, orthographic: bool = False) -> float:
    """Conservative sphere diameter / viewport height. Near-plane crossing stays detailed."""
    if not all(math.isfinite(v) for v in (radius_m, depth_m, projection_y, near_m)):
        raise ValueError('Projection inputs must be finite')
    if radius_m <= 0 or projection_y <= 0 or near_m <= 0:
        raise ValueError('Radius, projection scale and near plane must be positive')
    if depth_m + radius_m < near_m:
        return 0.0
    if orthographic:
        return radius_m * projection_y
    if depth_m - radius_m <= near_m:
        return 100.0
    # Nearest sphere surface is conservative and protects near-camera canopy.
    return radius_m * projection_y / (depth_m - radius_m)


@dataclass(frozen=True)
class BudgetGroup:
    id: str
    projected_fraction: float
    desired_lod: int
    triangles: tuple[int, int, int]
    instance_count: int = 1
    protected: bool = False

    def __post_init__(self) -> None:
        if not self.id or self.desired_lod not in (0, 1, 2):
            raise ValueError('Invalid budget group identity or LOD')
        if not math.isfinite(self.projected_fraction) or self.projected_fraction < 0:
            raise ValueError('Invalid projected fraction')
        if type(self.instance_count) is not int or self.instance_count < 1:
            raise ValueError('Invalid instance count')
        if len(self.triangles) != 3 or any(type(t) is not int or t < 0 for t in self.triangles):
            raise ValueError('Triangle costs must be three nonnegative integers')
        if tuple(sorted(self.triangles, reverse=True)) != self.triangles:
            raise ValueError('LOD costs must not increase with distance')


def allocate_budget(groups: Iterable[BudgetGroup], target: int) -> dict:
    if type(target) is not int or target < 0:
        raise ValueError('Triangle target must be a nonnegative integer')
    groups = list(groups)
    if len({g.id for g in groups}) != len(groups):
        raise ValueError('Duplicate budget group identity')
    chosen = {g.id: g.desired_lod for g in groups}
    total = sum(g.triangles[chosen[g.id]] * g.instance_count for g in groups)
    changes = 0
    while total > target:
        candidates = []
        for group in groups:
            level = chosen[group.id]
            if group.protected or level == 2:
                continue
            saving = (group.triangles[level] - group.triangles[level + 1]) * group.instance_count
            # Equal-cost transitions are allowed so the next level remains reachable.
            # Account for every member so a large shrub batch is not treated as
            # visually expendable merely because it saves many triangles at once.
            priority = group.projected_fraction * group.instance_count / max(saving, 1)
            candidates.append((priority, group.id, group, saving))
        if not candidates:
            break
        _, _, group, saving = min(candidates, key=lambda x: (x[0], x[1]))
        chosen[group.id] += 1
        total -= saving
        changes += 1
    return {'lods': chosen, 'estimated_primary_triangles': total, 'target': target,
            'target_met': total <= target, 'budget_degradations': changes,
            'hidden_plants': 0}
