extends RefCounted
## Narrow adapter of Godot's canvas stroke construction; see THIRD_PARTY_NOTICES.md.
## Positive local widths <= 1 and non-looping paths only. No pixel-space cache.
var vertices := PackedVector2Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()

func _strip(points: PackedVector2Array, tones: PackedColorArray) -> void:
	var offset := vertices.size()
	vertices.append_array(points);colors.append_array(tones)
	for i in range(2,points.size()):
		if i%2==0:indices.append_array(PackedInt32Array([offset+i-2,offset+i-1,offset+i]))
		else:indices.append_array(PackedInt32Array([offset+i-1,offset+i-2,offset+i]))

func _quad(points: PackedVector2Array, tones: PackedColorArray) -> void:
	var offset := vertices.size()
	vertices.append_array(points);colors.append_array(tones)
	indices.append_array(PackedInt32Array([offset,offset+1,offset+2,offset,offset+2,offset+3]))

static func _edge(direction: Vector2, previous: Vector2) -> Vector2:
	var bisector := (previous*direction.length()-direction*previous.length()).normalized()
	var sine := sin(atan2(bisector.cross(previous),bisector.dot(previous)))
	var extent := 1.0
	if not is_zero_approx(sine) and not direction.is_equal_approx(previous):
		extent=clampf(1.0/sine,-3.0,3.0)
	else:bisector=direction.orthogonal()
	if bisector.is_zero_approx():bisector=direction.orthogonal()
	return bisector*extent

func polyline(path: PackedVector2Array, color: Color, width: float) -> void:
	assert(path.size()>=2 and width>0.0 and width<=1.0)
	assert(not path[0].is_equal_approx(path[-1]),"Closed paths use the native Technical renderer")
	# Godot compensates small antialiased widths before constructing the feathers.
	width*=.5
	var feather := width*1.25
	var transparent := Color(color,0.0)
	var count := path.size()
	var core := PackedVector2Array();core.resize(count*2+4)
	var left := PackedVector2Array();left.resize(count*2+5)
	var right := PackedVector2Array();right.resize(count*2+5)
	var core_colors := PackedColorArray();core_colors.resize(core.size());core_colors.fill(transparent)
	var side_colors := PackedColorArray();side_colors.resize(left.size());side_colors.fill(transparent)
	var first := Vector2.ZERO
	var last := Vector2.ZERO
	for i in range(1,count):
		first=(path[i]-path[i-1]).normalized()
		if not first.is_zero_approx():break
	for i in range(count-1,0,-1):
		last=(path[i]-path[i-1]).normalized()
		if not last.is_zero_approx():break
	var previous := Vector2.ZERO
	for i in count:
		var direction := previous if i==count-1 else (path[i+1]-path[i]).normalized()
		if direction.is_zero_approx():direction=previous
		var edge := _edge(direction,previous)
		if i==0:edge=first.orthogonal()
		elif i==count-1:edge=last.orthogonal()
		var half := edge*(width*.5)
		var border := edge*feather
		var p := path[i]
		var j := i*2+2
		core[j]=p+half;core[j+1]=p-half
		left[j]=p+half;left[j+1]=p+half+border
		right[j]=p-half;right[j+1]=p-half-border
		core_colors[j]=color;core_colors[j+1]=color;side_colors[j]=color
		if i==0:
			var begin := -direction*feather
			core[0]=p+half+begin;core[1]=p-half+begin
			left[0]=p+half+begin;left[1]=p+half+begin+border
			right[0]=p-half+begin;right[1]=p-half+begin-border
		if i==count-1:
			var end := previous*feather
			var k := count*2+2
			core[k]=p+half+end;core[k+1]=p-half+end
			left[k]=p+half;left[k+1]=p+half+end+border;left[k+2]=p+half+end
			right[k]=p-half;right[k+1]=p-half+end-border;right[k+2]=p-half+end
			side_colors[k]=color
		previous=direction
	# Preserve native command order: core, left feather, right feather.
	_strip(core,core_colors);_strip(left,side_colors);_strip(right,side_colors)

func segment(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	assert(width>0.0 and width<=1.0)
	width*=.5
	var direction := (from-to).normalized()
	var side := (from-to).orthogonal().normalized()
	var half := side*width*.5
	var border := side*width*1.25
	var along := direction*width*1.25
	var a := from+half;var b := from-half;var c := to+half;var d := to-half
	var transparent := Color(color,0.0)
	var fade := PackedColorArray([color,transparent,transparent,color])
	var corner := PackedColorArray([color,transparent,transparent,transparent])
	_quad(PackedVector2Array([a,b,d,c]),PackedColorArray([color,color,color,color]))
	_quad(PackedVector2Array([a,a+border,c+border,c]),fade)
	_quad(PackedVector2Array([b,b-border,d-border,d]),fade)
	_quad(PackedVector2Array([a,a+along,b+along,b]),fade)
	_quad(PackedVector2Array([c,c-along,d-along,d]),fade)
	_quad(PackedVector2Array([a,a+along,a+border+along,a+border]),corner)
	_quad(PackedVector2Array([b,b+along,b-border+along,b-border]),corner)
	_quad(PackedVector2Array([c,c-along,c+border-along,c+border]),corner)
	_quad(PackedVector2Array([d,d-along,d-border-along,d-border]),corner)
