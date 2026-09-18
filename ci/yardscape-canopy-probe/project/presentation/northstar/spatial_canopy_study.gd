extends "res://presentation/northstar/spatial_material_study.gd"
## One generic canopy in the existing courtyard; no change to model authority.
const CanopyForm = preload("res://presentation/northstar/canopy/illustrative_tree.gd")
var canopy_enabled:=true
var illustrative_tree: Node3D
var canopy_button: Button

func _build() -> void:
	super._build()
	illustrative_tree=CanopyForm.new();illustrative_tree.name="IllustrativeTree"
	illustrative_tree.configure(document.tree)
	derived.add_child(illustrative_tree)
	_apply_canopy()

func _apply_canopy() -> void:
	for child in derived.get_children():
		if child.name=="tree-trunk" or str(child.name).begins_with("crown-"):
			child.visible=not canopy_enabled
	if is_instance_valid(illustrative_tree):illustrative_tree.visible=canopy_enabled
	if is_instance_valid(canopy_button):canopy_button.text="Canopy ON" if canopy_enabled else "Canopy OFF"

func set_canopy_enabled(value: bool) -> void:
	canopy_enabled=value;_apply_canopy()

func _ui() -> void:
	super._ui()
	canopy_button=Button.new();canopy_button.text="Canopy ON" if canopy_enabled else "Canopy OFF"
	canopy_button.focus_mode=Control.FOCUS_NONE
	canopy_button.pressed.connect(_choose.bind("Canopy"))
	buttons["Plan"].get_parent().add_child(canopy_button)
	buttons["Canopy"]=canopy_button

func _choose(action: String) -> void:
	if action=="Canopy":set_canopy_enabled(not canopy_enabled);return
	super._choose(action)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_T:
		set_canopy_enabled(not canopy_enabled);get_viewport().set_input_as_handled();return
	super._unhandled_input(event)
