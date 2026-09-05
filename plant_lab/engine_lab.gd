extends "res://plant_lab.gd"
## Opt-in integration; original main.tscn, courtyard, materials and assets are preserved.

@export var catalog_path: String = "res://engine_data/catalog.json"
var engine_catalog := PlantCatalog.new()
var engine_cache := PlantAssetCache.new()
var engine_runtime := PlantRuntime.new()
var instance_records: Dictionary = {}
var envelope_mesh: MeshInstance3D
var show_mature_envelopes: bool = false
var frame_samples: Array[float] = []
var foundation_ready: bool = false

func _ready() -> void:
	if not engine_catalog.open_catalog(catalog_path):
		push_error("; ".join(engine_catalog.errors))
		get_tree().quit(2)
		return
	engine_cache.configure(engine_catalog)
	add_child(engine_runtime)
	engine_runtime.configure(engine_catalog, engine_cache, _material)
	foundation_ready = true
	super._ready()

func _build_hud() -> void:
	super._build_hud()
	var row := HBoxContainer.new()
	row.position = Vector2(12, 242)
	hud.add_child(row)
	var envelopes := Button.new()
	envelopes.text = "Mature footprint on / off"
	envelopes.pressed.connect(_toggle_envelopes)
	row.add_child(envelopes)
	var budget := Button.new()
	budget.text = "Triangle target on / off"
	budget.pressed.connect(_toggle_budget)
	row.add_child(budget)
	var export_button := Button.new()
	export_button.text = "Save diagnostics"
	export_button.pressed.connect(_export_diagnostics)
	row.add_child(export_button)

func _rebuild() -> void:
	if not foundation_ready:
		return
	if is_instance_valid(plant_root):
		plant_root.free()
	plant_root = Node3D.new()
	add_child(plant_root)
	var placements: Array = _placements()
	var next_records: Dictionary = {}
	var plants: Array = []
	for index in range(placements.size()):
		var point: Array = placements[index]
		var id := "%s:%d:%s" % [mode, index, point[0]]
		var record: PlantInstance = instance_records.get(id)
		if record == null:
			record = PlantInstance.create(id, String(point[0]), int(point[3]), int(point[2]), point[1],
				0.0 if placements.size() < 5 else float(index) * 2.3999632)
		else:
			record.set_stage(int(point[2]))
		if record == null:
			push_error("Plant placement validation failed")
			return
		plants.append(record)
		next_records[id] = record
	if not engine_runtime.set_plants(plants):
		push_error("; ".join(engine_runtime.errors))
		return
	instance_records = next_records
	if litter:
		_make_litter(placements)
	_refresh_envelopes()
	_update_lods()

func _process(delta: float) -> void:
	if not foundation_ready:
		return
	frame_samples.append(delta * 1000.0)
	if frame_samples.size() > 120:
		frame_samples.pop_front()
	var committed: bool = engine_runtime.poll_preparation()
	lod_timer += delta
	if committed or lod_timer >= 0.20:
		lod_timer = 0.0
		_update_lods()

func _update_lods() -> void:
	if not foundation_ready or not is_instance_valid(camera):
		return
	engine_runtime.update_view(camera, bloom, forced_lod)
	if not is_instance_valid(status):
		return
	var d: Dictionary = engine_runtime.diagnostics()
	var timing: Dictionary = _frame_statistics()
	status.text = "FOUNDATION | %d plants | LOD %s | %d active component nodes\n" % [d.placements, str(d.lod_instances), d.active_component_nodes]
	status.text += "Primary triangles (all groups): %d / target %d | loaded %d, queued %d, loading %d\n" % [
		d.estimated_primary_triangles_all_groups, d.triangle_target, d.cache.loaded_assets, d.cache.queued_assets, d.cache.loading_assets]
	status.text += "Frame interval p50/p95: %.1f / %.1f ms | %s | device approval PENDING" % [
		timing.p50_ms, timing.p95_ms, "Preparing assets" if d.preparation_pending else ("Target met" if d.target_met else "Target exceeded; protected plants retained")]
	if not d.errors.is_empty():
		status.text += "\nERROR: " + String(d.errors[0])

func _frame_statistics() -> Dictionary:
	if frame_samples.is_empty():
		return {"p50_ms": 0.0, "p95_ms": 0.0, "sample_count": 0}
	var ordered: Array[float] = frame_samples.duplicate()
	ordered.sort()
	return {"p50_ms": ordered[floori(float(ordered.size() - 1) * 0.50)],
		"p95_ms": ordered[floori(float(ordered.size() - 1) * 0.95)], "sample_count": ordered.size()}

func _toggle_budget() -> void:
	engine_runtime.budget_enabled = not engine_runtime.budget_enabled
	_update_lods()

func _toggle_envelopes() -> void:
	show_mature_envelopes = not show_mature_envelopes
	_refresh_envelopes()

func _refresh_envelopes() -> void:
	if is_instance_valid(envelope_mesh):
		envelope_mesh.free()
	if not show_mature_envelopes or instance_records.is_empty():
		return
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for record in instance_records.values():
		var variant: Dictionary = engine_catalog.get_variant(record.variant_key())
		var radius: float = float(variant.design_envelope.mature_spread_m) * 0.5
		for index in range(64):
			var a: float = TAU * float(index) / 64.0
			var b: float = TAU * float(index + 1) / 64.0
			mesh.surface_add_vertex(record.placement.origin + Vector3(cos(a) * radius, 0.025, sin(a) * radius))
			mesh.surface_add_vertex(record.placement.origin + Vector3(cos(b) * radius, 0.025, sin(b) * radius))
	mesh.surface_end()
	envelope_mesh = MeshInstance3D.new()
	envelope_mesh.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.40, 0.52, 0.44)
	envelope_mesh.material_override = mat
	envelope_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(envelope_mesh)

func _export_diagnostics() -> void:
	var report: Dictionary = engine_runtime.diagnostics()
	report["frame_intervals"] = _frame_statistics()
	report["renderer"] = RenderingServer.get_current_rendering_method()
	report["adapter"] = RenderingServer.get_video_adapter_name()
	report["os"] = OS.get_name()
	report["catalog_generation"] = engine_catalog.data.generation
	report["draw_calls_scene_last_frame"] = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	report["primitives_scene_last_frame"] = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	report["intervals_are_gpu_timings"] = false
	report["art_approved"] = false
	var file := FileAccess.open("user://plant-foundation-diagnostics.json", FileAccess.WRITE)
	if file == null:
		push_error("Cannot write plant diagnostics")
		return
	file.store_string(JSON.stringify(report, "\t"))
	print("PLANT_FOUNDATION_DIAGNOSTICS " + JSON.stringify(report))

func _save_frame(folder: String, name: String, images: Array) -> void:
	var deadline: int = Time.get_ticks_msec() + 60000
	while engine_runtime.has_pending and engine_cache.errors.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if engine_runtime.has_pending:
		errors.append("Asset preparation incomplete for capture: " + name)
		return
	await super._save_frame(folder, name, images)
