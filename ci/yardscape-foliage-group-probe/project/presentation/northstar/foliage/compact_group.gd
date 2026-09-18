extends Node3D
## Compact generic broadleaf group made from small closed interleaved forms.
## It is an authored shape grammar, not literal leaves or a species model.
const Paint = preload("res://presentation/northstar/foliage/compact_group.gdshader")
const RECIPE := "compact-interleaved-group/1"
var descriptor: Dictionary = {}
var foliage: MeshInstance3D
var twig: MeshInstance3D
var stats: Dictionary = {}
var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _ix := PackedInt32Array()
var _colors := PackedColorArray()

func configure(seed_value: int, radius: float, height: float) -> void:
	assert(get_child_count()==0)
	assert(radius>0.0 and height>0.0)
	descriptor={"seed":seed_value,"radius":radius,"height":height}
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value
	var hub:=Vector3.ZERO
	var stems=[
		PackedVector3Array([hub,Vector3(.03,.16,.01),Vector3(.08,.31,-.02)]),
		PackedVector3Array([Vector3(.04,.13,0),Vector3(-.12,.25,.05),Vector3(-.22,.34,.09)]),
		PackedVector3Array([Vector3(.05,.18,-.01),Vector3(.17,.28,-.07),Vector3(.25,.39,-.11)])
	]
	for path in stems:
		_tube(path,radius*.035,radius*.014,radius,height)
	twig=_finish("TwigGesture")
	var bark:=StandardMaterial3D.new();bark.albedo_color=Color("665541");bark.roughness=1.
	twig.material_override=bark
	var placements=[
		[Vector3(-.20,.33,.10),Vector3(-.68,.48,.36),1.08,.52],
		[Vector3(-.11,.27,-.04),Vector3(-.58,.62,-.28),.96,.47],
		[Vector3(-.02,.38,.08),Vector3(-.18,.92,.34),1.04,.50],
		[Vector3(.08,.31,-.10),Vector3(.24,.82,-.52),.94,.48],
		[Vector3(.18,.38,-.05),Vector3(.65,.61,-.36),1.02,.51],
		[Vector3(.25,.43,-.11),Vector3(.78,.50,-.22),.92,.46],
		[Vector3(.12,.47,.08),Vector3(.43,.80,.41),.88,.45],
		[Vector3(-.13,.46,.02),Vector3(-.42,.84,.31),.90,.45],
		[Vector3(.00,.53,-.02),Vector3(.04,.98,-.17),.84,.43],
		[Vector3(-.24,.40,.01),Vector3(-.84,.47,-.08),.82,.42],
		[Vector3(.23,.34,.12),Vector3(.78,.50,.38),.80,.41]
	]
	for i in placements.size():
		var p=placements[i]
		var jitter:=Vector3(rng.randf_range(-.018,.018),rng.randf_range(-.012,.018),rng.randf_range(-.018,.018))
		var direction: Vector3=(p[1]+jitter).normalized()
		var roll:=rng.randf_range(-.42,.42)
		var scale_value: float=p[2]*rng.randf_range(.94,1.05)
		var tone: float=p[3]+rng.randf_range(-.05,.05)
		_leaf(p[0],direction,roll,scale_value,tone,radius,height)
	foliage=_finish("CompactFoliage")
	var paint:=ShaderMaterial.new();paint.shader=Paint
	foliage.material_override=paint
	var fa: Array=foliage.mesh.surface_get_arrays(0)
	var ta: Array=twig.mesh.surface_get_arrays(0)
	stats={"recipe":RECIPE,"subforms":placements.size(),"mesh_surfaces":2,
		"foliage_triangles":int(fa[Mesh.ARRAY_INDEX].size()/3),
		"twig_triangles":int(ta[Mesh.ARRAY_INDEX].size()/3),
		"alpha_blended":false}

func _basis_from(direction: Vector3, roll: float) -> Basis:
	var y:=direction.normalized()
	var x:=y.cross(Vector3.FORWARD)
	if x.length_squared()<.01:x=y.cross(Vector3.RIGHT)
	x=x.normalized()
	var z:=x.cross(y).normalized()
	var basis:=Basis(x,y,z)
	return basis*Basis(y,roll)

func _leaf(center: Vector3,direction: Vector3,roll: float,scale_value: float,tone: float,radius: float,height: float) -> void:
	var basis:=_basis_from(direction,roll)
	var center_world:=Vector3(center.x*radius,center.y*height,center.z*radius)
	var start:=_v.size()
	var stations:=6
	var sides:=6
	var length:=height*.44*scale_value
	var width:=radius*.18*scale_value
	var thickness:=radius*.075*scale_value
	for j in stations:
		var t:=float(j)/float(stations-1)
		var axial:=(t-.47)*length
		var swell:=pow(maxf(0.,sin(PI*t)),.72)
		var bend:=sin(PI*t)*length*.09
		var axis:=Vector3(bend*sin(roll+.7),axial,bend*cos(roll-.4))
		for k in sides:
			var a:=TAU*float(k)/sides
			var asym:=1.0+.10*sin(a*3.0+roll)+.04*cos(a*5.0)
			var local:=axis+Vector3(cos(a)*width*swell*asym,0.,sin(a)*thickness*swell)
			_v.append(center_world+basis*local)
			_colors.append(Color(tone,tone,tone,1))
			_n.append(Vector3.ZERO)
	for j in stations-1:
		for k in sides:
			var a:=start+j*sides+k
			var b:=start+j*sides+(k+1)%sides
			var c:=a+sides
			var d:=b+sides
			_ix.append_array(PackedInt32Array([a,c,b,b,c,d]))
	for k in range(1,sides-1):
		_ix.append_array(PackedInt32Array([start,start+k+1,start+k]))
		var e:=start+(stations-1)*sides
		_ix.append_array(PackedInt32Array([e,e+k,e+k+1]))
	_recompute_normals(start,_v.size())

func _tube(path: PackedVector3Array,start_radius: float,end_radius: float,radius: float,height: float) -> void:
	var offset:=_v.size();var sides:=6
	for j in path.size():
		var at:=Vector3(path[j].x*radius,path[j].y*height,path[j].z*radius)
		var before:=Vector3(path[maxi(0,j-1)].x*radius,path[maxi(0,j-1)].y*height,path[maxi(0,j-1)].z*radius)
		var after:=Vector3(path[mini(path.size()-1,j+1)].x*radius,path[mini(path.size()-1,j+1)].y*height,path[mini(path.size()-1,j+1)].z*radius)
		var tangent:=(after-before).normalized()
		var x:=tangent.cross(Vector3.FORWARD).normalized()
		if x.length_squared()<.1:x=tangent.cross(Vector3.RIGHT).normalized()
		var z:=tangent.cross(x).normalized()
		var rr:=lerpf(start_radius,end_radius,float(j)/float(path.size()-1))
		for k in sides:
			var n:=x*cos(TAU*k/sides)+z*sin(TAU*k/sides)
			_v.append(at+n*rr);_n.append(n);_colors.append(Color.WHITE)
	for j in path.size()-1:
		for k in sides:
			var a:=offset+j*sides+k;var b:=offset+j*sides+(k+1)%sides
			var c:=a+sides;var d:=b+sides
			_ix.append_array(PackedInt32Array([a,c,b,b,c,d]))
	for k in range(1,sides-1):
		_ix.append_array(PackedInt32Array([offset,offset+k+1,offset+k]))
		var e:=offset+(path.size()-1)*sides
		_ix.append_array(PackedInt32Array([e,e+k,e+k+1]))

func _recompute_normals(first_vertex: int,end_vertex: int) -> void:
	var sums:=PackedVector3Array();sums.resize(end_vertex-first_vertex);sums.fill(Vector3.ZERO)
	for i in range(0,_ix.size(),3):
		var a:=_ix[i];var b:=_ix[i+1];var c:=_ix[i+2]
		if a<first_vertex or a>=end_vertex or b<first_vertex or b>=end_vertex or c<first_vertex or c>=end_vertex:continue
		var normal:=(_v[c]-_v[a]).cross(_v[b]-_v[a])
		if normal.length_squared()<1e-18:continue
		sums[a-first_vertex]+=normal;sums[b-first_vertex]+=normal;sums[c-first_vertex]+=normal
	for i in sums.size():
		_n[first_vertex+i]=sums[i].normalized() if sums[i].length_squared()>1e-18 else Vector3.UP

func _finish(label: String) -> MeshInstance3D:
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=_v;arrays[Mesh.ARRAY_NORMAL]=_n;arrays[Mesh.ARRAY_INDEX]=_ix
	if label=="CompactFoliage":arrays[Mesh.ARRAY_COLOR]=_colors
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node:=MeshInstance3D.new();node.name=label;node.mesh=mesh;add_child(node)
	_v=PackedVector3Array();_n=PackedVector3Array();_ix=PackedInt32Array();_colors=PackedColorArray()
	return node

func geometry_signature() -> String:
	return var_to_bytes([descriptor,twig.mesh.surface_get_arrays(0),foliage.mesh.surface_get_arrays(0)]).hex_encode().sha256_text()
