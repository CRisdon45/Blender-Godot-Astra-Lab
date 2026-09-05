class_name PlantRuntime
extends Node3D
## One active MultiMesh per component/group, not three complete hidden LOD scenes.
## Bounds and costs describe geometry; design envelopes never change with LOD.
## Scene preparation is transactional: retain the previous scene until all requested
## variants are ready. A newer placement request supersedes an older pending request.

var catalog: PlantCatalog
var cache: PlantAssetCache
var material_provider: Callable
var policy := PlantLodPolicy.new()
var groups: Array = []
var pending_groups: Array = []
var has_pending: bool = false
var generation: int = 0
var committed_generation: int = 0
var lod_switches: int = 0
var last_prepare_ms: float = 0.0
var last_update_ms: float = 0.0
var triangle_target: int = 140000
var budget_enabled: bool = true
var last_allocation: Dictionary = {}
var errors: Array[String] = []

func configure(value: PlantCatalog, asset_cache: PlantAssetCache, materials: Callable) -> void:
	catalog = value
	cache = asset_cache
	material_provider = materials
	var settings: Dictionary = catalog.data.policy
	policy.near_enter = float(settings.near_enter)
	policy.near_exit = float(settings.near_exit)
	policy.far_enter = float(settings.far_enter)
	policy.far_exit = float(settings.far_exit)
	triangle_target = int(settings.primary_triangle_target)

func set_plants(plants: Array) -> bool:
	var bins: Dictionary = {}
	var ids: Dictionary = {}
	var cell_size: float = float(catalog.data.policy.cell_size_m)
	for plant in plants:
		if not plant is PlantInstance or ids.has(plant.instance_id):
			errors.append("Invalid or duplicate placement identity")
			return false
		ids[plant.instance_id] = true
		var variant: Dictionary = catalog.get_variant(plant.variant_key())
		if variant.is_empty():
			errors.append("Uncompiled plant variant: " + plant.variant_key())
			return false
		var pos: Vector3 = plant.placement.origin
		var key := "%s:%d:%d" % [plant.variant_key(), floori(pos.x / cell_size), floori(pos.z / cell_size)]
		if not bins.has(key):
			bins[key] = {"id": key, "variant": variant, "plants": [], "nodes": [],
				"desired_lod": -1, "active_lod": -1, "fraction": 0.0,
				"bounds": catalog.bounds_for_variant(variant)}
		bins[key].plants.append(plant)
	# Only replace pending state after complete input validation.
	var keys: Array = bins.keys()
	keys.sort()
	pending_groups.clear()
	for key in keys:
		var group: Dictionary = bins[key]
		pending_groups.append(group)
		# Load distant first for predictable cache ordering, but commit only once all
		# three representations are ready, avoiding a blank frame during a LOD swap.
		for level in [2, 1, 0]:
			cache.request(String(group.variant.lods[level].asset_key))
	has_pending = true
	generation += 1
	return true

func poll_preparation() -> bool:
	cache.poll()
	if not has_pending:
		return false
	for group in pending_groups:
		for level in group.variant.lods:
			if not cache.ready.has(level.asset_key):
				return false
	var started: int = Time.get_ticks_usec()
	var new_groups: Array = pending_groups
	pending_groups = []
	for group in new_groups:
		# Children are prepared hidden. Their first selected LOD is applied by update_view.
		for component in ["wood", "leaf", "flower"]:
			var node := MultiMeshInstance3D.new()
			node.name = "Plant_" + String(component)
			node.multimesh = MultiMesh.new()
			node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			node.material_override = material_provider.call(String(group.variant.species), component)
			node.visible = false
			add_child(node)
			group.nodes.append({"node": node, "component": component})
	for group in groups:
		for entry in group.nodes:
			entry.node.free()
	groups = new_groups
	has_pending = false
	committed_generation = generation
	last_prepare_ms = float(Time.get_ticks_usec() - started) / 1000.0
	return true

func update_view(camera: Camera3D, bloom: float, forced_lod: int = -1) -> void:
	if camera == null or catalog == null:
		return
	var started: int = Time.get_ticks_usec()
	# Brush contract/1 does not support a scaled parent. Reject, rather than silently
	# drifting rendered leaves away from geometry and declared design dimensions.
	if not global_transform.basis.get_scale().is_equal_approx(Vector3.ONE):
		if not errors.has("Scaled runtime parent is unsupported"):
			errors.append("Scaled runtime parent is unsupported")
		return
	var inverse_camera: Transform3D = camera.get_camera_transform().affine_inverse()
	var projection: Projection = camera.get_camera_projection()
	var budget_groups: Array = []
	for group in groups:
		var bounds: AABB = group.bounds
		var radius: float = bounds.size.length() * 0.5
		var fraction: float = 0.0
		for plant in group.plants:
			var world_center: Vector3 = global_transform * (plant.placement * bounds.get_center())
			var center: Vector3 = inverse_camera * world_center
			# Use the nearest/most prominent MEMBER, not the average batch center.
			fraction = maxf(fraction, PlantLodPolicy.projected_fraction(radius, -center.z,
				absf(projection.y.y), camera.near, camera.projection == Camera3D.PROJECTION_ORTHOGONAL))
		group.fraction = fraction
		group.desired_lod = forced_lod if forced_lod >= 0 else policy.choose(fraction, int(group.desired_lod))
		var costs: Array[int] = []
		for level in group.variant.lods:
			var counts: Dictionary = level.triangles
			costs.append(int(counts.wood) + int(counts.leaf) + (int(counts.flower) if bloom > 0.0 else 0))
		budget_groups.append({"id": group.id, "desired_lod": group.desired_lod,
			"projected_fraction": fraction, "triangles": costs, "instance_count": group.plants.size(),
			"protected": forced_lod >= 0 or fraction >= 0.60})
	var target: int = triangle_target if budget_enabled else 2147483647
	last_allocation = PlantLodPolicy.allocate_budget(budget_groups, target)
	for group in groups:
		var selected: int = last_allocation.lods[group.id]
		if selected != int(group.active_lod):
			_apply_lod(group, selected)
		for entry in group.nodes:
			entry.node.visible = entry.component != "flower" or bloom > 0.0
	last_update_ms = float(Time.get_ticks_usec() - started) / 1000.0

func _apply_lod(group: Dictionary, lod: int) -> void:
	var parts: Array = cache.get_parts(String(group.variant.lods[lod].asset_key))
	if parts.is_empty():
		# Keep the previous representation. Never hide a plant on a cache miss.
		return
	var combined := AABB()
	var first: bool = true
	for plant in group.plants:
		var source_bounds: AABB = group.bounds
		var box: AABB = plant.placement * source_bounds
		combined = box if first else combined.merge(box)
		first = false
	for entry in group.nodes:
		for part in parts:
			if part.component != entry.component:
				continue
			var node := entry.node as MultiMeshInstance3D
			var mm: MultiMesh = node.multimesh
			mm.mesh = part.mesh
			mm.instance_count = group.plants.size()
			for index in range(group.plants.size()):
				mm.set_instance_transform(index, group.plants[index].placement * part.local_transform)
			# Explicit full-rotation shader-safe bounds, not the original flat brush AABB.
			mm.custom_aabb = combined
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if lod == 2 or entry.component == "flower" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	group.active_lod = lod
	lod_switches += 1

func diagnostics() -> Dictionary:
	var counts: Array[int] = [0, 0, 0]
	var plants: int = 0
	var primary: int = 0
	for group in groups:
		plants += group.plants.size()
		if int(group.active_lod) >= 0:
			counts[int(group.active_lod)] += group.plants.size()
			for entry in group.nodes:
				if entry.node.visible:
					primary += int(group.variant.lods[int(group.active_lod)].triangles[entry.component]) * group.plants.size()
	return {"placements": plants, "spatial_variant_groups": groups.size(), "lod_instances": counts,
		"active_component_nodes": groups.size() * 3, "estimated_primary_triangles_all_groups": primary,
		"triangle_target": triangle_target, "budget_enabled": budget_enabled,
		"target_met": primary <= triangle_target, "lod_switches": lod_switches,
		"preparation_pending": has_pending, "requested_generation": generation,
		"committed_generation": committed_generation, "last_prepare_ms": last_prepare_ms,
		"last_lod_update_ms": last_update_ms, "cache": cache.diagnostics(),
		"errors": errors + cache.errors, "tablet_certified": false,
		"cost_excludes_shadow_and_reflection_passes": true}
