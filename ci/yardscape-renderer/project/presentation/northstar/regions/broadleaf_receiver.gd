extends "res://presentation/northstar/regions/broadleaf.gd"
## Same deterministic blade geometry; optional color-only receiving material.
const ReceivingPigment = preload("res://presentation/northstar/regions/broadleaf_shade.gdshader")
var _receiving_material: ShaderMaterial

func setup(value: Array, shadow_pass: bool = false) -> void:
	super.setup(value,shadow_pass)
	_receiving_material = null

func receiver_descriptor() -> Dictionary:
	# No lobe/disc opacity is supplied: this object can receive but not cast
	# through the crown context. Its existing blade-derived ground cast stays.
	return {"id":identifier,"at":Vector2(source_record[1],24.-source_record[2]),
		"radius":radius,"height":cast_height,"seed":0.,"family":2,
		"lobes":PackedVector4Array(),"receiver_only":true}

func apply_received_shade(data: Dictionary, enabled: bool) -> void:
	if shadow:return
	if _receiving_material == null:
		_receiving_material = ShaderMaterial.new()
		_receiving_material.shader = ReceivingPigment
		_receiving_material.set_shader_parameter("seed",float(absi(identifier.hash())%10000))
		_receiving_material.set_shader_parameter("receiver_radius",radius)
		material = _receiving_material
	_receiving_material.set_shader_parameter("paint_enabled",not technical)
	_receiving_material.set_shader_parameter("neighbor_count",data.count if enabled and not technical else 0)
	if not enabled or technical:return
	for key in ["cast","contact","meta","lobes"]:
		_receiving_material.set_shader_parameter("neighbor_"+key,data[key])
	# Uniform changes do not redraw/retriangulate/reseed the retained paint.
