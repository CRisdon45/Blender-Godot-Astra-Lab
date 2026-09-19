extends SceneTree
## Direct CI first-look capture. Bypasses normal project-main lifecycle and does
## not depend on RenderingServer.frame_post_draw.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var output := OS.get_environment("YARDSCAPE_WATER_CAPTURE").replace("\\", "/")
	if output.is_empty():
		push_error("YARDSCAPE_WATER_CAPTURE is required")
		quit(2)
		return

	root.size = Vector2i(480, 360)

	var packed := load("res://main.tscn")
	if packed == null:
		push_error("Could not load minimal water scene")
		quit(3)
		return

	var study = packed.instantiate()
	root.add_child(study)
	study.paused = true
	study.visual_time = 0.0
	study.caustics_enabled = true
	study.surface_enabled = true
	study.basin_material.set_shader_parameter("caustics_enabled", true)
	study.water_surface.visible = true
	study._apply_time()

	# Process frames are sufficient to drive the display renderer; no post-draw
	# signal is required. Extra frames make startup/import timing irrelevant.
	for i in 24:
		await process_frame

	var image := root.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	var error := image.save_png(output)
	print("DIRECT_WATER_CAPTURE path=%s error=%d size=%dx%d" % [
		output, error, image.get_width(), image.get_height()
	])

	study.queue_free()
	await process_frame
	quit(0 if error == OK else 1)
