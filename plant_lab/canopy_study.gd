extends "res://engine_lab.gd"
## Same placement/cache/budget engine, opt-in 4-component art catalog. No separate runtime.
const CORE_SHADER = preload("res://shaders/canopy_core.gdshader")
const EDGE_SHADER = preload("res://shaders/canopy_edge.gdshader")
const LEAF_SHADER = preload("res://shaders/canopy_leaf.gdshader")
const GROUND_SHADER = preload("res://shaders/canopy_ground.gdshader")
var treatment: String = "canopy"
var component_view: String = "all"
var sun: DirectionalLight3D
var sun_vector := Vector3(-0.314, 0.743, 0.589).normalized()

func _build_world() -> void:
	super._build_world()
	for child in get_children():
		if child is DirectionalLight3D:
			sun = child as DirectionalLight3D
		elif child is MeshInstance3D and child.mesh is PlaneMesh:
			var mat := ShaderMaterial.new()
			mat.shader = GROUND_SHADER
			child.material_override = mat

func _build_hud() -> void:
	super._build_hud()
	var row := HBoxContainer.new()
	row.position = Vector2(12, 285)
	hud.add_child(row)
	for name in ["Baseline", "Canopy", "Core only", "All layers"]:
		var button := Button.new()
		button.text = name
		button.pressed.connect(_study_control.bind(name))
		row.add_child(button)

func _study_control(value: String) -> void:
	if value in ["Baseline", "Canopy"]:
		_set_treatment(value.to_lower())
	else:
		component_view = "core" if value == "Core only" else "all"
		_update_lods()

func _set_treatment(value: String) -> bool:
	if value not in ["baseline", "canopy"]:
		return false
	var candidate := PlantCatalog.new()
	var path: String = "res://engine_data/catalog.json" if value == "baseline" else "res://engine_data/canopy_catalog.json"
	if not candidate.open_catalog(path):
		errors.append_array(candidate.errors)
		return false
	engine_runtime.free()
	engine_catalog = candidate
	engine_cache = PlantAssetCache.new()
	engine_cache.configure(engine_catalog)
	engine_runtime = PlantRuntime.new()
	add_child(engine_runtime)
	treatment = value
	component_view = "all"
	material_cache.clear()
	engine_runtime.configure(engine_catalog, engine_cache, _material)
	instance_records.clear()
	_rebuild()
	return true

func _material(species: String, component: String) -> ShaderMaterial:
	if treatment == "baseline" or component == "wood":
		return super._material(species, component)
	var key: String = species + ":" + component
	if material_cache.has(key):
		return material_cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = CORE_SHADER if component == "core" else (LEAF_SHADER if component == "leaf" else EDGE_SHADER)
	var profile: Dictionary = manifest.profiles[species]
	var palette: Array = profile.flowers if component == "flower" else profile.leaves
	for index in range(3):
		mat.set_shader_parameter(["shadow_color", "middle_color", "light_color"][index], _as_color(palette[index]))
	mat.set_shader_parameter("sun_direction", sun_vector)
	if component in ["core", "leaf"]:
		mat.set_shader_parameter("paint_mask", load("res://assets/canopy/%s_paint_mask.png" % species))
	else:
		mat.set_shader_parameter("brush_atlas", load("res://assets/canopy/%s_%s_atlas.png" % [species, component]))
		mat.set_shader_parameter("flower_layer", component == "flower")
		mat.set_shader_parameter("bloom", bloom)
	material_cache[key] = mat
	return mat

func _sync_materials() -> void:
	for mat in material_cache.values():
		mat.set_shader_parameter("sun_direction", sun_vector)
		if mat.shader == EDGE_SHADER or mat.shader == FOLIAGE:
			mat.set_shader_parameter("bloom", bloom)
	if is_instance_valid(sun):
		sun.look_at(-sun_vector, Vector3.UP)

func _toggle_bloom() -> void:
	bloom = 0.0 if bloom > 0.0 else 1.0
	_sync_materials()
	_update_lods()

func _update_lods() -> void:
	super._update_lods()
	if treatment == "canopy" and component_view == "core":
		for group in engine_runtime.groups:
			for entry in group.nodes:
				entry.node.visible = entry.component in ["wood", "core"]

func _save_frame(folder: String, name: String, images: Array) -> void:
	_sync_materials()
	await super._save_frame(folder, name, images)
	if images.is_empty():
		return
	var entry: Dictionary = images[-1]
	entry["treatment"] = treatment
	entry["component_view"] = component_view
	entry["runtime"] = engine_runtime.diagnostics()
	entry["camera"] = {"yaw": yaw, "pitch": pitch, "distance": distance, "fov": camera.fov,
		"focus": [focus.x, focus.y, focus.z]}
	entry["sun"] = [sun_vector.x, sun_vector.y, sun_vector.z]

func _prepare_capture(species: String, lod: int = 0) -> void:
	_select_mode(species)
	stage = 2
	bloom = 0.55
	litter = false
	forced_lod = lod
	yaw = 0.54
	pitch = 0.22
	component_view = "all"
	_rebuild()
	_update_camera()
	_sync_materials()

func _capture_suite(folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	var images: Array = []
	for style in ["baseline", "canopy"]:
		if not _set_treatment(style):
			break
		for species in ["tree", "sage"]:
			_prepare_capture(species)
			for lod in range(3):
				forced_lod = lod
				await _save_frame(folder, "%s-%s-lod%d" % [style, species, lod], images)
			if style == "canopy":
				forced_lod = 0
				yaw += PI * 0.65
				_update_camera()
				await _save_frame(folder, species + "-reverse", images)
				pitch = 0.95
				_update_camera()
				await _save_frame(folder, species + "-elevated", images)
	_prepare_capture("sage")
	component_view = "core"
	await _save_frame(folder, "sage-core-only", images)
	component_view = "all"
	for view in ["growth_tree", "growth_sage", "garden"]:
		yaw = 0.54
		pitch = 0.22
		_select_mode(view)
		await _save_frame(folder, view, images)
	_prepare_capture("sage")
	await _save_frame(folder, "sage-repeat-a", images)
	await _save_frame(folder, "sage-repeat-b", images)
	var report: Dictionary = {"schema": "canopy-capture/1", "images": images, "errors": errors + engine_cache.errors + engine_runtime.errors,
		"renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(),
		"engine": Engine.get_version_info(), "android_device_tested": false, "art_approved": false}
	var file := FileAccess.open(folder.path_join("capture-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("CANOPY_CAPTURE_DONE " + JSON.stringify(report))
	get_tree().quit(0 if report.errors.is_empty() else 2)
