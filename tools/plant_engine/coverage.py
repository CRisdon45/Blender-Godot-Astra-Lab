"""Nested, geometry-aware foliage reduction performed only at compile time.

The fixed-card renderer is unchanged. A farthest-point prefix covers each lobe
more evenly than every Nth randomly ranked card, with exactly the same count.
This is a spacing heuristic, not a guarantee of equal visible coverage or GPU cost.
"""
from __future__ import annotations
from functools import lru_cache
import math
from typing import Any, Sequence


@lru_cache(maxsize=1024)
def _coverage_order(records: tuple) -> tuple[int, ...]:
    count = len(records)
    low = [min(row[1][axis] for row in records) for axis in range(3)]
    span = [max(row[1][axis] for row in records) - low[axis] for axis in range(3)]
    points = [tuple((row[1][axis] - low[axis]) / max(span[axis], 1e-9)
                    for axis in range(3)) for row in records]
    nearest = [math.inf] * count
    used = [False] * count
    order = []
    current = 0  # Stable rank/id ordering provides a reproducible starting anchor.
    for _ in range(count):
        order.append(current)
        used[current] = True
        x, y, z = points[current]
        for index, (px, py, pz) in enumerate(points):
            if not used[index]:
                distance = (x-px)**2 + (y-py)**2 + (z-pz)**2
                nearest[index] = min(nearest[index], distance)
        if len(order) < count:
            current = max((i for i in range(count) if not used[i]),
                          key=lambda i: (nearest[i], -i))
    return tuple(order)


def select_coverage(cards: Sequence[Any], stride: int) -> list[Any]:
    """Select a deterministic nested prefix; preserve the original LOD0 ordering."""
    if type(stride) is not int or not 1 <= stride <= 16:
        raise ValueError('Coverage stride must be an integer in [1,16]')
    values = sorted(cards, key=lambda card: (card.rank, card.id))
    if stride == 1 or not values:
        return values
    if len({card.id for card in values}) != len(values):
        raise ValueError('Duplicate foliage anchor identity')
    records = tuple((card.id, tuple(card.center), float(card.rank)) for card in values)
    if any(not all(math.isfinite(v) for v in row[1]) for row in records):
        raise ValueError('Non-finite foliage anchor')
    count = (len(values) + stride - 1) // stride
    return [values[index] for index in _coverage_order(records)[:count]]
