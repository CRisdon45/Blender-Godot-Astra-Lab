extends "res://presentation/northstar/spatial_material_study.gd"

const DabTree=preload("res://presentation/northstar/foliage/profiled_batched_dab_tree.gd")
const BrushTree=preload("res://presentation/northstar/foliage/profiled_batched_brush_tree.gd")
const Profiles=preload("res://presentation/northstar/foliage/plant_form_profiles.gd")
const ShrubProfiles=preload("res://presentation/northstar/foliage/shrub_form_profile.gd")

var tree_brush:Node3D
var shrub_dab:Node3D
var shrub_brush:Node3D
var shrub_record:Dictionary={}
var shrub_profile:Dictionary={}
var display_mode:="both"

func _build()->void:
	super._build()
	for child in derived.get_children():
		if child.name=="tree-trunk" or str(child.name).begins_with("crown-"):child.visible=false
	shrub_record={
		"id":"shrub-01",
		"x":8.20,
		"y":5.35,
		"base_elevation":float(document.bed.elevation),
		"height":1.20,
		"crown_radius":.86,
		"seed":16411
	}
	shrub_profile=ShrubProfiles.dense_desert_mound_v1()
	tree_brush=BrushTree.new();tree_brush.name="RetainedFanTexBrush";tree_brush.configure(document.tree,Profiles.fan_tex_ash_v2());derived.add_child(tree_brush)
	shrub_dab=DabTree.new();shrub_dab.name="ShrubDabBaseline";shrub_dab.configure(shrub_record,shrub_profile);derived.add_child(shrub_dab)
	shrub_brush=BrushTree.new();shrub_brush.name="ShrubRetainedBrush";shrub_brush.configure(shrub_record,shrub_profile);derived.add_child(shrub_brush)
	_apply_light_values();set_display_mode("both")

func set_display_mode(value:String)->void:
	assert(value in ["tree","shrub_dab","shrub_brush","both"])
	display_mode=value
	if is_instance_valid(tree_brush):tree_brush.visible=value=="tree" or value=="both"
	if is_instance_valid(shrub_dab):shrub_dab.visible=value=="shrub_dab"
	if is_instance_valid(shrub_brush):shrub_brush.visible=value=="shrub_brush" or value=="both"

func _set_light(value:String)->void:
	super._set_light(value);_apply_light_values()

func _apply_light_values()->void:
	var direction:=Vector2(sun.global_basis.z.x,sun.global_basis.z.z)
	if direction.length_squared()<1e-8:direction=Vector2(0,-1)
	direction=direction.normalized()
	if is_instance_valid(tree_brush):tree_brush.set_light_values(direction)
	if is_instance_valid(shrub_dab):shrub_dab.set_light_values(direction)
	if is_instance_valid(shrub_brush):shrub_brush.set_light_values(direction)

func _ui()->void:
	super._ui()
	for layer in get_children():
		if layer is CanvasLayer:
			for child in layer.get_children():
				if child is Label and child.text.begins_with("MATERIAL TRANSFER"):
					child.text="SHRUB GENERALITY / exact retained brush v4 / separate shrub record + profile / art and tablet acceptance unproven"
