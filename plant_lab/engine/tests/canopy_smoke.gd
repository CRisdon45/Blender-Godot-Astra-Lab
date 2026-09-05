extends SceneTree
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func settle(world: Node) -> bool:
	var end: int = Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < end:
		if not world.engine_cache.errors.is_empty():
			check(false, str(world.engine_cache.errors))
			return false
		if not world.engine_runtime.has_pending and world.engine_cache.is_idle():
			world._update_lods()
			return true
		await process_frame
	check(false, "Asset preparation timeout")
	return false

func _run() -> void:
	var scene := load("res://canopy_study.tscn") as PackedScene
	if scene == null:
		check(false, "Canopy scene loads")
		finish()
		return
	var world: Node = scene.instantiate()
	root.add_child(world)
	if not await settle(world):
		world.free()
		finish()
		return
	check(world.engine_catalog.data.schema == "plant-catalog/2", "Versioned canopy catalog")
	check(world.engine_catalog.assets.size() == 36, "36 canopy assets")
	check(world.engine_runtime.diagnostics().placements == 2, "Two-species startup")
	check(world.engine_runtime.diagnostics().active_component_nodes == 8, "Four components per specimen")
	check(not world.engine_catalog._valid_costs({"wood": 10, "leaf": 2, "flower": 2, "core": 3, "total": 14}), "Core costs cannot be omitted")
	check(not world._set_treatment("unsupported"), "Unknown treatment rejected")
	world._select_mode("garden")
	await settle(world)
	var d: Dictionary = world.engine_runtime.diagnostics()
	check(d.placements == 108, "108-plant garden")
	check(d.active_component_nodes == d.spatial_variant_groups * 4, "One active four-component set")
	check(d.errors.is_empty(), "No preparation errors")
	check(d.estimated_primary_triangles_all_groups == world.engine_runtime.last_allocation.estimated_primary_triangles, "Budget includes opaque cores")
	var requests: int = world.engine_cache.requests_total
	for i in range(12):
		world.yaw += 0.1
		world._update_camera()
		await process_frame
	check(world.engine_cache.requests_total == requests, "Camera changes reuse compiled assets")
	for level in range(3):
		world.forced_lod = level
		world._update_lods()
		for group in world.engine_runtime.groups:
			check(group.active_lod == level, "Forced LOD selects actual mesh")
			check(group.nodes.size() == 4, "LOD change retains core component")
	world.forced_lod = -1
	world._toggle_bloom()
	world._update_lods()
	d = world.engine_runtime.diagnostics()
	check(d.estimated_primary_triangles_all_groups == world.engine_runtime.last_allocation.estimated_primary_triangles, "Bloom costs remain accounted")
	var ids: Array = world.instance_records.keys()
	ids.sort()
	world._select_stage(0)
	world._select_stage(1)
	world._select_stage(2)
	await settle(world)
	var after: Array = world.instance_records.keys()
	after.sort()
	check(ids == after, "Growth preserves placement identity")
	world._study_control("Core only")
	for group in world.engine_runtime.groups:
		for entry in group.nodes:
			check(entry.node.visible == (entry.component in ["wood", "core"]), "Core-only diagnostic is real geometry")
	world._study_control("All layers")
	check(world._set_treatment("baseline"), "Baseline remains available")
	await settle(world)
	d = world.engine_runtime.diagnostics()
	check(d.active_component_nodes == d.spatial_variant_groups * 3, "Baseline still uses three components")
	check(world._set_treatment("canopy"), "Canopy can be restored")
	await settle(world)
	check(world.engine_runtime.diagnostics().placements == 108, "Study restore retains scene population")
	check(world.engine_cache.errors.is_empty(), "No cache failures")
	world.free()
	await process_frame
	finish()

func finish() -> void:
	print("CANOPY_SMOKE " + JSON.stringify({"checks": checks, "passed": failures.is_empty(), "failures": failures,
		"godot_executed": true, "tablet_tested": false, "art_approved": false}))
	quit(0 if failures.is_empty() else 2)
