extends Node3D
## Generic crown study, not a botanical species or growth model.
## Closed opaque folded foliage groups; no alpha cards, billboard or runtime AI.
const Paint = preload("res://presentation/northstar/canopy/foliage.gdshader")
const RECIPE = "folded-foliage-groups/2"
var descriptor: Dictionary = {}
var crown: MeshInstance3D
var wood: MeshInstance3D
var stats: Dictionary = {}
var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _ix := PackedInt32Array()
var _height := 1.0
var _radius := 1.0

static func input_error(t: Dictionary) -> String:
	if not t.has_all(["id","x","y","base_elevation","height","crown_radius","seed"]): return "missing_fields"
	if not t.id is String or t.id.is_empty(): return "invalid_id"
	for key in ["x","y","base_elevation","height","crown_radius","seed"]:
		if typeof(t[key]) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(t[key]): return "invalid_number"
	if t.height <= 0. or t.crown_radius <= 0.: return "invalid_size"
	return ""

func configure(t: Dictionary) -> void:
	assert(input_error(t).is_empty())
	assert(get_child_count()==0,"Configure a fresh derived tree only")
	descriptor=t.duplicate(true);_height=t.height;_radius=t.crown_radius
	position=Vector3(t.x,t.base_elevation,-t.y)
	var rng:=RandomNumberGenerator.new();rng.seed=int(t.seed)
	var phase:=rng.randf()*TAU
	var trunk:=PackedVector3Array([Vector3.ZERO,Vector3(.025,.19,-.015),Vector3(-.055,.36,.025),Vector3(.035,.52,0.)])
	_tube(trunk,.075,.022)
	var groups: Array[Dictionary]=[]
	for j in 5:
		var angle: float=phase+[0.,1.16,2.62,3.76,5.10][j]
		var direction:=Vector3(cos(angle),0.,sin(angle))
		var side:=Vector3(-sin(angle),0.,cos(angle))
		var reach: float=[.58,.48,.63,.50,.61][j]
		var level: float=[.65,.80,.69,.83,.73][j]
		var center:=direction*reach;center.y=level
		var start:=trunk[2] if j%2==0 else trunk[3]
		var elbow:=start.lerp(center,.50);elbow.y-=.04
		_tube(PackedVector3Array([start,elbow,center]),.026,.006)
		groups.append({"c":center,"s":Vector3(.34,.105,.31),"a":angle,"p":rng.randf()*TAU})
		for k in 2:
			var at:=center+side*(-.23 if k==0 else .22)-direction*.12
			at.y+=-.065 if k==0 else .075
			_tube(PackedVector3Array([elbow,center.lerp(at,.50),at]),.012,.003)
			groups.append({"c":at,"s":Vector3(.285,.10,.27),"a":angle+.45*float(k*2-1),"p":rng.randf()*TAU})
	var leader:=Vector3(-.08,.90,.06)
	_tube(PackedVector3Array([trunk[3],Vector3(-.11,.73,.04),leader]),.018,.004)
	groups.append({"c":leader,"s":Vector3(.32,.10,.28),"a":phase+.8,"p":1.7})
	wood=_finish("BranchGesture")
	var bark:=StandardMaterial3D.new();bark.albedo_color=Color("665541");bark.roughness=1.
	wood.material_override=bark
	var branch_triangles:=int(wood.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()/3)
	for g in groups: _mass(g.c,g.s,g.a,g.p)
	crown=_finish("OpaqueFoliage")
	var paint:=ShaderMaterial.new();paint.shader=Paint
	paint.set_shader_parameter("height",_height);paint.set_shader_parameter("radius",_radius)
	paint.set_shader_parameter("seed_phase",phase)
	crown.material_override=paint
	stats={"recipe":RECIPE,"bough_groups":groups.size(),"folded_sprays":groups.size()*4,"foliage_triangles":int(crown.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()/3),
		"branch_triangles":branch_triangles,"mesh_surfaces":2,"alpha_blended_foliage":false}

func _point(p: Vector3) -> Vector3:
	return Vector3(p.x*_radius,p.y*_height,p.z*_radius)

func _tube(path: PackedVector3Array,start: float,end: float) -> void:
	var offset:=_v.size();var sides:=7
	for j in path.size():
		var at:=_point(path[j])
		var before:=_point(path[maxi(0,j-1)]);var after:=_point(path[mini(path.size()-1,j+1)])
		var tangent: Vector3=(after-before).normalized()
		var x:=tangent.cross(Vector3.FORWARD).normalized()
		if x.length_squared()<.1:x=tangent.cross(Vector3.RIGHT).normalized()
		var z:=tangent.cross(x).normalized()
		var r:=lerpf(start,end,float(j)/float(path.size()-1))*_radius
		for k in sides:
			var n: Vector3=x*cos(TAU*k/sides)+z*sin(TAU*k/sides)
			var vertex:=at+n*r;vertex.y=maxf(0.,vertex.y)
			_v.append(vertex);_n.append(n)
	for j in path.size()-1:
		for k in sides:
			var a:=offset+j*sides+k;var b:=offset+j*sides+(k+1)%sides
			var c:=a+sides;var d:=b+sides
			_ix.append_array(PackedInt32Array([a,c,b,b,c,d]))
	# Close each end with a fan using its perimeter vertices.
	for k in range(1,sides-1):
		_ix.append_array(PackedInt32Array([offset,offset+k,offset+k+1]))
		var e:=offset+(path.size()-1)*sides
		_ix.append_array(PackedInt32Array([e,e+k+1,e+k]))

func _bounded(p: Vector3) -> Vector3:
	var radial:=Vector2(p.x,p.z)
	if radial.length()>_radius*.995:
		radial=radial.normalized()*_radius*.995;p.x=radial.x;p.z=radial.y
	p.y=clampf(p.y,0.,_height)
	return p

func _mass(center: Vector3,extent: Vector3,angle: float,phase: float) -> void:
	# A bough value mass emerges from several folded silhouettes, not a solid ball.
	for j in 4:
		var spin:=angle+float(j)*1.72+phase*.25
		var rotation:=Basis(Vector3.UP,spin)*Basis(Vector3.RIGHT,.35*sin(phase+j*1.6))*Basis(Vector3.FORWARD,.45*cos(phase-j))
		var offset:=Basis(Vector3.UP,angle)*Vector3(extent.x*[-.38,.40,-.16,.14][j],extent.y*[-.42,.18,.48,-.10][j],extent.z*[-.24,.20,.35,-.37][j])
		var c:=_point(center+offset)
		var rx:=extent.x*_radius*.76;var rz:=extent.z*_radius*.78
		var start:=_v.size();var sides:=30
		var guide:=Vector3(c.x/_radius,(c.y/_height-.69)*3.,c.z/_radius).normalized()
		var up: Vector3=rotation*Vector3.UP
		_v.append(_bounded(c+up*rx*.18));_n.append(up.lerp(guide,.56).normalized())
		_v.append(_bounded(c-up*rx*.09));_n.append((-up).lerp(guide,.56).normalized())
		for side in 2:
			for k in sides:
				var u:=TAU*float(k)/sides
				var edge:=.77+.23*cos(5.*u+phase)+.04*sin(9.*u-phase)
				var offset_world: Vector3=rotation*Vector3(cos(u)*rx*edge,sin(3.*u+phase)*rx*.045,sin(u)*rz*edge)
				var normal: Vector3=(up*(1. if side==0 else -1.)+offset_world.normalized()*.18).normalized()
				_v.append(_bounded(c+offset_world));_n.append(normal.lerp(guide,.56).normalized())
		for k in sides:
			var a:=start+2+k;var b:=start+2+(k+1)%sides
			_ix.append_array(PackedInt32Array([start,a,b,start+1,b+sides,a+sides]))

func _finish(label: String) -> MeshInstance3D:
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=_v;arrays[Mesh.ARRAY_NORMAL]=_n;arrays[Mesh.ARRAY_INDEX]=_ix
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node:=MeshInstance3D.new();node.name=label;node.mesh=mesh;add_child(node)
	_v=PackedVector3Array();_n=PackedVector3Array();_ix=PackedInt32Array()
	return node

func geometry_signature() -> String:
	return var_to_bytes([descriptor,wood.mesh.surface_get_arrays(0),crown.mesh.surface_get_arrays(0)]).hex_encode().sha256_text()
