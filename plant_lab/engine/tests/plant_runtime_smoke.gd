extends SceneTree
## Run after an editor import. This report is generated ONLY by an actual engine run.
## A headless smoke test is not a visual review and is not tablet GPU evidence.

var failures: Array[String] = []
var checks: int = 0
var budget_evidence: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _lod_maps_match(actual: Dictionary, expected: Dictionary) -> bool:
	# JSON parses numbers as floats. Normalize only validated integral expectations;
	# do not loosen the production result's integer contract or truncate bad fixtures.
	if actual.size() != expected.size():
		return false
	for key in expected:
		if not actual.has(key) or not actual[key] is int:
			return false
		var value: Variant = expected[key]
		if not (value is int or value is float) or not is_finite(float(value)):
			return false
		if float(value) != floorf(float(value)) or int(value) < 0 or int(value) > 2:
			return false
		if actual[key] != int(value):
			return false
	return true

func _run() -> void:
	_check(_lod_maps_match({"a": 1}, {"a": 1.0}), "JSON integral values normalize")
	_check(not _lod_maps_match({"a": 1}, {"a": 1.5}), "Fractional expected LOD rejected")
	_check(not _lod_maps_match({"a": 0}, {"a": 1.0}), "Wrong actual LOD rejected")
	_check(not _lod_maps_match({"a": 1.0}, {"a": 1.0}), "Actual LOD must remain integer")
	_check(not _lod_maps_match({"a": 1}, {"b": 1.0}), "Wrong group identity rejected")
	_check(not _lod_maps_match({"a": 1}, {"a": 1.0, "b": 2.0}), "Missing group rejected")
	_check(not _lod_maps_match({"a": 1, "b": 2}, {"a": 1.0}), "Extra group rejected")
	var file := FileAccess.open("res://engine/tests/lod_contract.json", FileAccess.READ)
	if file == null:
		_check(false, "LOD contract fixture missing")
		_finish()
		return
	var fixture: Dictionary = JSON.parse_string(file.get_as_text())
	var policy := PlantLodPolicy.new()
	for value in fixture.choice_cases:
		_check(policy.choose(float(value.fraction), int(value.previous)) == int(value.expected), "LOD choice parity")
	for value in fixture.projection_cases:
		var actual: float = PlantLodPolicy.projected_fraction(float(value.radius_m), float(value.depth_m),
			float(value.projection_y), float(value.near_m), bool(value.orthographic))
		_check(is_equal_approx(actual, float(value.expected)), "Camera projection parity")
	for value in fixture.budget_cases:
		var result: Dictionary = PlantLodPolicy.allocate_budget(value.groups, int(value.target))
		budget_evidence.append({"actual": result, "expected": value.expected})
		_check(_lod_maps_match(result.lods, value.expected.lods), "Budget LOD parity: " + JSON.stringify(result))
		_check(int(result.estimated_primary_triangles) == int(value.expected.estimated_primary_triangles), "Budget triangle parity")
		_check(bool(result.target_met) == bool(value.expected.target_met), "Impossible-budget reporting parity")
	var original := PlantInstance.create("saved-tree", "desert_museum", 41, 0, Vector3(2.0, 0.0, 4.0), 0.6)
	var restored := PlantInstance.from_record(JSON.parse_string(JSON.stringify(original.to_record())))
	_check(restored != null and restored.instance_id == original.instance_id, "Placement roundtrip identity")
	if restored != null:
		_check(restored.placement.is_equal_approx(original.placement), "Placement roundtrip transform")
		var identity_before: String = restored.instance_id
		restored.set_stage(2)
		_check(restored.instance_id == identity_before and restored.revision == 1, "Direct stage commit preserves identity")
	var packed := load("res://engine_lab.tscn") as PackedScene
	if packed == null:
		_check(false, "Foundation scene failed to load")
		_finish()
		return
	var world: Node = packed.instantiate()
	root.add_child(world)
	if not await _settle(world):
		world.free()
		_finish()
		return
	_check(world.engine_catalog.assets.size() == 36, "Catalog asset matrix")
	_check(world.engine_runtime.diagnostics().placements == 2, "Two-species initial view")
	world._select_mode("garden")
	await _settle(world)
	var report: Dictionary = world.engine_runtime.diagnostics()
	_check(report.placements == 108, "108-plant garden")
	_check(report.active_component_nodes == report.spatial_variant_groups * 3, "Only one active LOD component set")
	var requests_before: int = world.engine_cache.requests_total
	var ids: Array = world.instance_records.keys()
	ids.sort()
	for index in range(20):
		world.yaw += 0.1
		world._update_camera()
		await process_frame
	_check(world.engine_cache.requests_total == requests_before, "Orbit must not request or rebuild assets")
	world._select_stage(0)
	world._select_stage(1)
	world._select_stage(2)
	await _settle(world)
	_check(world.engine_runtime.committed_generation == world.engine_runtime.generation, "Latest preparation supersedes stale requests")
	var new_ids: Array = world.instance_records.keys()
	new_ids.sort()
	_check(ids == new_ids, "Growth-stage changes preserve placement identity")
	world._select_stage(0)
	await _settle(world)
	world._toggle_envelopes()
	_check(is_instance_valid(world.envelope_mesh), "Mature footprint overlay")
	world.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	world.camera.size = 35.0
	world._update_lods()
	_check(world.engine_runtime.errors.is_empty(), "Orthographic camera update")
	_check(world.engine_cache.errors.is_empty(), "No async asset-loading failures")
	world._export_diagnostics()
	world.free()
	await process_frame
	_finish()

func _settle(world: Node) -> bool:
	var deadline: int = Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline:
		if not world.engine_cache.errors.is_empty():
			_check(false, "Asset preparation failed: " + str(world.engine_cache.errors))
			return false
		if not world.engine_runtime.has_pending and world.engine_cache.is_idle():
			world._update_lods()
			return true
		await process_frame
	_check(false, "Asset preparation timed out")
	return false

func _finish() -> void:
	var report := {"schema": "plant-runtime-smoke/1", "checks": checks, "failures": failures, "budget_evidence": budget_evidence,
		"passed": failures.is_empty(), "godot_runtime_executed": true,
		"engine_version": Engine.get_version_info(), "visual_approved": false, "tablet_tested": false}
	var file := FileAccess.open("user://plant-foundation-smoke.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	print("PLANT_FOUNDATION_SMOKE " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 2)
