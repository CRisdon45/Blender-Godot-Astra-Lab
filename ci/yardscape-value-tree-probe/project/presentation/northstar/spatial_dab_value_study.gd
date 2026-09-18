extends "res://presentation/northstar/spatial_material_study.gd"
const ValueTree = preload("res://presentation/northstar/foliage/dab_value_tree.gd")
var value_tree: Node3D
func _build() -> void:
	super._build()
	for child in derived.get_children():
		if child.name=="tree-trunk" or str(child.name).begins_with("crown-"):
			child.visible=false
	value_tree=ValueTree.new();value_tree.name="DabValueTree";value_tree.configure(document.tree);derived.add_child(value_tree)
func _ui() -> void:
	super._ui()
	for layer in get_children():
		if layer is CanvasLayer:
			for child in layer.get_children():
				if child is Label and child.text.begins_with("MATERIAL TRANSFER"):
					child.text="DAB VALUE TREE / same geometry + hierarchy-coherent pigment values / generic test"
