extends Node3D
## One quiet foliage lobe made from small opaque bowed brush polygons.
## Marks have fixed 3D centers and broad emitter-derived normals. They are not
## literal leaves, alpha cards, camera-facing billboards, or a visible solid core.
const RECIPE := "opaque-brush-cloud/1"
const OUTER_PATCHES := 16
const INNER_PATCHES := 4
const GOLDEN_ANGLE := 2.399963229728653

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
		PackedVector3Array([Vector3(0,-height*.47,0),Vector3(.025*radius,-height*.18,.015*radius),Vector3(.02*radius,height*.16,.03*radius)]),
		PackedVector3Array([Vector3(.01*radius,-height*.28,0),Vector3(.15*radius,-height*.05,-.06*radius),Vector3(.39*radius,height*.18,-.18*radius)]),
		PackedVector3Array([Vector3(-.01*radius,-height*.27,0),Vector3(-.14*radius,-height*.04,.07*radius),Vector3(-.37*radius,height*.17,.19*radius)])
	]
	for path in stems:_tube(path,radius*.030,radius*.009)
	twig=_finish("BrushTwigGesture")
	var bark:=StandardMaterial3D.new();bark.albedo_color=Color("665541");bark.roughness=1.;twig.material_override=bark
	var phase:=rng.randf()*TAU
	for index in OUTER_PATCHES:
		var vertical:=1.0-2.0*(float(index)+.5)/float(OUTER_PATCHES)
		var ring:=sqrt(maxf(0.,1.-vertical*vertical))
		var angle:=phase+float(index)*GOLDEN_ANGLE
		var direction:=Vector3(cos(angle)*ring,vertical,sin(angle)*ring)
		var shell:=rng.randf_range(.68,.94)
		var center:=Vector3(direction.x*radius*.76,direction.y*height*.40,direction.z*radius*.76)*shell
		center+=Vector3(rng.randf_range(-.025,.025)*radius,rng.randf_range(-.018,.018)*height,rng.randf_range(-.025,.025)*radius)
		var normal:=Vector3(direction.x/maxf(radius,.001),direction.y/maxf(height*.52,.001),direction.z/maxf(radius,.001)).normalized()
		var width:=radius*rng.randf_range(.42,.54)
		var length:=height*rng.randf_range(.205,.275)
		var tone:=clampf(.49+direction.y*.035+rng.randf_range(-.035,.035),.38,.61)
		_patch(center,normal,rng.randf_range(-PI,PI),width,length,tone,.08,rng.randf()*TAU)
	for index in INNER_PATCHES:
		var angle:=phase+.47+float(index)*TAU/float(INNER_PATCHES)
		var normal:=Vector3(cos(angle)*.72,.34 if index%2==0 else -.18,sin(angle)*.72).normalized()
		var center:=Vector3(cos(angle)*radius*.20,(.04 if index%2==0 else -.09)*height,sin(angle)*radius*.20)
		_patch(center,normal,rng.randf_range(-PI,PI),radius*rng.randf_range(.48,.59),height*rng.randf_range(.22,.29),rng.randf_range(.42,.49),.62,rng.randf()*TAU)
	foliage=_finish("OpaqueBrushFoliage")
	var fa:Array=foliage.mesh.surface_get_arrays(0);var ta:Array=twig.mesh.surface_get_arrays(0)
	stats={
		"recipe":RECIPE,
		"patches":OUTER_PATCHES+INNER_PATCHES,
		"outer_patches":OUTER_PATCHES,
		"inner_patches":INNER_PATCHES,
		"mesh_surfaces":2,
		"foliage_triangles":int(fa[Mesh.ARRAY_INDEX].size()/3),
		"twig_triangles":int(ta[Mesh.ARRAY_INDEX].size()/3),
		"alpha_blended":false,
		"alpha_scissor":false,
		"camera_facing":false,
		"solid_core":false
	}

func _frame(normal:Vector3,roll:float)->Array[Vector3]:
	var n:=normal.normalized();var tangent:=Vector3.UP.cross(n)
	if tangent.length_squared()<.01:tangent=Vector3.RIGHT
	tangent=tangent.normalized();var bitangent:=n.cross(tangent).normalized()
	var ca:=cos(roll);var sa:=sin(roll)
	var t:=(tangent*ca+bitangent*sa).normalized()
	var b:=(bitangent*ca-tangent*sa).normalized()
	return [n,t,b]

func _patch(center:Vector3,normal:Vector3,roll:float,width:float,length:float,tone:float,occlusion:float,wobble_phase:float)->void:
	var frame:=_frame(normal,roll);var n:Vector3=frame[0];var tangent:Vector3=frame[1];var bitangent:Vector3=frame[2]
	var proxy:=(n*.82+Vector3.UP*.18).normalized()
	var first:=_v.size();var angles:=PackedFloat32Array([-2.72,-1.72,-.63,.38,1.36,2.38])
	var radii:=PackedFloat32Array([.84,1.05,.89,1.07,.82,1.0])
	for index in angles.size():
		var a:=angles[index];var irregular:=radii[index]*(1.+.045*sin(float(index)*2.17+wobble_phase))
		var x:=cos(a)*width*.5*irregular;var y:=sin(a)*length*.5*irregular
		var bow:=sin(a*2.+wobble_phase)*minf(width,length)*.055
		_v.append(center+tangent*x+bitangent*y+n*bow)
		_n.append(proxy);_colors.append(Color(tone,occlusion,0,1))
	for index in range(1,angles.size()-1):_ix.append_array(PackedInt32Array([first,first+index,first+index+1]))

func _tube(path:PackedVector3Array,start_radius:float,end_radius:float)->void:
	var first:=_v.size();var sides:=5
	for j in path.size():
		var at:=path[j];var before:=path[maxi(0,j-1)];var after:=path[mini(path.size()-1,j+1)]
		var tangent:Vector3=(after-before).normalized();var x:=tangent.cross(Vector3.FORWARD).normalized()
		if x.length_squared()<.1:x=tangent.cross(Vector3.RIGHT).normalized()
		var z:=tangent.cross(x).normalized();var rr:=lerpf(start_radius,end_radius,float(j)/float(path.size()-1))
		for k in sides:
			var n:=x*cos(TAU*k/sides)+z*sin(TAU*k/sides);_v.append(at+n*rr);_n.append(n);_colors.append(Color.WHITE)
	for j in path.size()-1:
		for k in sides:
			var a:=first+j*sides+k;var b:=first+j*sides+(k+1)%sides;var c:=a+sides;var d:=b+sides;_ix.append_array(PackedInt32Array([a,c,b,b,c,d]))
	for k in range(1,sides-1):
		_ix.append_array(PackedInt32Array([first,first+k+1,first+k]))
		var e:=first+(path.size()-1)*sides;_ix.append_array(PackedInt32Array([e,e+k,e+k+1]))

func _finish(label:String)->MeshInstance3D:
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=_v;arrays[Mesh.ARRAY_NORMAL]=_n;arrays[Mesh.ARRAY_INDEX]=_ix
	if label=="OpaqueBrushFoliage":arrays[Mesh.ARRAY_COLOR]=_colors
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node:=MeshInstance3D.new();node.name=label;node.mesh=mesh;add_child(node)
	_v=PackedVector3Array();_n=PackedVector3Array();_ix=PackedInt32Array();_colors=PackedColorArray();return node

func geometry_signature()->String:return var_to_bytes([descriptor,twig.mesh.surface_get_arrays(0),foliage.mesh.surface_get_arrays(0)]).hex_encode().sha256_text()
