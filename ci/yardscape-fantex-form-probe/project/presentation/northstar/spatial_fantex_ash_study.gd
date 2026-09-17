extends "res://presentation/northstar/spatial_material_study.gd"
const GenericTree=preload("res://presentation/northstar/foliage/batched_dab_tree.gd")
const FanTexTree=preload("res://presentation/northstar/foliage/fantex_ash_batched_tree.gd")
var generic_tree:Node3D
var fantex_tree:Node3D
var fantex_enabled:=true

func _build()->void:
	super._build()
	for child in derived.get_children():
		if child.name=="tree-trunk" or str(child.name).begins_with("crown-"):child.visible=false
	generic_tree=GenericTree.new();generic_tree.name="GenericBatchedTree";generic_tree.configure(document.tree);derived.add_child(generic_tree)
	fantex_tree=FanTexTree.new();fantex_tree.name="FanTexAshForm";fantex_tree.configure(document.tree);derived.add_child(fantex_tree)
	_apply_light_values();_apply_visibility()

func _set_light(value:String)->void:
	super._set_light(value);_apply_light_values()

func set_fantex_enabled(value:bool)->void:
	fantex_enabled=value;_apply_visibility()

func _apply_visibility()->void:
	if is_instance_valid(generic_tree):generic_tree.visible=not fantex_enabled
	if is_instance_valid(fantex_tree):fantex_tree.visible=fantex_enabled

func _apply_light_values()->void:
	var direction:=Vector2(sun.global_basis.z.x,sun.global_basis.z.z)
	if direction.length_squared()<1e-8:direction=Vector2(0,-1)
	direction=direction.normalized()
	if is_instance_valid(generic_tree):
		var sum:=0.0
		for angle in generic_tree.family_angles():
			var alignment:=Vector2(cos(angle),sin(angle)).dot(direction)
			if alignment>.28:sum+=.095
			elif alignment<-.28:sum-=.095
		generic_tree.set_light_values(direction,sum/5.0)
	if is_instance_valid(fantex_tree):fantex_tree.set_light_values(direction)

func _ui()->void:
	super._ui()
	for layer in get_children():
		if layer is CanvasLayer:
			for child in layer.get_children():
				if child is Label and child.text.begins_with("MATERIAL TRANSFER"):
					child.text="FAN-TEX ASH MACRO FORM / broad rounded crown + upright scaffold / no literal leaf detail"
