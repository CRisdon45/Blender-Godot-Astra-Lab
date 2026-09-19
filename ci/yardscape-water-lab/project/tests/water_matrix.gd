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

	root.size = Vector2i(480, 360)
	var scene = load("res://main.tscn")
	check(scene != null, "minimal water scene loads")
	if scene == null:
		quit(1)
		return

	study = scene.instantiate()
	root.add_child(study)
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
		["05-t400-full", 4.00, true, true],
	]

	for state in states:
		set_state(state[1], state[2], state[3])
		await grab(state[0])

	check(hashes["01-t000-full"] != hashes["02-t000-no-caustics"],
		"caustics visibly affect fixed time-zero framebuffer")
	check(hashes["01-t000-full"] != hashes["03-t000-no-surface"],
		"surface visibly affects fixed time-zero framebuffer")
	check(hashes["01-t000-full"] != hashes["04-t175-full"]
		and hashes["04-t175-full"] != hashes["05-t400-full"]
		and hashes["01-t000-full"] != hashes["05-t400-full"],
		"explicit water time produces three distinct full-water frames")

	var report := {
		"run_id": run_id,
		"passed": failures.is_empty(),
		"checks": checks,
		"failures": failures,
		"hashes": hashes,
		"engine": Engine.get_version_info().string,
		"adapter": RenderingServer.get_video_adapter_name(),
		"renderer": "Compatibility / OpenGL",
		"viewport": [480, 360],
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
