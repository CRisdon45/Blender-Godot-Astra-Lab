extends "res://presentation/northstar/spatial_material_study.gd"
const ProfiledTree=preload("res://presentation/northstar/foliage/profiled_batched_dab_tree.gd")
const Profiles=preload("res://presentation/northstar/foliage/plant_form_profiles.gd")
var ash_tree:Node3D
var palo_tree:Node3D
var palo_enabled:=true

func _build()->void:
	super._build()
	for child in derived.get_children():
		if child.name=="tree-trunk" or str(child.name).begins_with("crown-"):child.visible=false
	ash_tree=ProfiledTree.new();ash_tree.name="ProfiledFanTex";ash_tree.configure(document.tree,Profiles.fan_tex_ash_v2());derived.add_child(ash_tree)
	palo_tree=ProfiledTree.new();palo_tree.name="ProfiledDesertMuseum";palo_tree.configure(document.tree,Profiles.desert_museum_palo_verde_v2());derived.add_child(palo_tree)
	_apply_light_values();_apply_visibility()

func _set_light(value:String)->void:
	super._set_light(value);_apply_light_values()

func set_palo_enabled(value:bool)->void:
	palo_enabled=value;_apply_visibility()

func _apply_visibility()->void:
	if is_instance_valid(ash_tree):ash_tree.visible=not palo_enabled
	if is_instance_valid(palo_tree):palo_tree.visible=palo_enabled

func _apply_light_values()->void:
	var direction:=Vector2(sun.global_basis.z.x,sun.global_basis.z.z)
	if direction.length_squared()<1e-8:direction=Vector2(0,-1)
	direction=direction.normalized()
	if is_instance_valid(ash_tree):ash_tree.set_light_values(direction)
	if is_instance_valid(palo_tree):palo_tree.set_light_values(direction)

func _ui()->void:
	super._ui()
	for layer in get_children():
		if layer is CanvasLayer:
			for child in layer.get_children():
				if child is Label and child.text.begins_with("MATERIAL TRANSFER"):
					child.text="SPECIES PROFILE CONTRAST / Fan-Tex dense-rounded vs Desert Museum airy-spreading / same builder"
