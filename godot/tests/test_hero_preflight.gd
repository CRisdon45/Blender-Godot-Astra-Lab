extends SceneTree
## Compile the actual inheritance chain and capture script before expensive views.
const STUDY = preload("res://courtyard_hero_water.gd")
const CAPTURE = preload("res://tests/capture_hero_water.gd")
func _initialize() -> void:
	print("HERO_PREFLIGHT_PASSED")
	quit(0)
