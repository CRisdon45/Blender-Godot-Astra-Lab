extends Node2D
## Explicit illustrative silhouette. Seed and physical size survive every view change.
const Pigment = preload("res://presentation/northstar/canopy.gdshader")
const StrokeMesh = preload("res://presentation/northstar/stroke_mesh.gd")
var radius := 1.0
var family := "tree"
var palette := "sage"
var identifier := "plant"
var technical := false:
	set(value):
		technical=value
		if material: material.set_shader_parameter("paint_enabled",not value)
var shadow := false
var cast_height := 1.0
var sun := Vector2(-.7,-.7)
var lobes := PackedVector2Array()
var patches: Array = []
var fronds: Array = []
var fans: Array = []
var flowers: Array = []
var leaflets: Array = []
var branches: Array = []
var _paint_vertices := PackedVector2Array()
var _paint_colors := PackedColorArray()
var _paint_indices := PackedInt32Array()
# Canvas drawing is deferred; retain every mesh for the lifetime of its draw commands.
var _paint_meshes: Array[ArrayMesh] = []
var draw_generation := 0
var batched_ink := true # Development comparison path; not an end-user control.
var last_build_usec := 0
var last_build_cached := false
# The study has two light presets. Bound retained media even for arbitrary test lights.
var _light_cache := {}
# Immutable command order and geometry are shared by both light states. Recolor
# the same layout instead of triangulating and assembling every shape again.
var _layout_vertices := PackedVector2Array()
var _layout_indices := PackedInt32Array()
var _stroke_colors: Array[PackedColorArray] = []
var _stroke_cursor := 0
var _reuse_layout := false
var last_build_reused_geometry := false

func invalidate_media() -> void:
	# Call after any future mutation of derived shapes, ink or palette. Current
	# study records remain immutable; this also proves all media is disposable.
	_light_cache.clear()
	_layout_vertices=PackedVector2Array()
	_layout_indices=PackedInt32Array()
	_stroke_colors.clear()
	queue_redraw()

func _finish_build(start_usec: int, cache_key: Vector2) -> void:
	if batched_ink and not technical and not shadow:
		assert(_stroke_cursor==_stroke_colors.size(),"Plant stroke command order must remain fixed between lights")
	if batched_ink and not technical:
		if _light_cache.size()>=2 and not _light_cache.has(cache_key):
			_light_cache.erase(_light_cache.keys()[0])
		_light_cache[cache_key]=_paint_meshes.duplicate()
	last_build_usec=Time.get_ticks_usec()-start_usec

func apply_appearance(is_technical: bool, light: Vector2) -> void:
	var changed := technical!=is_technical or (not shadow and sun!=light)
	technical=is_technical
	sun=light
	if changed: queue_redraw()

func _paint_polygon(points: PackedVector2Array, color: Color) -> void:
	var colors := PackedColorArray()
	colors.resize(points.size());colors.fill(color)
	_paint_colors.append_array(colors)
	if _reuse_layout:return
	var triangles := Geometry2D.triangulate_polygon(points)
	assert(not triangles.is_empty(), "Plant paint polygon must triangulate")
	var offset := _paint_vertices.size()
	_paint_vertices.append_array(points)
	for index in triangles: _paint_indices.append(offset+index)

func _flush_paint() -> void:
	if _paint_colors.is_empty(): return
	if _reuse_layout:
		_paint_vertices=_layout_vertices
		_paint_indices=_layout_indices
	assert(_paint_vertices.size()==_paint_colors.size(),"Retained plant layout must match its paint commands")
	if batched_ink and not technical and not shadow and not _reuse_layout:
		assert(_paint_meshes.is_empty(),"Retained plant layout is one ordered surface")
		_layout_vertices=_paint_vertices
		_layout_indices=_paint_indices
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=_paint_vertices
	arrays[Mesh.ARRAY_COLOR]=_paint_colors
	arrays[Mesh.ARRAY_INDEX]=_paint_indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	_paint_meshes.append(mesh)
	draw_mesh(mesh,null)
	_paint_vertices=PackedVector2Array()
	_paint_colors=PackedColorArray()
	_paint_indices=PackedInt32Array()

func _shadow_patch(patch: Dictionary) -> void:
	# A local penumbra follows the existing radial foliage silhouette. Alpha is
	# integrated into the retained mesh: no viewport blur or navigation redraw.
	var points: PackedVector2Array = patch.points
	var center: Vector2 = patch.at
	var feather := minf(.012+cast_height*.007,patch.radius*.22)
	var offset := _paint_vertices.size()
	var count := points.size()
	_paint_vertices.append(center)
	_paint_colors.append(Color(.20,.25,.19,.095))
	for ring in 3:
		for p in points:
			var delta := p-center
			var extension: float = [-feather*.4,0.0,feather][ring]
			_paint_vertices.append(center+delta.normalized()*maxf(.001,delta.length()+extension))
			_paint_colors.append(Color(.20,.25,.19,[.095,.067,0.0][ring]))
	for j in count:
		var next := (j+1)%count
		_paint_indices.append_array(PackedInt32Array([offset,offset+1+j,offset+1+next]))
		for ring in 2:
			var inner := offset+1+ring*count
			var outer := inner+count
			_paint_indices.append_array(PackedInt32Array([inner+j,outer+j,outer+next,inner+j,outer+next,inner+next]))

func _stroke(points: PackedVector2Array, color: Color, width: float) -> void:
	if technical or not batched_ink:
		_flush_paint();draw_polyline(points,color,width,true);return
	if _reuse_layout:
		_paint_colors.append_array(_stroke_colors[_stroke_cursor]);_stroke_cursor+=1;return
	var stroke := StrokeMesh.new()
	stroke.polyline(points,color,width)
	_stroke_colors.append(stroke.colors)
	_stroke_cursor+=1
	_append_stroke(stroke)

func _append_stroke(stroke: RefCounted) -> void:
	_paint_colors.append_array(stroke.colors)
	if _reuse_layout:return
	var offset := _paint_vertices.size()
	_paint_vertices.append_array(stroke.vertices)
	for index in stroke.indices:_paint_indices.append(offset+index)

func _segment(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	if technical or not batched_ink:
		_flush_paint();draw_line(from,to,color,width,true);return
	if _reuse_layout:
		_paint_colors.append_array(_stroke_colors[_stroke_cursor]);_stroke_cursor+=1;return
	var stroke := StrokeMesh.new()
	stroke.segment(from,to,color,width)
	_stroke_colors.append(stroke.colors)
	_stroke_cursor+=1
	_append_stroke(stroke)

func setup(record: Array, shadow_pass: bool = false) -> void:
	identifier=record[0]; radius=record[3]; family=record[5]; palette=record[6]; shadow=shadow_pass
	cast_height=record[4]
	var rng := RandomNumberGenerator.new()
	rng.seed=identifier.hash()
	if not shadow:
		var paint := ShaderMaterial.new()
		paint.shader=Pigment
		paint.set_shader_parameter("seed",float(absi(identifier.hash())%10000))
		material=paint
	for i in 96:
		var a := TAU*i/96.0
		var r := radius*(.88+.055*sin(a*7+.6)+.04*sin(a*17+2)+rng.randf_range(-.045,.045))
		lobes.append(Vector2.from_angle(a)*r)
	# Branch-scale gaps expose the actual ground beneath the canopy, not painted paper.
	var branch_count := 9 if family=="tree" else 7
	for i in branch_count:
		var a := TAU*i/branch_count+rng.randf_range(-.25,.25)
		branches.append(Vector2.from_angle(a)*radius*rng.randf_range(.40,.76))
	var count := 108 if family=="tree" else 58
	for i in count:
		var anchor: Vector2 = branches[i%branch_count]
		if i%4==0: anchor*=rng.randf_range(.12,.65)
		var at := anchor+Vector2.from_angle(rng.randf()*TAU)*radius*sqrt(rng.randf())*.28
		var r := radius*rng.randf_range(.055,.19)
		var points := PackedVector2Array()
		var phase := rng.randf()*TAU
		for j in 64:
			var t := TAU*j/64.0
			points.append(at+Vector2.from_angle(t)*r*(.85+.17*sin(t*5.0+phase)+.08*sin(t*11.0+phase)+rng.randf_range(-.035,.035)))
		patches.append({"points":points,"at":at,"tone":rng.randf(),"radius":r})
	var blade_count := 9 if family=="broadleaf" else 13
	for i in blade_count:
		var a := TAU*i/blade_count+rng.randf_range(-.24,.24)
		var direction := Vector2.from_angle(a)
		var side := direction.orthogonal()
		var length := radius*rng.randf_range(.65,1.12)
		var bend := rng.randf_range(-.18,.18)*length
		var breadth := .21 if family=="broadleaf" else .070
		var points := PackedVector2Array()
		for j in 17:
			var t := j/16.0
			points.append(direction*length*t+side*(sin(PI*t)*length*breadth+bend*t*t))
		for j in range(16,-1,-1):
			var t := j/16.0
			points.append(direction*length*t+side*(-sin(PI*t)*length*breadth*.65+bend*t*t))
		fronds.append({"points":points,"tip":direction*length,"tone":rng.randf()})
	for patch in patches:
		for i in (5 if patch.tone>.45 else 2):
			var at: Vector2 = patch.at+Vector2.from_angle(rng.randf()*TAU)*patch.radius*sqrt(rng.randf())*.9
			var r: float = radius*rng.randf_range(.012,.035)
			var angle := rng.randf()*TAU
			var points := PackedVector2Array()
			for j in 14:
				var a := TAU*j/14.0
				var p := Vector2(cos(a)*r,sin(a)*r*.55)*(1.0+rng.randf_range(-.20,.20))
				points.append(at+p.rotated(angle))
			leaflets.append({"points":points,"tone":rng.randf(),"at":at})
	for i in 32:
		flowers.append([Vector2.from_angle(rng.randf()*TAU)*radius*sqrt(rng.randf())*.82,rng.randf_range(.075,.14)*radius])
	if family=="palm":_build_fans()
	queue_redraw()

func _build_fans() -> void:
	# Separate stream leaves every pre-existing canopy and flower mark untouched.
	var rng := RandomNumberGenerator.new()
	rng.seed=(identifier+"/fans").hash()
	var order := range(0,fronds.size(),2)
	for i in range(3,fronds.size(),4):order.append(i)
	for i in order:
		var frond: Dictionary = fronds[i]
		var inner: bool = i%2==1
		var direction: Vector2 = frond.tip.normalized()
		var length: float = frond.tip.length()
		var stem_fraction := rng.randf_range(.10,.18) if inner else rng.randf_range(.23,.40)
		var hub: Vector2 = frond.tip*stem_fraction+direction.orthogonal()*length*rng.randf_range(-.04,.04)
		var reach: float = length*(rng.randf_range(.34,.45) if inner else rng.randf_range(.55,.68))
		var spread := rng.randf_range(.64,.84)
		var count := rng.randi_range(8,11)
		var tips := PackedVector2Array()
		var valleys := PackedVector2Array()
		for j in count:
			var angle := lerpf(-spread,spread,float(j)/(count-1))
			tips.append(hub+direction.rotated(angle)*reach*rng.randf_range(.88,1.05))
			if j<count-1:
				var between := angle+spread/(count-1)
				valleys.append(hub+direction.rotated(between)*reach*rng.randf_range(.66,.78))
		var outline := PackedVector2Array([hub])
		for j in count:
			outline.append(tips[j])
			if j<valleys.size():outline.append(valleys[j])
		fans.append({"hub":hub,"tips":tips,"valleys":valleys,"points":outline,"tone":frond.tone})

func _shadow_outline(points: PackedVector2Array, opacity: float) -> void:
	if points[0].is_equal_approx(points[-1]):
		points=points.duplicate();points.resize(points.size()-1)
	_paint_polygon(points,Color(.20,.25,.19,opacity))
	# Small exterior penumbra on the same contour. Bound acute-tip miters.
	var area := 0.0
	for j in points.size():area+=points[j].cross(points[(j+1)%points.size()])
	var feather := .008+cast_height*.004
	var offset := _paint_vertices.size()
	for j in points.size():
		var a := (points[j]-points[(j-1+points.size())%points.size()]).normalized()
		var b := (points[(j+1)%points.size()]-points[j]).normalized()
		var na := Vector2(a.y,-a.x)*signf(area)
		var nb := Vector2(b.y,-b.x)*signf(area)
		var outward := (na+nb).normalized()
		var distance := feather/maxf(.4,absf(outward.dot(nb)))
		_paint_vertices.append(points[j]);_paint_vertices.append(points[j]+outward*distance)
		_paint_colors.append(Color(.20,.25,.19,opacity));_paint_colors.append(Color(.20,.25,.19,0))
	for j in points.size():
		var a := offset+j*2
		var b := offset+((j+1)%points.size())*2
		_paint_indices.append_array(PackedInt32Array([a,a+1,b+1,a,b+1,b]))

func _draw_fans() -> void:
	for fan in fans:
		if shadow:
			_segment(Vector2.ZERO,fan.hub,Color(.20,.25,.19,.16),.016)
			_shadow_outline(fan.points,.15)
			continue
		_segment(Vector2.ZERO,fan.hub,Color(.10,.22,.12,.72),.018)
		if technical:
			_line(fan.points,Color(.25,.32,.28,.60),.018)
			continue
		var color := _canopy_color(fan.hub,fan.tone)
		_paint_polygon(fan.points,color)
		for j in fan.tips.size():
			var tip: Vector2 = fan.tips[j]
			var left: Vector2 = fan.hub if j==0 else fan.valleys[j-1]
			var right: Vector2 = fan.hub if j==fan.tips.size()-1 else fan.valleys[j]
			if j>0:_paint_polygon(PackedVector2Array([fan.hub,left,tip]),color.darkened(.15))
			if j<fan.tips.size()-1:_paint_polygon(PackedVector2Array([fan.hub,tip,right]),color.lerp(Color("e2e8c7"),.16))
			if j%2==0:
				_segment(fan.hub+(tip-fan.hub)*.10,tip,Color(.09,.20,.10,.42),.009)
		var edge: PackedVector2Array = fan.points.slice(1,mini(8,fan.points.size()))
		_stroke(edge,Color(.07,.17,.09,.65),.012)

func base_color() -> Color:
	return {"sage":Color("849b72"),"blue":Color("72a29a"),"lime":Color("a3b94a"),
		"green":Color("3d662b"),"yellow":Color("728232"),"orange":Color("527038"),"pink":Color("7a925c")}[palette]

func _canopy_tone(at: Vector2, variation: float) -> float:
	# Neighboring marks share the crown's light field; small variation articulates it.
	var p := at/radius
	var phase := float(absi(identifier.hash())%1000)*.017
	var branch_variation := sin(p.x*5.0+phase)*sin(p.y*4.0-phase)*.08
	return clampf(.49+.59*p.dot(sun)+branch_variation+(variation-.5)*.19,0.0,1.0)

func _canopy_color(at: Vector2, variation: float) -> Color:
	var tone := _canopy_tone(at,variation)
	var base := base_color()
	var middle := base.lerp(Color("659344"),.26 if palette!="blue" else .04)
	var dark := base.darkened(.78).lerp(Color("063c28"),.38)
	var color := dark.lerp(middle,smoothstep(.10,.53,tone))
	return color.lerp(Color("eef1d8"),smoothstep(.48,.91,tone)*.91)

func _line(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := points.duplicate(); closed.append(points[0])
	_stroke(closed,color,width)

func _broken_ink(points: PackedVector2Array, tone: float, width: float, opacity: float = .80) -> void:
	# Only a few linked edges are inked. The rest remain paint boundaries.
	var start := int(tone*points.size())%points.size()
	var stroke := PackedVector2Array()
	for j in 12: stroke.append(points[(start+j)%points.size()])
	_stroke(stroke,Color(.055,.13,.065,opacity),width)

func _draw() -> void:
	var started := Time.get_ticks_usec()
	draw_generation+=1
	_paint_meshes.clear()
	last_build_cached=false
	_stroke_cursor=0
	_reuse_layout=batched_ink and not technical and not shadow and not _layout_vertices.is_empty()
	last_build_reused_geometry=_reuse_layout
	var cache_key := Vector2.ZERO if shadow else sun
	if batched_ink and not technical and _light_cache.has(cache_key):
		_paint_meshes.assign(_light_cache[cache_key])
		for mesh in _paint_meshes:draw_mesh(mesh,null)
		last_build_cached=true
		last_build_usec=Time.get_ticks_usec()-started
		return
	if lobes.is_empty(): return
	var ink := Color("233728")
	if shadow:
		if technical: return
		if family=="palm":_draw_fans()
		elif family=="broadleaf":
			for f in fronds: _shadow_outline(f.points,.17)
		else:
			for patch in patches:
				_shadow_patch(patch)
		_flush_paint()
		_finish_build(started,cache_key)
		return
	if technical:
		if family=="palm":_draw_fans()
		elif family=="broadleaf":
			for f in fronds: _line(f.points,Color(.25,.32,.28,.6),.018)
		else: _line(lobes,Color(.25,.32,.28,.65),.025)
		draw_circle(Vector2.ZERO,.055,ink)
		last_build_usec=Time.get_ticks_usec()-started
		return
	var base := base_color()
	if family=="palm":_draw_fans()
	elif family=="broadleaf":
		for f in fronds:
			var color := _canopy_color(f.tip*.55,f.tone)
			_paint_polygon(f.points,color)
			var spine := PackedVector2Array()
			for j in 17:spine.append((f.points[j]+f.points[33-j])*.5)
			var left: PackedVector2Array = f.points.slice(0,17)
			for j in range(15,0,-1):left.append(spine[j])
			var right := spine.duplicate()
			for j in range(18,33):right.append(f.points[j])
			var direction: Vector2 = f.tip.normalized()
			var facing := clampf(.5+direction.orthogonal().dot(sun)*.35,0.0,1.0)
			_paint_polygon(left,color.darkened(.14).lerp(color.lightened(.13),facing))
			_paint_polygon(right,color.darkened(.14).lerp(color.lightened(.13),1.0-facing))
			_broken_ink(f.points,f.tone,.012,.60)
			_stroke(PackedVector2Array([spine[0],spine[3],spine[7],spine[11],spine[16]]),Color(.12,.24,.14,.60),.012)
			for j in [5,8,11]:
				_segment(spine[j],f.points[j+2],Color(.15,.26,.14,.32),.007)
				_segment(spine[j],f.points[31-j],Color(.15,.26,.14,.32),.007)
	else:
		for branch in branches:
			_stroke(PackedVector2Array([branch*.30,branch*.55+branch.orthogonal()*.07,branch]),Color(.17,.23,.12,.40),.012)
		for patch in patches:
			var tone := _canopy_tone(patch.at,patch.tone)
			var color := _canopy_color(patch.at,patch.tone)
			_paint_polygon(patch.points,color)
			if patch.tone>.38:
				var highlight: PackedVector2Array = patch.points.duplicate()
				for j in highlight.size(): highlight[j]=patch.at+(highlight[j]-patch.at)*.83
				_paint_polygon(highlight,color.lerp(Color("eef0d5"),.06+.12*tone))
			if patch.tone<.40 or patch.tone>.83:
				var edge_emphasis := smoothstep(.35,.90,patch.at.length()/radius)
				_broken_ink(patch.points,patch.tone,.018,lerpf(.24,.70,edge_emphasis))
			# Local short dry strokes, kept with their canopy patch.
			var k: Vector2 = patch.at
			if patch.tone<.24: _segment(k,k+k.normalized()*patch.radius*.5,Color(.12,.22,.12,.45),.012)
		for leaf in leaflets:
			var color := _canopy_color(leaf.at,leaf.tone).lerp(Color("e5edc7"),.035)
			_paint_polygon(leaf.points,color)
			if leaf.tone<.2: _broken_ink(leaf.points,leaf.tone,.011,.36)
	if family=="flower":
		var petal: Color = {"yellow":Color("efdb39"),"orange":Color("e96d31"),"pink":Color("e6b9c5")}.get(palette,Color("f3efe1"))
		for f in flowers:
			var bloom := PackedVector2Array()
			for j in 30:
				var a := TAU*j/30.0
				bloom.append(f[0]+Vector2.from_angle(a)*f[1]*(1.0+.25*sin(a*5.0)))
			_paint_polygon(bloom,petal)
			var centre := PackedVector2Array()
			for j in 8: centre.append(f[0]+Vector2.from_angle(TAU*j/8.0)*f[1]*.23)
			_paint_polygon(centre,Color("665423"))
	_flush_paint()
	_finish_build(started,cache_key)
