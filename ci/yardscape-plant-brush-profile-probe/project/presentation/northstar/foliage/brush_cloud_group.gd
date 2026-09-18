extends Node3D
## One quiet foliage lobe made from small alpha-scissored brush clusters.
## Every card has a fixed 3D center and broad emitter-derived normal. Only each
## small card faces the camera; the plant never billboards and has no solid core.
const RECIPE := "fixed-center-brush-card-cloud/2"
const ATLAS_TILES := 4
const GOLDEN_ANGLE := 2.399963229728653

var descriptor:Dictionary={}
var foliage:MeshInstance3D
var twig:MeshInstance3D
var stats:Dictionary={}
var _v:=PackedVector3Array()
var _n:=PackedVector3Array()
var _ix:=PackedInt32Array()
var _colors:=PackedColorArray()
var _uv:=PackedVector2Array()
var _uv2:=PackedVector2Array()

func configure(seed_value:int,radius:float,height:float,card_budget:=18)->void:
	assert(get_child_count()==0 and radius>0. and height>0. and card_budget>=8)
	descriptor={"seed":seed_value,"radius":radius,"height":height,"card_budget":card_budget}
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
	var outer_cards:=maxi(6,roundi(float(card_budget)*.67));var inner_cards:=card_budget-outer_cards
	for index in outer_cards:
		var vertical:=1.0-2.0*(float(index)+.5)/float(outer_cards)
		var ring:=sqrt(maxf(0.,1.-vertical*vertical))
		var angle:=phase+float(index)*GOLDEN_ANGLE
		var direction:=Vector3(cos(angle)*ring,vertical,sin(angle)*ring)
		var shell:=rng.randf_range(.62,.91)
		var center:=Vector3(direction.x*radius*.78,direction.y*height*.40,direction.z*radius*.78)*shell
		center+=Vector3(rng.randf_range(-.025,.025)*radius,rng.randf_range(-.018,.018)*height,rng.randf_range(-.025,.025)*radius)
		var normal:=Vector3(direction.x/maxf(radius,.001),direction.y/maxf(height*.52,.001),direction.z/maxf(radius,.001)).normalized()
		var width:=radius*rng.randf_range(.57,.72)
		var length:=height*rng.randf_range(.235,.305)
		var tone:=clampf(.49+direction.y*.035+rng.randf_range(-.035,.035),.38,.61)
		_card(center,normal,rng.randf_range(-.38,.38),width,length,tone,.08,rng.randi_range(0,ATLAS_TILES-1))
	for index in inner_cards:
		var angle:=phase+.37+float(index)*GOLDEN_ANGLE
		var vertical:=rng.randf_range(-.52,.58)
		var direction:=Vector3(cos(angle)*sqrt(1.-vertical*vertical),vertical,sin(angle)*sqrt(1.-vertical*vertical))
		var depth:=rng.randf_range(.16,.49)
		var center:=Vector3(direction.x*radius*.78,direction.y*height*.38,direction.z*radius*.78)*depth
		var normal:=(direction*.78+Vector3.UP*.22).normalized()
		_card(center,normal,rng.randf_range(-.52,.52),radius*rng.randf_range(.62,.78),height*rng.randf_range(.25,.33),rng.randf_range(.42,.49),.56,rng.randi_range(0,ATLAS_TILES-1))
	foliage=_finish("BrushCardFoliage")
	var fa:Array=foliage.mesh.surface_get_arrays(0);var ta:Array=twig.mesh.surface_get_arrays(0)
	stats={
		"recipe":RECIPE,
		"cards":card_budget,
		"outer_cards":outer_cards,
		"inner_cards":inner_cards,
		"mesh_surfaces":2,
		"foliage_triangles":int(fa[Mesh.ARRAY_INDEX].size()/3),
		"twig_triangles":int(ta[Mesh.ARRAY_INDEX].size()/3),
		"alpha_blended":false,
		"alpha_scissor":true,
		"camera_facing":true,
		"fixed_3d_centers":true,
		"whole_plant_billboard":false,
		"solid_core":false
	}

func _card(center:Vector3,normal:Vector3,roll:float,width:float,height:float,tone:float,occlusion:float,tile:int)->void:
	var proxy:=(normal.normalized()*.82+Vector3.UP*.18).normalized();var first:=_v.size()
	var corners:=PackedVector2Array([Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)])
	var roll_code:=fposmod(roll+PI,TAU)/TAU
	for corner in corners:
		_v.append(center);_n.append(proxy);_colors.append(Color(tone,occlusion,roll_code,1))
		_uv.append(Vector2((float(tile)+lerpf(.018,.982,corner.x))/float(ATLAS_TILES),lerpf(.018,.982,corner.y)))
		_uv2.append(Vector2(width,height))
	_ix.append_array(PackedInt32Array([first,first+1,first+2,first,first+2,first+3]))

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
	if label=="BrushCardFoliage":arrays[Mesh.ARRAY_COLOR]=_colors;arrays[Mesh.ARRAY_TEX_UV]=_uv;arrays[Mesh.ARRAY_TEX_UV2]=_uv2
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node:=MeshInstance3D.new();node.name=label;node.mesh=mesh;add_child(node)
	_v=PackedVector3Array();_n=PackedVector3Array();_ix=PackedInt32Array();_colors=PackedColorArray();_uv=PackedVector2Array();_uv2=PackedVector2Array();return node

static func brush_atlas()->ImageTexture:
	var tile_size:=64;var image:=Image.create(tile_size*ATLAS_TILES,tile_size,false,Image.FORMAT_RGBA8)
	for tile in ATLAS_TILES:
		for y in tile_size:
			for x in tile_size:
				var p:=Vector2((float(x)+.5)/float(tile_size)*2.-1.,(float(y)+.5)/float(tile_size)*2.-1.)
				var centers:=[Vector2(-.39,.02),Vector2(-.02,-.055),Vector2(.39,.035)]
				var radii:=[Vector2(.56,.55),Vector2(.61,.61),Vector2(.54,.52)]
				var alpha:=0.0
				for lobe in centers.size():
					var center:Vector2=centers[lobe]+Vector2(.018*float(tile-1),.028*sin(float(tile+lobe)*1.7))
					var radius:Vector2=radii[lobe]*Vector2(1.+.025*float(tile%2),1.-.035*float((tile+lobe)%2))
					var q:=(p-center)/radius;var angle:=atan2(q.y,q.x);var radial:=q.length()
					var edge:=.96+.055*sin((3.+float((tile+lobe)%2))*angle+float(tile)*.81+float(lobe))+.025*cos(7.*angle-float(lobe))
					var bristle:=.022*sin((p.x+float(lobe)*.17)*19.+float(tile)*1.3)*(1.-clampf(abs(q.y),0.,1.))
					alpha=maxf(alpha,clampf((edge+bristle-radial)*18.+.5,0.,1.))
				image.set_pixel(tile*tile_size+x,y,Color(1,1,1,alpha))
	image.generate_mipmaps();return ImageTexture.create_from_image(image)

func geometry_signature()->String:return var_to_bytes([descriptor,twig.mesh.surface_get_arrays(0),foliage.mesh.surface_get_arrays(0)]).hex_encode().sha256_text()
