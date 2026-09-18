extends "res://presentation/northstar/spatial_material_study.gd"

const BrushTree=preload("res://presentation/northstar/foliage/profiled_batched_brush_tree.gd")
const VolumeTree=preload("res://presentation/northstar/foliage/profiled_batched_wash_tree.gd")
const Profiles=preload("res://presentation/northstar/foliage/plant_form_profiles.gd")

var brush_tree:Node3D
var volume_tree:Node3D
var active_profile:Dictionary={}
var volume_enabled:=true

func _build()->void:
	super._build()
	for child in derived.get_children():
		if child.name=="tree-trunk" or str(child.name).begins_with("crown-"):child.visible=false
	set_profile(Profiles.fan_tex_ash_v2())

func set_profile(value:Dictionary)->void:
	active_profile=value.duplicate(true)
	if is_instance_valid(brush_tree):brush_tree.free()
	if is_instance_valid(volume_tree):volume_tree.free()
	brush_tree=BrushTree.new();brush_tree.name="RetainedBrushTree";brush_tree.configure(document.tree,active_profile);derived.add_child(brush_tree)
	volume_tree=VolumeTree.new();volume_tree.name="WashVolumeTree";volume_tree.configure(document.tree,active_profile);derived.add_child(volume_tree)
	_apply_light_values();_apply_visibility()

func set_volume_enabled(value:bool)->void:
	volume_enabled=value;_apply_visibility()

func _set_light(value:String)->void:
	super._set_light(value);_apply_light_values()

func _apply_visibility()->void:
	if is_instance_valid(brush_tree):brush_tree.visible=not volume_enabled
	if is_instance_valid(volume_tree):volume_tree.visible=volume_enabled

func _apply_light_values()->void:
	var direction:=Vector2(sun.global_basis.z.x,sun.global_basis.z.z)
	if direction.length_squared()<1e-8:direction=Vector2(0,-1)
	direction=direction.normalized()
	if is_instance_valid(brush_tree):brush_tree.set_light_values(direction)
	if is_instance_valid(volume_tree):volume_tree.set_light_values(direction)

func _ui()->void:
	super._ui()
	for layer in get_children():
		if layer is CanvasLayer:
			for child in layer.get_children():
				if child is Label and child.text.begins_with("MATERIAL TRANSFER"):
					child.text="3D WASH VOLUMES / shared profile + layout / opaque two-mesh challenger / visual and tablet acceptance unproven"
