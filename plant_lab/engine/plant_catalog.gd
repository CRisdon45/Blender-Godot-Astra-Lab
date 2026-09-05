class_name PlantCatalog
extends RefCounted
## Validated catalog. v1 keeps the three-component baseline; v2 adds an opaque core.
var data: Dictionary = {}
var variants: Dictionary = {}
var assets: Dictionary = {}
var errors: Array[String] = []

static func safe_relative(path: String) -> bool:
	if path.is_empty() or path.begins_with("/") or ":" in path or "\\" in path:
		return false
	for part in path.split("/", true):
		if part in ["", ".", ".."]:
			return false
	return true

static func valid_hash(value: Variant) -> bool:
	if not value is String or value.length() != 64:
		return false
	for index in range(value.length()):
		if value.substr(index, 1) not in "0123456789abcdef":
			return false
	return true

func open_catalog(path: String = "res://engine_data/catalog.json") -> bool:
	errors.clear()
	data.clear()
	variants.clear()
	assets.clear()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("Plant catalog missing; run the corresponding Blender/catalog compiler")
	if file.get_length() > 8 * 1024 * 1024:
		return _fail("Catalog exceeds bounded study input size")
	var decoded: Variant = JSON.parse_string(file.get_as_text())
	if not decoded is Dictionary:
		return _fail("Plant catalog must be a JSON object")
	if decoded.get("schema") not in ["plant-catalog/1", "plant-catalog/2"] or decoded.get("render_coordinates") != "y_up":
		return _fail("Unsupported plant catalog or coordinates")
	if decoded.get("growth_domain") != "illustrative_maturity_0_to_1":
		return _fail("Uncalibrated study cannot accept calendar-age claims")
	if not decoded.get("variants") is Array or not decoded.get("species") is Dictionary:
		return _fail("Catalog lacks species/variants")
	if not decoded.get("policy") is Dictionary or not decoded.get("approval") is Dictionary:
		return _fail("Catalog lacks policy/approval metadata")
	for flag in ["art", "android_device", "calendar_growth", "production"]:
		if decoded.approval.get(flag) != false:
			return _fail("This study cannot assert production or device approval")
	if not _valid_policy(decoded.policy):
		return _fail("Invalid detail/cache policy")
	if not decoded.get("validation") is Dictionary or decoded.validation.get("independent_glb_check") != true:
		return _fail("Catalog must pass independent Blender artifact validation")
	if not valid_hash(decoded.get("generation")):
		return _fail("Catalog generation hash missing")
	var staged_variants: Dictionary = {}
	var staged_assets: Dictionary = {}
	var has_core: bool = decoded.schema == "plant-catalog/2"
	var layout: Array = ["wood", "core", "leaf", "flower"] if has_core else ["wood", "leaf", "flower"]
	for value in decoded.variants:
		if not value is Dictionary:
			return _fail("Invalid variant")
		var key: String = str(value.get("key", ""))
		if key.is_empty() or staged_variants.has(key) or not value.get("lods") is Array:
			return _fail("Duplicate or malformed variant")
		if not decoded.species.has(value.get("species")) or not value.get("design_envelope") is Dictionary:
			return _fail("Unknown variant species or missing design envelope")
		if not _integer(value.get("seed"), 0, 2147483647) or not _integer(value.get("stage"), 0, 2):
			return _fail("Invalid seed/stage")
		if key != "%s_s%d_g%d" % [value.species, int(value.seed), int(value.stage)]:
			return _fail("Variant identity does not match species/seed/stage")
		if not safe_relative(str(value.get("topology_path", ""))) or not valid_hash(value.get("topology_sha256")):
			return _fail("Invalid topology path/hash")
		for dimension in ["height_m", "spread_m", "mature_height_m", "mature_spread_m"]:
			if not _positive(value.design_envelope.get(dimension), 100.0):
				return _fail("Invalid design envelope")
		if value.design_envelope.get("calendar_calibrated") != false:
			return _fail("Study growth envelope is not calendar calibrated")
		if value.lods.size() != 3 or not valid_hash(value.get("blueprint_id")):
			return _fail("Invalid LOD matrix or plant identity")
		if value.get("components", ["wood", "leaf", "flower"]) != layout:
			return _fail("Component layout does not match catalog version")
		for index in range(3):
			var level: Variant = value.lods[index]
			if not level is Dictionary or not _integer(level.get("lod"), 0, 2) or int(level.lod) != index:
				return _fail("Unordered LOD entries")
			var asset_id: String = str(level.get("asset_key", ""))
			var model_path: String = str(level.get("path", ""))
			if not valid_hash(asset_id) or not valid_hash(level.get("sha256")) or staged_assets.has(asset_id):
				return _fail("Invalid or duplicate asset hash")
			if not safe_relative(model_path) or not model_path.begins_with("assets/") or not model_path.ends_with(".glb"):
				return _fail("Unsafe model path")
			if not _valid_bounds(level.get("render_aabb_y_up")) or not _valid_costs(level.get("triangles")):
				return _fail("Invalid render bounds or triangle costs")
			if level.triangles.has("core") != has_core:
				return _fail("Triangle components do not match catalog layout")
			if index > 0:
				for component in level.triangles:
					if int(level.triangles[component]) > int(value.lods[index - 1].triangles[component]):
						return _fail("LOD costs cannot increase with distance")
			staged_assets[asset_id] = level
		staged_variants[key] = value
	if staged_assets.is_empty() or staged_assets.size() > int(decoded.policy.max_loaded_assets):
		return _fail("Study catalog supports 1–36 assets; larger libraries require a streaming policy")
	data = decoded
	variants = staged_variants
	assets = staged_assets
	return true

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	if not (value is float or value is int) or not is_finite(float(value)):
		return false
	return float(value) == floorf(float(value)) and float(value) >= minimum and float(value) <= maximum

static func _positive(value: Variant, maximum: float) -> bool:
	if not (value is float or value is int) or not is_finite(float(value)):
		return false
	return float(value) > 0.0 and float(value) <= maximum

func _valid_policy(value: Dictionary) -> bool:
	var previous: float = 0.0
	for key in ["far_enter", "far_exit", "near_exit", "near_enter"]:
		if not _positive(value.get(key), 10.0) or float(value[key]) <= previous:
			return false
		previous = float(value[key])
	if not _positive(value.get("cell_size_m"), 100.0):
		return false
	if not _integer(value.get("primary_triangle_target"), 1, 10000000):
		return false
	if not _integer(value.get("max_loaded_assets"), 1, 36):
		return false
	if not _integer(value.get("max_concurrent_loads"), 1, 8):
		return false
	if not _integer(value.get("finalize_assets_per_frame"), 1, 4):
		return false
	return value.get("far_shadow_policy") == "off_legacy_study" and value.get("budget_is_gpu_guarantee") == false

func _valid_costs(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var total: int = 0
	var keys: Array = value.keys()
	keys.sort()
	if keys != ["flower", "leaf", "total", "wood"] and keys != ["core", "flower", "leaf", "total", "wood"]:
		return false
	for key in keys:
		var number: Variant = value.get(key)
		if not (number is float or number is int) or not is_finite(float(number)):
			return false
		if float(number) < 0 or float(number) > 20000 or float(number) != floorf(float(number)):
			return false
		if key != "total":
			total += int(number)
	return total == int(value.total)

func _valid_bounds(value: Variant) -> bool:
	if not value is Dictionary or not value.get("min") is Array or not value.get("max") is Array:
		return false
	if value.min.size() != 3 or value.max.size() != 3:
		return false
	for index in range(3):
		var low: Variant = value.min[index]
		var high: Variant = value.max[index]
		if not (low is float or low is int) or not (high is float or high is int):
			return false
		if not is_finite(float(low)) or not is_finite(float(high)) or float(low) >= float(high):
			return false
	return true

func _fail(message: String) -> bool:
	errors.append(message)
	return false

func get_variant(key: String) -> Dictionary:
	return variants.get(key, {})

func get_asset(key: String) -> Dictionary:
	return assets.get(key, {})

func bounds_for_variant(value: Dictionary) -> AABB:
	var result := AABB()
	var first: bool = true
	for level in value.lods:
		var low: Array = level.render_aabb_y_up.min
		var high: Array = level.render_aabb_y_up.max
		var origin := Vector3(float(low[0]), float(low[1]), float(low[2]))
		var end := Vector3(float(high[0]), float(high[1]), float(high[2]))
		var box := AABB(origin, end - origin)
		result = box if first else result.merge(box)
		first = false
	return result
