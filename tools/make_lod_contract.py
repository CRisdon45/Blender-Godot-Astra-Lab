"""Write reference fixtures for the independently executed Godot smoke test."""
from dataclasses import asdict
import json
from pathlib import Path
from plant_engine.lod import LodPolicy, BudgetGroup, allocate_budget, projected_fraction
ROOT = Path(__file__).resolve().parents[1]
policy = LodPolicy()
choices = [{'fraction': x, 'previous': previous, 'expected': policy.choose(x, previous)}
           for x in (0, .01, .08, .09, .11, .12, .239, .24, .26, .299, .30, .6, 1.0, 100.0)
           for previous in (-1, 0, 1, 2)]
projection = []
for radius, depth, scale, near, ortho in ((1, 10, 2, .1, False), (3, 2, 2, .1, False),
                                       (1, -5, 2, .1, False), (2, 10, .2, .1, True),
                                       (2, 100, .2, .1, True)):
    args = dict(radius_m=radius, depth_m=depth, projection_y=scale, near_m=near, orthographic=ortho)
    projection.append({**args, 'expected': projected_fraction(**args)})
budgets = []
for groups, target in (([BudgetGroup('tree', .4, 0, (4504,2080,1132), 12),
                        BudgetGroup('sage', .15, 0, (1692,992,562), 96)], 140000),
                       ([BudgetGroup('specimen', 1, 0, (1000,500,250), 1, True)], 100),
                       ([BudgetGroup('plant', .2, 0, (500,500,100))], 100), ([], 0)):
    budgets.append({'groups': [asdict(g) for g in groups], 'target': target,
                    'expected': allocate_budget(groups, target)})
value = {'schema':'plant-lod-contract/1', 'choice_cases':choices, 'projection_cases':projection,
         'budget_cases':budgets}
path = ROOT/'plant_lab/engine/tests/lod_contract.json'
path.write_text(json.dumps(value,indent=2)+'\n')
print(f'Wrote {len(choices)+len(projection)+len(budgets)} Godot parity cases')
