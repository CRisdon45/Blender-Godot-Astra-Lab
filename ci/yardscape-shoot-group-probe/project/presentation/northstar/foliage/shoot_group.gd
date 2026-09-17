extends Node3D
## Three compact shoot gestures carrying fifteen small closed foliage hints.
## Generic visual component; not a species or literal canopy leaf inventory.
const Paint = preload("res://presentation/northstar/foliage/compact_group.gdshader")
const RECIPE := "three-shoot-group/1"
var descriptor:Dictionary={}
var foliage:MeshInstance3D
var twig:MeshInstance3D
var stats:Dictionary={}
var _v:=PackedVector3Array()
var _n:=PackedVector3Array()
var _ix:=PackedInt32Array()
var _colors:=PackedColorArray()

func configure(seed_value:int,radius:float,height:float)->void:
	assert(get_child_count()==0 and radius>0. and height>0.)
	descriptor={"seed":seed_value,"radius":radius,"height":height}
	var rng:=RandomNumberGenerator.new()
	rng.seed=seed_value
	var paths:Array[PackedVector3Array]=[
		PackedVector3Array([Vector3.ZERO,Vector3(.01,.18,.01),Vector3(-.05,.38,.04),Vector3(-.10,.56,.08)]),
		PackedVector3Array([Vector3(.02,.05,0),Vector3(.10,.20,-.02),Vector3(.22,.36,-.08),Vector3(.31,.49,-.13)]),
		PackedVector3Array([Vector3(-.02,.07,0),Vector3(-.11,.22,.04),Vector3(-.24,.35,.09),Vector3(-.30,.48,.12)])
	]
	var tones:PackedFloat32Array=PackedFloat32Array([.51,.46,.55])
	var leaflets:=0
	for s in paths.size():
		var path:=paths[s]
		_tube(path,radius*.028,radius*.010,radius,height)
		for node_index in [1,2]:
			var tangent:Vector3=(path[node_index+1]-path[node_index-1]).normalized()
			var side:=tangent.cross(Vector3.UP)
			if side.length_squared()<.01:
				side=tangent.cross(Vector3.FORWARD)
			side=side.normalized()
			for sign_value in [-1.,1.]:
				var center:Vector3=path[node_index]+side*sign_value*.045+Vector3.UP*.012
				var direction:Vector3=(tangent*.42+side*sign_value*.88+Vector3.UP*.16).normalized()
				var scale_value:=1.0 if node_index==1 else .86
				var tone:=tones[s]+rng.randf_range(-.035,.035)
				_leaf(center,direction,sign_value*.25+rng.randf_range(-.12,.12),scale_value,tone,radius,height)
				leaflets+=1
		var terminal_direction:Vector3=(path[-1]-path[-2]+Vector3.UP*.08).normalized()
		_leaf(path[-1],terminal_direction,rng.randf_range(-.25,.25),.78,tones[s]+rng.randf_range(-.03,.03),radius,height)
		leaflets+=1
	twig=_finish("ShootGesture")
	var bark:=StandardMaterial3D.new()
	bark.albedo_color=Color("665541")
	bark.roughness=1.
	twig.material_override=bark
	foliage=_finish("ShootFoliage")
	var paint:=ShaderMaterial.new()
	paint.shader=Paint
	foliage.material_override=paint
	var fa:Array=foliage.mesh.surface_get_arrays(0)
	var ta:Array=twig.mesh.surface_get_arrays(0)
	stats={"recipe":RECIPE,"shoots":paths.size(),"leaflet_hints":leaflets,"mesh_surfaces":2,"foliage_triangles":int(fa[Mesh.ARRAY_INDEX].size()/3),"twig_triangles":int(ta[Mesh.ARRAY_INDEX].size()/3),"alpha_blended":false}

func _basis_from(direction:Vector3,roll:float)->Basis:
	var y:=direction.normalized()
	var x:=y.cross(Vector3.FORWARD)
	if x.length_squared()<.01:
		x=y.cross(Vector3.RIGHT)
	x=x.normalized()
	var z:=x.cross(y).normalized()
	return Basis(x,y,z)*Basis(y,roll)

func _leaf(center:Vector3,direction:Vector3,roll:float,scale_value:float,tone:float,radius:float,height:float)->void:
	var basis:=_basis_from(direction,roll)
	var center_world:=Vector3(center.x*radius,center.y*height,center.z*radius)
	var first:=_v.size()
	var stations:=4
	var sides:=5
	var length:=height*.19*scale_value
	var width:=radius*.085*scale_value
	var thickness:=radius*.026*scale_value
	for j in stations:
		var t:=float(j)/float(stations-1)
		var axial:=(t-.46)*length
		var swell:=pow(maxf(0.,sin(PI*t)),.72)
		var bend:=sin(PI*t)*length*.07
		for k in sides:
			var a:=TAU*float(k)/sides
			var asym:=1.+.07*sin(a*3.+roll)
			var local:=Vector3(bend,axial,0)+Vector3(cos(a)*width*swell*asym,0,sin(a)*thickness*swell)
			_v.append(center_world+basis*local)
			_n.append(Vector3.ZERO)
			_colors.append(Color(tone,tone,tone,1))
	for j in stations-1:
		for k in sides:
			var a:=first+j*sides+k
			var b:=first+j*sides+(k+1)%sides
			var c:=a+sides
			var d:=b+sides
			_ix.append_array(PackedInt32Array([a,c,b,b,c,d]))
	for k in range(1,sides-1):
		_ix.append_array(PackedInt32Array([first,first+k+1,first+k]))
		var e:=first+(stations-1)*sides
		_ix.append_array(PackedInt32Array([e,e+k,e+k+1]))
	_recompute_normals(first,_v.size())

func _tube(path:PackedVector3Array,start_radius:float,end_radius:float,radius:float,height:float)->void:
	var first:=_v.size()
	var sides:=5
	for j in path.size():
		var at:=Vector3(path[j].x*radius,path[j].y*height,path[j].z*radius)
		var before:=Vector3(path[maxi(0,j-1)].x*radius,path[maxi(0,j-1)].y*height,path[maxi(0,j-1)].z*radius)
		var after:=Vector3(path[mini(path.size()-1,j+1)].x*radius,path[mini(path.size()-1,j+1)].y*height,path[mini(path.size()-1,j+1)].z*radius)
		var tangent:Vector3=(after-before).normalized()
		var x:=tangent.cross(Vector3.FORWARD).normalized()
		if x.length_squared()<.1:
			x=tangent.cross(Vector3.RIGHT).normalized()
		var z:=tangent.cross(x).normalized()
		var rr:=lerpf(start_radius,end_radius,float(j)/float(path.size()-1))
		for k in sides:
			var n:=x*cos(TAU*k/sides)+z*sin(TAU*k/sides)
			_v.append(at+n*rr)
			_n.append(n)
			_colors.append(Color.WHITE)
	for j in path.size()-1:
		for k in sides:
			var a:=first+j*sides+k
			var b:=first+j*sides+(k+1)%sides
			var c:=a+sides
			var d:=b+sides
			_ix.append_array(PackedInt32Array([a,c,b,b,c,d]))
	for k in range(1,sides-1):
		_ix.append_array(PackedInt32Array([first,first+k+1,first+k]))
		var e:=first+(path.size()-1)*sides
		_ix.append_array(PackedInt32Array([e,e+k,e+k+1]))

func _recompute_normals(first:int,end:int)->void:
	var sums:=PackedVector3Array()
	sums.resize(end-first)
	sums.fill(Vector3.ZERO)
	for i in range(0,_ix.size(),3):
		var a:=_ix[i]
		var b:=_ix[i+1]
		var c:=_ix[i+2]
		if a<first or a>=end or b<first or b>=end or c<first or c>=end:
			continue
		var n:=(_v[c]-_v[a]).cross(_v[b]-_v[a])
		if n.length_squared()<1e-18:
			continue
		sums[a-first]+=n
		sums[b-first]+=n
		sums[c-first]+=n
	for i in sums.size():
		_n[first+i]=sums[i].normalized() if sums[i].length_squared()>1e-18 else Vector3.UP

func _finish(label:String)->MeshInstance3D:
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=_v
	arrays[Mesh.ARRAY_NORMAL]=_n
	arrays[Mesh.ARRAY_INDEX]=_ix
	if label=="ShootFoliage":
		arrays[Mesh.ARRAY_COLOR]=_colors
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node:=MeshInstance3D.new()
	node.name=label
	node.mesh=mesh
	add_child(node)
	_v=PackedVector3Array();_n=PackedVector3Array();_ix=PackedInt32Array();_colors=PackedColorArray()
	return node

func geometry_signature()->String:
	return var_to_bytes([descriptor,twig.mesh.surface_get_arrays(0),foliage.mesh.surface_get_arrays(0)]).hex_encode().sha256_text()
