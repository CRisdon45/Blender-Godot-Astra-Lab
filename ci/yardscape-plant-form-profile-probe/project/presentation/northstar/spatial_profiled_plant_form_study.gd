extends "res://presentation/northstar/spatial_material_study.gd"
const ReferenceTree=preload("res://presentation/northstar/foliage/fantex_ash_batched_tree.gd")
const ProfiledTree=preload("res://presentation/northstar/foliage/profiled_batched_dab_tree.gd")
const Profiles=preload("res://presentation/northstar/foliage/plant_form_profiles.gd")
var reference_tree:Node3D
var profiled_tree:Node3D
var profiled_enabled:=true

func _build()->void:
	super._build()
	for child in derived.get_children():
		if child.name=="tree-trunk" or str(child.name).begins_with("crown-"):child.visible=false
	reference_tree=ReferenceTree.new();reference_tree.name="HardCodedFanTex";reference_tree.configure(document.tree);derived.add_child(reference_tree)
	profiled_tree=ProfiledTree.new();profiled_tree.name="ProfiledFanTex";profiled_tree.configure(document.tree,Profiles.fan_tex_ash_v2());derived.add_child(profiled_tree)
	_apply_light_values();_apply_visibility()

func _set_light(value:String)->void:
	super._set_light(value);_apply_light_values()

func set_profiled_enabled(value:bool)->void:
	profiled_enabled=value;_apply_visibility()

func _apply_visibility()->void:
	if is_instance_valid(reference_tree):reference_tree.visible=not profiled_enabled
	if is_instance_valid(profiled_tree):profiled_tree.visible=profiled_enabled

func _apply_light_values()->void:
	var direction:=Vector2(sun.global_basis.z.x,sun.global_basis.z.z)
	if direction.length_squared()<1e-8:direction=Vector2(0,-1)
	direction=direction.normalized()
	if is_instance_valid(reference_tree):reference_tree.set_light_values(direction)
	if is_instance_valid(profiled_tree):profiled_tree.set_light_values(direction)

func _ui()->void:
	super._ui()
	for layer in get_children():
		if layer is CanvasLayer:
			for child in layer.get_children():
				if child is Label and child.text.begins_with("MATERIAL TRANSFER"):
					child.text="PLANT FORM PROFILE / exact Fan-Tex v2 reproduction through generic two-mesh builder"
