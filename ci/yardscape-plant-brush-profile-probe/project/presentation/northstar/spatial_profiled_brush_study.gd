extends "res://presentation/northstar/spatial_material_study.gd"
const DabTree=preload("res://presentation/northstar/foliage/profiled_batched_dab_tree.gd")
const BrushTree=preload("res://presentation/northstar/foliage/profiled_batched_brush_tree.gd")
const Profiles=preload("res://presentation/northstar/foliage/plant_form_profiles.gd")
const SHADOW_STYLE := "northstar-light-shadow-wash/1"
const SHADOW_OPACITY := .42
var dab_tree:Node3D
var brush_tree:Node3D
var active_profile:Dictionary={}
var brush_enabled:=true

func _build()->void:
	super._build()
	# The reference treats cast vegetation shadow as a subordinate wash. Keep
	# the real sun vector and shadow geometry, but prevent cutout cards from
	# becoming the highest-contrast marks in the composition.
	sun.shadow_opacity=SHADOW_OPACITY
	for child in derived.get_children():
		if child.name=="tree-trunk" or str(child.name).begins_with("crown-"):child.visible=false
	set_profile(Profiles.fan_tex_ash_v2())

func set_profile(value:Dictionary)->void:
	active_profile=value.duplicate(true)
	if is_instance_valid(dab_tree):dab_tree.free()
	if is_instance_valid(brush_tree):brush_tree.free()
	dab_tree=DabTree.new();dab_tree.name="RetainedDabTree";dab_tree.configure(document.tree,active_profile);derived.add_child(dab_tree)
	brush_tree=BrushTree.new();brush_tree.name="OpaqueBrushTree";brush_tree.configure(document.tree,active_profile);derived.add_child(brush_tree)
	_apply_light_values();_apply_visibility()

func set_brush_enabled(value:bool)->void:
	brush_enabled=value;_apply_visibility()

func _set_light(value:String)->void:
	super._set_light(value);_apply_light_values()

func _apply_visibility()->void:
	if is_instance_valid(dab_tree):dab_tree.visible=not brush_enabled
	if is_instance_valid(brush_tree):brush_tree.visible=brush_enabled

func _apply_light_values()->void:
	var direction:=Vector2(sun.global_basis.z.x,sun.global_basis.z.z)
	if direction.length_squared()<1e-8:direction=Vector2(0,-1)
	direction=direction.normalized()
	if is_instance_valid(dab_tree):dab_tree.set_light_values(direction)
	if is_instance_valid(brush_tree):brush_tree.set_light_values(direction)

func _ui()->void:
	super._ui()
	for layer in get_children():
		if layer is CanvasLayer:
			for child in layer.get_children():
				if child is Label and child.text.begins_with("MATERIAL TRANSFER"):
					child.text="OPAQUE BRUSH CLOUD / shared profile + layout / two meshes / visual and tablet acceptance unproven"
