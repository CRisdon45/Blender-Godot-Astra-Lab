extends Node3D
## One generic two-mesh tree builder consuming normalized morphology profiles.
## Horticultural facts remain outside this presentation layer.
const Group = preload("res://presentation/northstar/foliage/dab_group.gd")
const Paint = preload("res://presentation/northstar/foliage/batched_dab_value.gdshader")
const Profiles = preload("res://presentation/northstar/foliage/plant_form_profiles.gd")

var descriptor:Dictionary={}
var form_profile:Dictionary={}
var foliage:MeshInstance3D
var wood:MeshInstance3D
var stats:Dictionary={}
var _family_angles:=PackedFloat32Array()
var _wv:=PackedVector3Array()
var _wn:=PackedVector3Array()
var _wi:=PackedInt32Array()
var _fv:=PackedVector3Array()
var _fn:=PackedVector3Array()
var _fi:=PackedInt32Array()
var _fc:=PackedColorArray()
var _fuv:=PackedVector2Array()
var _fuv2:=PackedVector2Array()
var _height:=1.0
var _radius:=1.0

func configure(tree:Dictionary, profile:Dictionary)->void:
	assert(get_child_count()==0)
	assert(Profiles.input_error(profile).is_empty())
	descriptor=tree.duplicate(true);form_profile=profile.duplicate(true)
	_height=float(tree.height);_radius=float(tree.crown_radius)
	position=Vector3(tree.x,tree.base_elevation,-tree.y)
	var rng:=RandomNumberGenerator.new();rng.seed=int(tree.seed)+int(profile.seed_offset)
	var phase:=rng.randf()*TAU
	_build_scaffold(phase)
	var anchors:=_anchors(phase)
	var group_radius:=_radius*float(profile.group.radius_factor)
	var group_height:=_height*float(profile.group.height_factor)
	for i in anchors.size():
		var anchor:Dictionary=anchors[i]
		var group:=Group.new();group.configure(int(tree.seed)+int(profile.group_seed_stride)*(i+1),group_radius,group_height)
		var bounds:AABB=group.foliage.mesh.get_aabb().merge(group.twig.mesh.get_aabb())
		var p:Vector3=anchor.position
		var target:=Vector3(p.x*_radius,p.y*_height,p.z*_radius)
		group.scale=Vector3.ONE*float(anchor.scale)
		group.rotation.y=float(anchor.angle);group.rotation.z=float(anchor.tilt)
		group.position=target-group.basis*bounds.get_center()
		_append_wood(group.twig,group.transform)
		_append_foliage(group.foliage,group.transform,float(anchor.family_angle),str(anchor.role))
		group.free()
	wood=_finish_wood();foliage=_finish_foliage()
	var wa:=wood.mesh.get_aabb();var fa:=foliage.mesh.get_aabb()
	stats={
		"profile":str(profile.id),
		"groups":anchors.size(),
		"families":int(profile.family_count),
		"visible_meshes":2,
		"visible_triangles":_triangle_count(wood.mesh)+_triangle_count(foliage.mesh),
		"wood_triangles":_triangle_count(wood.mesh),
		"foliage_triangles":_triangle_count(foliage.mesh),
		"foliage_width":maxf(fa.size.x,fa.size.z),
		"foliage_depth":minf(fa.size.x,fa.size.z),
		"foliage_height":fa.size.y,
		"overall_height":wa.merge(fa).size.y,
		"alpha_blended":false,
		"source_record_unchanged":true,
		"profile_schema":str(profile.schema)
	}

func _anchors(phase:float)->Array[Dictionary]:
	var p:=form_profile;var f:Dictionary=p.families
	var result:Array[Dictionary]=[]
	for j in int(p.family_count):
		var angle:float=phase+float(f.angle_offsets[j])
		var direction:=Vector3(cos(angle),0.,sin(angle))
		var side:=Vector3(-sin(angle),0.,cos(angle))
		var center:=direction*float(f.reaches[j]);center.y=float(f.levels[j])
		result.append({"position":center,"angle":angle,"family_angle":angle,"scale":float(f.primary_scale),"tilt":float(f.primary_tilt),"role":"primary"})
		var sign:float=-1. if j%2==0 else 1.
		var at:=center+side*float(f.secondary_lateral)*sign-direction*float(f.secondary_back)
		at.y+=float(f.secondary_height)
		result.append({"position":at,"angle":angle+float(f.secondary_angle_delta)*sign,"family_angle":angle,"scale":float(f.secondary_scale),"tilt":float(f.secondary_tilt)*sign,"role":"secondary"})
	var inner:Dictionary=p.inner
	for i in inner.angle_offsets.size():
		var angle:float=phase+float(inner.angle_offsets[i])
		var at:=Vector3(cos(angle)*float(inner.radius),float(inner.levels[i]),sin(angle)*float(inner.radius))
		result.append({"position":at,"angle":angle,"family_angle":angle,"scale":float(inner.scale),"tilt":float(inner.tilt),"role":"secondary"})
	var leader:Dictionary=p.leader
	var leader_angle:float=phase+float(leader.angle_offset)
	result.append({"position":Vector3(cos(leader_angle)*float(leader.radius),float(leader.level),sin(leader_angle)*float(leader.radius)),"angle":leader_angle,"family_angle":leader_angle,"scale":float(leader.scale),"tilt":float(leader.tilt),"role":"leader"})
	return result

func _build_scaffold(phase:float)->void:
	var p:=form_profile;var trunk_spec:Dictionary=p.trunk;var scaffold:Dictionary=p.scaffold;var f:Dictionary=p.families
	var trunk:=PackedVector3Array()
	for point in trunk_spec.points:trunk.append(_v3(point))
	_tube(trunk,float(trunk_spec.start_radius),float(trunk_spec.end_radius))
	for j in int(p.family_count):
		var angle:float=phase+float(f.angle_offsets[j])
		var direction:=Vector3(cos(angle),0.,sin(angle))
		var side:=Vector3(-sin(angle),0.,cos(angle))
		var reach:float=float(f.reaches[j]);var level:float=float(f.levels[j])
		var center:=direction*reach;center.y=level
		var start:Vector3=trunk[int(scaffold.primary_start_indices[j])]
		var side_sign:=1. if j%2==0 else -1.
		var mid1:=direction*(reach*float(scaffold.mid1_radial))+side*(float(scaffold.mid1_side)*side_sign);mid1.y=float(scaffold.mid1_level)
		var mid2:=direction*(reach*float(scaffold.mid2_radial))+side*(float(scaffold.mid2_side)*side_sign);mid2.y=level*float(scaffold.mid2_level_factor)
		_tube(PackedVector3Array([start,mid1,mid2,center]),float(scaffold.primary_start_radius),float(scaffold.primary_end_radius))
		var sign:float=-1. if j%2==0 else 1.
		var secondary:=center+side*float(f.secondary_lateral)*sign-direction*float(f.secondary_back);secondary.y+=float(f.secondary_height)
		_tube(PackedVector3Array([mid2,center.lerp(secondary,.52),secondary]),float(scaffold.secondary_start_radius),float(scaffold.secondary_end_radius))
	var inner:Dictionary=p.inner
	for i in inner.angle_offsets.size():
		var angle:float=phase+float(inner.angle_offsets[i])
		var target:=Vector3(cos(angle)*float(inner.radius),float(inner.levels[i]),sin(angle)*float(inner.radius))
		_tube(PackedVector3Array([trunk[3],Vector3(target.x*float(scaffold.inner_mid_radial_factor),float(scaffold.inner_mid_level),target.z*float(scaffold.inner_mid_radial_factor)),target]),float(scaffold.inner_start_radius),float(scaffold.inner_end_radius))
	var leader:Dictionary=p.leader
	var leader_angle:float=phase+float(leader.angle_offset)
	var leader_point:=Vector3(cos(leader_angle)*float(leader.radius),float(leader.level),sin(leader_angle)*float(leader.radius))
	_tube(PackedVector3Array([trunk[4],Vector3(leader_point.x*float(scaffold.leader_mid_radial_factor),float(scaffold.leader_mid_level),leader_point.z*float(scaffold.leader_mid_radial_factor)),leader_point]),float(scaffold.leader_start_radius),float(scaffold.leader_end_radius))

func _v3(value:Array)->Vector3:return Vector3(float(value[0]),float(value[1]),float(value[2]))
func _point(p:Vector3)->Vector3:return Vector3(p.x*_radius,p.y*_height,p.z*_radius)

func _tube(path:PackedVector3Array,start_radius:float,end_radius:float)->void:
	var first:=_wv.size();var sides:=7
	for j in path.size():
		var at:=_point(path[j])
		var before:=_point(path[maxi(0,j-1)]);var after:=_point(path[mini(path.size()-1,j+1)])
		var tangent:Vector3=(after-before).normalized()
		var x:=tangent.cross(Vector3.FORWARD).normalized()
		if x.length_squared()<.1:x=tangent.cross(Vector3.RIGHT).normalized()
		var z:=tangent.cross(x).normalized()
		var rr:=lerpf(start_radius,end_radius,float(j)/float(path.size()-1))*_radius
		for k in sides:
			var n:=x*cos(TAU*k/sides)+z*sin(TAU*k/sides)
			_wv.append(at+n*rr);_wn.append(n)
	for j in path.size()-1:
		for k in sides:
			var a:=first+j*sides+k;var b:=first+j*sides+(k+1)%sides;var c:=a+sides;var d:=b+sides
			_wi.append_array(PackedInt32Array([a,c,b,b,c,d]))
	for k in range(1,sides-1):
		_wi.append_array(PackedInt32Array([first,first+k,first+k+1]))
		var e:=first+(path.size()-1)*sides
		_wi.append_array(PackedInt32Array([e,e+k+1,e+k]))

func _append_wood(node:MeshInstance3D,xform:Transform3D)->void:
	var arrays:Array=node.mesh.surface_get_arrays(0);var offset:=_wv.size()
	for i in arrays[Mesh.ARRAY_VERTEX].size():
		_wv.append(xform*arrays[Mesh.ARRAY_VERTEX][i])
		_wn.append((xform.basis*arrays[Mesh.ARRAY_NORMAL][i]).normalized())
	for index in arrays[Mesh.ARRAY_INDEX]:_wi.append(offset+int(index))

func _append_foliage(node:MeshInstance3D,xform:Transform3D,family_angle:float,role:String)->void:
	var arrays:Array=node.mesh.surface_get_arrays(0);var offset:=_fv.size()
	var role_code:=1.0 if role=="leader" else .75 if role=="primary" else .25
	_family_angles.append(family_angle)
	for i in arrays[Mesh.ARRAY_VERTEX].size():
		var local:Vector3=arrays[Mesh.ARRAY_VERTEX][i]
		_fv.append(xform*local);_fn.append((xform.basis*arrays[Mesh.ARRAY_NORMAL][i]).normalized())
		var source_color:Color=arrays[Mesh.ARRAY_COLOR][i]
		_fc.append(Color(source_color.r,0,0,role_code))
		_fuv.append(Vector2(local.x,local.z));_fuv2.append(Vector2(local.y,family_angle))
	for index in arrays[Mesh.ARRAY_INDEX]:_fi.append(offset+int(index))

func _finish_wood()->MeshInstance3D:
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=_wv;arrays[Mesh.ARRAY_NORMAL]=_wn;arrays[Mesh.ARRAY_INDEX]=_wi
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node:=MeshInstance3D.new();node.name="ProfiledWood";node.mesh=mesh
	var bark:=StandardMaterial3D.new();bark.albedo_color=Color(str(form_profile.bark_hex));bark.roughness=1.;node.material_override=bark;add_child(node);return node

func _finish_foliage()->MeshInstance3D:
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=_fv;arrays[Mesh.ARRAY_NORMAL]=_fn;arrays[Mesh.ARRAY_INDEX]=_fi;arrays[Mesh.ARRAY_COLOR]=_fc;arrays[Mesh.ARRAY_TEX_UV]=_fuv;arrays[Mesh.ARRAY_TEX_UV2]=_fuv2
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node:=MeshInstance3D.new();node.name="ProfiledFoliage";node.mesh=mesh
	var material:=ShaderMaterial.new();material.shader=Paint;node.material_override=material;add_child(node);return node

func _triangle_count(mesh:Mesh)->int:
	var arrays:Array=mesh.surface_get_arrays(0);return int(arrays[Mesh.ARRAY_INDEX].size()/3)

func set_light_values(direction:Vector2)->void:
	var d:=direction
	if d.length_squared()<1e-8:d=Vector2(0,-1)
	d=d.normalized()
	var family_count:=int(form_profile.family_count);var sum:=0.0
	for j in family_count:
		var angle:=_family_angles[j*2]
		var alignment:=Vector2(cos(angle),sin(angle)).dot(d)
		if alignment>.28:sum+=.095
		elif alignment<-.28:sum-=.095
	var material:ShaderMaterial=foliage.material_override
	material.set_shader_parameter("sun_direction",d)
	material.set_shader_parameter("leader_family_value",sum/float(family_count))

func geometry_signature()->String:
	return var_to_bytes([descriptor,wood.mesh.surface_get_arrays(0),foliage.mesh.surface_get_arrays(0)]).hex_encode().sha256_text()
