extends "res://presentation/northstar/spatial_dab_value_study.gd"
const BatchedTree = preload("res://presentation/northstar/foliage/batched_dab_tree.gd")
var batched_tree:Node3D
var batch_enabled:=true

func _build()->void:
	super._build()
	dab_tree.visible=false
	batched_tree=BatchedTree.new();batched_tree.name="BatchedDabTree";batched_tree.configure(document.tree);derived.add_child(batched_tree)
	_apply_batch_light()
	_apply_batch_visibility()

func _set_light(value:String)->void:
	super._set_light(value)
	_apply_batch_light()

func set_batch_enabled(value:bool)->void:
	batch_enabled=value
	_apply_batch_visibility()

func _apply_batch_visibility()->void:
	if is_instance_valid(dab_tree):dab_tree.visible=not batch_enabled
	if is_instance_valid(batched_tree):batched_tree.visible=batch_enabled

func _apply_batch_light()->void:
	if not is_instance_valid(batched_tree):return
	var direction:=Vector2(sun.global_basis.z.x,sun.global_basis.z.z)
	if direction.length_squared()<1e-8:direction=Vector2(0,-1)
	direction=direction.normalized()
	var sum:=0.0
	var angles:PackedFloat32Array=batched_tree.family_angles()
	for angle in angles:
		var alignment:=Vector2(cos(angle),sin(angle)).dot(direction)
		if alignment>.28:sum+=.095
		elif alignment<-.28:sum-=.095
	batched_tree.set_light_values(direction,sum/5.0)
