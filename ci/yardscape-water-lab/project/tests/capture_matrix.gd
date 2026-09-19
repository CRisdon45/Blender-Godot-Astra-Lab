extends SceneTree
## Five-state deterministic water comparison. No frame-post-draw signal.

var study
var output := ""

func _initialize() -> void:
	call_deferred("run")

func set_state(time_value: float, caustics: bool, surface: bool) -> void:
	study.paused = true
	study.visual_time = time_value
	study.caustics_enabled = caustics
	study.surface_enabled = surface
	study.basin_material.set_shader_parameter("caustics_enabled", caustics)
	study.water_surface.visible = surface
	study._apply_time()

func grab(name: String) -> String:
	for i in 8:
		await process_frame
	var image := root.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	var path := output.path_join(name + ".png")
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save " + path)
		return ""
	return image.get_data().hex_encode().sha256_text()

func run() -> void:
	output = OS.get_environment("YARDSCAPE_WATER_OUTPUT").replace("\\", "/")
	if output.is_empty():
		push_error("YARDSCAPE_WATER_OUTPUT is required")
		quit(2)
		return

	root.size = Vector2i(480, 360)
	var packed := load("res://main.tscn")
	if packed == null:
		push_error("Could not load water scene")
		quit(3)
		return

	study = packed.instantiate()
	root.add_child(study)
	study.capture_path = ""
	study.paused = true

	var hashes := {}
	var states := [
		["01-t000-full", 0.00, true, true],
		["02-t000-no-caustics", 0.00, false, true],
		["03-t000-no-surface", 0.00, true, false],
		["04-t175-full", 1.75, true, true],
		["05-t400-full", 4.00, true, true],
	]

	for state in states:
		set_state(state[1], state[2], state[3])
		hashes[state[0]] = await grab(state[0])
		if hashes[state[0]].is_empty():
			quit(4)
			return

	var valid := true
	valid = valid and hashes["01-t000-full"] != hashes["02-t000-no-caustics"]
	valid = valid and hashes["01-t000-full"] != hashes["03-t000-no-surface"]
	valid = valid and hashes["01-t000-full"] != hashes["04-t175-full"]
	valid = valid and hashes["04-t175-full"] != hashes["05-t400-full"]
	valid = valid and hashes["01-t000-full"] != hashes["05-t400-full"]

	print("WATER_MATRIX captures=%d valid=%s hashes=%s" % [hashes.size(), valid, hashes])
	study.queue_free()
	await process_frame
	quit(0 if valid else 5)
