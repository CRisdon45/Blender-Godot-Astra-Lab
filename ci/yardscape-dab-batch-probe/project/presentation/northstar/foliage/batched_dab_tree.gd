extends Node3D
## Display-equivalent batching witness built from the retained dab-group tree.
## No source dimensions, anchors, dab geometry or branch geometry are changed.
const SourceTree = preload("res://presentation/northstar/foliage/dab_tree.gd")
const Paint = preload("res://presentation/northstar/foliage/batched_dab_value.gdshader")
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

func configure(t:Dictionary)->void:
	assert(get_child_count()==0)
	descriptor=t.duplicate(true)
	position=Vector3(t.x,t.base_elevation,-t.y)
	var source:=SourceTree.new();source.configure(t);source.position=Vector3.ZERO
	for family in 5:
		var p:Vector3=source.groups[family*3].position
		_family_angles.append(Vector2(p.x,p.z).angle())
	_append_wood(source.skeleton.wood,Transform3D.IDENTITY)
	for i in source.groups.size():
		var group:Node3D=source.groups[i]
		_append_wood(group.twig,group.transform)
		_append_foliage(group.foliage,group.transform,i)
	wood=_finish_wood()
	foliage=_finish_foliage()
	source.free()
	stats={
		"recipe":"batched-dab-value-tree/1",
		"visible_meshes":2,
		"visible_triangles":int(_triangle_count(wood.mesh)+_triangle_count(foliage.mesh)),
		"wood_triangles":int(_triangle_count(wood.mesh)),
		"foliage_triangles":int(_triangle_count(foliage.mesh)),
		"source_record_unchanged":true,
		"alpha_blended":false
	}

func _triangle_count(mesh:Mesh)->int:
	var arrays:Array=mesh.surface_get_arrays(0)
	return int(arrays[Mesh.ARRAY_INDEX].size()/3)

func _append_wood(node:MeshInstance3D,xform:Transform3D)->void:
	var arrays:Array=node.mesh.surface_get_arrays(0)
	var offset:=_wv.size()
	for i in arrays[Mesh.ARRAY_VERTEX].size():
		_wv.append(xform*arrays[Mesh.ARRAY_VERTEX][i])
		_wn.append((xform.basis*arrays[Mesh.ARRAY_NORMAL][i]).normalized())
	for index in arrays[Mesh.ARRAY_INDEX]:_wi.append(offset+int(index))

func _append_foliage(node:MeshInstance3D,xform:Transform3D,group_index:int)->void:
	var arrays:Array=node.mesh.surface_get_arrays(0)
	var offset:=_fv.size()
	var role_code:=1.0 if group_index==15 else .75 if group_index%3==0 else .25
	var family_angle:=0.0 if group_index==15 else _family_angles[int(group_index/3)]
	for i in arrays[Mesh.ARRAY_VERTEX].size():
		var local:Vector3=arrays[Mesh.ARRAY_VERTEX][i]
		_fv.append(xform*local)
		_fn.append((xform.basis*arrays[Mesh.ARRAY_NORMAL][i]).normalized())
		var source_color:Color=arrays[Mesh.ARRAY_COLOR][i]
		_fc.append(Color(source_color.r,0,0,role_code))
		_fuv.append(Vector2(local.x,local.z))
		_fuv2.append(Vector2(local.y,family_angle))
	for index in arrays[Mesh.ARRAY_INDEX]:_fi.append(offset+int(index))

func _finish_wood()->MeshInstance3D:
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=_wv;arrays[Mesh.ARRAY_NORMAL]=_wn;arrays[Mesh.ARRAY_INDEX]=_wi
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node:=MeshInstance3D.new();node.name="BatchedWood";node.mesh=mesh
	var bark:=StandardMaterial3D.new();bark.albedo_color=Color("665541");bark.roughness=1.;node.material_override=bark;add_child(node)
	return node

func _finish_foliage()->MeshInstance3D:
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=_fv;arrays[Mesh.ARRAY_NORMAL]=_fn;arrays[Mesh.ARRAY_INDEX]=_fi;arrays[Mesh.ARRAY_COLOR]=_fc;arrays[Mesh.ARRAY_TEX_UV]=_fuv;arrays[Mesh.ARRAY_TEX_UV2]=_fuv2
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node:=MeshInstance3D.new();node.name="BatchedFoliage";node.mesh=mesh
	var material:=ShaderMaterial.new();material.shader=Paint;node.material_override=material;add_child(node)
	return node

func set_light_values(direction:Vector2,leader_value:float)->void:
	var d:=direction
	if d.length_squared()<1e-8:d=Vector2(0,-1)
	var material:ShaderMaterial=foliage.material_override
	material.set_shader_parameter("sun_direction",d.normalized())
	material.set_shader_parameter("leader_family_value",leader_value)

func family_angles()->PackedFloat32Array:return _family_angles.duplicate()

func geometry_signature()->String:
	return var_to_bytes([descriptor,wood.mesh.surface_get_arrays(0),foliage.mesh.surface_get_arrays(0)]).hex_encode().sha256_text()
