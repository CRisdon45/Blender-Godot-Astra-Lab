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
	var window := Window.new()
	window.size=Vector2i(1200,900)
	window.content_scale_size=Vector2i(1600,1200)
	window.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	check(MIRROR.source_pixel_size(window)==Vector2i(1200,900),"Window logical size confused with physical pixels")
	window.free()
	var sub := SubViewport.new()
	sub.size=Vector2i(500,300)
	sub.size_2d_override=Vector2i(1000,600)
	check(MIRROR.source_pixel_size(sub)==Vector2i(500,300),"SubViewport 2D override confused with pixels")
	sub.free()
	var adapted: String=MIRROR.clipped_code("shader_type spatial;\nvoid fragment() { ALBEDO=vec3(1.0); }")
	check(adapted.contains("reflection_plane_y") and adapted.contains("IN_SHADOW_PASS"),"Clip adapter absent")
	check(MIRROR.clipped_code("shader_type canvas_item;\nvoid fragment() {}").is_empty(),"Unsupported shader not rejected")
	if not errors.is_empty():
		push_error("REFLECTION_PREFLIGHT_FAILED "+JSON.stringify(errors))
	else:
		print("REFLECTION_PREFLIGHT_PASSED")
	quit(0 if errors.is_empty() else 1)
