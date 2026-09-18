extends "res://presentation/northstar/spatial_canopy_study.gd"
## Opt-in curved-cutout experiment. The preceding folded scene stays the default.
const CurvedForm = preload("res://presentation/northstar/canopy/cutout_tree.gd")

func _create_canopy() -> Node3D:
	return CurvedForm.new()
