extends Node3D

const FOLIAGE: Shader = preload("res://shaders/foliage.gdshader")
const GROUND: Shader = preload("res://shaders/ground.gdshader")
var camera: Camera3D
var target := Vector3(0.0, 3.2, 0.0)
var yaw := 0.10
var pitch := 0.12
var distance := 17.8
var dragging := false
var wind_enabled := false
var animation_time := 0.0
var foliage_materials: Array[ShaderMaterial] = []
var tree_meshes: Array[MeshInstance3D] = []
var controls: CanvasLayer


func _ready() -> void:
	camera = $Camera
	apply_materials($Tree, true)
	apply_materials($Meadow, false)
	update_camera()
	build_controls()
	if "--validate" in OS.get_cmdline_user_args():
		validate_asset()
	if "--capture" in OS.get_cmdline_user_args():
		capture_suite()


func apply_materials(node: Node, is_tree: bool) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if is_tree:
			tree_meshes.append(mesh_node)
		if "Bark" in node.name:
			var bark_material := ShaderMaterial.new()
			bark_material.shader = FOLIAGE
			mesh_node.material_override = bark_material
		if "Leaves" in node.name or "Blossoms" in node.name or "Grass" in node.name or "FallenPetals" in node.name:
			var mat := ShaderMaterial.new()
			mat.shader = FOLIAGE
			mat.set_shader_parameter("blossom", "Blossom" in node.name or "Petals" in node.name)
			mesh_node.material_override = mat
			if is_tree:
				foliage_materials.append(mat)
		elif node.name == "Meadow_Ground":
			var mat := ShaderMaterial.new()
			mat.shader = GROUND
			mesh_node.material_override = mat
	for child in node.get_children():
		apply_materials(child, is_tree)


func update_camera() -> void:
	camera.position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.look_at(target)


func _process(delta: float) -> void:
	if wind_enabled:
		animation_time += delta
		for mat in foliage_materials:
			mat.set_shader_parameter("time_seconds", animation_time)


func toggle_wind() -> void:
	wind_enabled = not wind_enabled
	for mat in foliage_materials:
		mat.set_shader_parameter("wind_strength", 0.075 if wind_enabled else 0.0)


func reset_camera() -> void:
	target = Vector3(0.0, 3.2, 0.0)
	yaw = 0.10
	pitch = 0.12
	distance = 17.8
	update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(4.0, distance * 0.93)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(60.0, distance * 1.07)
		update_camera()
	elif event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x * 0.004
		pitch = clampf(pitch + event.relative.y * 0.004, -0.08, 1.25)
		update_camera()
	elif event is InputEventScreenDrag:
		yaw -= event.relative.x * 0.004
		pitch = clampf(pitch + event.relative.y * 0.004, -0.08, 1.25)
		update_camera()
	elif event is InputEventMagnifyGesture:
		distance = clampf(distance / event.factor, 4.0, 60.0)
		update_camera()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			reset_camera()
		elif event.keycode == KEY_W:
			toggle_wind()
		elif event.keycode == KEY_F12:
			save_image("user://palo_verde.png")
		elif event.keycode == KEY_ESCAPE:
			get_tree().quit()


func build_controls() -> void:
	controls = CanvasLayer.new()
	add_child(controls)
	var panel := HBoxContainer.new()
	panel.position = Vector2(20, 20)
	panel.add_theme_constant_override("separation", 12)
	controls.add_child(panel)
	var label := Label.new()
	label.text = "PALO VERDE  ·  3D STUDY"
	label.add_theme_color_override("font_color", Color(0.13, 0.22, 0.12))
	panel.add_child(label)
	var reset := Button.new()
	reset.text = "Reset view"
	reset.pressed.connect(reset_camera)
	panel.add_child(reset)
	var wind := Button.new()
	wind.text = "Gentle wind"
	wind.toggle_mode = true
	wind.pressed.connect(toggle_wind)
	panel.add_child(wind)
	var hint := Label.new()
	hint.text = "Right-drag or touch to orbit · Scroll to zoom · R reset · W wind · F12 capture"
	hint.position = Vector2(20, 1040)
	hint.add_theme_color_override("font_color", Color(0.95, 0.96, 0.86))
	controls.add_child(hint)


func validate_asset() -> void:
	var bounds := AABB()
	var first := true
	var triangles := 0
	for node in tree_meshes:
		var box: AABB = node.global_transform * node.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		for surface in range(node.mesh.get_surface_count()):
			var arrays := node.mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			triangles += indices.size() / 3
	var passed := tree_meshes.size() == 3 and absf(bounds.position.y) < 0.05 and bounds.size.x > 9.0 and bounds.size.y > 5.0 and triangles > 10000 and triangles < 450000
	var report := {"passed": passed, "tree_meshes": tree_meshes.size(), "tree_triangles": triangles,
		"bounds_origin": [bounds.position.x, bounds.position.y, bounds.position.z],
		"bounds_size": [bounds.size.x, bounds.size.y, bounds.size.z],
		"godot": Engine.get_version_info(), "renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method")}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
	var file := FileAccess.open("res://captures/runtime_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print("PALO_VERDE_RUNTIME_", "OK" if passed else "FAILED", " ", JSON.stringify(report))
	if "--capture" not in OS.get_cmdline_user_args():
		get_tree().quit(0 if passed else 1)
	elif not passed:
		get_tree().quit(1)


func save_image(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var error := img.save_png(path)
	if error != OK:
		push_error("Image save failed: " + path)
		get_tree().quit(1)
	print("PALO_VERDE_CAPTURE_OK ", path)


func capture_suite() -> void:
	controls.hide()
	for _frame in range(12):
		await get_tree().process_frame
	await save_image("res://captures/01_hero.png")
	await save_image("res://captures/02_hero_repeat.png")
	yaw = 1.15
	pitch = 0.23
	update_camera()
	for _frame in range(4):
		await get_tree().process_frame
	await save_image("res://captures/03_side.png")
	distance = 9.0
	yaw = 0.3
	pitch = 0.10
	target = Vector3(0.0, 3.8, 0.0)
	update_camera()
	for _frame in range(4):
		await get_tree().process_frame
	await save_image("res://captures/04_foliage_detail.png")
	reset_camera()
	$Sun.rotation_degrees = Vector3(-28, 55, 0)
	for _frame in range(4):
		await get_tree().process_frame
	await save_image("res://captures/05_second_sun.png")
	for mat in foliage_materials:
		mat.set_shader_parameter("wind_strength", 0.075)
		mat.set_shader_parameter("time_seconds", 1.25)
	for _frame in range(4):
		await get_tree().process_frame
	await save_image("res://captures/06_fixed_wind.png")
	print("PALO_VERDE_CAPTURE_SUITE_OK")
	get_tree().quit()
