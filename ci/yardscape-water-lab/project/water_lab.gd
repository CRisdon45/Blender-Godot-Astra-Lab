extends Node3D
## Deliberately tiny water look-development scene.
## Pool shell + Baja shelf + three steps + one water surface. Nothing else.

const BasinShader = preload("res://shaders/basin.gdshader")
const SurfaceShader = preload("res://shaders/water_surface.gdshader")

const POOL_LENGTH := 8.0
const POOL_WIDTH := 4.0
const WATER_LEVEL := 0.0
const BASE_Y := -1.72
const SUN_RAY_DIR := Vector3(0.38, -0.82, 0.43).normalized()

var basin_material: ShaderMaterial
var surface_material: ShaderMaterial
var water_surface: MeshInstance3D

var visual_time := 0.0
var paused := false
var caustics_enabled := true
var surface_enabled := true


func _ready() -> void:
	_configure_from_environment()
	RenderingServer.set_default_clear_color(Color("f1efe8"))
	_make_materials()
	_make_pool()
	_make_camera()
	water_surface.visible = surface_enabled
	_apply_time()

	print("Northstar Water Lab | Space pause | C caustics | S surface | R reset | Left/Right scrub")

	var capture_path := OS.get_environment("YARDSCAPE_WATER_CAPTURE")
	if not capture_path.is_empty():
		paused = true
		call_deferred("_capture_and_quit", capture_path)


func _process(delta: float) -> void:
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


func _capture_and_quit(path: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	print("water_capture path=%s error=%d time=%.2f caustics=%s surface=%s" % [
		path, error, visual_time, caustics_enabled, surface_enabled
	])
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
	surface_material.set_shader_parameter("sun_ray_dir", SUN_RAY_DIR)


func _make_pool() -> void:
	# All blocks terminate at the same hidden bottom datum. Their exposed top
	# elevations are the only geometry we care about in this lab.
	_make_solid("baja-shelf", -4.00, -1.80, -0.25)
	_make_solid("step-1", -1.80, -1.30, -0.45)
	_make_solid("step-2", -1.30, -0.80, -0.70)
	_make_solid("step-3", -0.80, -0.30, -1.00)
	_make_solid("deep-floor", -0.30, 4.00, -1.50)

	# Thin walls only close the pool volume. No coping, deck or exterior shell.
	_make_box("wall-north", Vector3(0.0, BASE_Y * 0.5, -2.04),
		Vector3(POOL_LENGTH + 0.10, -BASE_Y, 0.08))
	_make_box("wall-south", Vector3(0.0, BASE_Y * 0.5, 2.04),
		Vector3(POOL_LENGTH + 0.10, -BASE_Y, 0.08))
	_make_box("wall-west", Vector3(-4.04, BASE_Y * 0.5, 0.0),
		Vector3(0.08, -BASE_Y, POOL_WIDTH + 0.10))
	_make_box("wall-east", Vector3(4.04, BASE_Y * 0.5, 0.0),
		Vector3(0.08, -BASE_Y, POOL_WIDTH + 0.10))

	var mesh := PlaneMesh.new()
	mesh.size = Vector2(POOL_LENGTH - 0.08, POOL_WIDTH - 0.08)
	mesh.subdivide_width = 95
	mesh.subdivide_depth = 47

	water_surface = MeshInstance3D.new()
	water_surface.name = "WaterSurface"
	water_surface.mesh = mesh
	water_surface.position.y = WATER_LEVEL
	water_surface.material_override = surface_material
	add_child(water_surface)


func _make_solid(_name: String, x0: float, x1: float, top_y: float) -> void:
	var height := top_y - BASE_Y
	_make_box(
		_name,
		Vector3((x0 + x1) * 0.5, BASE_Y + height * 0.5, 0.0),
		Vector3(x1 - x0, height, POOL_WIDTH)
	)


func _make_box(_name: String, centre: Vector3, size: Vector3) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size

	var node := MeshInstance3D.new()
	node.name = _name
	node.mesh = box
	node.position = centre
	node.material_override = basin_material
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
