extends Node3D
## PUBLIC DISPLAY ADAPTER of spatial_study. No persistence or app editing.
const Model = preload("res://presentation/northstar/spatial_fixture.gd")
var document: Dictionary
var draft_file := ""
var loaded_from_disk := false
var study_ready := false
var build_count := 0
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
var derived: Node3D
var camera: Camera3D
var sun: DirectionalLight3D
var lamp: OmniLight3D
var environment: Environment
var buttons: Dictionary = {}
var caption: Label
var plan_locked := true
var perspective := false
var lighting := "Morning"
var target := Vector3(5.0, 0.0, -7.5)
var plan_size := 20.0
var yaw := 0.55
var pitch := 0.85
var distance := 22.0
var saved_plan: Dictionary = {}
var orbit_target := Vector3(5.0, 0.0, -7.0)
var orbit_perspective := false
var show_water := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	document = Model.fresh()
	var world_environment := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("e8e5dc")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e4ecf0")
	environment.ambient_light_energy = 0.3
	world_environment.environment = environment
	add_child(world_environment)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(sun)
	lamp = OmniLight3D.new()
	lamp.omni_range = 8.0
	lamp.shadow_enabled = true
	lamp.light_color = Color("ffd69c")
	add_child(lamp)
	camera = Camera3D.new()
	camera.near = 0.1
	camera.far = 100.0
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.fov = 46.0
	add_child(camera)
	camera.make_current()
	_build()
	_ui()
	_set_light("Morning")
	_update_camera()
	for action in ["Narrower", "Wider", "Undo", "Redo"]: buttons[action].disabled = true
	study_ready = true

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material

func _box(id: String, x: float, y: float, width: float, length: float, bottom: float, top: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = id
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, top - bottom, length)
	node.mesh = mesh
	node.material_override = _material(color)
	node.position = Vector3(x + width * 0.5, (top + bottom) * 0.5, -(y + length * 0.5))
	derived.add_child(node)
	return node

func _build() -> void:
	if is_instance_valid(derived):
		remove_child(derived)
		derived.queue_free()
	derived = Node3D.new()
	derived.name = "DerivedCourtyard"
	add_child(derived)
	build_count += 1
	var p: Dictionary = document.pool
	var w: float = p.width
	var deck: float = document.deck.elevation
	var paving := Color("d7c6a6")
	# Four rectangles leave a real opening. The bottom is never a blue top decal.
	_box("deck-south", 0, 0, 10, p.y, -0.2, deck, paving)
	_box("deck-north", 0, p.y + p.length, 10, 14 - p.y - p.length, -0.2, deck, paving)
	_box("deck-west", 0, p.y, p.x, p.length, -0.2, deck, paving)
	_box("deck-east", p.x + w, p.y, 10 - p.x - w, p.length, -0.2, deck, paving)
	_box("pool-floor", p.x, p.y, w, p.length, -1.65, p.floor_elevation, Color("84afb2"))
	_box("pool-shelf", p.x, p.y, w, p.shelf_length, p.floor_elevation, p.shelf_elevation, Color("b5d4d0"))
	var wall := Color("c5d9d0")
	_box("wall-west", p.x - 0.15, p.y, 0.15, p.length, p.floor_elevation, deck, wall)
	_box("wall-east", p.x + w, p.y, 0.15, p.length, p.floor_elevation, deck, wall)
	_box("wall-south", p.x, p.y - 0.15, w, 0.15, p.floor_elevation, deck, wall)
	_box("wall-north", p.x, p.y + p.length, w, 0.15, p.floor_elevation, deck, wall)
	var c: float = p.coping_width
	var coping := Color("eee4cd")
	_box("coping-west", p.x - c, p.y - c, c, p.length + c * 2, deck, deck + 0.08, coping)
	_box("coping-east", p.x + w, p.y - c, c, p.length + c * 2, deck, deck + 0.08, coping)
	_box("coping-south", p.x, p.y - c, w, c, deck, deck + 0.08, coping)
	_box("coping-north", p.x, p.y + p.length, w, c, deck, deck + 0.08, coping)
	var water := MeshInstance3D.new()
	water.name = "Water"
	var surface := PlaneMesh.new()
	surface.size = Vector2(w, p.length)
	water.mesh = surface
	water.position = Vector3(p.x + w * 0.5, p.water_elevation, -(p.y + p.length * 0.5))
	var water_material := _material(Color(0.16, 0.60, 0.64, 0.28))
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	water.material_override = water_material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.visible = show_water
	derived.add_child(water)
	_box("lawn", 0.5, 0.5, 9, 2.5, deck, deck + 0.025, Color("a9b976"))
	var b: Dictionary = document.bed
	_box("bed", b.x, b.y, b.width, b.length, deck, b.elevation, Color("635c45"))
	_box("bed-rim", b.x - 0.1, b.y, 0.1, b.length, deck, b.elevation + 0.08, coping)
	# Crown clusters are structural proxies, not species or Northstar symbols.
	var t: Dictionary = document.tree
	var trunk := MeshInstance3D.new()
	trunk.name = "tree-trunk"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.12
	cylinder.bottom_radius = 0.18
	cylinder.height = t.height - 0.5
	trunk.mesh = cylinder
	trunk.material_override = _material(Color("62513d"))
	trunk.position = Vector3(t.x, t.base_elevation + cylinder.height * 0.5, -t.y)
	derived.add_child(trunk)
	var random := RandomNumberGenerator.new()
	random.seed = int(t.seed)
	for index in range(7):
		var crown := MeshInstance3D.new()
		crown.name = "crown-%02d" % index
		var sphere := SphereMesh.new()
		sphere.radius = t.crown_radius * (0.62 if index > 0 else 0.8)
		sphere.height = sphere.radius * 1.7
		crown.mesh = sphere
		var angle := index * TAU / 6.0
		var offset := 0.0 if index == 0 else 0.65
		crown.position = Vector3(t.x + cos(angle) * offset, t.base_elevation + t.height - sphere.height * 0.5 + random.randf_range(-0.12, 0.12), -t.y + sin(angle) * offset)
		crown.material_override = _material(Color("657d4b").lightened(random.randf_range(0, 0.12)))
		derived.add_child(crown)
	var f: Dictionary = document.lamp
	_box("lamp-post", f.x - 0.035, f.y - 0.035, 0.07, 0.07, deck, f.elevation, Color("434849"))
	_box("lamp-head", f.x - 0.12, f.y - 0.12, 0.24, 0.24, f.elevation, f.elevation + 0.08, Color("e6c68f"))
	lamp.position = Vector3(f.x, f.elevation - 0.12, -f.y)
	# A finite raised wall provides a clear day/night occlusion witness.
	_box("boundary-wall", 0, 13.8, 10, 0.2, deck, 1.1, Color("c5baa3"))

func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	layer.add_child(panel)
	var rows := VBoxContainer.new()
	panel.add_child(rows)
	var title := Label.new()
	title.text = "  COURTYARD / Spatial study — camera, shared dimensions and light"
	rows.add_child(title)
	var row := HBoxContainer.new()
	rows.add_child(row)
	for title_text in ["Plan", "Orbit", "Perspective", "Morning", "Afternoon", "Night", "Water", "Narrower", "Wider", "Undo", "Redo"]:
		var control := Button.new()
		control.text = title_text
		control.focus_mode = Control.FOCUS_NONE
		control.pressed.connect(_choose.bind(title_text))
		row.add_child(control)
		buttons[title_text] = control
	caption = Label.new()
	rows.add_child(caption)
	var hint := Label.new()
	hint.text = "  Plan: drag to pan · Orbit: drag to rotate · Right / middle drag to pan · Wheel to zoom"
	rows.add_child(hint)
	var footer := Label.new()
	layer.add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	footer.position = Vector2(18, get_viewport().get_visible_rect().size.y - 32)
	footer.text = "STRUCTURE ONLY  /  Northstar watercolor and planting fidelity remain unproven"

func _choose(action: String) -> void:
	match action:
		"Plan":
			if not plan_locked:
				orbit_target = target
				orbit_perspective = perspective
				target = saved_plan.target
				plan_size = saved_plan.size
			plan_locked = true
			perspective = false
		"Orbit":
			if plan_locked:
				saved_plan = {"target": target, "size": plan_size}
				target = orbit_target
				perspective = orbit_perspective
			plan_locked = false
		"Perspective":
			if not plan_locked: perspective = not perspective
		"Morning", "Afternoon", "Night": _set_light(action)
		"Water":
			show_water = not show_water
			derived.get_node("Water").visible = show_water
		"Narrower", "Wider", "Undo", "Redo":
			return # Public display adapter does not expose private edit commands.
	_update_camera()

func _set_light(value: String) -> void:
	lighting = value
	var night := value == "Night"
	sun.visible = not night
	lamp.visible = night
	lamp.light_energy = 2.4
	environment.ambient_light_energy = 0.10 if night else 0.3
	environment.background_color = Color("262d35") if night else Color("e8e5dc")
	var angles: Array = document.sun.afternoon if value == "Afternoon" else document.sun.morning
	sun.rotation_degrees = Vector3(angles[0], angles[1], angles[2])
	sun.light_energy = 0.6

func _update_camera() -> void:
	if plan_locked:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = plan_size
		camera.position = target + Vector3.UP * 26.0
		camera.look_at(target, Vector3(0, 0, -1))
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE if perspective else Camera3D.PROJECTION_ORTHOGONAL
		# Match framing at the target plane when toggling projection.
		camera.size = 2.0 * distance * tan(deg_to_rad(camera.fov) * 0.5)
		camera.position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
		camera.look_at(target, Vector3.UP)
	_update_caption()

func _update_caption() -> void:
	if not is_instance_valid(caption): return
	caption.text = "  %s · %s · Pool %.2f × %.2f m · Shelf 0.35 m / basin 1.50 m deep · %s" % ["Plan locked" if plan_locked else "Orbit", "Perspective" if perspective else "Orthographic", document.pool.width, document.pool.length, lighting]
	buttons.Perspective.disabled = plan_locked
	buttons.Undo.disabled = undo_stack.is_empty()
	buttons.Redo.disabled = redo_stack.is_empty()
	buttons.Narrower.disabled = true # Read-only public adapter
	buttons.Wider.disabled = true # Read-only public adapter

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if event.button_mask & (MOUSE_BUTTON_MASK_MIDDLE | MOUSE_BUTTON_MASK_RIGHT) or (plan_locked and event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			var scale_per_pixel := camera.size / get_viewport().get_visible_rect().size.y
			var right := camera.global_basis.x
			var forward := Vector3(right.z, 0, -right.x)
			target += (-right * event.relative.x + forward * event.relative.y) * scale_per_pixel
			_update_camera()
		elif not plan_locked and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			yaw -= event.relative.x * 0.008
			pitch = clampf(pitch + event.relative.y * 0.006, 0.15, 1.50)
			_update_camera()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var factor := 0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 0.9
			if plan_locked: plan_size = clampf(plan_size * factor, 5.0, 35.0)
			else: distance = clampf(distance * factor, 8.0, 45.0)
			_update_camera()

