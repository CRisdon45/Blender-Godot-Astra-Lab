extends RefCounted
## Lab-only coupling for one horizontal pool and the exported cascading sheet mesh.
## Contact spans come from triangle/plane intersections, never camera/world constants.
const WATER_PATH := "res://shaders/water.gdshader"
const SPILL_PATH := "res://shaders/spillway.gdshader"
const MAX_IMPACTS := 4
const EPSILON := 0.0001
# Covers the original 7 mm water motion and the sheet's small endpoint variation.
const CONTACT_BAND := 0.012

var flow_enabled := true
var water_time := 0.0
var _pool: MeshInstance3D
var _pool_surface := -1
var _pool_material: ShaderMaterial
var _sheets: Array = []
var _spill_nodes: Array = []
var _materials: Array[ShaderMaterial] = []
var _watched: Array = []
var _transforms: Array[Transform3D] = []
var _visibility: Array[bool] = []
var _segments := PackedVector4Array()
var _level := 0.0
var _error := ""


func setup(root: Node) -> Error:
	_collect(root)
	if not _error.is_empty():
		return ERR_INVALID_DATA
	# A navigation-only fixture is allowed; a partially bound water scene is not.
	if _pool == null and _spill_nodes.is_empty():
		return OK
	if _pool == null or _sheets.is_empty():
		_error = "Expected one pool surface and an exported Cascading water sheet mesh"
		return ERR_INVALID_DATA
	_watched.append(_pool)
	for sheet in _sheets:
		if not _watched.has(sheet.mesh):
			_watched.append(sheet.mesh)
	return rebuild_contacts()


func _collect(node: Node) -> void:
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		if instance.mesh != null:
			for surface in range(instance.mesh.get_surface_count()):
				var material := instance.get_active_material(surface) as ShaderMaterial
				if material == null or material.shader == null:
					continue
				var path := material.shader.resource_path
				if path != WATER_PATH and path != SPILL_PATH:
					continue
				if instance.material_override != null:
					_error = "Water binding requires surface overrides, not material_override"
					continue
				# Do not mutate resources shared with another scene instance or the editor.
				var local := material.duplicate() as ShaderMaterial
				instance.set_surface_override_material(surface, local)
				_materials.append(local)
				if path == WATER_PATH:
					if _pool != null:
						_error = "This lab pass supports exactly one pool material surface"
					_pool = instance
					_pool_surface = surface
					_pool_material = local
				else:
					if not _has_spill_node(instance):
						_spill_nodes.append({"node": instance, "visible": instance.visible})
					var label := String(instance.name).replace("_", " ").to_lower()
					if label.begins_with("cascading water sheet"):
						_sheets.append({"mesh": instance, "surface": surface})
	for child in node.get_children():
		_collect(child)


func _has_spill_node(instance: MeshInstance3D) -> bool:
	for entry in _spill_nodes:
		if entry.node == instance:
			return true
	return false


func rebuild_contacts() -> Error:
	_segments.clear()
	if _pool == null:
		return OK
	_pool_material.set_shader_parameter("impact_count", 0)
	var up := _pool.global_transform.basis.y.normalized()
	if not up.is_equal_approx(Vector3.UP) or absf(_pool.global_transform.basis.x.y) > EPSILON or absf(_pool.global_transform.basis.z.y) > EPSILON or absf(_pool.global_transform.basis.determinant()) < EPSILON:
		_error = "Pool must be horizontal and upright for the lab water contact pass"
		return ERR_INVALID_DATA
	var pool_arrays := _pool.mesh.surface_get_arrays(_pool_surface)
	var pool_vertices: PackedVector3Array = pool_arrays[Mesh.ARRAY_VERTEX]
	if pool_vertices.is_empty():
		_error = "Pool surface has no vertices"
		return ERR_INVALID_DATA
	var bounds := AABB(pool_vertices[0], Vector3.ZERO)
	for vertex in pool_vertices:
		if not vertex.is_finite():
			_error = "Pool has a non-finite vertex"
			return ERR_INVALID_DATA
		bounds = bounds.expand(vertex)
	_level = (_pool.global_transform * Vector3(0, bounds.end.y, 0)).y
	var contact_height := bounds.end.y + CONTACT_BAND / _pool.global_transform.basis.y.length()
	var pieces: Array = []
	var to_pool := _pool.global_transform.affine_inverse()
	for sheet in _sheets:
		var instance: MeshInstance3D = sheet.mesh
		if not _source_visible(instance):
			continue
		var array_mesh := instance.mesh as ArrayMesh
		if array_mesh == null or array_mesh.surface_get_primitive_type(sheet.surface) != Mesh.PRIMITIVE_TRIANGLES:
			_error = "Cascading sheet surface must be triangulated"
			return ERR_INVALID_DATA
		var arrays := instance.mesh.surface_get_arrays(sheet.surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			indices = arrays[Mesh.ARRAY_INDEX]
		var count := vertices.size() if indices.is_empty() else indices.size()
		if count % 3 != 0:
			_error = "Cascading sheet has an incomplete triangle"
			return ERR_INVALID_DATA
		for offset in range(0, count, 3):
			var triangle := PackedVector3Array()
			for corner in range(3):
				var index := offset + corner if indices.is_empty() else indices[offset + corner]
				if index < 0 or index >= vertices.size():
					_error = "Cascading sheet has an invalid vertex index"
					return ERR_INVALID_DATA
				var point := to_pool * instance.global_transform * vertices[index]
				if not point.is_finite():
					_error = "Cascading sheet has a non-finite vertex/transform"
					return ERR_INVALID_DATA
				triangle.append(point)
			var contact := triangle_contact(triangle, contact_height)
			if contact.size() == 2:
				contact = clip_contact(contact, Vector4(bounds.position.x, bounds.position.z, bounds.end.x, bounds.end.z))
				if contact.size() == 2:
					pieces.append(contact)
	for span in merge_contacts(pieces):
		var a := _pool.global_transform * Vector3(span.x, bounds.end.y, span.y)
		var b := _pool.global_transform * Vector3(span.z, bounds.end.y, span.w)
		_segments.append(Vector4(a.x, a.z, b.x, b.z))
	if _segments.size() > MAX_IMPACTS:
		_error = "More than four disconnected impacts; refusing to silently drop sources"
		return ERR_INVALID_DATA
	var uniforms := _segments.duplicate()
	uniforms.resize(MAX_IMPACTS)
	_pool_material.set_shader_parameter("impact_segments", uniforms)
	_pool_material.set_shader_parameter("impact_count", _segments.size())
	_pool_material.set_shader_parameter("water_level", _level)
	_transforms.clear()
	_visibility.clear()
	for instance in _watched:
		_transforms.append(instance.global_transform)
		_visibility.append(_source_visible(instance))
	_error = ""
	_apply_state()
	return OK


static func triangle_contact(triangle: PackedVector3Array, height: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	if triangle.size() != 3:
		return points
	if not is_finite(height):
		return points
	var coplanar := true
	for point in triangle:
		if not point.is_finite():
			return PackedVector2Array()
		if absf(point.y - height) > EPSILON:
			coplanar = false
	# A surface lying in the pool plane is not a falling sheet.
	if coplanar:
		return points
	for index in range(3):
		var a := triangle[index]
		var b := triangle[(index + 1) % 3]
		var da := a.y - height
		var db := b.y - height
		if absf(da) <= EPSILON:
			_append_unique(points, Vector2(a.x, a.z))
		if (da < -EPSILON and db > EPSILON) or (da > EPSILON and db < -EPSILON):
			var hit := a.lerp(b, da / (da - db))
			_append_unique(points, Vector2(hit.x, hit.z))
	return points if points.size() == 2 else PackedVector2Array()


static func _append_unique(points: PackedVector2Array, point: Vector2) -> void:
	for existing in points:
		if existing.distance_to(point) <= EPSILON:
			return
	points.append(point)


static func clip_contact(pair: PackedVector2Array, rect: Vector4) -> PackedVector2Array:
	# Liang-Barsky clipping in pool-local XZ; rotated/translated pools remain valid.
	if pair.size() != 2 or not pair[0].is_finite() or not pair[1].is_finite():
		return PackedVector2Array()
	var start := pair[0]
	var delta := pair[1] - start
	var low := 0.0
	var high := 1.0
	var p := [-delta.x, delta.x, -delta.y, delta.y]
	var q := [start.x - rect.x, rect.z - start.x, start.y - rect.y, rect.w - start.y]
	for index in range(4):
		if absf(p[index]) <= EPSILON:
			if q[index] < 0.0:
				return PackedVector2Array()
			continue
		var ratio: float = q[index] / p[index]
		if p[index] < 0.0:
			low = maxf(low, ratio)
		else:
			high = minf(high, ratio)
		if low > high:
			return PackedVector2Array()
	var result := PackedVector2Array([start + delta * low, start + delta * high])
	return result if result[0].distance_to(result[1]) > EPSILON else PackedVector2Array()


static func merge_contacts(pieces: Array) -> PackedVector4Array:
	# Shared-edge endpoints connect adjacent triangles, including unwelded glTF faces.
	# Only runs on setup/transform edits; never per pixel or per animation frame.
	var groups: Array = []
	for piece in pieces:
		var joined: Array[int] = []
		for index in range(groups.size()):
			var touching := false
			for point in groups[index]:
				if point.distance_to(piece[0]) <= EPSILON or point.distance_to(piece[1]) <= EPSILON:
					touching = true
			if touching:
				joined.append(index)
		var group: PackedVector2Array = piece.duplicate()
		joined.reverse()
		for index in joined:
			group.append_array(groups[index])
			groups.remove_at(index)
		groups.append(group)
	var result := PackedVector4Array()
	for group in groups:
		var a: Vector2 = group[0]
		var b: Vector2 = group[1]
		var longest := a.distance_squared_to(b)
		for left in range(group.size()):
			for right in range(left + 1, group.size()):
				var distance: float = group[left].distance_squared_to(group[right])
				if distance > longest:
					longest = distance
					a = group[left]
					b = group[right]
		if longest > EPSILON * EPSILON:
			result.append(Vector4(a.x, a.y, b.x, b.y))
	return result


func advance(delta: float) -> Error:
	for index in range(_watched.size()):
		if not is_instance_valid(_watched[index]):
			_error = "Bound water mesh removed; restart or rebuild the scene binding"
			return ERR_INVALID_DATA
		if not _watched[index].global_transform.is_equal_approx(_transforms[index]) or _source_visible(_watched[index]) != _visibility[index]:
			var result := rebuild_contacts()
			if result != OK:
				return result
			break
	if is_finite(delta) and delta > 0.0:
		water_time += delta
	_apply_state()
	return OK


func _source_visible(instance: MeshInstance3D) -> bool:
	if not flow_enabled:
		for entry in _spill_nodes:
			if entry.node == instance:
				var parent := instance.get_parent() as Node3D
				return entry.visible and (parent == null or parent.is_visible_in_tree())
	return instance.is_visible_in_tree()


func set_flow(enabled: bool) -> void:
	if enabled != flow_enabled:
		for entry in _spill_nodes:
			if is_instance_valid(entry.node):
				if not enabled:
					entry.visible = entry.node.visible
					entry.node.visible = false
				else:
					entry.node.visible = entry.visible
	flow_enabled = enabled
	_apply_state()


func _apply_state() -> void:
	for material in _materials:
		material.set_shader_parameter("water_time", water_time)
		material.set_shader_parameter("flow_strength", 1.0 if flow_enabled else 0.0)


func snapshot() -> Dictionary:
	var sources: Array = []
	for span in _segments:
		sources.append([span.x, span.y, span.z, span.w])
	return {"flow_enabled": flow_enabled, "time_seconds": water_time,
		"water_level": _level, "contact_band": CONTACT_BAND, "impact_segments_xz": sources,
		"active": _pool != null, "error": _error}
