extends Node3D
## Compact generic group made from small asymmetric 3D paint dabs around twig gestures.
## Dabs are visual marks, not literal leaves, cards, billboards or botanical organs.
const Paint = preload("res://presentation/northstar/foliage/compact_group.gdshader")
const RECIPE := "volumetric-paint-dabs/2"
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
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value
	var stems=[
		PackedVector3Array([Vector3.ZERO,Vector3(.02,.16,.01),Vector3(.03,.34,.02)]),
		PackedVector3Array([Vector3(.02,.08,0),Vector3(.14,.22,-.05),Vector3(.25,.35,-.11)]),
		PackedVector3Array([Vector3(-.02,.08,0),Vector3(-.14,.22,.05),Vector3(-.25,.35,.11)])
	]
	for path in stems:_tube(path,radius*.030,radius*.010,radius,height)
	twig=_finish("TwigGesture")
	var bark:=StandardMaterial3D.new();bark.albedo_color=Color("665541");bark.roughness=1.;twig.material_override=bark
	# Same four clusters and six dabs per cluster as v1. Only their spatial
	# footprint and mark dimensions grow to match the compact control more fairly.
	var centers=[Vector3(-.18,.38,.09),Vector3(.18,.37,-.09),Vector3(.00,.50,.04),Vector3(.02,.39,.19)]
	var tones=PackedFloat32Array([.46,.51,.56,.49])
	var offsets=[
		Vector3(-.112,-.044,.038),Vector3(.100,-.031,-.050),Vector3(-.050,.069,-.088),
		Vector3(.056,.081,.069),Vector3(-.094,.094,.019),Vector3(.106,.075,.025)
	]
	var count:=0
	for cluster in centers.size():
		for j in offsets.size():
			var at:Vector3=centers[cluster]+offsets[j]
			at+=Vector3(rng.randf_range(-.020,.020),rng.randf_range(-.014,.020),rng.randf_range(-.020,.020))
			var outward:Vector3=Vector3(at.x,at.y-.30,at.z).normalized()
			var direction:Vector3=(outward*.72+Vector3.UP*.45+Vector3(rng.randf_range(-.15,.15),0,rng.randf_range(-.15,.15))).normalized()
			var width:float=radius*rng.randf_range(.120,.165)
			var length:float=height*rng.randf_range(.082,.112)
			var thickness:float=radius*rng.randf_range(.060,.088)
			var tone:float=float(tones[cluster])+rng.randf_range(-.045,.045)
			_dab(at,direction,rng.randf_range(-PI,PI),width,length,thickness,tone,radius,height,rng.randf()*TAU)
			count+=1
	foliage=_finish("DabFoliage")
	var paint:=ShaderMaterial.new();paint.shader=Paint;foliage.material_override=paint
	var fa:Array=foliage.mesh.surface_get_arrays(0);var ta:Array=twig.mesh.surface_get_arrays(0)
	stats={"recipe":RECIPE,"dabs":count,"clusters":centers.size(),"mesh_surfaces":2,"foliage_triangles":int(fa[Mesh.ARRAY_INDEX].size()/3),"twig_triangles":int(ta[Mesh.ARRAY_INDEX].size()/3),"alpha_blended":false}

func _basis_from(direction:Vector3,roll:float)->Basis:
	var y:=direction.normalized();var x:=y.cross(Vector3.FORWARD)
	if x.length_squared()<.01:x=y.cross(Vector3.RIGHT)
	x=x.normalized();var z:=x.cross(y).normalized();return Basis(x,y,z)*Basis(y,roll)

func _dab(center:Vector3,direction:Vector3,roll:float,width:float,length:float,thickness:float,tone:float,radius:float,height:float,phase:float)->void:
	var basis:=_basis_from(direction,roll)
	var c:=Vector3(center.x*radius,center.y*height,center.z*radius)
	var first:=_v.size();var sides:=6
	_v.append(c+basis*Vector3(0,-length*.56,0));_n.append(Vector3.ZERO);_colors.append(Color(tone,tone,tone,1))
	for k in sides:
		var a:=TAU*float(k)/sides
		var irregular:=1.+.10*sin(3.*a+phase)+.055*cos(5.*a-phase)
		var local:=Vector3(cos(a)*width*irregular,length*.05*sin(2.*a+phase),sin(a)*thickness*irregular)
		_v.append(c+basis*local);_n.append(Vector3.ZERO);_colors.append(Color(tone,tone,tone,1))
	var end_tip:=_v.size();_v.append(c+basis*Vector3(length*.08,length*.44,0));_n.append(Vector3.ZERO);_colors.append(Color(tone,tone,tone,1))
	for k in sides:_ix.append_array(PackedInt32Array([first,first+1+(k+1)%sides,first+1+k]))
	for k in sides:_ix.append_array(PackedInt32Array([end_tip,first+1+k,first+1+(k+1)%sides]))
	_recompute_normals(first,_v.size())

func _tube(path:PackedVector3Array,start_radius:float,end_radius:float,radius:float,height:float)->void:
	var first:=_v.size();var sides:=5
	for j in path.size():
		var at:=Vector3(path[j].x*radius,path[j].y*height,path[j].z*radius)
		var before:=Vector3(path[maxi(0,j-1)].x*radius,path[maxi(0,j-1)].y*height,path[maxi(0,j-1)].z*radius)
		var after:=Vector3(path[mini(path.size()-1,j+1)].x*radius,path[mini(path.size()-1,j+1)].y*height,path[mini(path.size()-1,j+1)].z*radius)
		var tangent:Vector3=(after-before).normalized();var x:=tangent.cross(Vector3.FORWARD).normalized()
		if x.length_squared()<.1:x=tangent.cross(Vector3.RIGHT).normalized()
		var z:=tangent.cross(x).normalized();var rr:=lerpf(start_radius,end_radius,float(j)/float(path.size()-1))
		for k in sides:
			var n:=x*cos(TAU*k/sides)+z*sin(TAU*k/sides);_v.append(at+n*rr);_n.append(n);_colors.append(Color.WHITE)
	for j in path.size()-1:
		for k in sides:
			var a:=first+j*sides+k;var b:=first+j*sides+(k+1)%sides;var c:=a+sides;var d:=b+sides;_ix.append_array(PackedInt32Array([a,c,b,b,c,d]))
	for k in range(1,sides-1):
		_ix.append_array(PackedInt32Array([first,first+k+1,first+k]));var e:=first+(path.size()-1)*sides;_ix.append_array(PackedInt32Array([e,e+k,e+k+1]))

func _recompute_normals(first:int,end:int)->void:
	var sums:=PackedVector3Array();sums.resize(end-first);sums.fill(Vector3.ZERO)
	for i in range(0,_ix.size(),3):
		var a:=_ix[i];var b:=_ix[i+1];var c:=_ix[i+2]
		if a<first or a>=end or b<first or b>=end or c<first or c>=end:continue
		var n:=(_v[c]-_v[a]).cross(_v[b]-_v[a]);if n.length_squared()<1e-18:continue
		sums[a-first]+=n;sums[b-first]+=n;sums[c-first]+=n
	for i in sums.size():_n[first+i]=sums[i].normalized() if sums[i].length_squared()>1e-18 else Vector3.UP

func _finish(label:String)->MeshInstance3D:
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=_v;arrays[Mesh.ARRAY_NORMAL]=_n;arrays[Mesh.ARRAY_INDEX]=_ix
	if label=="DabFoliage":arrays[Mesh.ARRAY_COLOR]=_colors
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);var node:=MeshInstance3D.new();node.name=label;node.mesh=mesh;add_child(node)
	_v=PackedVector3Array();_n=PackedVector3Array();_ix=PackedInt32Array();_colors=PackedColorArray();return node

func geometry_signature()->String:return var_to_bytes([descriptor,twig.mesh.surface_get_arrays(0),foliage.mesh.surface_get_arrays(0)]).hex_encode().sha256_text()
