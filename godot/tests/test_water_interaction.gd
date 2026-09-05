extends SceneTree
## Executes the actual water binding/helpers. Requires Godot; Python contracts do not run this.
const Water = preload("res://water_interaction.gd")
const WATER_SHADER = preload("res://shaders/water.gdshader")
const SPILL_SHADER = preload("res://shaders/spillway.gdshader")
var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _mesh(name_text: String, vertices: PackedVector3Array, shader: Shader, indexed: bool = false) -> MeshInstance3D:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	if indexed:
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(range(vertices.size()))
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := ShaderMaterial.new()
	material.shader = shader
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = name_text
	instance.mesh = mesh
	return instance


func _fixture(diagonal: int = 0, indexed: bool = false) -> Dictionary:
	var scene := Node3D.new()
	var y := 0.3225
	var pool := _mesh("Pool", PackedVector3Array([
		Vector3(-3.995, y, -5.59), Vector3(3.995, y, -5.59), Vector3(3.995, y, 1.59),
		Vector3(-3.995, y, -5.59), Vector3(3.995, y, 1.59), Vector3(-3.995, y, 1.59)]), WATER_SHADER)
	scene.add_child(pool)
	# The exact two-sheet formula from build_scene.py, mapped Blender XYZ -> Godot XZ-Y.
	var triangles := PackedVector3Array()
	for x in [-2.65, 0.1]:
		var vertices := PackedVector3Array()
		for k in range(25):
			var t := float(k) / 24.0
			for j in range(21):
				vertices.append(Vector3(x - 0.47 + j * 0.047,
					1.41 - 1.1 * t * t + 0.014 * sin(j * 3 + k),
					-(5.48 - 0.48 * t + 0.012 * sin(j * 2 + k))))
		for k in range(24):
			for j in range(20):
				var a := k * 21 + j
				var face := [a, a + 1, a + 22, a + 21]
				var order := [0, 1, 2, 0, 2, 3] if diagonal == 0 else [0, 1, 3, 1, 2, 3]
				for index in order:
					triangles.append(vertices[face[index]])
	var sheet := _mesh("Cascading water sheet", triangles, SPILL_SHADER, indexed)
	scene.add_child(sheet)
	root.add_child(scene)
	return {"scene": scene, "pool": pool, "sheet": sheet}


func _run() -> void:
	var crossing := PackedVector3Array([Vector3(-1, 1, 0), Vector3(1, -1, 0), Vector3(1, 1, 0)])
	check(Water.triangle_contact(crossing, 0.0).size() == 2, "Crossing triangle")
	check(Water.triangle_contact(crossing, 3.0).is_empty(), "No contact above sheet")
	check(Water.triangle_contact(PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.FORWARD]), 0.0).is_empty(), "Ignore coplanar triangles")
	check(Water.triangle_contact(PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP]), 0.0).size() == 2, "Edge exactly on plane")
	check(Water.triangle_contact(PackedVector3Array([Vector3.ZERO, Vector3.ONE, Vector3(-1, 1, 0)]), 0.0).is_empty(), "Point-only contact")
	var rect := Vector4(-1, -1, 1, 1)
	var clipped := Water.clip_contact(PackedVector2Array([Vector2(-2, 0), Vector2(2, 0)]), rect)
	check(clipped.size() == 2 and clipped[0].is_equal_approx(Vector2(-1, 0)) and clipped[1].is_equal_approx(Vector2(1, 0)), "Clip partial contact")
	check(Water.clip_contact(PackedVector2Array([Vector2(-2, 2), Vector2(2, 2)]), rect).is_empty(), "Reject outside contact")
	check(Water.clip_contact(PackedVector2Array([Vector2.ZERO, Vector2.ZERO]), rect).is_empty(), "Reject zero-length contact")
	var pieces := [PackedVector2Array([Vector2(0, 0), Vector2(1, 0)]), PackedVector2Array([Vector2(2, 0), Vector2(3, 0)]), PackedVector2Array([Vector2(1, 0), Vector2(2, 0)])]
	check(Water.merge_contacts(pieces).size() == 1, "Bridge two unwelded contact groups")
	pieces.append(PackedVector2Array([Vector2(8, 0), Vector2(9, 0)]))
	check(Water.merge_contacts(pieces).size() == 2, "Keep separate sheers separate")

	for mode in range(4):
		var fixture := _fixture(mode % 2, mode >= 2)
		var binding := Water.new()
		var result := binding.setup(fixture.scene)
		check(result == OK, "Source-formula fixture binds")
		if result != OK:
			fixture.scene.free()
			continue
		var initial: Dictionary = binding.snapshot()
		var spans: Array = initial.impact_segments_xz
		check(spans.size() == 2, "Original twin sheets resolve to two spans, not fragmented ripples")
		for span in spans:
			var width := Vector2(span[0], span[1]).distance_to(Vector2(span[2], span[3]))
			check(absf(width - 0.94) < 0.01, "Full sheet width, not a point-source ring")
		var pool: MeshInstance3D = fixture.pool
		var sheet: MeshInstance3D = fixture.sheet
		check(pool.get_active_material(0) != pool.mesh.surface_get_material(0), "Pool material is runtime-local")
		check(sheet.get_active_material(0) != sheet.mesh.surface_get_material(0), "Sheet material is runtime-local")
		check(binding.advance(0.25) == OK, "Shared clock advances")
		check(is_equal_approx((pool.get_active_material(0) as ShaderMaterial).get_shader_parameter("water_time"), (sheet.get_active_material(0) as ShaderMaterial).get_shader_parameter("water_time")), "Pool and sheet use identical clock")
		binding.set_flow(false)
		check(not sheet.visible, "Off hides falling water geometry")
		check(is_zero_approx((pool.get_active_material(0) as ShaderMaterial).get_shader_parameter("flow_strength")), "Off removes impact response")
		sheet.position.x += 0.5
		check(binding.advance(0.0) == OK, "Transform rebuild while flow is off")
		var moved: Array = binding.snapshot().impact_segments_xz
		check(moved.size() == 2, "Flow-off rebuild must not lose hidden sheet contacts")
		if spans.size() == 2 and moved.size() == 2:
			check(absf(moved[0][0] - spans[0][0] - 0.5) < 0.001, "Impact follows sheet transform")
		binding.set_flow(true)
		check(sheet.visible, "On restores falling sheet")
		fixture.scene.rotation.y = 0.6
		check(binding.advance(0.0) == OK, "Parent yaw keeps pool horizontal")
		check(binding.snapshot().impact_segments_xz.size() == 2, "Rotated pool-local clipping")
		sheet.position.x = 30.0
		check(binding.advance(0.0) == OK and binding.snapshot().impact_segments_xz.is_empty(), "Outside pool produces no stale impact")
		sheet.position.x = 0.0
		check(binding.advance(0.0) == OK and binding.snapshot().impact_segments_xz.size() == 2, "Moving sheet back restores contacts")
		pool.rotation.x = 0.2
		check(binding.rebuild_contacts() != OK, "Reject tilted water surface")
		check((pool.get_active_material(0) as ShaderMaterial).get_shader_parameter("impact_count") == 0, "Binding failure clears stale impacts")
		fixture.scene.free()

	var crowded := _fixture()
	var old_sheet: MeshInstance3D = crowded.sheet
	old_sheet.free()
	for x in [-3.0, -1.5, 0.0, 1.5, 3.0]:
		var vertices := PackedVector3Array([
			Vector3(x - 0.25, 1, -2), Vector3(x + 0.25, 0, -2), Vector3(x + 0.25, 1, -2),
			Vector3(x - 0.25, 1, -2), Vector3(x - 0.25, 0, -2), Vector3(x + 0.25, 0, -2)])
		crowded.scene.add_child(_mesh("Cascading water sheet " + str(x), vertices, SPILL_SHADER))
	var limited := Water.new()
	check(limited.setup(crowded.scene) != OK, "Reject impact capacity overflow")
	check("four" in limited.snapshot().error, "Explain impact capacity failure")
	crowded.scene.free()

	var empty := Node3D.new()
	root.add_child(empty)
	check(Water.new().setup(empty) == OK, "Navigation-only fixture remains valid")
	empty.free()
	if failures == 0:
		print("WATER_TESTS_OK checks=", checks)
	quit(0 if failures == 0 else 1)
