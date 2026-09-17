extends "res://presentation/northstar/spatial_material_study.gd"
const MixedGroup = preload("res://presentation/northstar/foliage/mixed_group.gd")
var group: Node3D
func _build() -> void:
	super._build()
	for child in derived.get_children():
		if child.name=="tree-trunk" or str(child.name).begins_with("crown-"):child.visible=false
	group=MixedGroup.new();group.name="MixedFoliageGroup"
	var t:Dictionary=document.tree
	group.configure(int(t.seed),t.crown_radius*.54,t.height*.30)
	group.position=Vector3(t.x,t.base_elevation+t.height*.72,-t.y)
	derived.add_child(group)
func _ui() -> void:
	super._ui()
	for layer in get_children():
		if layer is CanvasLayer:
			for child in layer.get_children():
				if child is Label and child.text.begins_with("MATERIAL TRANSFER"):
					child.text="MIXED FOLIAGE GROUP / small volumes + selective accents / generic test"
