extends SceneTree
## Real viewport witness with matched pose/time and separate diagnostic views.
var output: String = ""
var images: Array = []
var errors: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for unused in range(count):
		await process_frame

func capture(scene, label: String, position: Vector3, aim: Vector3, seconds: float=2.0) -> void:
	scene.camera.position=position
	scene.camera.look_at(aim)
	if scene.has_method("set_water_phase"):
		scene.set_water_phase(seconds)
	else:
		scene.water.water_time=seconds
		scene.water.advance(0.0)
	await frames(5)
	await RenderingServer.frame_post_draw
	var image: Image=root.get_texture().get_image()
	if image==null or image.is_empty():
		errors.append("Empty viewport: "+label)
		return
	if image.save_png(output.path_join(label+".png"))!=OK:
		errors.append("Save failed: "+label)
		return
	images.append({"file":label+".png","camera":[position.x,position.y,position.z],
		"aim":[aim.x,aim.y,aim.z],"width":image.get_width(),"height":image.get_height(),
		"water":scene.water.snapshot()})
	print("HERO_FRAME ",label)

func check(condition: bool,message: String) -> void:
	if not condition:
		errors.append(message)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output=arg.trim_prefix("--output=")
	if not output.is_absolute_path() or DisplayServer.get_name()=="headless":
		push_error("HERO_CAPTURE_REQUIRES_DISPLAY_AND_ABSOLUTE_OUTPUT")
		quit(1)
		return
	check(DirAccess.make_dir_recursive_absolute(output)==OK,"Cannot create output directory")
	var poses: Array = [
		["courtyard",Vector3(4,3.3,10),Vector3(0,1.8,-3)],
		["pool",Vector3(2.4,2.7,4.8),Vector3(0,0.65,-2.7)],
		["grazing",Vector3(3.6,1.05,2.2),Vector3(-1.5,0.4,-4.2)],
		["shelf",Vector3(4.6,4.8,3.9),Vector3(0,0.05,-0.6)],
	]
	for version in ["before","after"]:
		var path: String="res://courtyard_anime.tscn" if version=="before" else "res://courtyard_hero_water.tscn"
		var packed := load(path) as PackedScene
		if packed==null:
			errors.append("Scene load failed: "+path)
			continue
		var scene=packed.instantiate()
		root.add_child(scene)
		await frames(12)
		scene.set_process(false)
		scene.set_illustration(true)
		var state: Dictionary=scene.water.snapshot()
		check(state.active and state.error.is_empty(),version+": water binding failed")
		check(state.impact_segments_xz.size()==2,version+": missing two sheet contacts")
		for pose in poses:
			await capture(scene,version+"-"+pose[0],pose[1],pose[2])
		if version=="after":
			check(scene.basin_materials.size()==1,"Expected one grouped basin receiver")
			check(scene.water._pool_material.shader.resource_path=="res://shaders/hero_water.gdshader","Optics shader not bound")
			scene.water.set_flow(false)
			await capture(scene,"after-flow-off",poses[1][1],poses[1][2])
			check(not scene.water.snapshot().flow_enabled,"W-equivalent flow-off failed")
			scene.water.set_flow(true)
			check(scene.water.snapshot().impact_segments_xz==state.impact_segments_xz,"Flow toggle moved contacts")
			scene.water._pool_material.set_shader_parameter("debug_view",1)
			await capture(scene,"diagnostic-depth",poses[3][1],poses[3][2])
			scene.water._pool_material.set_shader_parameter("debug_view",0)
			scene.set_night(true)
			await frames(12)
			for index in [0,1]:
				await capture(scene,"night-"+poses[index][0],poses[index][1],poses[index][2])
			scene.set_night(false)
			await frames(12)
			for step in range(8):
				await capture(scene,"motion-%02d"%step,poses[1][1],poses[1][2],2.0+step*0.16)
			check(is_equal_approx(scene.water.water_time,3.12),"Explicit water phase failed")
			for material in scene.basin_materials:
				check(is_equal_approx(float(material.get_shader_parameter("water_time")),scene.water.water_time),"Receiver phase out of sync")
		scene.queue_free()
		await frames(4)
	var report: Dictionary={"images":images,"errors":errors,"engine":Engine.get_version_info(),
		"renderer":"Forward+ / Linux software Vulkan","expected_images":20,
		"visual_acceptance":"pending_user_review","performance_certified":false}
	var file := FileAccess.open(output.path_join("hero-water-review.json"),FileAccess.WRITE)
	if file==null:
		push_error("HERO_MANIFEST_SAVE_FAILED")
		quit(1)
		return
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("HERO_REVIEW_DONE ",JSON.stringify({"images":images.size(),"errors":errors}))
	quit(0 if errors.is_empty() and images.size()==20 else 1)
