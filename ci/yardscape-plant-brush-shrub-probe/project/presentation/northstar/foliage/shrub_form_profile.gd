extends RefCounted
## Presentation-only generic shrub archetype using the retained profile schema.

const Profiles=preload("res://presentation/northstar/foliage/plant_form_profiles.gd")

static func dense_desert_mound_v1()->Dictionary:
	var profile:={
		"schema":Profiles.SCHEMA,
		"id":"dense-desert-shrub-mound/1",
		"family_count":7,
		"seed_offset":73129,
		"group_seed_stride":156007,
		"group":{"radius_factor":.42,"height_factor":.26},
		"families":{
			"angle_offsets":[0.0,.88,1.79,2.69,3.58,4.49,5.39],
			"reaches":[.57,.61,.55,.62,.58,.60,.56],
			"levels":[.45,.50,.47,.52,.46,.51,.48],
			"primary_scale":1.02,
			"primary_tilt":.20,
			"secondary_lateral":.22,
			"secondary_back":.035,
			"secondary_height":.045,
			"secondary_scale":.86,
			"secondary_angle_delta":.41,
			"secondary_tilt":.27
		},
		"inner":{
			"angle_offsets":[.43,1.98,3.55,5.08],
			"levels":[.55,.59,.57,.60],
			"radius":.16,
			"scale":.91,
			"tilt":.10
		},
		"leader":{
			"angle_offset":.16,
			"radius":.025,
			"level":.67,
			"scale":.77,
			"tilt":.02
		},
		"trunk":{
			"points":[[0.0,0.0,0.0],[.012,.055,-.010],[-.010,.115,.014],[.014,.175,-.012],[-.006,.225,.008]],
			"start_radius":.055,
			"end_radius":.016
		},
		"scaffold":{
			"primary_start_indices":[1,1,1,2,1,2,1],
			"mid1_radial":.25,
			"mid1_side":.045,
			"mid1_level":.18,
			"mid2_radial":.58,
			"mid2_side":.052,
			"mid2_level_factor":.74,
			"primary_start_radius":.026,
			"primary_end_radius":.006,
			"secondary_start_radius":.012,
			"secondary_end_radius":.0025,
			"inner_mid_radial_factor":.54,
			"inner_mid_level":.34,
			"inner_start_radius":.014,
			"inner_end_radius":.003,
			"leader_mid_radial_factor":.62,
			"leader_mid_level":.43,
			"leader_start_radius":.014,
			"leader_end_radius":.003
		},
		"bark_hex":"756653"
	}
	assert(Profiles.input_error(profile).is_empty())
	return profile
