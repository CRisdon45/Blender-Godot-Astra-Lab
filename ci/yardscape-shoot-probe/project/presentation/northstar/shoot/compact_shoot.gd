extends Node3D
## Generic broadleaf shoot study. Seven closed leaves around one short twig.
## Not a species claim or growth model.
const LeafPaint = preload("res://presentation/northstar/shoot/shoot_foliage.gdshader")
var descriptor: Dictionary = {}
var foliage: MeshInstance3D
var twig: MeshInstance3D
var stats: Dictionary = {}
var _v := PackedVector3Array()
var _ix := PackedInt32Array()
var _colors := PackedColorArray()

func configure(source: Dictionary) -> void:
	assert(source.has_all(["id","x","y","base_elevation","height","crown_radius","seed"]))
	assert(get_child_count()==0)
	descriptor = source.duplicate(true)
	var radius: float = float(source.crown_radius)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(source.seed) + 17021
	_build_twig(radius)
	var twig_arrays := _finish_arrays()
	twig = _mesh_node("ShootTwig", twig_arrays)
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color("655440")
	bark.roughness = 1.0
	twig.material_override = bark
	var stem := Vector3(0, 0.34 * radius, 0)
	var pairs := [
		{"t":.18,"yaw":-.64,"pitch":.14,"scale":.88},
		{"t":.18,"yaw":2.35,"pitch":-.08,"scale":.80},
		{"t":.42,"yaw":.52,"pitch":.23,"scale":1.0},
		{"t":.42,"yaw":3.45,"pitch":.02,"scale":.91},
		{"t":.68,"yaw":1.20,"pitch":.36,"scale":.87},
		{"t":.68,"yaw":4.30,"pitch":.16,"scale":.78}
	]
	for i in pairs.size():
		var p: Dictionary = pairs[i]
		var base := Vector3(0, lerpf(.05, stem.y, p.t), 0)
		base += Vector3(rng.randf_range(-.018,.018), rng.randf_range(-.012,.012), rng.randf_range(-.018,.018))*radius
		var yaw: float = float(p.yaw) + rng.randf_range(-.12,.12)
		var pitch: float = float(p.pitch) + rng.randf_range(-.08,.08)
		var axis := Vector3(cos(yaw)*cos(pitch), sin(pitch), sin(yaw)*cos(pitch)).normalized()
		_add_leaf(base, axis, radius*.31*float(p.scale), radius*.115*float(p.scale), i)
	# Terminal leaf lifts the group without turning the whole shoot into a radial star.
	_add_leaf(stem*0.91, Vector3(.10,.96,.22).normalized(), radius*.34, radius*.12, 6)
	var arrays := _finish_arrays(true)
	foliage = _mesh_node("ShootFoliage", arrays)
	var material := ShaderMaterial.new()
	material.shader = LeafPaint
	material.set_shader_parameter("seed_phase", fmod(float(source.seed), 997.0) * .017)
	foliage.material_override = material
	stats = {
		"recipe":"compact-seven-leaf-shoot/1",
		"leaf_count":7,
		"foliage_triangles":int(arrays[Mesh.ARRAY_INDEX].size()/3),
		"twig_triangles":int(twig_arrays[Mesh.ARRAY_INDEX].size()/3),
		"mesh_surfaces":2,
		"alpha_foliage":false
	}

func _build_twig(radius: float) -> void:
	var points := PackedVector3Array([
		Vector3(0,0,0),
		Vector3(.012,.12,-.008)*radius,
		Vector3(-.018,.24,.014)*radius,
		Vector3(0,.34,0)*radius
	])
	_add_tube(points, radius*.024, radius*.008, 7)

func _add_tube(path: PackedVector3Array, start_radius: float, end_radius: float, sides: int) -> void:
	var offset := _v.size()
	for j in path.size():
		var before := path[maxi(0,j-1)]
		var after := path[mini(path.size()-1,j+1)]
		var tangent := (after-before).normalized()
		var right := tangent.cross(Vector3.FORWARD).normalized()
		if right.length_squared()<.1: right = tangent.cross(Vector3.RIGHT).normalized()
		var binormal := tangent.cross(right).normalized()
		var r := lerpf(start_radius,end_radius,float(j)/float(path.size()-1))
		for k in sides:
			var n := right*cos(TAU*k/sides)+binormal*sin(TAU*k/sides)
			_v.append(path[j]+n*r)
	for j in path.size()-1:
		for k in sides:
			var a:=offset+j*sides+k
			var b:=offset+j*sides+(k+1)%sides
			var c:=a+sides
			var d:=b+sides
			_ix.append_array(PackedInt32Array([a,c,b,b,c,d]))
	for k in range(1,sides-1):
		_ix.append_array(PackedInt32Array([offset,offset+k+1,offset+k]))
		var e:=offset+(path.size()-1)*sides
		_ix.append_array(PackedInt32Array([e,e+k,e+k+1]))

func _add_leaf(base: Vector3, axis: Vector3, length: float, width: float, index: int) -> void:
	var tangent := axis.normalized()
	var side := tangent.cross(Vector3.UP).normalized()
	if side.length_squared()<.08: side = tangent.cross(Vector3.RIGHT).normalized()
	var lift := side.cross(tangent).normalized()
	var roll := [-.48,.31,.52,-.28,.18,-.55,.08][index]
	var rolled_side := (side*cos(roll)+lift*sin(roll)).normalized()
	var rolled_lift := tangent.cross(rolled_side).normalized()
	var rings := 5
	var around := 8
	var ring_starts: Array[int] = []
	var start_tip := _v.size()
	_v.append(base)
	for r in rings:
		var t := [.14,.31,.50,.69,.86][r]
		var shape := pow(sin(PI*t),.72)
		var center := base+tangent*length*t+rolled_lift*(sin(PI*t)*width*.20 + sin(TAU*t+index)*width*.035)
		var ring_start := _v.size()
		ring_starts.append(ring_start)
		for k in around:
			var a := TAU*float(k)/around
			var p := center + rolled_side*(cos(a)*width*shape) + rolled_lift*(sin(a)*width*.22*shape)
			_v.append(p)
	var end_tip := _v.size()
	_v.append(base+tangent*length)
	for k in around:
		var a:=ring_starts[0]+k
		var b:=ring_starts[0]+(k+1)%around
		_ix.append_array(PackedInt32Array([start_tip,b,a]))
	for r in rings-1:
		for k in around:
			var a:=ring_starts[r]+k
			var b:=ring_starts[r]+(k+1)%around
			var c:=ring_starts[r+1]+k
			var d:=ring_starts[r+1]+(k+1)%around
			_ix.append_array(PackedInt32Array([a,b,c,b,d,c]))
	for k in around:
		var a:=ring_starts[-1]+k
		var b:=ring_starts[-1]+(k+1)%around
		_ix.append_array(PackedInt32Array([end_tip,a,b]))

func _final_normals() -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(_v.size())
	normals.fill(Vector3.ZERO)
	for i in range(0,_ix.size(),3):
		var a:=_ix[i];var b:=_ix[i+1];var c:=_ix[i+2]
		# Godot front faces use clockwise winding.
		var n:=(_v[c]-_v[a]).cross(_v[b]-_v[a])
		if n.length_squared()>1e-18:
			normals[a]+=n;normals[b]+=n;normals[c]+=n
	for i in normals.size():
		if normals[i].length_squared()>1e-18: normals[i]=normals[i].normalized()
	return normals

func _finish_arrays(with_normals: bool=false) -> Array:
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=_v
	arrays[Mesh.ARRAY_INDEX]=_ix
	if with_normals: arrays[Mesh.ARRAY_NORMAL]=_final_normals()
	else: arrays[Mesh.ARRAY_NORMAL]=_final_normals()
	_v=PackedVector3Array();_ix=PackedInt32Array()
	return arrays

func _mesh_node(label: String, arrays: Array) -> MeshInstance3D:
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node:=MeshInstance3D.new()
	node.name=label
	node.mesh=mesh
	add_child(node)
	return node

func geometry_signature() -> String:
	return var_to_bytes([descriptor,twig.mesh.surface_get_arrays(0),foliage.mesh.surface_get_arrays(0)]).hex_encode().sha256_text()
