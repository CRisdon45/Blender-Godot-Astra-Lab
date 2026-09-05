extends SceneTree
## Real saved-scene/GLB binding test. Headless success is NOT graphics evidence.
const Navigation = preload("res://navigation.gd")
const Water = preload("res://water_interaction.gd")
const SCENES := ["res://courtyard_editable.tscn", "res://courtyard.tscn"]
var checks := 0
var failures := 0
var materials: Array[ShaderMaterial] = []
var spill_nodes: Array[MeshInstance3D] = []
var sheets: Array[MeshInstance3D] = []
var pool_materials: Array[ShaderMaterial] = []


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("SCENE_WATER_TEST_FAILED: " + message)


func _collect(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh != null:
			for surface in range(mesh_node.mesh.get_surface_count()):
				var material := mesh_node.get_active_material(surface) as ShaderMaterial
				if material == null or material.shader == null:
					continue
				var path := material.shader.resource_path
				if path == Water.WATER_PATH:
					pool_materials.append(material)
					materials.append(material)
				elif path == Water.SPILL_PATH:
					materials.append(material)
					if not spill_nodes.has(mesh_node):
						spill_nodes.append(mesh_node)
					var label := String(mesh_node.name).replace("_", " ").to_lower()
					if label.begins_with("cascading water sheet") and not sheets.has(mesh_node):
						sheets.append(mesh_node)
	for child in node.get_children():
		_collect(child)


func _key(scene: Navigation, code: Key, repeated: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.echo = repeated
	scene._unhandled_input(event)


func _same_spans(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	for index in range(left.size()):
		var a := Vector4(left[index][0], left[index][1], left[index][2], left[index][3])
		var b := Vector4(right[index][0], right[index][1], right[index][2], right[index][3])
		if not a.is_equal_approx(b):
			return false
	return true


func _uniform_state(scene: Navigation, enabled: bool) -> void:
	for material in materials:
		check(is_equal_approx(float(material.get_shader_parameter("flow_strength")), 1.0 if enabled else 0.0), "Flow uniform agrees across real materials")
		check(is_equal_approx(float(material.get_shader_parameter("water_time")), scene.water.water_time), "Clock agrees across real materials")


func _exercise(scene: Navigation) -> void:
	# _ready has executed on the actual scene. Stop live ticking during exact assertions.
	scene.set_process(false)
	var initial: Dictionary = scene.water.snapshot()
	check(initial.active and initial.error.is_empty(), "Real scene has an active, error-free water binding")
	check(initial.impact_segments_xz.size() == 2, "Real scene resolves exactly two sheers")
	check(scene.camera != null, "Real reference camera was bound")
	_collect(scene)
	check(pool_materials.size() == 1, "Exactly one real pool material surface")
	check(not sheets.is_empty(), "Exported sheet nodes were discovered")
	if failures > 0:
		return
	var original_visibility: Array[bool] = []
	for node in spill_nodes:
		original_visibility.append(node.visible)
	check(scene.water.advance(0.25) == OK, "Advance actual binding")
	check(is_equal_approx(scene.water.water_time, float(initial.time_seconds) + 0.25), "Ambient clock advances")
	_uniform_state(scene, true)
	for index in range(Navigation.VIEW_NAMES.size()):
		scene.select_view(index)
		check(scene.camera.position.is_finite() and scene.camera.rotation.is_finite(), "Review camera remains finite")
	var camera_before := scene.camera.transform
	_key(scene, KEY_W, true)
	check(scene.water.flow_enabled, "Repeated W must not toggle")
	_key(scene, KEY_W)
	check(not scene.water.flow_enabled, "W turns flow off through the real input handler")
	check(scene.camera.transform.is_equal_approx(camera_before), "W preserves camera")
	for node in spill_nodes:
		check(not node.visible, "W hides sheets and glints")
	check(scene.water.advance(0.25) == OK, "Ambient clock still advances with flow off")
	_uniform_state(scene, false)
	check(_same_spans(initial.impact_segments_xz, scene.water.snapshot().impact_segments_xz), "Flow off retains source contacts")

	var original_transforms: Array[Transform3D] = []
	for sheet in sheets:
		original_transforms.append(sheet.global_transform)
		sheet.global_position += Vector3(100.0, 0.0, 0.0)
	check(scene.water.advance(0.0) == OK, "Rebuild moved real sheets while flow is off")
	check(scene.water.snapshot().impact_segments_xz.is_empty(), "Moving real sheets outside clears stale impacts")
	for material in pool_materials:
		check(int(material.get_shader_parameter("impact_count")) == 0, "Pool uniform clears moved impacts")
	for index in range(sheets.size()):
		sheets[index].global_transform = original_transforms[index]
	check(scene.water.advance(0.0) == OK, "Restore real sheet transforms")
	check(_same_spans(initial.impact_segments_xz, scene.water.snapshot().impact_segments_xz), "Restoring sheets restores full contact spans")
	_key(scene, KEY_W)
	check(scene.water.flow_enabled, "W restores flow")
	_uniform_state(scene, true)
	for index in range(spill_nodes.size()):
		check(spill_nodes[index].visible == original_visibility[index], "W restores original sheet/glint visibility")
	for material in pool_materials:
		check(int(material.get_shader_parameter("impact_count")) == 2, "Pool uniform restores both impacts")

	# The capture lock must prevent input from invalidating capture metadata.
	scene._capturing = true
	_key(scene, KEY_W)
	check(scene.water.flow_enabled, "Capture lock blocks W")
	scene._capturing = false
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_RIGHT
	button.pressed = true
	scene._unhandled_input(button)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(9000, 9000)
	scene._unhandled_input(motion)
	check(scene.camera.position.is_finite() and scene.camera.rotation.is_finite(), "Actual orbit handler remains finite")
	var distance := scene.camera.position.distance_to(scene.target)
	check(distance >= Navigation.MIN_DISTANCE - 0.001 and distance <= Navigation.MAX_DISTANCE + 0.001, "Actual orbit stays bounded")
	scene.reset_camera()
	check(scene.camera.transform.is_equal_approx(scene.reference_transform), "Reset restores real reference pose")


func _run() -> void:
	var path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test-scene="):
			path = arg.trim_prefix("--test-scene=")
	check(path in SCENES, "Select an actual courtyard entry point with --test-scene")
	if failures > 0:
		quit(1)
		return
	var packed := load(path) as PackedScene
	check(packed != null, "Real scene resource loads after import")
	if packed == null:
		quit(1)
		return
	var instance := packed.instantiate()
	var scene := instance as Navigation
	check(scene != null, "Real scene uses shared navigation")
	if scene == null:
		instance.free()
		quit(1)
		return
	root.add_child(scene)
	_exercise(scene)
	scene.free()
	materials.clear()
	pool_materials.clear()
	spill_nodes.clear()
	sheets.clear()
	if failures == 0:
		print("SCENE_WATER_TESTS_OK ", JSON.stringify({
			"scene": path, "checks": checks, "impact_count": 2, "graphics_validated": false,
		}))
	quit(0 if failures == 0 else 1)
