extends RefCounted
## Pure normalized plant layout shared by renderer projections.
## Inputs are a validated presentation profile and deterministic tree seed.
const Profiles=preload("res://presentation/northstar/foliage/plant_form_profiles.gd")

static func phase_for_seed(tree_seed:int,profile:Dictionary)->float:
	assert(Profiles.input_error(profile).is_empty())
	var rng:=RandomNumberGenerator.new();rng.seed=tree_seed+int(profile.seed_offset)
	return rng.randf()*TAU

static func anchors(profile:Dictionary,phase:float)->Array[Dictionary]:
	assert(Profiles.input_error(profile).is_empty())
	var f:Dictionary=profile.families
	var result:Array[Dictionary]=[]
	for j in int(profile.family_count):
		var angle:float=phase+float(f.angle_offsets[j])
		var direction:=Vector3(cos(angle),0.,sin(angle))
		var side:=Vector3(-sin(angle),0.,cos(angle))
		var center:=direction*float(f.reaches[j]);center.y=float(f.levels[j])
		result.append({"position":center,"angle":angle,"family_angle":angle,"scale":float(f.primary_scale),"tilt":float(f.primary_tilt),"role":"primary","family":j})
		var sign:float=-1. if j%2==0 else 1.
		var at:=center+side*float(f.secondary_lateral)*sign-direction*float(f.secondary_back)
		at.y+=float(f.secondary_height)
		result.append({"position":at,"angle":angle+float(f.secondary_angle_delta)*sign,"family_angle":angle,"scale":float(f.secondary_scale),"tilt":float(f.secondary_tilt)*sign,"role":"secondary","family":j})
	var inner:Dictionary=profile.inner
	for i in inner.angle_offsets.size():
		var angle:float=phase+float(inner.angle_offsets[i])
		var at:=Vector3(cos(angle)*float(inner.radius),float(inner.levels[i]),sin(angle)*float(inner.radius))
		result.append({"position":at,"angle":angle,"family_angle":angle,"scale":float(inner.scale),"tilt":float(inner.tilt),"role":"secondary","family":-1})
	var leader:Dictionary=profile.leader
	var leader_angle:float=phase+float(leader.angle_offset)
	result.append({"position":Vector3(cos(leader_angle)*float(leader.radius),float(leader.level),sin(leader_angle)*float(leader.radius)),"angle":leader_angle,"family_angle":leader_angle,"scale":float(leader.scale),"tilt":float(leader.tilt),"role":"leader","family":-1})
	return result

static func scaffold_paths(profile:Dictionary,phase:float)->Array[Dictionary]:
	assert(Profiles.input_error(profile).is_empty())
	var trunk_spec:Dictionary=profile.trunk;var scaffold:Dictionary=profile.scaffold;var f:Dictionary=profile.families
	var trunk:=PackedVector3Array()
	for point in trunk_spec.points:trunk.append(_v3(point))
	var result:Array[Dictionary]=[
		{"role":"trunk","points":trunk,"start_radius":float(trunk_spec.start_radius),"end_radius":float(trunk_spec.end_radius)}
	]
	for j in int(profile.family_count):
		var angle:float=phase+float(f.angle_offsets[j])
		var direction:=Vector3(cos(angle),0.,sin(angle))
		var side:=Vector3(-sin(angle),0.,cos(angle))
		var reach:float=float(f.reaches[j]);var level:float=float(f.levels[j])
		var center:=direction*reach;center.y=level
		var start:Vector3=trunk[int(scaffold.primary_start_indices[j])]
		var side_sign:=1. if j%2==0 else -1.
		var mid1:=direction*(reach*float(scaffold.mid1_radial))+side*(float(scaffold.mid1_side)*side_sign);mid1.y=float(scaffold.mid1_level)
		var mid2:=direction*(reach*float(scaffold.mid2_radial))+side*(float(scaffold.mid2_side)*side_sign);mid2.y=level*float(scaffold.mid2_level_factor)
		result.append({"role":"primary","family":j,"points":PackedVector3Array([start,mid1,mid2,center]),"start_radius":float(scaffold.primary_start_radius),"end_radius":float(scaffold.primary_end_radius)})
		var sign:float=-1. if j%2==0 else 1.
		var secondary:=center+side*float(f.secondary_lateral)*sign-direction*float(f.secondary_back);secondary.y+=float(f.secondary_height)
		result.append({"role":"secondary","family":j,"points":PackedVector3Array([mid2,center.lerp(secondary,.52),secondary]),"start_radius":float(scaffold.secondary_start_radius),"end_radius":float(scaffold.secondary_end_radius)})
	var inner:Dictionary=profile.inner
	for i in inner.angle_offsets.size():
		var angle:float=phase+float(inner.angle_offsets[i])
		var target:=Vector3(cos(angle)*float(inner.radius),float(inner.levels[i]),sin(angle)*float(inner.radius))
		result.append({"role":"inner","family":-1,"points":PackedVector3Array([trunk[3],Vector3(target.x*float(scaffold.inner_mid_radial_factor),float(scaffold.inner_mid_level),target.z*float(scaffold.inner_mid_radial_factor)),target]),"start_radius":float(scaffold.inner_start_radius),"end_radius":float(scaffold.inner_end_radius)})
	var leader:Dictionary=profile.leader
	var leader_angle:float=phase+float(leader.angle_offset)
	var leader_point:=Vector3(cos(leader_angle)*float(leader.radius),float(leader.level),sin(leader_angle)*float(leader.radius))
	result.append({"role":"leader","family":-1,"points":PackedVector3Array([trunk[4],Vector3(leader_point.x*float(scaffold.leader_mid_radial_factor),float(scaffold.leader_mid_level),leader_point.z*float(scaffold.leader_mid_radial_factor)),leader_point]),"start_radius":float(scaffold.leader_start_radius),"end_radius":float(scaffold.leader_end_radius)})
	return result

static func plan_lobes(profile:Dictionary,phase:float)->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	var radius_factor:=float(profile.group.radius_factor)
	for anchor in anchors(profile,phase):
		var p:Vector3=anchor.position
		result.append({
			"center":Vector2(p.x,p.z),
			"radius":radius_factor*float(anchor.scale),
			"angle":float(anchor.angle),
			"family_angle":float(anchor.family_angle),
			"role":str(anchor.role),
			"family":int(anchor.family)
		})
	return result

static func _v3(value:Array)->Vector3:return Vector3(float(value[0]),float(value[1]),float(value[2]))
