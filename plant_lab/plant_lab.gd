extends Node3D
## Deterministic baked-variant runtime. No claim of live biological simulation.
const FOLIAGE = preload("res://shaders/foliage.gdshader")
const WOOD = preload("res://shaders/wood.gdshader")
var manifest: Dictionary
var camera: Camera3D
var plant_root: Node3D
var hud: CanvasLayer
var status: Label
var records: Array = []
var mesh_cache: Dictionary = {}
var material_cache: Dictionary = {}
var mode: String = "pair"
var stage: int = 2
var bloom: float = 0.0
var litter: bool = false
var forced_lod: int = -1
var yaw: float = 0.54
var pitch: float = 0.22
var distance: float = 15.0
var focus := Vector3(0, 3.2, 0)
var lod_timer: float = 0.0
var capturing: bool = false
var errors: Array[String] = []

func _ready() -> void:
	var file := FileAccess.open("res://assets/manifest.json", FileAccess.READ)
	if file == null:
		push_error("Run the Blender species build first; manifest is missing.")
		get_tree().quit(2)
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		push_error("Invalid species manifest")
		get_tree().quit(2)
		return
	manifest = data
	_build_world()
	_build_hud()
	_rebuild()
	_update_camera()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			capturing = true
			hud.visible = false
			call_deferred("_capture_suite", arg.trim_prefix("--capture="))

func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.76, 0.86, 0.88)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.81, 0.72)
	env.ambient_light_energy = 0.60
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	add_child(sun)
	var light_direction := Vector3(-0.314, 0.743, 0.589).normalized()
	sun.look_at(-light_direction, Vector3.UP)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 35.0
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(100, 100)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.73, 0.68, 0.56)
	mat.roughness = 1.0
	ground.material_override = mat
	add_child(ground)
	camera = Camera3D.new()
	camera.near = 0.1
	camera.far = 150.0
	camera.fov = 48.0
	add_child(camera)
	camera.current = true

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	hud.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var heading := Label.new()
	heading.text = "SPECIES LAB | Android Mobile profile | art / device approval pending"
	box.add_child(heading)
	var row := HBoxContainer.new()
	box.add_child(row)
	for value in ["pair", "tree", "sage", "garden", "growth_tree", "growth_sage"]:
		var button := Button.new()
		button.text = String(value).capitalize().replace("_", " ")
		button.pressed.connect(_select_mode.bind(String(value)))
		row.add_child(button)
	var ages := HBoxContainer.new()
	box.add_child(ages)
	for index in range(3):
		var button := Button.new()
		button.text = ["Installed example", "Growing example", "Mature target"][index]
		button.pressed.connect(_select_stage.bind(index))
		ages.add_child(button)
	var seasons := HBoxContainer.new()
	box.add_child(seasons)
	var flower_button := Button.new()
	flower_button.text = "Toggle bloom pulse"
	flower_button.pressed.connect(_toggle_bloom)
	seasons.add_child(flower_button)
	var litter_button := Button.new()
	litter_button.text = "Toggle post-bloom litter example"
	litter_button.pressed.connect(_toggle_litter)
	seasons.add_child(litter_button)
	status = Label.new()
	box.add_child(status)
	var note := Label.new()
	note.text = "Drag to orbit. Wheel / pinch to zoom. Stages are NOT calibrated years. Texas sage cultivar unspecified."
	box.add_child(note)

func _select_mode(value: String) -> void:
	mode = value
	forced_lod = -1
	_rebuild()
	if mode == "sage":
		focus = Vector3(0, 0.9, 0); distance = 4.7
	elif mode == "garden":
		focus = Vector3(0, 2, 0); distance = 42; pitch = 0.40
	elif mode.begins_with("growth"):
		focus = Vector3(0, 2 if mode == "growth_tree" else 0.8, 0)
		distance = 26 if mode == "growth_tree" else 7.8
	else:
		focus = Vector3(0, 3.2, 0); distance = 15
	_update_camera()

func _select_stage(value: int) -> void:
	stage = value
	_rebuild()

func _toggle_bloom() -> void:
	bloom = 0.0 if bloom > 0.0 else 1.0
	for mat in material_cache.values():
		if mat.shader == FOLIAGE: mat.set_shader_parameter("bloom", bloom)
	_update_lods()

func _toggle_litter() -> void:
	litter = not litter
	_rebuild()

func _as_color(values: Array) -> Color:
	return Color(float(values[0]), float(values[1]), float(values[2]), 1.0)

func _material(species: String, component: String) -> ShaderMaterial:
	var key := species + ":" + component
	if material_cache.has(key): return material_cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = WOOD if component == "wood" else FOLIAGE
	var profile: Dictionary = manifest.profiles[species]
	var palette: Array = profile.wood if component == "wood" else (profile.flowers if component == "flower" else profile.leaves)
	for i in range(3):
		mat.set_shader_parameter(["shadow_color", "middle_color", "light_color"][i], _as_color(palette[i]))
	if component != "wood":
		mat.set_shader_parameter("brush_atlas", load("res://assets/%s_%s_atlas.png" % [species, component]))
		mat.set_shader_parameter("flower_layer", component == "flower")
		mat.set_shader_parameter("bloom", bloom)
	material_cache[key] = mat
	return mat

func _collect_meshes(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		var source := instance.mesh.surface_get_material(0)
		var label: String = source.resource_name if source != null else String(node.name)
		var component: String = "wood"
		if "_leaf" in label: component = "leaf"
		if "_flower" in label: component = "flower"
		out.append({"mesh": instance.mesh, "component": component})
	for child in node.get_children(): _collect_meshes(child, out)

func _meshes(species: String, seed: int, growth: int, lod: int) -> Array:
	var key := "%s_s%d_g%d_lod%d" % [species, seed, growth, lod]
	if mesh_cache.has(key): return mesh_cache[key]
	var packed := load("res://assets/" + key + ".glb") as PackedScene
	if packed == null:
		errors.append("Asset missing: " + key)
		return []
	var instance := packed.instantiate()
	var parts: Array = []
	_collect_meshes(instance, parts)
	instance.free()
	if parts.size() != 3: errors.append("Expected wood/leaf/flower in " + key)
	mesh_cache[key] = parts
	return parts

func _placements() -> Array:
	var points: Array = []
	if mode == "pair":
		points = [["desert_museum", Vector3(-3, 0, 0), stage, 41], ["texas_sage", Vector3(3, 0, 1), stage, 41]]
	elif mode in ["tree", "sage"]:
		points = [["desert_museum" if mode == "tree" else "texas_sage", Vector3.ZERO, stage, 41]]
	elif mode.begins_with("growth"):
		var species: String = "desert_museum" if mode == "growth_tree" else "texas_sage"
		for index in range(3):
			points.append([species, Vector3((index-1)* (9.0 if species == "desert_museum" else 2.6), 0, 0), index, 41])
	else:
		for index in range(12):
			points.append(["desert_museum", Vector3((index%6-2.5)*8.0, 0, -10 if index<6 else 10), stage, 41 if index%2==0 else 73])
		for index in range(96):
			points.append(["texas_sage", Vector3((index%16-7.5)*2.4, 0, (floori(float(index)/16.0)-2.5)*2.6), stage, 41 if index%2==0 else 73])
	return points

func _rebuild() -> void:
	if is_instance_valid(plant_root): plant_root.free()
	plant_root = Node3D.new()
	add_child(plant_root)
	records.clear()
	var bins: Dictionary = {}
	var placements := _placements()
	for index in range(placements.size()):
		var point: Array = placements[index]
		var species: String = point[0]
		var pos: Vector3 = point[1]
		var growth: int = point[2]
		var seed: int = point[3]
		var key := "%s:%d:%d:%d:%d" % [species, seed, growth, floori(pos.x/8.0), floori(pos.z/8.0)]
		if not bins.has(key): bins[key] = {"species": species, "seed": seed, "stage": growth, "transforms": []}
		var angle: float = 0.0 if placements.size() < 5 else index*2.3999632
		bins[key].transforms.append(Transform3D(Basis(Vector3.UP, angle), pos))
	for bin in bins.values():
		var layers: Array = []
		var center := Vector3.ZERO
		for transform in bin.transforms: center += transform.origin
		center /= float(bin.transforms.size())
		for lod in range(3):
			var level: Array = []
			for part in _meshes(bin.species, bin.seed, bin.stage, lod):
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = part.mesh
				mm.instance_count = bin.transforms.size()
				for index in range(mm.instance_count): mm.set_instance_transform(index, bin.transforms[index])
				var node := MultiMeshInstance3D.new()
				node.multimesh = mm
				node.material_override = _material(bin.species, part.component)
				node.extra_cull_margin = 1.3
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if lod==2 or part.component=="flower" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				plant_root.add_child(node)
				level.append({"node": node, "flower": part.component == "flower"})
			layers.append(level)
		var profile: Dictionary = manifest.profiles[bin.species]
		var height: float = lerpf(float(profile.installed_m[0]), float(profile.mature_m[0]), float(bin.stage)/2.0)
		records.append({"levels": layers, "center": center+Vector3.UP*height*.5, "height": height, "lod": 0})
	if litter: _make_litter(placements)
	_update_lods()

func _make_litter(placements: Array) -> void:
	# Local post-bloom placement example, NOT a date/weather deposition prediction.
	# Opaque tiny ground geometry, no transparent whole-yard decal or leaf physics.
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var petal := PrismMesh.new()
	petal.size = Vector3(.018, .005, .028)
	mm.mesh = petal
	mm.instance_count = mini(300, placements.size()*48)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260905
	for index in range(mm.instance_count):
		var p: Array = placements[index%placements.size()]
		var species: String = p[0]
		var profile: Dictionary = manifest.profiles[species]
		var spread: float = lerpf(float(profile.installed_m[1]), float(profile.mature_m[1]), pow(float(p[2])/2.0, 1.15))
		var radius := sqrt(rng.randf())*spread*.48
		var angle := rng.randf()*TAU
		var pos: Vector3 = p[1]+Vector3(cos(angle)*radius+.12, .012, sin(angle)*radius)
		mm.set_instance_transform(index, Transform3D(Basis(Vector3.UP, angle), pos))
		mm.set_instance_color(index, Color(.96,.77,.16) if species=="desert_museum" else Color(.66,.37,.70))
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plant_root.add_child(node)

func _update_lods() -> void:
	if not is_instance_valid(camera): return
	for record in records:
		var dist: float = maxf(camera.global_position.distance_to(record.center), 0.5)
		var pixels: float = record.height*get_viewport().get_visible_rect().size.y/(2.0*tan(deg_to_rad(camera.fov)*.5)*dist)
		var selected: int = int(record.lod)
		if forced_lod >= 0: selected = forced_lod
		elif selected==0 and pixels<190: selected=1
		elif selected==1:
			if pixels>240: selected=0
			elif pixels<65: selected=2
		elif selected==2 and pixels>85: selected=1
		record.lod=selected
		for lod in range(3):
			for entry in record.levels[lod]:
				entry.node.visible = lod==selected and (not entry.flower or bloom>0)
	if is_instance_valid(status):
		status.text = "%s | %d plants | %d spatial/variant groups | bloom %.1f | litter %s\nRenderer: %s | actual tablet frame time: NOT MEASURED" % [mode, _placements().size(), records.size(), bloom, str(litter), RenderingServer.get_current_rendering_method()]

func _update_camera() -> void:
	camera.position=focus+Vector3(sin(yaw)*cos(pitch), sin(pitch), cos(yaw)*cos(pitch))*distance
	camera.look_at(focus, Vector3.UP)
	_update_lods()

func _process(delta: float) -> void:
	if capturing: return
	lod_timer+=delta
	if lod_timer>.20:
		lod_timer=0
		_update_lods()

func _unhandled_input(event: InputEvent) -> void:
	if capturing: return
	if event is InputEventMouseMotion and (event.button_mask & (MOUSE_BUTTON_MASK_RIGHT|MOUSE_BUTTON_MASK_LEFT)):
		yaw-=event.relative.x*.006; pitch=clampf(pitch+event.relative.y*.005,.05,1.3)
	elif event is InputEventScreenDrag:
		yaw-=event.relative.x*.006; pitch=clampf(pitch+event.relative.y*.005,.05,1.3)
	elif event is InputEventMagnifyGesture: distance=clampf(distance/event.factor,1.5,70)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: distance=maxf(1.5,distance*.90)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN: distance=minf(70,distance*1.10)
	_update_camera()

func _save_frame(folder: String, name: String, images: Array) -> void:
	_update_lods()
	for frame in range(5): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var code := image.save_png(folder.path_join(name+".png"))
	if code != OK: errors.append("PNG save failed: "+name)
	images.append({"file": name+".png", "mode": mode, "stage": stage, "bloom": bloom,
		"litter": litter, "forced_lod": forced_lod, "width": image.get_width(), "height": image.get_height(),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"rendered_primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})

func _capture_suite(folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	var images: Array = []
	for species in ["tree", "sage"]:
		_select_mode(species)
		stage=2; bloom=0.0; litter=false; forced_lod=0; _rebuild()
		await _save_frame(folder, species+"-foliage", images)
		_toggle_bloom()
		await _save_frame(folder, species+"-bloom", images)
		yaw+=PI*.65; _update_camera()
		await _save_frame(folder, species+"-reverse", images)
		pitch=.95; _update_camera()
		await _save_frame(folder, species+"-elevated", images)
		pitch=.22; yaw=.54; _update_camera()
		for lod in [1,2]:
			forced_lod=lod
			await _save_frame(folder, species+"-lod"+str(lod), images)
		forced_lod=0
		bloom=0.0; litter=true; _rebuild()
		for mat in material_cache.values():
			if mat.shader==FOLIAGE: mat.set_shader_parameter("bloom", bloom)
		await _save_frame(folder, species+"-post-bloom", images)
	litter=false; bloom=.55; forced_lod=-1
	for mat in material_cache.values():
		if mat.shader==FOLIAGE: mat.set_shader_parameter("bloom", bloom)
	for view in ["growth_tree", "growth_sage", "garden"]:
		_select_mode(view)
		await _save_frame(folder, view, images)
	var report := {"images":images,"errors":errors,"renderer":RenderingServer.get_current_rendering_method(),
		"adapter":RenderingServer.get_video_adapter_name(),"device_performance_certified":false,
		"visual_acceptance":"pending human review","botanical_growth_calibrated":false}
	var file := FileAccess.open(folder.path_join("capture-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("SPECIES_GODOT_CAPTURE_DONE "+JSON.stringify(report))
	get_tree().quit(0 if errors.is_empty() else 2)
