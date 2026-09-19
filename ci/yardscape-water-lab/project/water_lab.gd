extends Node3D
## Deliberately tiny water look-development scene.
## Surface-only pool + Baja shelf + three steps + one water surface. Nothing else.

const BasinShader = preload("res://shaders/basin_fast.gdshader")
const SurfaceShader = preload("res://shaders/water_surface_fast.gdshader")
const WallShader = preload("res://shaders/wall_fast.gdshader")

const POOL_LENGTH := 8.0
const POOL_WIDTH := 4.0
const WATER_LEVEL := 0.0
const SUN_RAY_DIR := Vector3(0.3796774, -0.8193039, 0.4296350)

var basin_material: ShaderMaterial
var surface_material: ShaderMaterial
var wall_material: ShaderMaterial
var water_surface: MeshInstance3D

var visual_time := 0.0
var paused := false
var caustics_enabled := true
var surface_enabled := true
var capture_path := ""
var capture_frame_count := 0


func _ready() -> void:
	_configure_from_environment()
	RenderingServer.set_default_clear_color(Color("f1efe8"))
	_make_materials()
	_make_pool()
	_make_camera()
	water_surface.visible = surface_enabled
	_apply_time()

	print("Northstar Water Lab | Space pause | C caustics | S surface | R reset | Left/Right scrub")

	capture_path = OS.get_environment("YARDSCAPE_WATER_CAPTURE")
	if not capture_path.is_empty():
		paused = true


func _process(delta: float) -> void:
	if not capture_path.is_empty():
		capture_frame_count += 1
		if capture_frame_count >= 8:
			_capture_now_and_quit()
			return

	if not paused:
		visual_time += delta
		_apply_time()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_SPACE:
			paused = not paused
		KEY_C:
			caustics_enabled = not caustics_enabled
			basin_material.set_shader_parameter("caustics_enabled", caustics_enabled)
		KEY_S:
			surface_enabled = not surface_enabled
			water_surface.visible = surface_enabled
		KEY_R:
			visual_time = 0.0
			_apply_time()
		KEY_LEFT:
			paused = true
			visual_time = maxf(0.0, visual_time - 0.25)
			_apply_time()
		KEY_RIGHT:
			paused = true
			visual_time += 0.25
			_apply_time()
		_:
			return

	get_viewport().set_input_as_handled()
	print("water_time=%.2f paused=%s caustics=%s surface=%s" % [
		visual_time, paused, caustics_enabled, surface_enabled
	])


func _configure_from_environment() -> void:
	var requested_time := OS.get_environment("YARDSCAPE_WATER_TIME")
	if not requested_time.is_empty():
		visual_time = maxf(0.0, requested_time.to_float())
		paused = true

	var requested_caustics := OS.get_environment("YARDSCAPE_WATER_CAUSTICS").to_lower()
	if requested_caustics in ["0", "false", "off"]:
		caustics_enabled = false
	elif requested_caustics in ["1", "true", "on"]:
		caustics_enabled = true

	var requested_surface := OS.get_environment("YARDSCAPE_WATER_SURFACE").to_lower()
	if requested_surface in ["0", "false", "off"]:
		surface_enabled = false
	elif requested_surface in ["1", "true", "on"]:
		surface_enabled = true


func _capture_now_and_quit() -> void:
	var image := get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	var error := image.save_png(capture_path)
	print("water_capture path=%s error=%d time=%.2f caustics=%s surface=%s frames=%d" % [
		capture_path, error, visual_time, caustics_enabled, surface_enabled, capture_frame_count
	])
	capture_path = ""
	get_tree().quit(0 if error == OK else 1)


func _make_materials() -> void:
	basin_material = ShaderMaterial.new()
	basin_material.shader = BasinShader
	basin_material.set_shader_parameter("visual_time", visual_time)
	basin_material.set_shader_parameter("water_level", WATER_LEVEL)
	basin_material.set_shader_parameter("sun_ray_dir", SUN_RAY_DIR)
	basin_material.set_shader_parameter("caustics_enabled", caustics_enabled)

	surface_material = ShaderMaterial.new()
	surface_material.shader = SurfaceShader
	surface_material.set_shader_parameter("visual_time", visual_time)

	wall_material = ShaderMaterial.new()
	wall_material.shader = WallShader
	wall_material.set_shader_parameter("water_level", WATER_LEVEL)


func _make_pool() -> void:
	# Horizontal water-contact surfaces only. No solid blocks, no exterior shell.
	_make_horizontal("baja-shelf", -4.00, -1.80, -0.25)
	_make_horizontal("step-1", -1.80, -1.30, -0.45)
	_make_horizontal("step-2", -1.30, -0.80, -0.70)
	_make_horizontal("step-3", -0.80, -0.30, -1.00)
	_make_horizontal("deep-floor", -0.30, 4.00, -1.50)

	# Four step risers.
	_make_vertical_x("riser-baja", -1.80, -0.45, -0.25)
	_make_vertical_x("riser-1", -1.30, -0.70, -0.45)
	_make_vertical_x("riser-2", -0.80, -1.00, -0.70)
	_make_vertical_x("riser-3", -0.30, -1.50, -1.00)

	# Water look-dev cutaway: retain only the two far interior walls.
	# The camera sits west/south of the pool, so the west and south walls only
	# occlude the Baja/steps/deep-water read and add no useful water evidence.
	_make_vertical_z("wall-north", -POOL_WIDTH * 0.5, -1.50, WATER_LEVEL)
	_make_vertical_x_span("wall-east", POOL_LENGTH * 0.5, -1.50, WATER_LEVEL, POOL_WIDTH)

	var mesh := PlaneMesh.new()
	mesh.size = Vector2(POOL_LENGTH - 0.08, POOL_WIDTH - 0.08)
	mesh.subdivide_width = 31
	mesh.subdivide_depth = 15

	water_surface = MeshInstance3D.new()
	water_surface.name = "WaterSurface"
	water_surface.mesh = mesh
	water_surface.position.y = WATER_LEVEL
	water_surface.material_override = surface_material
	add_child(water_surface)


func _make_horizontal(_name: String, x0: float, x1: float, y: float) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(x1 - x0, POOL_WIDTH)

	var node := MeshInstance3D.new()
	node.name = _name
	node.mesh = mesh
	node.position = Vector3((x0 + x1) * 0.5, y, 0.0)
	node.material_override = basin_material
	add_child(node)
	return node


func _make_vertical_x(_name: String, x: float, y0: float, y1: float) -> MeshInstance3D:
	return _make_vertical_x_span(_name, x, y0, y1, POOL_WIDTH)


func _make_vertical_x_span(_name: String, x: float, y0: float, y1: float, span_z: float) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(absf(y1 - y0), span_z)

	var node := MeshInstance3D.new()
	node.name = _name
	node.mesh = mesh
	node.position = Vector3(x, (y0 + y1) * 0.5, 0.0)
	node.rotation_degrees.z = 90.0
	node.material_override = wall_material
	add_child(node)
	return node


func _make_vertical_z(_name: String, z: float, y0: float, y1: float) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(POOL_LENGTH, absf(y1 - y0))

	var node := MeshInstance3D.new()
	node.name = _name
	node.mesh = mesh
	node.position = Vector3(0.0, (y0 + y1) * 0.5, z)
	node.rotation_degrees.x = 90.0
	node.material_override = wall_material
	add_child(node)
	return node


func _make_camera() -> void:
	var camera := Camera3D.new()
	camera.name = "FixedCamera"
	camera.position = Vector3(-7.5, 5.35, 6.65)
	camera.fov = 45.0
	camera.near = 0.05
	camera.far = 40.0
	add_child(camera)
	camera.look_at(Vector3(-0.35, -0.62, 0.0), Vector3.UP)
	camera.current = true


func _apply_time() -> void:
	if is_instance_valid(basin_material):
		basin_material.set_shader_parameter("visual_time", visual_time)
	if is_instance_valid(surface_material):
		surface_material.set_shader_parameter("visual_time", visual_time)
