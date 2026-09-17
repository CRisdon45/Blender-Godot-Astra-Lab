extends Node3D
## Presentation-only species-form study. The authoritative tree record remains
## untouched; this profile changes crown/scaffold organization, not horticultural data.
const Group = preload("res://presentation/northstar/foliage/dab_group.gd")
const Paint = preload("res://presentation/northstar/foliage/batched_dab_value.gdshader")
const PROFILE_ID := "fan-tex-ash-macro-form/1"

var descriptor:Dictionary={}
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

func configure(t:Dictionary)->void:
	assert(get_child_count()==0)
	descriptor=t.duplicate(true);_height=float(t.height);_radius=float(t.crown_radius)
	position=Vector3(t.x,t.base_elevation,-t.y)
	var rng:=RandomNumberGenerator.new();rng.seed=int(t.seed)+44041
	var phase:=rng.randf()*TAU
	_build_scaffold(phase)
	var anchors:=_anchors(phase)
	var group_radius:=_radius*.56
	var group_height:=_height*.29
	for i in anchors.size():
		var anchor:Dictionary=anchors[i]
		var group:=Group.new();group.configure(int(t.seed)+104729*(i+1),group_radius,group_height)
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
		"profile":PROFILE_ID,
		"groups":anchors.size(),
		"families":6,
		"visible_meshes":2,
		"visible_triangles":_triangle_count(wood.mesh)+_triangle_count(foliage.mesh),
		"wood_triangles":_triangle_count(wood.mesh),
		"foliage_triangles":_triangle_count(foliage.mesh),
		"foliage_width":maxf(fa.size.x,fa.size.z),
		"foliage_depth":minf(fa.size.x,fa.size.z),
		"foliage_height":fa.size.y,
		"overall_height":wa.merge(fa).size.y,
		"alpha_blended":false,
		"source_record_unchanged":true
	}

func _anchors(phase:float)->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	var offsets=[0.0,1.01,2.09,3.13,4.19,5.28]
	var reaches=[.60,.64,.61,.65,.59,.63]
	var levels=[.62,.67,.64,.70,.66,.71]
	for j in 6:
		var angle:float=phase+float(offsets[j])
		var direction:=Vector3(cos(angle),0.,sin(angle))
		var side:=Vector3(-sin(angle),0.,cos(angle))
		var center:=direction*float(reaches[j]);center.y=float(levels[j])
		result.append({"position":center,"angle":angle,"family_angle":angle,"scale":1.03,"tilt":.07,"role":"primary"})
		var sign:float=-1. if j%2==0 else 1.
		var at:=center+side*.22*sign-direction*.08
		at.y+=.105
		result.append({"position":at,"angle":angle+.34*sign,"family_angle":angle,"scale":.84,"tilt":.16*sign,"role":"secondary"})
	var inner_angles=[phase+.62,phase+2.74,phase+4.83]
	var inner_levels=[.78,.82,.77]
	for i in 3:
		var angle:float=float(inner_angles[i])
		var at:=Vector3(cos(angle)*.27,float(inner_levels[i]),sin(angle)*.27)
		result.append({"position":at,"angle":angle,"family_angle":angle,"scale":.90,"tilt":.05,"role":"secondary"})
	var leader_angle:=phase+.22
	result.append({"position":Vector3(cos(leader_angle)*.055,.91,sin(leader_angle)*.055),"angle":leader_angle,"family_angle":leader_angle,"scale":.88,"tilt":-.03,"role":"leader"})
	return result

func _build_scaffold(phase:float)->void:
	var trunk:=PackedVector3Array([
		Vector3.ZERO,Vector3(.008,.18,-.006),Vector3(-.012,.34,.010),
		Vector3(.014,.47,-.008),Vector3(-.006,.58,.004)
	])
	_tube(trunk,.080,.030)
	var offsets=[0.0,1.01,2.09,3.13,4.19,5.28]
	var reaches=[.60,.64,.61,.65,.59,.63]
	var levels=[.62,.67,.64,.70,.66,.71]
	for j in 6:
		var angle:float=phase+float(offsets[j])
		var direction:=Vector3(cos(angle),0.,sin(angle))
		var side:=Vector3(-sin(angle),0.,cos(angle))
		var reach:float=float(reaches[j]);var level:float=float(levels[j])
		var center:=direction*reach;center.y=level
		var start:=trunk[2] if j%3==0 else trunk[3]
		var mid1:=direction*(reach*.20)+side*(.025 if j%2==0 else -.025);mid1.y=.48
		var mid2:=direction*(reach*.52)+side*(.035 if j%2==0 else -.035);mid2.y=level*.78
		_tube(PackedVector3Array([start,mid1,mid2,center]),.032,.009)
		var sign:float=-1. if j%2==0 else 1.
		var secondary:=center+side*.22*sign-direction*.08;secondary.y+=.105
		_tube(PackedVector3Array([mid2,center.lerp(secondary,.52),secondary]),.015,.004)
	var inner_angles=[phase+.62,phase+2.74,phase+4.83]
	var inner_levels=[.78,.82,.77]
	for i in 3:
		var angle:float=float(inner_angles[i])
		var target:=Vector3(cos(angle)*.27,float(inner_levels[i]),sin(angle)*.27)
		_tube(PackedVector3Array([trunk[3],Vector3(target.x*.42,.62,target.z*.42),target]),.017,.004)
	var leader_angle:=phase+.22
	var leader:=Vector3(cos(leader_angle)*.055,.91,sin(leader_angle)*.055)
	_tube(PackedVector3Array([trunk[4],Vector3(leader.x*.7,.74,leader.z*.7),leader]),.020,.005)

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
	var node:=MeshInstance3D.new();node.name="FanTexWood";node.mesh=mesh
	var bark:=StandardMaterial3D.new();bark.albedo_color=Color("6d665a");bark.roughness=1.;node.material_override=bark;add_child(node);return node

func _finish_foliage()->MeshInstance3D:
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=_fv;arrays[Mesh.ARRAY_NORMAL]=_fn;arrays[Mesh.ARRAY_INDEX]=_fi;arrays[Mesh.ARRAY_COLOR]=_fc;arrays[Mesh.ARRAY_TEX_UV]=_fuv;arrays[Mesh.ARRAY_TEX_UV2]=_fuv2
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node:=MeshInstance3D.new();node.name="FanTexFoliage";node.mesh=mesh
	var material:=ShaderMaterial.new();material.shader=Paint;node.material_override=material;add_child(node);return node

func _triangle_count(mesh:Mesh)->int:
	var arrays:Array=mesh.surface_get_arrays(0);return int(arrays[Mesh.ARRAY_INDEX].size()/3)

func set_light_values(direction:Vector2)->void:
	var d:=direction
	if d.length_squared()<1e-8:d=Vector2(0,-1)
	d=d.normalized()
	var sum:=0.0
	for j in 6:
		var angle:=_family_angles[j*2]
		var alignment:=Vector2(cos(angle),sin(angle)).dot(d)
		if alignment>.28:sum+=.095
		elif alignment<-.28:sum-=.095
	var material:ShaderMaterial=foliage.material_override
	material.set_shader_parameter("sun_direction",d)
	material.set_shader_parameter("leader_family_value",sum/6.0)

func geometry_signature()->String:
	return var_to_bytes([descriptor,wood.mesh.surface_get_arrays(0),foliage.mesh.surface_get_arrays(0)]).hex_encode().sha256_text()
