extends "res://presentation/northstar/spatial_material_study.gd"
const InterleavedTree = preload("res://presentation/northstar/shoot/interleaved_tree.gd")
var shoot_tree_enabled:=true
var interleaved_tree: Node3D

func _build() -> void:
	super._build()
	interleaved_tree=InterleavedTree.new()
	interleaved_tree.name="InterleavedShootTree"
	interleaved_tree.configure(document.tree)
	derived.add_child(interleaved_tree)
	_apply_tree_visibility()

func _apply_tree_visibility() -> void:
	for child in derived.get_children():
		if child.name=="tree-trunk" or str(child.name).begins_with("crown-"):
			child.visible=not shoot_tree_enabled
	if is_instance_valid(interleaved_tree):interleaved_tree.visible=shoot_tree_enabled

func set_tree_enabled(value: bool) -> void:
	shoot_tree_enabled=value;_apply_tree_visibility()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_T:
		set_tree_enabled(not shoot_tree_enabled)
		get_viewport().set_input_as_handled();return
	super._unhandled_input(event)
