extends "res://presentation/northstar/spatial_material_study.gd"
## Whole-tree visual witness assembled from the accepted-for-testing compact group.
const CompactTree = preload("res://presentation/northstar/foliage/compact_tree.gd")
var compact_tree: Node3D

func _build() -> void:
	super._build()
	for child in derived.get_children():
		if child.name=="tree-trunk" or str(child.name).begins_with("crown-"):
			child.visible=false
	compact_tree=CompactTree.new();compact_tree.name="CompactTree"
	compact_tree.configure(document.tree)
	derived.add_child(compact_tree)

func _ui() -> void:
	super._ui()
	for layer in get_children():
		if layer is CanvasLayer:
			for child in layer.get_children():
				if child is Label and child.text.begins_with("MATERIAL TRANSFER"):
					child.text="COMPACT GROUP TREE / generic whole-tree visual witness / not species or production asset"
