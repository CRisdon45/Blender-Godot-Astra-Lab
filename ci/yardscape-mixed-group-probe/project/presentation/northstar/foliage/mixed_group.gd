extends Node3D
## Five overlapping low-poly foliage volumes plus four selective closed accents.
## Generic shape grammar only; no species claim, alpha cards, billboard or runtime AI.
const Paint = preload("res://presentation/northstar/foliage/compact_group.gdshader")
const RECIPE := "mixed-volume-accent-group/1"
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
	var stems=[PackedVector3Array([Vector3.ZERO,Vector3(.02,.16,.01),Vector3(.07,.31,-.02)]),PackedVector3Array([Vector3(.03,.12,0),Vector3(-.11,.25,.04),Vector3(-.20,.34,.08)]),PackedVector3Array([Vector3(.04,.17,-.01),Vector3(.15,.28,-.06),Vector3(.23,.39,-.10)])]
	for path in stems:_tube(path,radius*.032,radius*.013,radius,height)
	twig=_finish("TwigGesture")
	var bark:=StandardMaterial3D.new();bark.albedo_color=Color("665541");bark.roughness=1.;twig.material_override=bark
	var masses=[
		[Vector3(-.13,.37,.04),Vector3(.30,.12,.23),.46,0.2],
		[Vector3(.10,.35,-.06),Vector3(.28,.115,.21),.50,1.1],
		[Vector3(-.02,.47,.08),Vector3(.29,.125,.22),.55,2.0],
		[Vector3(.17,.45,.04),Vector3(.245,.105,.19),.48,3.1],
		[Vector3(-.18,.46,-.05),Vector3(.23,.105,.18),.43,4.0]
	]
	for i in masses.size():
		var m=masses[i];_puff(m[0],m[1],float(m[3])+rng.randf_range(-.18,.18),float(m[2])+rng.randf_range(-.035,.035),radius,height)
	var accents=[
		[Vector3(-.25,.40,.08),Vector3(-.80,.50,.30),.68,.54],
		[Vector3(.24,.40,-.08),Vector3(.78,.55,-.29),.66,.50],
		[Vector3(.06,.55,.07),Vector3(.25,.91,.33),.62,.57],
		[Vector3(-.08,.53,-.08),Vector3(-.27,.91,-.31),.60,.52]
	]
	for a in accents:
		var direction:Vector3=(a[1]+Vector3(rng.randf_range(-.02,.02),rng.randf_range(-.01,.02),rng.randf_range(-.02,.02))).normalized()
		_accent(a[0],direction,rng.randf_range(-.35,.35),float(a[2]),float(a[3]),radius,height)
	foliage=_finish("MixedFoliage")
	var paint:=ShaderMaterial.new();paint.shader=Paint;foliage.material_override=paint
	var fa:Array=foliage.mesh.surface_get_arrays(0);var ta:Array=twig.mesh.surface_get_arrays(0)
	stats={"recipe":RECIPE,"masses":masses.size(),"accents":accents.size(),"mesh_surfaces":2,"foliage_triangles":int(fa[Mesh.ARRAY_INDEX].size()/3),"twig_triangles":int(ta[Mesh.ARRAY_INDEX].size()/3),"alpha_blended":false}

func _puff(center:Vector3,extent:Vector3,phase:float,tone:float,radius:float,height:float)->void:
	var first:=_v.size();var sides:=10;var middle_rings:=4
	var c:=Vector3(center.x*radius,center.y*height,center.z*radius)
	_v.append(c+Vector3(0,extent.y*height,0));_n.append(Vector3.ZERO);_colors.append(Color(tone,tone,tone,1))
	for r in range(1,middle_rings+1):
		var v:=PI*float(r)/float(middle_rings+1);var sv:=sin(v);var cv:=cos(v)
		for k in sides:
			var u:=TAU*float(k)/sides
			var irregular:=1.+.08*sin(3.*u+phase)+.045*cos(5.*u-phase*.7)+.035*sin(2.*v+phase)
			var p:=Vector3(cos(u)*extent.x*radius*sv*irregular,extent.y*height*cv,sin(u)*extent.z*radius*sv*irregular)
			_v.append(c+p);_n.append(Vector3.ZERO);_colors.append(Color(tone,tone,tone,1))
	var bottom:=_v.size();_v.append(c-Vector3(0,extent.y*height,0));_n.append(Vector3.ZERO);_colors.append(Color(tone,tone,tone,1))
	for k in sides:_ix.append_array(PackedInt32Array([first,first+1+(k+1)%sides,first+1+k]))
	for r in range(middle_rings-1):
		var base:=first+1+r*sides;var next:=base+sides
		for k in sides:
			var a:=base+k;var b:=base+(k+1)%sides;var cidx:=next+k;var d:=next+(k+1)%sides
			_ix.append_array(PackedInt32Array([a,d,cidx,a,b,d]))
	var last:=first+1+(middle_rings-1)*sides
	for k in sides:_ix.append_array(PackedInt32Array([bottom,last+k,last+(k+1)%sides]))
	_recompute_normals(first,_v.size())

func _basis_from(direction:Vector3,roll:float)->Basis:
	var y:=direction.normalized();var x:=y.cross(Vector3.FORWARD)
	if x.length_squared()<.01:x=y.cross(Vector3.RIGHT)
	x=x.normalized();var z:=x.cross(y).normalized();return Basis(x,y,z)*Basis(y,roll)

func _accent(center:Vector3,direction:Vector3,roll:float,scale_value:float,tone:float,radius:float,height:float)->void:
	var basis:=_basis_from(direction,roll);var cw:=Vector3(center.x*radius,center.y*height,center.z*radius);var first:=_v.size();var stations:=5;var sides:=6
	var length:=height*.27*scale_value;var width:=radius*.115*scale_value;var thickness:=radius*.050*scale_value
	for j in stations:
		var t:=float(j)/float(stations-1);var axial:=(t-.47)*length;var swell:=pow(maxf(0.,sin(PI*t)),.70);var bend:=sin(PI*t)*length*.08
		for k in sides:
			var a:=TAU*float(k)/sides;var local:=Vector3(bend,axial,0)+Vector3(cos(a)*width*swell,0,sin(a)*thickness*swell)
			_v.append(cw+basis*local);_n.append(Vector3.ZERO);_colors.append(Color(tone,tone,tone,1))
	for j in stations-1:
		for k in sides:
			var a:=first+j*sides+k;var b:=first+j*sides+(k+1)%sides;var c:=a+sides;var d:=b+sides;_ix.append_array(PackedInt32Array([a,c,b,b,c,d]))
	for k in range(1,sides-1):
		_ix.append_array(PackedInt32Array([first,first+k+1,first+k]));var e:=first+(stations-1)*sides;_ix.append_array(PackedInt32Array([e,e+k,e+k+1]))
	_recompute_normals(first,_v.size())

func _tube(path:PackedVector3Array,start_radius:float,end_radius:float,radius:float,height:float)->void:
	var first:=_v.size();var sides:=6
	for j in path.size():
		var at:=Vector3(path[j].x*radius,path[j].y*height,path[j].z*radius);var before:=Vector3(path[maxi(0,j-1)].x*radius,path[maxi(0,j-1)].y*height,path[maxi(0,j-1)].z*radius);var after:=Vector3(path[mini(path.size()-1,j+1)].x*radius,path[mini(path.size()-1,j+1)].y*height,path[mini(path.size()-1,j+1)].z*radius)
		var tangent:Vector3=(after-before).normalized();var x:=tangent.cross(Vector3.FORWARD).normalized();if x.length_squared()<.1:x=tangent.cross(Vector3.RIGHT).normalized();var z:=tangent.cross(x).normalized();var rr:=lerpf(start_radius,end_radius,float(j)/float(path.size()-1))
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
	if label=="MixedFoliage":arrays[Mesh.ARRAY_COLOR]=_colors
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);var node:=MeshInstance3D.new();node.name=label;node.mesh=mesh;add_child(node)
	_v=PackedVector3Array();_n=PackedVector3Array();_ix=PackedInt32Array();_colors=PackedColorArray();return node

func geometry_signature()->String:return var_to_bytes([descriptor,twig.mesh.surface_get_arrays(0),foliage.mesh.surface_get_arrays(0)]).hex_encode().sha256_text()
