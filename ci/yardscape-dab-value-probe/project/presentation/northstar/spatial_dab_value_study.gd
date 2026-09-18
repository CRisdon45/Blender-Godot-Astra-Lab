extends "res://presentation/northstar/spatial_dab_tree_study.gd"
## Material-only hierarchy experiment. Geometry/transforms and real shadows remain.
const ValuePaint = preload("res://presentation/northstar/foliage/dab_value.gdshader")
var values_enabled := true
var _baseline_materials: Array[Material] = []
var _value_materials: Array[ShaderMaterial] = []
var _family_values := PackedFloat32Array()
var _role_values := PackedFloat32Array()

func _build() -> void:
	super._build()
	_baseline_materials.clear()
	_value_materials.clear()
	for group in dab_tree.groups:
		_baseline_materials.append(group.foliage.material_override)
		var material := ShaderMaterial.new()
		material.shader = ValuePaint
		_value_materials.append(material)
	_apply_value_materials()

func _set_light(value: String) -> void:
	super._set_light(value)
	_apply_value_materials()

func set_values_enabled(value: bool) -> void:
	values_enabled = value
	_apply_value_materials()

func _apply_value_materials() -> void:
	if not is_instance_valid(dab_tree) or _value_materials.size() != dab_tree.groups.size(): return
	_family_values = PackedFloat32Array()
	_role_values = PackedFloat32Array()
	var source_direction := Vector2(sun.global_basis.z.x, sun.global_basis.z.z)
	if source_direction.length_squared() < 1e-8: source_direction = Vector2(0,-1)
	source_direction = source_direction.normalized()
	var family_biases := PackedFloat32Array()
	for family in 5:
		var primary: Node3D = dab_tree.groups[family*3]
		var radial := Vector2(primary.position.x, primary.position.z)
		if radial.length_squared() < 1e-8: radial = Vector2.RIGHT
		var alignment: float = radial.normalized().dot(source_direction)
		var band: float = .0
		if alignment > .28: band = .095
		elif alignment < -.28: band = -.095
		family_biases.append(band)
	for i in dab_tree.groups.size():
		var family_value := 0.0
		var role_value := 0.0
		if i < 15:
			family_value = family_biases[int(i/3)]
			role_value = .008 if i%3==0 else -.004
		else:
			# Leader stays near the crown-wide middle value so it does not become a beacon.
			var average := 0.0
			for value in family_biases: average += value
			family_value = average/5.0
			role_value = .006
		_family_values.append(family_value)
		_role_values.append(role_value)
		var group: Node3D = dab_tree.groups[i]
		var candidate: ShaderMaterial = _value_materials[i]
		candidate.set_shader_parameter("family_value", family_value)
		candidate.set_shader_parameter("role_value", role_value)
		group.foliage.material_override = candidate if values_enabled else _baseline_materials[i]

func value_state() -> Dictionary:
	return {"enabled":values_enabled,"family":_family_values,"role":_role_values,"lighting":lighting}
