extends Node3D
## Generic profile-driven tree assembled from overlapping closed 3D wash volumes.

const Paint=preload("res://presentation/northstar/foliage/batched_wash_volume.gdshader")
const Profiles=preload("res://presentation/northstar/foliage/plant_form_profiles.gd")
const Layout=preload("res://presentation/northstar/foliage/plant_form_layout.gd")
const RECIPE:="profile-lobe-wash-volume/1"
const VOLUMES_PER_GROUP:=2
const RINGS:=6
const SEGMENTS:=12

var descriptor:Dictionary={}
var form_profile:Dictionary={}
var foliage:MeshInstance3D
var wood:MeshInstance3D
var stats:Dictionary={}
var _wv:=PackedVector3Array()
var _wn:=PackedVector3Array()
var _wi:=PackedInt32Array()
var _fv:=PackedVector3Array()
var _fn:=PackedVector3Array()
var _fi:=PackedInt32Array()
var _fc:=PackedColorArray()
var _height:=1.0
var _radius:=1.0

func configure(tree:Dictionary,profile:Dictionary)->void:
	assert(get_child_count()==0)
	assert(Profiles.input_error(profile).is_empty())
	descriptor=tree.duplicate(true);form_profile=profile.duplicate(true)
	_height=float(tree.height);_radius=float(tree.crown_radius)
	position=Vector3(tree.x,tree.base_elevation,-tree.y)
	var phase:=Layout.phase_for_seed(int(tree.seed),profile)
	for path in Layout.scaffold_paths(profile,phase):_tube(path.points,float(path.start_radius),float(path.end_radius))
	var anchors:=Layout.anchors(profile,phase)
	var group_radius:=_radius*float(profile.group.radius_factor)
	var group_height:=_height*float(profile.group.height_factor)
	for i in anchors.size():
		var anchor:Dictionary=anchors[i]
		var p:Vector3=anchor.position
		var target:=Vector3(p.x*_radius,p.y*_height,p.z*_radius)
		var basis:=Basis(Vector3.UP,float(anchor.angle))*Basis(Vector3.FORWARD,float(anchor.tilt))
		var scale_value:=float(anchor.scale)
		var family_angle:=float(anchor.family_angle)
		var role:=str(anchor.role)
		var seed_value:=int(tree.seed)+int(profile.group_seed_stride)*(i+1)
		var role_tone:=.515 if role=="leader" else .505 if role=="primary" else .475
		for lobe in VOLUMES_PER_GROUP:
			var side:=-1.0 if lobe==0 else 1.0
			var local_center:=Vector3(side*group_radius*.18,group_height*(.015+.035*float(lobe)),side*group_radius*-.055)
			var extent:=Vector3(
				group_radius*(.76 if lobe==0 else .70),
				group_height*(.50 if lobe==0 else .55),
				group_radius*(.64 if lobe==0 else .72)
			)*scale_value
			_wash_volume(target+basis*(local_center*scale_value),basis,extent,seed_value+lobe*7919,family_angle,role_tone+(.018 if lobe==0 else -.016))
	wood=_finish_wood();foliage=_finish_foliage()
	var wa:=wood.mesh.get_aabb();var fa:=foliage.mesh.get_aabb()
	stats={
		"recipe":RECIPE,
		"profile":str(profile.id),
		"profile_schema":str(profile.schema),
		"groups":anchors.size(),
		"volumes":anchors.size()*VOLUMES_PER_GROUP,
		"volumes_per_group":VOLUMES_PER_GROUP,
		"visible_meshes":2,
		"visible_triangles":_triangle_count(wood.mesh)+_triangle_count(foliage.mesh),
		"wood_triangles":_triangle_count(wood.mesh),
		"foliage_triangles":_triangle_count(foliage.mesh),
		"foliage_width":maxf(fa.size.x,fa.size.z),
		"foliage_depth":minf(fa.size.x,fa.size.z),
		"foliage_height":fa.size.y,
		"overall_height":wa.merge(fa).size.y,
		"alpha_blended":false,
		"alpha_scissor":false,
		"closed_lobe_volumes":true,
		"whole_plant_billboard":false,
		"single_crown_core":false,
		"source_record_unchanged":true
	}

func normalized_plan_lobes()->Array[Dictionary]:return Layout.plan_lobes(form_profile,Layout.phase_for_seed(int(descriptor.seed),form_profile))
func _point(p:Vector3)->Vector3:return Vector3(p.x*_radius,p.y*_height,p.z*_radius)

func _wash_volume(center:Vector3,basis:Basis,extent:Vector3,seed_value:int,family_angle:float,tone:float)->void:
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value
	var shape_phase:=rng.randf()*TAU
	var guide:=Vector3(center.x/maxf(_radius,.001),(center.y-_height*.62)/maxf(_height*.38,.001),center.z/maxf(_radius,.001)).normalized()
	if guide.length_squared()<.01:guide=Vector3.UP
	var top:=_fv.size()
	_append_volume_vertex(center+basis*Vector3(0,extent.y,0),(basis*Vector3.UP).lerp(guide,.48).normalized(),tone,shape_phase,family_angle)
	var first_ring:=_fv.size()
	for ring in range(1,RINGS):
		var phi:=PI*float(ring)/float(RINGS)
		var vertical:=cos(phi)
		var radial:=sin(phi)
		for segment in SEGMENTS:
			var theta:=TAU*float(segment)/float(SEGMENTS)
			var warp:=1.0+.075*sin(theta*3.0+shape_phase)*sin(phi*2.0)+.035*cos(theta*5.0-phi+shape_phase*.7)
			var local:=Vector3(cos(theta)*extent.x*radial*warp,vertical*extent.y*(1.0+.025*sin(theta*2.0+shape_phase)),sin(theta)*extent.z*radial*warp)
			var analytic:=Vector3(local.x/maxf(extent.x*extent.x,.0001),local.y/maxf(extent.y*extent.y,.0001),local.z/maxf(extent.z*extent.z,.0001)).normalized()
			var normal:=(basis*analytic).lerp(guide,.48).normalized()
			_append_volume_vertex(center+basis*local,normal,tone,shape_phase,family_angle)
	var bottom:=_fv.size()
	_append_volume_vertex(center-basis*Vector3(0,extent.y,0),(basis*Vector3.DOWN).lerp(guide,.48).normalized(),tone,shape_phase,family_angle)
	for segment in SEGMENTS:
		_fi.append_array(PackedInt32Array([top,first_ring+segment,first_ring+(segment+1)%SEGMENTS]))
	for ring in range(RINGS-2):
		var a0:=first_ring+ring*SEGMENTS
		var b0:=a0+SEGMENTS
		for segment in SEGMENTS:
			var a:=a0+segment;var b:=a0+(segment+1)%SEGMENTS
			var c:=b0+segment;var d:=b0+(segment+1)%SEGMENTS
			_fi.append_array(PackedInt32Array([a,c,b,b,c,d]))
	var last_ring:=first_ring+(RINGS-2)*SEGMENTS
	for segment in SEGMENTS:
		_fi.append_array(PackedInt32Array([bottom,last_ring+(segment+1)%SEGMENTS,last_ring+segment]))

func _append_volume_vertex(vertex:Vector3,normal:Vector3,tone:float,shape_phase:float,family_angle:float)->void:
	_fv.append(vertex);_fn.append(normal)
	_fc.append(Color(tone,fposmod(shape_phase,TAU)/TAU,.5,fposmod(family_angle,TAU)/TAU))

func _tube(path:PackedVector3Array,start_radius:float,end_radius:float)->void:
	var first:=_wv.size();var sides:=7
	for j in path.size():
		var at:=_point(path[j]);var before:=_point(path[maxi(0,j-1)]);var after:=_point(path[mini(path.size()-1,j+1)])
		var tangent:Vector3=(after-before).normalized();var x:=tangent.cross(Vector3.FORWARD).normalized()
		if x.length_squared()<.1:x=tangent.cross(Vector3.RIGHT).normalized()
		var z:=tangent.cross(x).normalized();var rr:=lerpf(start_radius,end_radius,float(j)/float(path.size()-1))*_radius
		for k in sides:
			var n:=x*cos(TAU*k/sides)+z*sin(TAU*k/sides);_wv.append(at+n*rr);_wn.append(n)
	for j in path.size()-1:
		for k in sides:
			var a:=first+j*sides+k;var b:=first+j*sides+(k+1)%sides;var c:=a+sides;var d:=b+sides;_wi.append_array(PackedInt32Array([a,c,b,b,c,d]))
	for k in range(1,sides-1):
		_wi.append_array(PackedInt32Array([first,first+k,first+k+1]))
		var e:=first+(path.size()-1)*sides;_wi.append_array(PackedInt32Array([e,e+k+1,e+k]))

func _finish_wood()->MeshInstance3D:
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=_wv;arrays[Mesh.ARRAY_NORMAL]=_wn;arrays[Mesh.ARRAY_INDEX]=_wi
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node:=MeshInstance3D.new();node.name="ProfiledWashWood";node.mesh=mesh
	var bark:=StandardMaterial3D.new();bark.albedo_color=Color(str(form_profile.bark_hex));bark.roughness=1.;node.material_override=bark;add_child(node);return node

func _finish_foliage()->MeshInstance3D:
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=_fv;arrays[Mesh.ARRAY_NORMAL]=_fn;arrays[Mesh.ARRAY_INDEX]=_fi;arrays[Mesh.ARRAY_COLOR]=_fc
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node:=MeshInstance3D.new();node.name="ProfiledWashFoliage";node.mesh=mesh
	var material:=ShaderMaterial.new();material.shader=Paint;node.material_override=material;add_child(node);return node

func _triangle_count(mesh:Mesh)->int:
	var arrays:Array=mesh.surface_get_arrays(0);return int(arrays[Mesh.ARRAY_INDEX].size()/3)

func set_light_values(direction:Vector2)->void:
	var d:=direction
	if d.length_squared()<1e-8:d=Vector2(0,-1)
	var material:ShaderMaterial=foliage.material_override
	material.set_shader_parameter("sun_direction",d.normalized())

func geometry_signature()->String:return var_to_bytes([descriptor,wood.mesh.surface_get_arrays(0),foliage.mesh.surface_get_arrays(0)]).hex_encode().sha256_text()
