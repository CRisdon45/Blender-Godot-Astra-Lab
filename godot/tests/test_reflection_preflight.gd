extends SceneTree
## Preload the actual scripts and check camera math before starting a render.
const STUDY = preload("res://courtyard_water_reflections.gd")
const CAPTURE = preload("res://tests/capture_water_reflections.gd")
const MIRROR = preload("res://planar_water_reflection.gd")
var errors: Array[String] = []
func check(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
func _initialize() -> void:
	var original := Transform3D(Basis.from_euler(Vector3(-0.28,0.37,0.12)),Vector3(4,3.3,10))
	var reflected: Transform3D = MIRROR.mirror_transform(original,0.3225)
	check(is_equal_approx(reflected.basis.determinant(),1.0),"Camera handedness reversed")
	check(MIRROR.mirror_transform(reflected,0.3225).is_equal_approx(original),"Mirror is not an involution")
	check(is_equal_approx(reflected.origin.y,-2.655),"Wrong mirrored camera height")
	check(MIRROR.target_size(Vector2i(1200,900),0.5,1024)==Vector2i(600,450),"Reflection resolution wrong")
	check(MIRROR.target_size(Vector2i(4000,3000),1.0,1024)==Vector2i(1024,768),"Reflection size not bounded")
	var adapted: String=MIRROR.clipped_code("shader_type spatial;\nvoid fragment() { ALBEDO=vec3(1.0); }")
	check(adapted.contains("reflection_plane_y") and adapted.contains("IN_SHADOW_PASS"),"Clip adapter absent")
	check(MIRROR.clipped_code("shader_type canvas_item;\nvoid fragment() {}").is_empty(),"Unsupported shader not rejected")
	if not errors.is_empty():
		push_error("REFLECTION_PREFLIGHT_FAILED "+JSON.stringify(errors))
	else:
		print("REFLECTION_PREFLIGHT_PASSED")
	quit(0 if errors.is_empty() else 1)
