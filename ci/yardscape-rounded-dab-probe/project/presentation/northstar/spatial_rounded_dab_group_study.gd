extends "res://presentation/northstar/spatial_dab_group_study.gd"
const RoundedGroup = preload("res://presentation/northstar/foliage/rounded_dab_group.gd")
var rounded_group: Node3D
func _build() -> void:
	super._build()
	group.visible=false
	var t:Dictionary=document.tree
	rounded_group=RoundedGroup.new();rounded_group.name="RoundedDabFoliageGroup"
	rounded_group.configure(int(t.seed),t.crown_radius*.54,t.height*.30)
	rounded_group.position=group.position
	derived.add_child(rounded_group)
func _ui() -> void:
	super._ui()
	for layer in get_children():
		if layer is CanvasLayer:
			for child in layer.get_children():
				if child is Label and child.text.begins_with("DAB FOLIAGE GROUP"):
					child.text="ROUNDED DAB GROUP / same 24 marks, two staggered rings / component-only test"
