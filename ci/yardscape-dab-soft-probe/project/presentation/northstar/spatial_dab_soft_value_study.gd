extends "res://presentation/northstar/spatial_dab_value_study.gd"
## Fixed-geometry comparison: preserve hierarchy values and real shadows while
## compressing normal-driven diffuse variation on the small 3D dab faces.
const BaselinePaint = preload("res://presentation/northstar/foliage/dab_value.gdshader")
const SoftPaint = preload("res://presentation/northstar/foliage/dab_value_soft.gdshader")
var soft_diffuse_enabled := true

func _build() -> void:
	super._build()
	_apply_soft_diffuse()

func set_soft_diffuse_enabled(value: bool) -> void:
	soft_diffuse_enabled = value
	_apply_soft_diffuse()

func _apply_soft_diffuse() -> void:
	if _value_materials.size() != dab_tree.groups.size(): return
	for material in _value_materials:
		material.shader = SoftPaint if soft_diffuse_enabled else BaselinePaint
	_apply_value_materials()

func soft_state() -> Dictionary:
	return {"enabled":soft_diffuse_enabled,"values":value_state()}
