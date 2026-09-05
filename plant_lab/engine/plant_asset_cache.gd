class_name PlantAssetCache
extends RefCounted
## Bounded asynchronous PackedScene cache; supports baseline and opaque-core catalogs.
var catalog: PlantCatalog
var ready: Dictionary = {}
var pending: Dictionary = {}
var waiting: Array[String] = []
var failed: Dictionary = {}
var errors: Array[String] = []
var max_concurrent: int = 4
var max_finalize_per_frame: int = 2
var finalized_total: int = 0
var requests_total: int = 0

func configure(value: PlantCatalog) -> void:
	catalog = value
	max_concurrent = int(catalog.data.policy.max_concurrent_loads)
	max_finalize_per_frame = int(catalog.data.policy.finalize_assets_per_frame)

func request(asset_key: String) -> void:
	if ready.has(asset_key) or pending.has(asset_key) or waiting.has(asset_key) or failed.has(asset_key):
		return
	if catalog == null or not catalog.assets.has(asset_key):
		failed[asset_key] = true
		errors.append("Unknown catalog asset: " + asset_key)
		return
	waiting.append(asset_key)

func poll() -> bool:
	var changed: bool = false
	while pending.size() < max_concurrent and not waiting.is_empty():
		var key: String = waiting.pop_front()
		var path: String = "res://" + String(catalog.get_asset(key).path)
		var code := ResourceLoader.load_threaded_request(path, "PackedScene")
		requests_total += 1
		if code != OK:
			failed[key] = true
			errors.append("Async model request failed: " + path)
		else:
			pending[key] = path
	var finalized: int = 0
	for key in pending.keys():
		if finalized >= max_finalize_per_frame:
			break
		var path: String = pending[key]
		var state := ResourceLoader.load_threaded_get_status(path)
		if state == ResourceLoader.THREAD_LOAD_FAILED or state == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			pending.erase(key)
			failed[key] = true
			errors.append("Async model load failed: " + path)
		elif state == ResourceLoader.THREAD_LOAD_LOADED:
			var packed := ResourceLoader.load_threaded_get(path) as PackedScene
			pending.erase(key)
			finalized += 1
			if packed == null:
				failed[key] = true
				errors.append("Asset is not a PackedScene: " + path)
				continue
			var instance: Node = packed.instantiate()
			var parts: Array = []
			_collect_meshes(instance, Transform3D.IDENTITY, parts)
			instance.free()
			if not _valid_parts(parts) or parts.size() != (4 if catalog.get_asset(key).triangles.has("core") else 3):
				failed[key] = true
				errors.append("Mesh components do not match catalog: " + path)
				continue
			ready[key] = parts
			finalized_total += 1
			changed = true
	return changed

func _collect_meshes(node: Node, parent_transform: Transform3D, out: Array) -> void:
	var local := parent_transform
	if node is Node3D:
		local = parent_transform * (node as Node3D).transform
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		if instance.mesh == null or instance.mesh.get_surface_count() != 1:
			return
		var source: Material = instance.mesh.surface_get_material(0)
		var label: String = source.resource_name if source != null else String(node.name)
		var component: String = "wood"
		if "_core" in label:
			component = "core"
		elif "_leaf" in label:
			component = "leaf"
		elif "_flower" in label:
			component = "flower"
		out.append({"mesh": instance.mesh, "component": component, "local_transform": local})
	for child in node.get_children():
		_collect_meshes(child, local, out)

func _valid_parts(parts: Array) -> bool:
	var names: Array[String] = []
	for part in parts:
		names.append(part.component)
		var basis: Basis = part.local_transform.basis
		if not basis.get_scale().is_equal_approx(Vector3.ONE) or basis.determinant() <= 0.0:
			return false
	names.sort()
	return names == ["flower", "leaf", "wood"] or names == ["core", "flower", "leaf", "wood"]

func get_parts(key: String) -> Array:
	return ready.get(key, [])

func is_idle() -> bool:
	return waiting.is_empty() and pending.is_empty()

func diagnostics() -> Dictionary:
	return {"loaded_assets": ready.size(), "queued_assets": waiting.size(), "loading_assets": pending.size(),
		"failed_assets": failed.size(), "requests_total": requests_total, "finalized_total": finalized_total}
