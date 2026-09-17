extends "res://presentation/northstar/foliage/dab_tree.gd"
## Same dab geometry and group transforms; only the foliage pigment organization changes.
const ValuePaint = preload("res://presentation/northstar/foliage/dab_value.gdshader")
const VALUE_RECIPE := "dab-group-tree-values/1"
var value_targets: PackedFloat32Array = PackedFloat32Array()

func configure(t:Dictionary)->void:
	super.configure(t)
	var anchors:Array[Dictionary]=_anchors(t)
	var minimum_value:float=INF
	var maximum_value:float=-INF
	for i in groups.size():
		var anchor:Dictionary=anchors[i]
		var height_band:float=clampf((float(anchor.position.y)-.60)/.30,0.,1.)
		var role_adjust:float=.0
		if anchor.role=="primary":role_adjust=.015
		elif anchor.role=="secondary":role_adjust=-.015
		else:role_adjust=.04
		var target:float=clampf(.46+.12*height_band+role_adjust,.40,.64)
		value_targets.append(target)
		minimum_value=minf(minimum_value,target)
		maximum_value=maxf(maximum_value,target)
		var material:=ShaderMaterial.new()
		material.shader=ValuePaint
		material.set_shader_parameter("group_value",target)
		material.set_shader_parameter("group_mix",.72)
		material.set_shader_parameter("group_phase",float(i)*1.37)
		groups[i].foliage.material_override=material
	stats["recipe"]=VALUE_RECIPE
	stats["value_grouping"]=true
	stats["value_min"]=minimum_value
	stats["value_max"]=maximum_value

func pigment_signature()->String:
	return var_to_bytes(value_targets).hex_encode().sha256_text()
