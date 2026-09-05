class_name PlantLodPolicy
extends RefCounted
## Keep in parity with tools/plant_engine/lod.py. No renderer allocations here.

var near_enter: float = 0.30
var near_exit: float = 0.24
var far_enter: float = 0.08
var far_exit: float = 0.11

func choose(fraction: float, previous: int = -1) -> int:
	if not is_finite(fraction) or fraction < 0.0 or previous < -1 or previous > 2:
		push_error("Invalid LOD inputs")
		return 0
	if previous == -1:
		return 0 if fraction >= near_enter else (2 if fraction <= far_enter else 1)
	if previous == 0:
		return 2 if fraction <= far_enter else (1 if fraction < near_exit else 0)
	if previous == 2:
		return 0 if fraction >= near_enter else (1 if fraction > far_exit else 2)
	return 0 if fraction >= near_enter else (2 if fraction <= far_enter else 1)

static func projected_fraction(radius: float, depth: float, projection_y: float,
		near_plane: float, orthographic: bool = false) -> float:
	if depth + radius < near_plane:
		return 0.0
	if orthographic:
		return radius * projection_y
	if depth - radius <= near_plane:
		return 100.0
	return radius * projection_y / (depth - radius)

static func allocate_budget(groups: Array, target: int) -> Dictionary:
	var chosen: Dictionary = {}
	var total: int = 0
	for group in groups:
		var level: int = group.desired_lod
		chosen[group.id] = level
		total += int(group.triangles[level]) * int(group.instance_count)
	var changes: int = 0
	while total > target:
		var best: Dictionary = {}
		var best_priority: float = INF
		var best_saving: int = 0
		for group in groups:
			var level: int = chosen[group.id]
			if bool(group.protected) or level == 2:
				continue
			var saving: int = (int(group.triangles[level]) - int(group.triangles[level + 1])) * int(group.instance_count)
			var priority: float = float(group.projected_fraction) * float(group.instance_count) / float(maxi(saving, 1))
			if priority < best_priority or (priority == best_priority and (best.is_empty() or String(group.id) < String(best.id))):
				best = group
				best_priority = priority
				best_saving = saving
		if best.is_empty():
			break
		chosen[best.id] = int(chosen[best.id]) + 1
		total -= best_saving
		changes += 1
	return {"lods": chosen, "estimated_primary_triangles": total, "target": target,
		"target_met": total <= target, "budget_degradations": changes, "hidden_plants": 0}
