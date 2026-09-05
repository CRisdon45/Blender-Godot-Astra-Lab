extends SceneTree
## Every PNG is an actual Godot viewport. No replacement baselines or generated art.
const MIRROR = preload("res://planar_water_reflection.gd")
var output: String=""
var images: Array=[]
var errors: Array[String]=[]
var witnesses: Dictionary={}
func _initialize() -> void:
	call_deferred("run")
func frames(count: int) -> void:
	for unused in range(count):
		await process_frame
func check(condition: bool,message: String) -> void:
	if not condition:
		errors.append(message)
func capture(scene, label: String, position: Vector3, aim: Vector3, seconds: float=2.0) -> void:
	scene.camera.position=position
	scene.camera.look_at(aim)
	scene.set_water_phase(seconds)
	await frames(6)
	await RenderingServer.frame_post_draw
	var image: Image=root.get_texture().get_image()
	if image==null or image.is_empty():
		errors.append("Empty viewport: "+label)
		return
	check(image.save_png(output.path_join(label+".png"))==OK,"Save failed: "+label)
	images.append({"file":label+".png","camera":[position.x,position.y,position.z],
		"aim":[aim.x,aim.y,aim.z],"width":image.get_width(),"height":image.get_height(),
		"water":scene.water.snapshot(),"study":scene.study_snapshot()})
	print("REFLECTION_FRAME ",label)
func marker(color: Vector3, position: Vector3, scene) -> MeshInstance3D:
	var box := MeshInstance3D.new()
	box.mesh=BoxMesh.new()
	box.mesh.size=Vector3(0.6,0.22,0.6)
	box.position=position
	box.layers=MIRROR.REFLECTION_LAYER
	var shader := Shader.new()
	shader.code="shader_type spatial; render_mode ambient_light_disabled; uniform vec3 marker_color; void fragment() { ALBEDO=vec3(0.0); EMISSION=marker_color; SPECULAR=0.0; }"
	var material := ShaderMaterial.new()
	material.shader=shader
	material.set_shader_parameter("marker_color",color)
	box.material_override=material
	scene.add_child(box)
	check(scene.mirror.register_material(material)==OK,"Marker material could not be clipped")
	return box
func marker_pixels(image: Image) -> Dictionary:
	var magenta: int=0
	var green: int=0
	var maximum: float=0.0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var c: Color=image.get_pixel(x,y)
			maximum=maxf(maximum,maxf(c.r,maxf(c.g,c.b)))
			if c.r>0.7 and c.b>0.7 and c.g<0.15:
				magenta+=1
			if c.g>0.7 and c.r<0.15 and c.b<0.15:
				green+=1
	return {"below_magenta_pixels":magenta,"above_green_pixels":green,"maximum_linear_value":maximum}
func reflection_witness(scene) -> void:
	# Reflection-only controls: a submerged bright box MUST vanish with clipping,
	# while an above-water one stays. Then deliberately disable clipping to prove
	# that the submerged box really was inside the reflected camera's view.
	scene.camera.position=Vector3(2.4,2.7,4.8)
	scene.camera.look_at(Vector3(0,0.65,-2.7))
	scene.mirror.sync_camera()
	var level: float=scene.water.snapshot().water_level
	var below: MeshInstance3D=marker(Vector3(3,0,3),Vector3(-0.9,level-0.15,-3.1),scene)
	var above: MeshInstance3D=marker(Vector3(0,3,0),Vector3(0.9,level+0.45,-3.1),scene)
	var below_mat: ShaderMaterial=below.material_override
	scene.mirror.set_process(false)
	var measurements: Dictionary={}
	for clip in [true,false]:
		below_mat.set_shader_parameter("reflection_plane_y",level if clip else -100.0)
		await frames(6)
		await RenderingServer.frame_post_draw
		var raw: Image=scene.mirror.viewport.get_texture().get_image()
		if raw==null or raw.is_empty():
			errors.append("Empty raw reflection witness")
			continue
		var name: String="diagnostic-clip-on" if clip else "diagnostic-clip-off"
		measurements[name]=marker_pixels(raw)
		# Presentation copy only: raw HDR values above are the test evidence.
		var display: Image=raw.duplicate() as Image
		display.convert(Image.FORMAT_RGB8)
		display.linear_to_srgb()
		check(display.save_png(output.path_join(name+".png"))==OK,"Raw diagnostic save failed")
		images.append({"file":name+".png","width":display.get_width(),"height":display.get_height(),
			"diagnostic":"Reflection viewport with artificial clip-test markers, not a beauty render",
			"measurement":measurements[name]})
	if measurements.size()==2:
		var clipped: Dictionary=measurements["diagnostic-clip-on"]
		var visible: Dictionary=measurements["diagnostic-clip-off"]
		check(clipped.below_magenta_pixels==0,"Below-water geometry leaked into reflection")
		check(visible.below_magenta_pixels>4,"Submerged marker positive control missing")
		check(clipped.above_green_pixels>4 and visible.above_green_pixels>4,"Above-plane marker missing")
		check(visible.maximum_linear_value>1.1,"Reflection texture lost HDR range")
	witnesses["clip_and_hdr"]=measurements
	below.queue_free()
	above.queue_free()
	await frames(3)
	scene.mirror.set_process(true)
	scene.mirror.sync_camera()
func projection_witness(scene) -> void:
	var level: float=scene.water.snapshot().water_level
	var point := Vector3(0,level,-3)
	var a: Vector2=scene.camera.unproject_position(point)/root.get_visible_rect().size
	var b: Vector2=scene.mirror.mirror_camera.unproject_position(point)/Vector2(scene.mirror.viewport.size)
	witnesses["plane_projection"]={"main_uv":[a.x,a.y],"mirror_uv":[b.x,b.y]}
	check(absf(a.x+b.x-1.0)<0.003 and absf(a.y-b.y)<0.003,"Planar camera registration wrong")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output=arg.trim_prefix("--output=")
	if not output.is_absolute_path() or DisplayServer.get_name()=="headless":
		push_error("REFLECTION_CAPTURE_REQUIRES_DISPLAY_AND_ABSOLUTE_OUTPUT")
		quit(1)
		return
	check(DirAccess.make_dir_recursive_absolute(output)==OK,"Output directory failed")
	var poses: Array=[
		["courtyard",Vector3(4,3.3,10),Vector3(0,1.8,-3)],
		["pool",Vector3(2.4,2.7,4.8),Vector3(0,0.65,-2.7)],
		["grazing",Vector3(-3.3,1.1,2.2),Vector3(0,0.45,-4.3)],
		["shelf",Vector3(4.6,4.8,3.9),Vector3(0,0.05,-0.6)],
		["sheer",Vector3(-3.8,1.8,-1.2),Vector3(-2.65,0.75,-4.7)]]
	for version in ["before","after"]:
		var path: String="res://courtyard_hero_water.tscn" if version=="before" else "res://courtyard_water_reflections.tscn"
		var packed := load(path) as PackedScene
		if packed==null:
			errors.append("Failed scene load: "+path)
			continue
		var scene=packed.instantiate()
		if not scene.has_method("set_water_phase"):
			errors.append("Failed actual scene script: "+path)
			scene.free()
			continue
		root.add_child(scene)
		await frames(12)
		scene.set_process(false)
		scene.set_illustration(true)
		var state: Dictionary=scene.water.snapshot()
		check(state.active and state.error.is_empty(),version+": binding failed")
		check(state.impact_segments_xz.size()==2,version+": missing two contacts")
		if version=="after" and not scene.reflection_ready:
			errors.append("Planar reflection did not initialize")
			scene.queue_free()
			await frames(4)
			continue
		for pose in poses:
			await capture(scene,version+"-"+pose[0],pose[1],pose[2])
		if version=="after":
			check(not scene.probe.visible,"Old probe still active")
			check((scene.camera.cull_mask & MIRROR.REFLECTION_LAYER)==0,"Main camera clips reflection layer")
			check(scene.mirror.mirror_camera.cull_mask==MIRROR.REFLECTION_LAYER,"Mirror includes unintended layer")
			check((scene.water._pool.layers & MIRROR.REFLECTION_LAYER)==0,"Recursive pool capture")
			check(scene.reflected_meshes>20 and scene.mirror.reflected_materials.size()>20,"Reflection scene incomplete")
			check(scene.mirror.viewport.use_hdr_2d,"Linear HDR reflection disabled")
			check(int(scene.water._pool_material.get_shader_parameter("impact_count"))==2,"Impact uniforms lost")
			check(scene.painted_foliage.size()==12,"Foliage materials lost")
			projection_witness(scene)
			var mat: ShaderMaterial=scene.water._pool_material
			mat.set_shader_parameter("debug_view",3)
			await capture(scene,"diagnostic-reflection",poses[1][1],poses[1][2])
			mat.set_shader_parameter("reflection_distortion",0.0)
			await capture(scene,"diagnostic-reflection-flat",poses[1][1],poses[1][2])
			mat.set_shader_parameter("reflection_distortion",0.035)
			mat.set_shader_parameter("debug_view",4)
			await capture(scene,"diagnostic-receiver",poses[3][1],poses[3][2])
			for material in scene.basin_materials:
				material.set_shader_parameter("caustic_daylight",0.0)
			await capture(scene,"diagnostic-receiver-no-caustics",poses[3][1],poses[3][2])
			for material in scene.basin_materials:
				material.set_shader_parameter("caustic_daylight",1.0)
			mat.set_shader_parameter("debug_view",0)
			scene.water.set_flow(false)
			await capture(scene,"after-flow-off",poses[1][1],poses[1][2])
			check(not scene.water.snapshot().flow_enabled,"Flow off failed")
			scene.water.set_flow(true)
			check(scene.water.snapshot().impact_segments_xz==state.impact_segments_xz,"Flow changed contacts")
			scene.set_night(true)
			await frames(8)
			await capture(scene,"night-pool",poses[1][1],poses[1][2])
			for material in scene.painted_foliage:
				check(is_equal_approx(float(material.get_shader_parameter("paint_illumination")),0.1),"Night foliage not dimmed")
			scene.set_night(false)
			await frames(8)
			for material in scene.painted_foliage:
				check(is_equal_approx(float(material.get_shader_parameter("paint_illumination")),1.0),"Day foliage not restored")
			for step in range(6):
				await capture(scene,"motion-%02d"%step,poses[1][1],poses[1][2],2.0+step*0.19)
			for material in scene.basin_materials:
				check(is_equal_approx(float(material.get_shader_parameter("water_time")),scene.water.water_time),"Receiver clock mismatch")
			for index in range(4):
				var angle: float=deg_to_rad(-35.0+index*23.0)
				await capture(scene,"orbit-%02d"%index,Vector3(sin(angle)*7,2.6,cos(angle)*7-2.5),Vector3(0,0.6,-3))
			await reflection_witness(scene)
			scene.mirror.close()
			await frames(4)
		scene.queue_free()
		await frames(6)
	await frames(8)
	await RenderingServer.frame_post_draw
	var report: Dictionary={"images":images,"errors":errors,"witnesses":witnesses,"expected_images":28,
		"engine":Engine.get_version_info(),"renderer":"Forward+ / Linux software Vulkan",
		"visual_acceptance":"pending_review","performance_certified":false}
	var file := FileAccess.open(output.path_join("water-reflection-review.json"),FileAccess.WRITE)
	if file==null:
		push_error("REFLECTION_MANIFEST_SAVE_FAILED")
		quit(1)
		return
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("REFLECTION_REVIEW_DONE ",JSON.stringify({"images":images.size(),"errors":errors}))
	quit(0 if errors.is_empty() and images.size()==28 else 1)
