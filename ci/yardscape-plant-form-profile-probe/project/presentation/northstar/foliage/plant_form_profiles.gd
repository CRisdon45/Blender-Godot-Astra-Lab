extends RefCounted
## Normalized presentation-form data only. No mature size, growth, water,
## phenology or other horticultural facts belong in this profile.
const SCHEMA := "plant-form-profile/1"

static func fan_tex_ash_v2() -> Dictionary:
	return {
		"schema": SCHEMA,
		"id": "fan-tex-ash-macro-form/2",
		"family_count": 6,
		"seed_offset": 44041,
		"group_seed_stride": 104729,
		"group": {"radius_factor": .56, "height_factor": .29},
		"families": {
			"angle_offsets": [0.0,1.01,2.09,3.13,4.19,5.28],
			"reaches": [.60,.64,.61,.65,.59,.63],
			"levels": [.60,.64,.61,.66,.63,.67],
			"primary_scale": 1.08,
			"primary_tilt": .055,
			"secondary_lateral": .20,
			"secondary_back": .075,
			"secondary_height": .080,
			"secondary_scale": .90,
			"secondary_angle_delta": .30,
			"secondary_tilt": .13
		},
		"inner": {
			"angle_offsets": [.62,2.74,4.83],
			"levels": [.72,.76,.73],
			"radius": .18,
			"scale": 1.08,
			"tilt": .035
		},
		"leader": {
			"angle_offset": .22,
			"radius": .03,
			"level": .84,
			"scale": 1.00,
			"tilt": -.02
		},
		"trunk": {
			"points": [[0.0,0.0,0.0],[.008,.18,-.006],[-.012,.34,.010],[.014,.46,-.008],[-.006,.55,.004]],
			"start_radius": .080,
			"end_radius": .030
		},
		"scaffold": {
			"primary_start_indices": [2,3,3,2,3,3],
			"mid1_radial": .20,
			"mid1_side": .025,
			"mid1_level": .46,
			"mid2_radial": .52,
			"mid2_side": .032,
			"mid2_level_factor": .78,
			"primary_start_radius": .032,
			"primary_end_radius": .009,
			"secondary_start_radius": .015,
			"secondary_end_radius": .004,
			"inner_mid_radial_factor": .42,
			"inner_mid_level": .59,
			"inner_start_radius": .017,
			"inner_end_radius": .004,
			"leader_mid_radial_factor": .70,
			"leader_mid_level": .70,
			"leader_start_radius": .020,
			"leader_end_radius": .005
		},
		"bark_hex": "6d665a"
	}

static func desert_museum_palo_verde_v1() -> Dictionary:
	return {
		"schema": SCHEMA,
		"id": "desert-museum-palo-verde-macro-form/1",
		"family_count": 5,
		"seed_offset": 55117,
		"group_seed_stride": 130363,
		"group": {"radius_factor": .46, "height_factor": .24},
		"families": {
			"angle_offsets": [0.0,1.18,2.43,3.67,5.04],
			"reaches": [.72,.78,.74,.80,.70],
			"levels": [.56,.62,.58,.66,.60],
			"primary_scale": .86,
			"primary_tilt": .11,
			"secondary_lateral": .30,
			"secondary_back": .03,
			"secondary_height": .11,
			"secondary_scale": .66,
			"secondary_angle_delta": .42,
			"secondary_tilt": .22
		},
		"inner": {
			"angle_offsets": [1.95,4.35],
			"levels": [.73,.78],
			"radius": .30,
			"scale": .68,
			"tilt": .12
		},
		"leader": {
			"angle_offset": .35,
			"radius": .10,
			"level": .87,
			"scale": .64,
			"tilt": .05
		},
		"trunk": {
			"points": [[0.0,0.0,0.0],[.015,.15,-.010],[-.025,.29,.020],[.035,.40,-.018],[-.015,.50,.025]],
			"start_radius": .075,
			"end_radius": .026
		},
		"scaffold": {
			"primary_start_indices": [1,2,2,3,3],
			"mid1_radial": .24,
			"mid1_side": .05,
			"mid1_level": .38,
			"mid2_radial": .58,
			"mid2_side": .06,
			"mid2_level_factor": .80,
			"primary_start_radius": .026,
			"primary_end_radius": .006,
			"secondary_start_radius": .012,
			"secondary_end_radius": .003,
			"inner_mid_radial_factor": .50,
			"inner_mid_level": .56,
			"inner_start_radius": .014,
			"inner_end_radius": .003,
			"leader_mid_radial_factor": .68,
			"leader_mid_level": .67,
			"leader_start_radius": .016,
			"leader_end_radius": .004
		},
		"bark_hex": "65a94f"
	}

static func input_error(profile: Dictionary) -> String:
	var required := ["schema","id","family_count","seed_offset","group_seed_stride","group","families","inner","leader","trunk","scaffold","bark_hex"]
	for key in required:
		if not profile.has(key): return "missing_" + str(key)
	if profile.schema != SCHEMA: return "schema"
	if not profile.id is String or profile.id.is_empty(): return "id"
	if not profile.family_count is int or int(profile.family_count) < 3: return "family_count"
	if not profile.seed_offset is int or not profile.group_seed_stride is int: return "seed"
	if not profile.group is Dictionary or not profile.families is Dictionary or not profile.inner is Dictionary or not profile.leader is Dictionary or not profile.trunk is Dictionary or not profile.scaffold is Dictionary: return "section"
	var count := int(profile.family_count)
	if not _number_array(profile.families.get("angle_offsets",[]),count): return "family_angles"
	if not _number_array(profile.families.get("reaches",[]),count): return "family_reaches"
	if not _number_array(profile.families.get("levels",[]),count): return "family_levels"
	if not _number_array(profile.scaffold.get("primary_start_indices",[]),count,true): return "start_indices"
	if not _number_array(profile.inner.get("angle_offsets",[]),-1) or profile.inner.angle_offsets.is_empty(): return "inner_angles"
	if not _number_array(profile.inner.get("levels",[]),profile.inner.angle_offsets.size()): return "inner_levels"
	var points: Variant = profile.trunk.get("points")
	if not points is Array or points.size() < 3: return "trunk_points"
	for point in points:
		if not point is Array or not _number_array(point,3): return "trunk_point"
	var numeric_paths := [
		["group","radius_factor"],["group","height_factor"],
		["families","primary_scale"],["families","primary_tilt"],
		["families","secondary_lateral"],["families","secondary_back"],["families","secondary_height"],
		["families","secondary_scale"],["families","secondary_angle_delta"],["families","secondary_tilt"],
		["inner","radius"],["inner","scale"],["inner","tilt"],
		["leader","angle_offset"],["leader","radius"],["leader","level"],["leader","scale"],["leader","tilt"],
		["trunk","start_radius"],["trunk","end_radius"],
		["scaffold","mid1_radial"],["scaffold","mid1_side"],["scaffold","mid1_level"],
		["scaffold","mid2_radial"],["scaffold","mid2_side"],["scaffold","mid2_level_factor"],
		["scaffold","primary_start_radius"],["scaffold","primary_end_radius"],
		["scaffold","secondary_start_radius"],["scaffold","secondary_end_radius"],
		["scaffold","inner_mid_radial_factor"],["scaffold","inner_mid_level"],
		["scaffold","inner_start_radius"],["scaffold","inner_end_radius"],
		["scaffold","leader_mid_radial_factor"],["scaffold","leader_mid_level"],
		["scaffold","leader_start_radius"],["scaffold","leader_end_radius"]
	]
	for path in numeric_paths:
		var section: Dictionary = profile[path[0]]
		var value: Variant = section.get(path[1])
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)): return "number_" + str(path[0]) + "_" + str(path[1])
	if float(profile.group.radius_factor) <= 0. or float(profile.group.height_factor) <= 0.: return "group_size"
	if float(profile.families.primary_scale) <= 0. or float(profile.families.secondary_scale) <= 0. or float(profile.inner.scale) <= 0. or float(profile.leader.scale) <= 0.: return "scale"
	if not profile.bark_hex is String or profile.bark_hex.length() != 6: return "bark"
	for index in profile.scaffold.primary_start_indices:
		if int(index) < 0 or int(index) >= points.size(): return "start_index_range"
	return ""

static func _number_array(value: Variant, expected: int, integer_only := false) -> bool:
	if not value is Array: return false
	if expected >= 0 and value.size() != expected: return false
	for item in value:
		if integer_only:
			if not item is int: return false
		else:
			if typeof(item) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(item)): return false
	return true
