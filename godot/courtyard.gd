extends Node3D

const ARCH=preload("res://shaders/architectural.gdshader")
const WATER=preload("res://shaders/water.gdshader")
const SPILL=preload("res://shaders/spillway.gdshader")
const FIRE=preload("res://shaders/flame.gdshader")
const GRAIN=preload("res://assets/stone_grain.png")
const WOOD=preload("res://assets/wood_grain.png")
var camera: Camera3D
var ink: ColorRect
var elapsed := 0.0
var capturing := false
var target := Vector3(0,1.8,-3)
var origin := Vector3(4,3.3,10)
var dragging := false
var material_count := 0
var mesh_count := 0

func _ready() -> void:
	var packed=load("res://assets/backyard.glb") as PackedScene
	var scene=packed.instantiate()
	add_child(scene)
	apply_materials(scene)
	var env=Environment.new()
	env.background_mode=Environment.BG_SKY
	var sky=Sky.new()
	var sky_material=ProceduralSkyMaterial.new()
	sky_material.sky_top_color=Color("8bcdf4")
	sky_material.sky_horizon_color=Color("c6e8fa")
	sky_material.ground_bottom_color=Color("b5aa8f")
	sky_material.ground_horizon_color=Color("c6e8fa")
	sky_material.sky_curve=0.18
	sky.sky_material=sky_material
	env.sky=sky
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("e8edf2")
	env.ambient_light_energy=0.4
	env.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure=1.0
	env.ssao_enabled=true
	env.ssao_radius=0.55
	env.ssao_intensity=1.8
	env.ssao_light_affect=0.4
	var we=WorldEnvironment.new(); we.environment=env; add_child(we)
	var sun=DirectionalLight3D.new(); sun.name="Warm afternoon sunlight"
	add_child(sun); sun.rotation_degrees=Vector3(-48,-28,0)
	sun.light_color=Color("fff2db"); sun.light_energy=1.6
	sun.shadow_enabled=true; sun.directional_shadow_max_distance=50
	sun.shadow_bias=0.035; sun.shadow_normal_bias=0.6
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	var fill=DirectionalLight3D.new(); add_child(fill)
	fill.rotation_degrees=Vector3(-35,145,0); fill.light_color=Color("dfeefe"); fill.light_energy=0.12
	camera=Camera3D.new(); camera.name="Reference camera"; add_child(camera)
	camera.fov=55; camera.near=0.08; camera.far=150; reset_camera(); camera.current=true
	var contour=MeshInstance3D.new(); contour.name="Fine architectural contours"
	var quad=QuadMesh.new(); quad.size=Vector2(2,2); contour.mesh=quad
	var contour_mat=ShaderMaterial.new(); contour_mat.shader=preload("res://shaders/contours.gdshader")
	contour.material_override=contour_mat; contour.extra_cull_margin=10000.0
	contour.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(contour); contour.position.z=-1
	var layer=CanvasLayer.new(); layer.name="Illustration finish"; add_child(layer)
	ink=ColorRect.new(); ink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ink.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var post=ShaderMaterial.new(); post.shader=preload("res://shaders/illustration.gdshader"); ink.material=post; layer.add_child(ink)
	print("SCENE_READY meshes=",mesh_count," materials=",material_count)
	if "--save-editable" in OS.get_cmdline_user_args():save_editable_scene()
	if "--capture" in OS.get_cmdline_user_args():
		capturing=true
		capture_after_frames()

func apply_materials(node: Node) -> void:
	if node is MeshInstance3D:
		mesh_count+=1
		var mi=node as MeshInstance3D
		for surface in mi.mesh.get_surface_count():
			var old=mi.mesh.surface_get_material(surface)
			var label=old.resource_name if old else str(node.name)
			var mat=ShaderMaterial.new()
			if "Pool clear" in label:
				mat.shader=WATER
			elif "Golden flame" in label:
				mat.shader=FIRE
			elif "Waterfall silver" in label or "Cascading water" in label:
				mat.shader=SPILL
			else:
				mat.shader=ARCH
				var tint=Color("d9ceba")
				if old is StandardMaterial3D:tint=old.albedo_color
				var kind=0
				if "teak" in label:kind=1; tint=Color("ac8759")
				elif "Tree canopy" in label:
					kind=2
					var colors=[Color("758e45"),Color("8fa44e"),Color("b2bd65"),Color("657e3c")]
					tint=colors[int(label.right(1)) % 4]
				elif "foliage" in label:kind=2; tint=Color("6d875b") if not "2" in label else Color("63847e")
				elif "upholstery" in label:kind=3; tint=Color("f4efe3")
				elif "charcoal" in label:kind=4; tint=Color("3d4141")
				elif "limestone" in label:tint=Color("e4dace")
				elif "concrete blocks" in label:tint=Color("d5cbbb")
				elif "joints" in label:tint=Color("b7ad9e")
				elif "earth" in label:tint=Color("79715e")
				mat.set_shader_parameter("tint",tint)
				mat.set_shader_parameter("kind",kind)
				mat.set_shader_parameter("grain_tex",WOOD if kind==1 else GRAIN)
				mat.set_shader_parameter("detail",0.45 if kind==1 else 0.16)
			mi.set_surface_override_material(surface,mat); material_count+=1
	for child in node.get_children():apply_materials(child)

func reset_camera() -> void:
	camera.position=origin
	camera.look_at(target)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode==KEY_R:reset_camera()
		if event.keycode==KEY_I:ink.visible=not ink.visible
		if event.keycode==KEY_F12:capture_image("res://captures/manual.png")
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_RIGHT:dragging=event.pressed
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:camera.position=target+(camera.position-target)*0.94
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:camera.position=target+(camera.position-target)*1.06
	if event is InputEventMouseMotion and dragging:
		var offset=camera.position-target
		offset=offset.rotated(Vector3.UP,-event.relative.x*0.004)
		offset=offset.rotated(camera.global_basis.x,-event.relative.y*0.004)
		camera.position=target+offset; camera.look_at(target)

func capture_after_frames() -> void:
	for i in range(40):await get_tree().process_frame
	await RenderingServer.frame_post_draw
	capture_image("res://captures/godot_courtyard.png")
	for i in range(40):await get_tree().process_frame
	await RenderingServer.frame_post_draw
	capture_image("res://captures/godot_animation_check.png")
	print("RENDER_STATS objects=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)," draws=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	print("CAPTURE_OK")
	get_tree().quit()

func capture_image(path: String) -> void:
	var img=get_viewport().get_texture().get_image()
	var result=img.save_png(path)
	print("Saved ",path," result=",result)

func save_editable_scene() -> void:
	var root=Node3D.new(); root.name="Courtyard"
	for child in get_children():
		var copied=child.duplicate()
		root.add_child(copied)
		assign_owner(copied,root)
	root.set_script(load("res://navigation.gd"))
	var packed=PackedScene.new()
	var result=packed.pack(root)
	if result==OK:result=ResourceSaver.save(packed,"res://courtyard_editable.tscn")
	print("EDITABLE_SCENE_SAVED result=",result)
	root.free()

func assign_owner(node: Node, root: Node) -> void:
	node.owner=root
	for child in node.get_children():assign_owner(child,root)


