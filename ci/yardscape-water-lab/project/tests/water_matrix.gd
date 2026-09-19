extends SceneTree

var study
var output: String
var run_id: String
var checks: Array = []
var failures: Array = []
var hashes: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks.append({"name": label, "passed": ok})
	if not ok:
		failures.append(label)

func image_hash(image: Image) -> String:
	return image.get_data().hex_encode().sha256_text()

func set_state(time_value: float, caustics: bool, surface: bool) -> void:
	study.paused = true
	study.visual_time = time_value
	study.caustics_enabled = caustics
	study.surface_enabled = surface
	study.basin_material.set_shader_parameter("caustics_enabled", caustics)
	study.water_surface.visible = surface
	study._apply_time()

func grab(name: String) -> Image:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	var path := output.path_join(name + ".png")
	check(image.save_png(path) == OK, "capture " + name)
	hashes[name] = image_hash(image)
	return image

func run() -> void:
	output = OS.get_environment("YARDSCAPE_WATER_OUTPUT").replace("\\", "/")
	run_id = OS.get_environment("YARDSCAPE_WATER_RUN_ID")
	if run_id.length() != 36 or not output.begins_with(ProjectSettings.globalize_path("res://.local/")):
		push_error("Fresh isolated water output/run identity required")
		quit(1)
		return

	root.size = Vector2i(720, 540)
	var scene = load("res://main.tscn")
	check(scene != null, "minimal water scene loads")
	if scene == null:
		quit(1)
		return

	study = scene.instantiate()
	root.add_child(study)
	for i in 2:
		await process_frame

	check(is_instance_valid(study.basin_material), "basin material initializes")
	check(is_instance_valid(study.surface_material), "surface material initializes")
	check(is_instance_valid(study.water_surface), "water surface initializes")
	check(study.get_child_count() == 11, "only ten pool meshes plus fixed camera are present")

	var states := [
		["01-t000-full", 0.00, true, true],
		["02-t000-no-caustics", 0.00, false, true],
		["03-t000-no-surface", 0.00, true, false],
		["04-t175-full", 1.75, true, true],
		["05-t175-no-caustics", 1.75, false, true],
		["06-t175-no-surface", 1.75, true, false],
		["07-t400-full", 4.00, true, true],
		["08-t400-no-caustics", 4.00, false, true],
		["09-t400-no-surface", 4.00, true, false],
	]

	for state in states:
		set_state(state[1], state[2], state[3])
		await grab(state[0])

	for prefix in ["t000", "t175", "t400"]:
		var full_key := ""
		var no_c_key := ""
		var no_s_key := ""
		for key in hashes:
			if prefix in key:
				if "no-caustics" in key:
					no_c_key = key
				elif "no-surface" in key:
					no_s_key = key
				elif "full" in key:
					full_key = key
		check(not full_key.is_empty() and not no_c_key.is_empty() and not no_s_key.is_empty(), "state keys " + prefix)
		if not full_key.is_empty() and not no_c_key.is_empty() and not no_s_key.is_empty():
			check(hashes[full_key] != hashes[no_c_key], "caustics visibly affect " + prefix)
			check(hashes[full_key] != hashes[no_s_key], "surface visibly affects " + prefix)

	var full_hashes: Array = []
	for key in hashes:
		if "full" in key:
			full_hashes.append(hashes[key])
	check(full_hashes.size() == 3, "three full-water time samples captured")
	check(full_hashes.size() == 3 and full_hashes[0] != full_hashes[1] and full_hashes[1] != full_hashes[2] and full_hashes[0] != full_hashes[2],
		"explicit water time changes full-water framebuffer")

	var report := {
		"run_id": run_id,
		"passed": failures.is_empty(),
		"checks": checks,
		"failures": failures,
		"hashes": hashes,
		"engine": Engine.get_version_info().string,
		"adapter": RenderingServer.get_video_adapter_name(),
		"renderer": "Compatibility / OpenGL",
		"viewport": [960, 720],
		"artistic_acceptance": "not_reviewed",
	}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t", true, true))
	file.close()

	print(JSON.stringify({
		"passed": report.passed,
		"checks": checks.size(),
		"failures": failures,
		"captures": hashes.size(),
	}))
	study.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
