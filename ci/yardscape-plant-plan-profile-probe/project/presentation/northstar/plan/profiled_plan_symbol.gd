extends Node2D
## Direct Plan projection from semantic plant inputs.
## No 3D mesh, Node3D, renderer readback, textures, or runtime AI.
const Layout=preload("res://presentation/northstar/foliage/plant_form_layout.gd")
const Profiles=preload("res://presentation/northstar/foliage/plant_form_profiles.gd")

var tree:Dictionary={}
var profile:Dictionary={}
var sun_direction:=Vector2(.53,-.85).normalized()
var pixels_per_meter:=112.0
var lobes:Array[Dictionary]=[]
var scaffold:Array[Dictionary]=[]
var phase:=0.0
var stats:Dictionary={}

func configure(tree_value:Dictionary,profile_value:Dictionary,ppm:=112.0)->void:
	assert(Profiles.input_error(profile_value).is_empty())
	assert(tree_value.has("seed") and tree_value.has("crown_radius"))
	tree=tree_value.duplicate(true);profile=profile_value.duplicate(true);pixels_per_meter=ppm
	phase=Layout.phase_for_seed(int(tree.seed),profile)
	lobes=Layout.plan_lobes(profile,phase)
	scaffold=Layout.scaffold_paths(profile,phase)
	stats={
		"profile":str(profile.id),
		"lobes":lobes.size(),
		"scaffold_paths":scaffold.size(),
		"crown_radius":float(tree.crown_radius),
		"layout_signature":layout_signature(),
		"normalized_bounds":normalized_bounds(),
		"lobe_area_proxy":lobe_area_proxy()
	}
	queue_redraw()

func set_sun_direction(value:Vector2)->void:
	if value.length_squared()<1e-8:return
	sun_direction=value.normalized();queue_redraw()

func layout_signature()->String:
	return var_to_bytes([phase,lobes,scaffold]).hex_encode().sha256_text()

func normalized_bounds()->Rect2:
	if lobes.is_empty():return Rect2()
	var first:Dictionary=lobes[0];var c:Vector2=first.center;var r:float=float(first.radius)
	var minp:=c-Vector2.ONE*r;var maxp:=c+Vector2.ONE*r
	for lobe in lobes:
		c=lobe.center;r=float(lobe.radius)
		minp.x=minf(minp.x,c.x-r);minp.y=minf(minp.y,c.y-r)
		maxp.x=maxf(maxp.x,c.x+r);maxp.y=maxf(maxp.y,c.y+r)
	return Rect2(minp,maxp-minp)

func lobe_area_proxy()->float:
	var total:=0.0
	for lobe in lobes:
		var r:float=float(lobe.radius)
		total+=PI*r*r
	return total

func _plan_point(value:Vector3)->Vector2:
	return Vector2(value.x,-value.z)*float(tree.crown_radius)*pixels_per_meter

func _lobe_center(value:Vector2)->Vector2:
	return Vector2(value.x,-value.y)*float(tree.crown_radius)*pixels_per_meter

func _family_value(angle:float)->float:
	var alignment:=Vector2(cos(angle),sin(angle)).dot(sun_direction)
	if alignment>.28:return 1.0
	if alignment<-.28:return -1.0
	return 0.0

func _fill_for(lobe:Dictionary)->Color:
	var family_value:=0.0 if int(lobe.family)<0 else _family_value(float(lobe.family_angle))
	var role:=str(lobe.role)
	var alpha:=.54 if role=="primary" else .45 if role=="secondary" else .48
	if family_value>0.5:return Color(0.58,0.65,0.36,alpha)
	if family_value<-.5:return Color(0.22,0.35,0.16,alpha+.05)
	return Color(0.38,0.51,0.24,alpha)

func _wash_for(fill:Color)->Color:
	return Color(fill.r+.06,fill.g+.07,fill.b+.04,.18)

func _lobe_polygon(lobe:Dictionary,index:int,scale_value:float)->PackedVector2Array:
	var result:=PackedVector2Array()
	var center:=_lobe_center(lobe.center)
	var radius:=float(lobe.radius)*float(tree.crown_radius)*pixels_per_meter*scale_value
	var rotation:=float(lobe.angle)*.34
	var role:=str(lobe.role)
	var squash:=.80 if role=="primary" else .76 if role=="secondary" else .84
	var wobble_phase:=float(index)*.67+float(tree.seed)*.013
	var points:=18
	for k in points:
		var a:=TAU*float(k)/float(points)
		var wobble:=1.0+.065*sin(3.*a+wobble_phase)+.035*cos(5.*a-wobble_phase*.7)
		var local:=Vector2(cos(a)*radius*wobble,sin(a)*radius*squash*wobble)
		result.append(center+local.rotated(rotation))
	return result

func _draw_scaffold()->void:
	var bark:=Color(str(profile.bark_hex));bark.a=.60
	for path in scaffold:
		var role:=str(path.role)
		if role=="trunk":continue
		var points:=PackedVector2Array()
		for p in path.points:points.append(_plan_point(p))
		var base_width:=float(path.start_radius)*float(tree.crown_radius)*pixels_per_meter*2.0
		var width:=maxf(.8,base_width*(.80 if role=="primary" else .64))
		draw_polyline(points,bark,width,true)
	draw_circle(Vector2.ZERO,maxf(2.2,float(profile.trunk.start_radius)*float(tree.crown_radius)*pixels_per_meter*.82),Color(bark.r,bark.g,bark.b,.72))

func _draw()->void:
	if lobes.is_empty():return
	# Scaffold first: enough to hint species gesture without becoming branch spaghetti.
	_draw_scaffold()
	# Broad watercolor-like washes unify overlapping lobes.
	for i in lobes.size():
		var fill:=_fill_for(lobes[i])
		draw_colored_polygon(_lobe_polygon(lobes[i],i,1.08),_wash_for(fill))
	# Main tonal masses.
	for i in lobes.size():
		var lobe:Dictionary=lobes[i]
		var fill:=_fill_for(lobe)
		draw_colored_polygon(_lobe_polygon(lobe,i,1.0),fill)
		if str(lobe.role)=="primary":
			var outline:=Color(.16,.25,.12,.42)
			var edge:=_lobe_polygon(lobe,i,1.0)
			edge.append(edge[0])
			draw_polyline(edge,outline,1.15,true)
