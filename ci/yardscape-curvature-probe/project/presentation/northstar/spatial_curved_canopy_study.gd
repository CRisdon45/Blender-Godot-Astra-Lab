extends "res://presentation/northstar/spatial_canopy_study.gd"
## Opt-in curvature experiment. The preceding folded scene stays the default.
const CurvedForm = preload("res://presentation/northstar/canopy/curved_tree.gd")

func _create_canopy() -> Node3D:
	return CurvedForm.new()
