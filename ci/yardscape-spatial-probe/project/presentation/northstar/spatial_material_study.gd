extends "res://presentation/northstar/spatial_study.gd"
## Opt-in material transfer over the retained shared spatial courtyard.
## Original model, meshes, camera/edit/undo/save paths remain in the base study.
const PavingPaint = preload("res://presentation/northstar/spatial_materials/paving.gdshader")
const BasinPaint = preload("res://presentation/northstar/spatial_materials/basin.gdshader")
const WaterPaint = preload("res://presentation/northstar/spatial_materials/water_surface.gdshader")
var materials_enabled := true
var water_paint_enabled := true
var paving_paint_enabled := true
var _original_materials: Dictionary = {}
var _style_materials: Dictionary = {}
var style_button: Button

func _build() -> void:
	super._build()
	_original_materials.clear()
	for node in derived.get_children():
		if node is MeshInstance3D:
			_original_materials[str(node.name)] = node.material_override
	_apply_materials()

func _apply_materials() -> void:
	if not is_instance_valid(derived): return
	for node in derived.get_children():
		if not node is MeshInstance3D: continue
		var id := str(node.name)
		var stone := id.begins_with("deck-") or id.begins_with("coping-")
		var basin := id in ["pool-floor","pool-shelf","wall-west","wall-east","wall-south","wall-north"]
		var surface := id == "Water"
		if not stone and not basin and not surface: continue
		if not _style_materials.has(id):
			var paint := ShaderMaterial.new()
			paint.shader = PavingPaint if stone else WaterPaint if surface else BasinPaint
			_style_materials[id] = paint
		var paint: ShaderMaterial = _style_materials[id]
		if stone:
			paint.set_shader_parameter("coping",id.begins_with("coping-"))
			paint.set_shader_parameter("half_size",Vector2(node.mesh.size.x,node.mesh.size.z)*.5)
		elif basin:
			paint.set_shader_parameter("water_level",float(document.pool.water_elevation))
		var active := materials_enabled and (paving_paint_enabled if stone else water_paint_enabled)
		node.material_override = paint if active else _original_materials[id]
	if is_instance_valid(style_button): style_button.text = "Materials ON" if materials_enabled else "Materials OFF"

func set_materials_enabled(value: bool) -> void:
	materials_enabled = value
	_apply_materials()

func set_material_groups(water_value: bool, paving_value: bool) -> void:
	water_paint_enabled = water_value
	paving_paint_enabled = paving_value
	_apply_materials()

func _ui() -> void:
	super._ui()
	style_button = Button.new()
	style_button.text = "Materials ON" if materials_enabled else "Materials OFF"
	style_button.focus_mode = Control.FOCUS_NONE
	style_button.pressed.connect(_choose.bind("Materials"))
	buttons["Plan"].get_parent().add_child(style_button)
	buttons["Materials"] = style_button
	# Keep the evidence boundary visible in the actual viewer.
	for layer in get_children():
		if layer is CanvasLayer:
			for child in layer.get_children():
				if child is Label and child.text.begins_with("STRUCTURE ONLY"):
					child.text = "MATERIAL TRANSFER / 3D water + paving / proxy plants / tablet and Northstar acceptance unproven"

func _choose(action: String) -> void:
	if action == "Materials":
		set_materials_enabled(not materials_enabled)
		return
	super._choose(action)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		set_materials_enabled(not materials_enabled)
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)
