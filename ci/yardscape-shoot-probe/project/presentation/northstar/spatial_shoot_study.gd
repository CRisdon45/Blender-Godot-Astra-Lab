extends "res://presentation/northstar/spatial_material_study.gd"
const CompactShoot = preload("res://presentation/northstar/shoot/compact_shoot.gd")
var shoot_enabled := true
var compact_shoot: Node3D

func _build() -> void:
	super._build()
	var t: Dictionary = document.tree
	compact_shoot = CompactShoot.new()
	compact_shoot.name = "CompactShootWitness"
	compact_shoot.configure(t)
	# One authored witness at the retained tree location; not a whole crown.
	compact_shoot.position = Vector3(t.x - .03*t.crown_radius, t.base_elevation + .46*t.height, -t.y + .02*t.crown_radius)
	compact_shoot.rotation = Vector3(-.08,.72,-.22)
	derived.add_child(compact_shoot)
	_apply_shoot_visibility()

func _apply_shoot_visibility() -> void:
	for child in derived.get_children():
		if str(child.name).begins_with("crown-"):
			child.visible = not shoot_enabled
	if is_instance_valid(compact_shoot): compact_shoot.visible = shoot_enabled

func set_shoot_enabled(value: bool) -> void:
	shoot_enabled = value
	_apply_shoot_visibility()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T:
		set_shoot_enabled(not shoot_enabled)
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)
