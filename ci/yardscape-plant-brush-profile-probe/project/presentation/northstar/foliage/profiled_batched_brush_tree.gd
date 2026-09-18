extends Node3D
## Generic two-mesh tree using the shared normalized layout and opaque brush lobes.
const Group=preload("res://presentation/northstar/foliage/brush_cloud_group.gd")
const Paint=preload("res://presentation/northstar/foliage/batched_brush_cloud.gdshader")
const Profiles=preload("res://presentation/northstar/foliage/plant_form_profiles.gd")
const Layout=preload("res://presentation/northstar/foliage/plant_form_layout.gd")

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
	var reference_volume:=.56*.56*.29
	var normalized_volume:=float(profile.group.radius_factor)*float(profile.group.radius_factor)*float(profile.group.height_factor)
	var cards_per_group:=clampi(roundi(18.*normalized_volume/reference_volume),9,20)
	var card_count:=0
	for i in anchors.size():
		var anchor:Dictionary=anchors[i]
		var group:=Group.new();group.configure(int(tree.seed)+int(profile.group_seed_stride)*(i+1),group_radius,group_height,cards_per_group)
		var bounds:AABB=group.foliage.mesh.get_aabb().merge(group.twig.mesh.get_aabb())
		var p:Vector3=anchor.position;var target:=Vector3(p.x*_radius,p.y*_height,p.z*_radius)
		group.scale=Vector3.ONE*float(anchor.scale);group.rotation.y=float(anchor.angle);group.rotation.z=float(anchor.tilt)
		group.position=target-group.basis*bounds.get_center()
		_append_wood(group.twig,group.transform)
		_append_foliage(group.foliage,group.transform,float(anchor.family_angle),str(anchor.role))
		card_count+=int(group.stats.cards);group.free()
	wood=_finish_wood();foliage=_finish_foliage()
	var wa:=wood.mesh.get_aabb();var fa:=foliage.mesh.get_aabb()
	stats={
		"recipe":Group.RECIPE,
		"profile":str(profile.id),
		"groups":anchors.size(),
		"cards":card_count,
		"cards_per_group":cards_per_group,
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
		"alpha_scissor":true,
		"camera_facing":true,
		"fixed_3d_centers":true,
		"whole_plant_billboard":false,
		"solid_core":false,
		"source_record_unchanged":true,
		"profile_schema":str(profile.schema)
	}

func normalized_plan_lobes()->Array[Dictionary]:return Layout.plan_lobes(form_profile,Layout.phase_for_seed(int(descriptor.seed),form_profile))
func _point(p:Vector3)->Vector3:return Vector3(p.x*_radius,p.y*_height,p.z*_radius)

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

func _append_wood(node:MeshInstance3D,xform:Transform3D)->void:
	var arrays:Array=node.mesh.surface_get_arrays(0);var offset:=_wv.size()
	for i in arrays[Mesh.ARRAY_VERTEX].size():
		_wv.append(xform*arrays[Mesh.ARRAY_VERTEX][i]);_wn.append((xform.basis*arrays[Mesh.ARRAY_NORMAL][i]).normalized())
	for index in arrays[Mesh.ARRAY_INDEX]:_wi.append(offset+int(index))

func _append_foliage(node:MeshInstance3D,xform:Transform3D,family_angle:float,role:String)->void:
	var arrays:Array=node.mesh.surface_get_arrays(0);var offset:=_fv.size()
	var scale_value:=xform.basis.get_scale().x
	_family_angles.append(family_angle)
	for i in arrays[Mesh.ARRAY_VERTEX].size():
		var local:Vector3=arrays[Mesh.ARRAY_VERTEX][i]
		var source_color:Color=arrays[Mesh.ARRAY_COLOR][i]
		var uv:Vector2=arrays[Mesh.ARRAY_TEX_UV][i];var size:Vector2=arrays[Mesh.ARRAY_TEX_UV2][i]*scale_value
		var corner:=(Vector2(fposmod(uv.x*4.,1.),uv.y)-Vector2(.5,.5))*size
		var roll:=source_color.b*TAU-PI;corner=corner.rotated(roll)
		_fv.append(xform*local+Vector3(corner.x,corner.y,0));_fn.append((xform.basis*arrays[Mesh.ARRAY_NORMAL][i]).normalized())
		var role_tone:=.006 if role=="leader" else .008 if role=="primary" else -.004
		_fc.append(Color(clampf(source_color.r+role_tone,0.,1.),source_color.g,source_color.b,fposmod(family_angle,TAU)/TAU))
		_fuv.append(uv);_fuv2.append(size)
	for index in arrays[Mesh.ARRAY_INDEX]:_fi.append(offset+int(index))

func _finish_wood()->MeshInstance3D:
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=_wv;arrays[Mesh.ARRAY_NORMAL]=_wn;arrays[Mesh.ARRAY_INDEX]=_wi
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node:=MeshInstance3D.new();node.name="ProfiledBrushWood";node.mesh=mesh
	var bark:=StandardMaterial3D.new();bark.albedo_color=Color(str(form_profile.bark_hex));bark.roughness=1.;node.material_override=bark;add_child(node);return node

func _finish_foliage()->MeshInstance3D:
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=_fv;arrays[Mesh.ARRAY_NORMAL]=_fn;arrays[Mesh.ARRAY_INDEX]=_fi;arrays[Mesh.ARRAY_COLOR]=_fc;arrays[Mesh.ARRAY_TEX_UV]=_fuv;arrays[Mesh.ARRAY_TEX_UV2]=_fuv2
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node:=MeshInstance3D.new();node.name="ProfiledBrushFoliage";node.mesh=mesh
	var material:=ShaderMaterial.new();material.shader=Paint;material.set_shader_parameter("brush_atlas",Group.brush_atlas());node.material_override=material
	node.custom_aabb=mesh.get_aabb().grow(_radius*.45);add_child(node);return node

func _triangle_count(mesh:Mesh)->int:
	var arrays:Array=mesh.surface_get_arrays(0);return int(arrays[Mesh.ARRAY_INDEX].size()/3)

func set_light_values(direction:Vector2)->void:
	var d:=direction
	if d.length_squared()<1e-8:d=Vector2(0,-1)
	d=d.normalized();var family_count:=int(form_profile.family_count);var sum:=0.0
	for j in family_count:
		var angle:=_family_angles[j*2];var alignment:=Vector2(cos(angle),sin(angle)).dot(d)
		if alignment>.28:sum+=.095
		elif alignment<-.28:sum-=.095
	var material:ShaderMaterial=foliage.material_override
	material.set_shader_parameter("sun_direction",d);material.set_shader_parameter("leader_family_value",sum/float(family_count))

func geometry_signature()->String:return var_to_bytes([descriptor,wood.mesh.surface_get_arrays(0),foliage.mesh.surface_get_arrays(0)]).hex_encode().sha256_text()
