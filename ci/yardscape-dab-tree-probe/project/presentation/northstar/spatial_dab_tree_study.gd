extends "res://presentation/northstar/spatial_material_study.gd"
const DabTree = preload("res://presentation/northstar/foliage/dab_tree.gd")
var dab_tree: Node3D
func _build() -> void:
	super._build()
	for child in derived.get_children():
		if child.name=="tree-trunk" or str(child.name).begins_with("crown-"):
			child.visible=false
	dab_tree=DabTree.new();dab_tree.name="DabTree";dab_tree.configure(document.tree);derived.add_child(dab_tree)
func _ui() -> void:
	super._ui()
	for layer in get_children():
		if layer is CanvasLayer:
			for child in layer.get_children():
				if child is Label and child.text.begins_with("MATERIAL TRANSFER"):
					child.text="DAB GROUP TREE / hierarchy-aware low-poly marks / generic whole-tree test"
