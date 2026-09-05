"""Regression checks for nested compile-time foliage distribution, not art approval."""
from collections import defaultdict
from dataclasses import replace
import math
from pathlib import Path
import sys
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from plant_engine.coverage import select_coverage
from species_lab_core import compile_plant, cards_for_lod


class CoverageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.plants = [compile_plant(species, seed, maturity)
                      for species in ('desert_museum', 'texas_sage')
                      for seed in (41, 73) for maturity in (0.0, 0.5, 1.0)]

    def test_all_counts_and_nested_identities_preserved(self):
        for plant in self.plants:
            for cards in (plant.cards, plant.flowers):
                groups = defaultdict(list)
                for card in cards:
                    groups[card.lobe_id].append(card)
                previous = {c.id for c in cards}
                for lod in range(3):
                    selected = cards_for_lod(cards, lod)
                    expected = sum((len(g) + 2**lod - 1) // 2**lod for g in groups.values())
                    self.assertEqual(len(selected), expected)
                    self.assertTrue({c.id for c in selected} <= previous)
                    self.assertEqual({c.lobe_id for c in selected}, set(groups))
                    previous = {c.id for c in selected}

    def test_high_detail_order_and_data_unchanged(self):
        for plant in self.plants:
            groups = defaultdict(list)
            for card in plant.cards:
                groups[card.lobe_id].append(card)
            expected = [c for group in groups.values() for c in sorted(group, key=lambda c:(c.rank,c.id))]
            self.assertEqual(cards_for_lod(plant.cards, 0), expected)

    def test_input_order_does_not_change_selection(self):
        values = self.plants[0].cards[:50]
        self.assertEqual(select_coverage(values, 4), select_coverage(list(reversed(values)), 4))

    def test_spatial_gap_reduced_on_each_mature_specimen(self):
        def gap(source, selected):
            return max(min(math.dist(c.center, s.center) for s in selected) for c in source)
        for plant in self.plants:
            if plant.maturity != 1.0:
                continue
            groups = defaultdict(list)
            for card in plant.cards:
                groups[card.lobe_id].append(card)
            for stride in (2, 4):
                old = sum(gap(v, sorted(v,key=lambda c:(c.rank,c.id))[::stride]) for v in groups.values())
                new = sum(gap(v, select_coverage(v, stride)) for v in groups.values())
                self.assertLess(new, old, (plant.species, plant.seed, stride))

    def test_invalid_stride_fails(self):
        for stride in (0, -1, 17, True, 1.5):
            with self.assertRaises(ValueError):
                select_coverage(self.plants[0].cards, stride)

    def test_empty_input_is_valid(self):
        self.assertEqual(select_coverage([], 4), [])

    def test_duplicate_identity_rejected(self):
        card = self.plants[0].cards[0]
        with self.assertRaises(ValueError):
            select_coverage([card, card], 2)

    def test_nonfinite_anchor_rejected(self):
        card = replace(self.plants[0].cards[0], center=(math.nan, 0, 0))
        with self.assertRaises(ValueError):
            select_coverage([card], 2)


if __name__ == '__main__':
    unittest.main()
