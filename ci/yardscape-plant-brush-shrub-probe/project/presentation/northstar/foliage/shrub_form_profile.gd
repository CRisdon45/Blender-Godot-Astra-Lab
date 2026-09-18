extends RefCounted
## Presentation-only generic shrub archetype using the retained profile schema.

const Profiles=preload("res://presentation/northstar/foliage/plant_form_profiles.gd")

static func dense_desert_mound_v2()->Dictionary:
	var profile:={
		"schema":Profiles.SCHEMA,
		"id":"dense-desert-shrub-mound/2",
		"family_count":6,
		"seed_offset":73129,
		"group_seed_stride":156007,
		"group":{"radius_factor":.44,"height_factor":.34},
		"families":{
			"angle_offsets":[0.0,1.03,2.08,3.14,4.18,5.25],
			"reaches":[.58,.62,.56,.63,.59,.61],
			"levels":[.27,.32,.29,.34,.28,.31],
			"primary_scale":1.00,
			"primary_tilt":.10,
			"secondary_lateral":.19,
			"secondary_back":.025,
			"secondary_height":.025,
			"secondary_scale":.88,
			"secondary_angle_delta":.38,
			"secondary_tilt":.18
		},
		"inner":{
			"angle_offsets":[.48,2.03,3.57,5.12],
			"levels":[.35,.39,.36,.40],
			"radius":.10,
			"scale":1.03,
			"tilt":.045
		},
		"leader":{
			"angle_offset":.16,
			"radius":.015,
			"level":.46,
			"scale":.86,
			"tilt":.0
		},
		"trunk":{
			"points":[[0.0,0.0,0.0],[.008,.030,-.007],[-.007,.062,.009],[.009,.095,-.008],[-.004,.125,.005]],
			"start_radius":.050,
			"end_radius":.013
		},
		"scaffold":{
			"primary_start_indices":[1,1,1,1,1,1],
			"mid1_radial":.29,
			"mid1_side":.045,
			"mid1_level":.085,
			"mid2_radial":.60,
			"mid2_side":.048,
			"mid2_level_factor":.70,
			"primary_start_radius":.022,
			"primary_end_radius":.005,
			"secondary_start_radius":.010,
			"secondary_end_radius":.002,
			"inner_mid_radial_factor":.58,
			"inner_mid_level":.21,
			"inner_start_radius":.012,
			"inner_end_radius":.003,
			"leader_mid_radial_factor":.62,
			"leader_mid_level":.29,
			"leader_start_radius":.012,
			"leader_end_radius":.003
		},
		"bark_hex":"756653"
	}
	assert(Profiles.input_error(profile).is_empty())
	return profile
