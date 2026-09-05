extends SceneTree
## Headless checks against the real navigation implementation, not a reimplementation.
const Navigation = preload("res://navigation.gd")
var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var original := Vector3(4, 1.5, 13)
	check(Navigation.bounded_offset(original).is_equal_approx(original), "Reference offset changed")
	check(Navigation.bounded_offset(Vector3.ZERO).is_finite(), "Zero offset is not finite")
	check(is_equal_approx(Navigation.bounded_offset(Vector3.ZERO).length(), Navigation.MIN_DISTANCE), "Zero offset distance")
	check(Navigation.bounded_offset(Vector3(INF, 0, 0)).is_finite(), "Invalid offset recovery")
	check(is_equal_approx(Navigation.zoom_offset(original, -10000).length(), Navigation.MIN_DISTANCE), "Near zoom clamp")
	check(is_equal_approx(Navigation.zoom_offset(original, 10000).length(), Navigation.MAX_DISTANCE), "Far zoom clamp")
	var above := Navigation.bounded_offset(original, Vector2(0, 10000))
	var below := Navigation.bounded_offset(original, Vector2(0, -10000))
	check(absf(asin(above.normalized().y) - Navigation.MAX_PITCH) < 0.0001, "Upper pole clamp")
	check(absf(asin(below.normalized().y) - Navigation.MIN_PITCH) < 0.0001, "Lower pitch clamp")
	var offset := original
	for index in range(1000):
		offset = Navigation.bounded_offset(offset, Vector2(80, 90))
	check(offset.is_finite() and offset.y > 0, "Repeated orbit must not flip")
	check(absf(offset.length() - original.length()) < 0.002, "Repeated orbit radius drift")

	var rig = Navigation.new()
	var camera := Camera3D.new()
	camera.name = "Reference camera"
	camera.position = Vector3(4, 3.3, 10)
	rig.add_child(camera)
	var contours := MeshInstance3D.new()
	contours.name = "Fine architectural contours"
	camera.add_child(contours)
	var overlay := CanvasLayer.new()
	overlay.name = "Illustration finish"
	rig.add_child(overlay)
	root.add_child(rig)
	camera.look_at(rig.target)
	# Capture a valid reference after constructing the headless fixture.
	rig.reference_transform = camera.transform
	var reference := camera.transform
	rig.set_illustration(false)
	check(not overlay.visible and not contours.visible, "Both illustration passes must disable")
	rig.set_illustration(true)
	check(overlay.visible and contours.visible, "Both illustration passes must enable")
	for index in range(Navigation.VIEW_NAMES.size()):
		rig.select_view(index)
		check(camera.position.is_finite(), "Review view must be finite")
		check((camera.position - rig.target).length() <= Navigation.MAX_DISTANCE + 0.001, "Review view too far")
	rig.reset_camera()
	check(camera.transform.is_equal_approx(reference), "Reset must restore exact reference transform")
	rig.select_view(-1)
	rig.select_view(99)
	check(camera.transform.is_equal_approx(reference), "Invalid view must not change camera")
	rig.dragging = true
	rig._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(not rig.dragging, "Focus loss must release drag")
	var echo_key := InputEventKey.new()
	echo_key.keycode = KEY_I
	echo_key.pressed = true
	echo_key.echo = true
	rig._unhandled_input(echo_key)
	check(overlay.visible and contours.visible, "Key repeat must not toggle illustration")
	rig._capturing = true
	echo_key.echo = false
	rig._unhandled_input(echo_key)
	check(overlay.visible and contours.visible, "Input must not change a capture in progress")
	rig._capturing = false
	rig._unhandled_input(echo_key)
	check(not overlay.visible and not contours.visible, "I key must toggle both passes")
	rig.free()
	if failures == 0:
		print("NAVIGATION_TESTS_OK checks=", checks)
	quit(0 if failures == 0 else 1)
