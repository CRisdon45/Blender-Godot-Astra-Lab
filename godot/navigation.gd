extends Node3D
## Shared navigation, capture and water binding for the saved and generated scenes.

const WaterInteraction = preload("res://water_interaction.gd")

const VIEW_NAMES = ["reference", "left", "right", "elevated", "close", "reverse"]
const MIN_DISTANCE := 2.0
const MAX_DISTANCE := 45.0
const MIN_PITCH := 0.034906585  # 2 degrees; stay above the orbit target.
const MAX_PITCH := 1.483529864  # 85 degrees; never cross the camera pole.
const ORBIT_SENSITIVITY := 0.004

var water = WaterInteraction.new()

var camera: Camera3D
var target := Vector3(0, 1.8, -3)
var reference_transform: Transform3D
var dragging := false
var _overlay: CanvasLayer
var _contours: GeometryInstance3D
var _capturing := false
var _view_name := "reference"


func _ready() -> void:
	camera = get_node_or_null("Reference camera") as Camera3D
	_overlay = get_node_or_null("Illustration finish") as CanvasLayer
	_contours = get_node_or_null("Reference camera/Fine architectural contours") as GeometryInstance3D
	if camera == null or _overlay == null or _contours == null:
		push_error("REVIEW_SETUP_FAILED: camera, illustration layer or contours missing")
		get_tree().quit(1)
		return
	reference_transform = camera.transform
	var result := water.setup(self)
	if result != OK:
		push_error("WATER_SETUP_FAILED: " + str(water.snapshot()))
		set_process(false)
		get_tree().quit(1)
		return
	var args := OS.get_cmdline_user_args()
	water.set_flow(not "--water-off" in args)
	print("WATER_READY ", JSON.stringify(water.snapshot()))
	if "--review" in args:
		capture_session("review")
	elif "--capture" in args:
		capture_session("capture")


func _process(delta: float) -> void:
	if water.advance(delta) != OK:
		push_error("WATER_UPDATE_FAILED: " + str(water.snapshot()))
		set_process(false)
		get_tree().quit(1)


static func bounded_offset(offset: Vector3, motion: Vector2 = Vector2.ZERO) -> Vector3:
	if not offset.is_finite() or offset.length_squared() < 0.000001:
		offset = Vector3(0, 0, MIN_DISTANCE)
	var distance := clampf(offset.length(), MIN_DISTANCE, MAX_DISTANCE)
	var unit := offset.normalized()
	var yaw := atan2(unit.x, unit.z) - motion.x * ORBIT_SENSITIVITY
	var pitch := clampf(asin(clampf(unit.y, -1.0, 1.0)) + motion.y * ORBIT_SENSITIVITY, MIN_PITCH, MAX_PITCH)
	return Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance


static func zoom_offset(offset: Vector3, steps: float) -> Vector3:
	var safe := bounded_offset(offset)
	var distance := clampf(safe.length() * exp(clampf(steps, -100.0, 100.0) * 0.06), MIN_DISTANCE, MAX_DISTANCE)
	return safe.normalized() * distance


func reset_camera() -> void:
	camera.transform = reference_transform
	_view_name = "reference"


func select_view(index: int) -> void:
	if index < 0 or index >= VIEW_NAMES.size():
		return
	reset_camera()
	var offset := reference_transform.origin - target
	match index:
		1: offset = offset.rotated(Vector3.UP, deg_to_rad(30.0))
		2: offset = offset.rotated(Vector3.UP, deg_to_rad(-30.0))
		3: offset = Vector3(offset.x, offset.length(), offset.z) * 1.15
		4: offset *= 0.6
		5: offset = offset.rotated(Vector3.UP, PI)
	if index != 0:
		camera.position = target + bounded_offset(offset)
		camera.look_at(target)
	_view_name = VIEW_NAMES[index]


func set_illustration(enabled: bool) -> void:
	_overlay.visible = enabled
	_contours.visible = enabled


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		dragging = false


func _unhandled_input(event: InputEvent) -> void:
	if _capturing:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			reset_camera()
		elif event.keycode == KEY_I:
			set_illustration(not _overlay.visible)
		elif event.keycode == KEY_W:
			water.set_flow(not water.flow_enabled)
		elif event.keycode == KEY_F12:
			capture_session("manual")
		elif event.keycode >= KEY_1 and event.keycode <= KEY_6:
			select_view(event.keycode - KEY_1)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var steps := maxf(event.factor, 0.01)
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				steps = -steps
			camera.position = target + zoom_offset(camera.position - target, steps)
			camera.look_at(target)
			_view_name = "custom"
	if event is InputEventMouseMotion and dragging:
		camera.position = target + bounded_offset(camera.position - target, event.relative)
		camera.look_at(target)
		_view_name = "custom"


func _new_capture_directory() -> String:
	var output_root := "user://reviews"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			output_root = arg.trim_prefix("--capture-dir=")
	if output_root.is_empty() or output_root.begins_with("res://"):
		push_error("Use an absolute path or user:// for --capture-dir, not res://")
		return ""
	if not output_root.begins_with("user://") and not output_root.is_absolute_path():
		push_error("--capture-dir must be absolute or begin with user://")
		return ""
	output_root = ProjectSettings.globalize_path(output_root)
	if DirAccess.make_dir_recursive_absolute(output_root) != OK:
		return ""
	var stem := "review-%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	for attempt in range(100):
		var directory := output_root.path_join("%s-%d" % [stem, attempt])
		var result := DirAccess.make_dir_absolute(directory)
		if result == OK:
			return directory
		if result != ERR_ALREADY_EXISTS:
			return ""
	return ""


func _wait_frames(count: int) -> void:
	for unused in range(count):
		await get_tree().process_frame


func _save_frame(directory: String, filename: String, records: Array) -> Error:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return ERR_CANT_CREATE
	var result := image.save_png(directory.path_join(filename))
	if result != OK:
		return result
	records.append({
		"file": filename, "view": _view_name, "illustration": _overlay.visible,
		"width": image.get_width(), "height": image.get_height(),
		"camera_position": [camera.position.x, camera.position.y, camera.position.z],
		"camera_rotation": [camera.rotation.x, camera.rotation.y, camera.rotation.z],
		"camera_fov": camera.fov, "ticks_usec": Time.get_ticks_usec(),
		"water": water.snapshot(),
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
	})
	return OK


func _save_manifest(directory: String, mode: String, records: Array) -> Error:
	var file := FileAccess.open(directory.path_join("manifest.json"), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({
		"schema_version": 1, "status": "captured", "mode": mode,
		"engine": Engine.get_version_info(), "display_server": DisplayServer.get_name(),
		"animation": "live", "pixel_deterministic": false,
		"visual_acceptance": "not_evaluated", "images": records,
	}, "\t"))
	file.flush()
	var result := file.get_error()
	file.close()
	return result


func capture_session(mode: String) -> void:
	if _capturing:
		return
	if DisplayServer.get_name() == "headless":
		push_error("REVIEW_FAILED: captures require a graphics-capable display, not --headless")
		if mode != "manual":
			get_tree().quit(1)
		return
	_capturing = true
	dragging = false
	var original_camera := camera.transform
	var original_illustration := _overlay.visible
	var original_contours := _contours.visible
	var original_view := _view_name
	var directory := _new_capture_directory()
	var result: Error = OK if not directory.is_empty() else ERR_CANT_CREATE
	var records: Array = []
	if result == OK:
		await _wait_frames(45)
		if mode == "review":
			for index in range(VIEW_NAMES.size()):
				select_view(index)
				for enabled in [true, false]:
					set_illustration(enabled)
					await _wait_frames(12)
					var suffix := "illustrated" if enabled else "plain"
					result = await _save_frame(directory, "%s-%s.png" % [_view_name, suffix], records)
					if result != OK:
						break
				if result != OK:
					break
		elif mode == "capture":
			reset_camera()
			set_illustration(true)
			await _wait_frames(12)
			result = await _save_frame(directory, "reference.png", records)
			if result == OK:
				await _wait_frames(40)
				result = await _save_frame(directory, "animation-check.png", records)
		else:
			result = await _save_frame(directory, "manual.png", records)
	if result == OK:
		result = _save_manifest(directory, mode, records)
	camera.transform = original_camera
	_overlay.visible = original_illustration
	_contours.visible = original_contours
	_view_name = original_view
	_capturing = false
	if result == OK:
		print("REVIEW_OK ", JSON.stringify({"manifest": directory.path_join("manifest.json")}))
	else:
		push_error("REVIEW_FAILED: error=%d directory=%s" % [result, directory])
	if mode != "manual":
		get_tree().quit(0 if result == OK else 1)
