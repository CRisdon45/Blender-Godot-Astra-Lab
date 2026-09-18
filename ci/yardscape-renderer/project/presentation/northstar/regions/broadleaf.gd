extends "res://presentation/northstar/plant.gd"
## Generic broadleaf clump, not a named species. Derived paint only.
## Retains the old fronds for Technical mode; source position/radius never change.
const RECIPE := "broadleaf-clump/1"
var blades: Array[Dictionary] = []
var source_record: Array = []
var basal_mass := PackedVector2Array()

static func input_error(value: Array) -> String:
	if value.size() != 7: return "record_size"
	if not value[0] is String or value[0].is_empty(): return "identifier"
	for index in [1, 2, 3, 4]:
		if typeof(value[index]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(value[index]):
			return "nonfinite_dimension"
	if value[3] <= 0. or value[4] < 0.: return "dimension_range"
	if value[5] != "broadleaf": return "family"
	if value[6] not in ["sage", "blue", "lime", "green", "yellow", "orange", "pink"]: return "palette"
	return ""

func setup(value: Array, shadow_pass: bool = false) -> void:
	assert(input_error(value).is_empty(), "Invalid broadleaf study record")
	source_record = value.duplicate(true)
	super.setup(value, shadow_pass)
	_build_blades()

func _build_blades() -> void:
	blades.clear()
	basal_mass.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = (identifier + "/" + RECIPE).hash()
	var phase := rng.randf() * TAU
	for j in 13:
		basal_mass.append(Vector2.from_angle(phase + TAU * float(j) / 13.) * radius * rng.randf_range(.065, .11))
	# Three unequal shoots, not evenly-spaced blades sharing a single centre.
	# Outer leaves draw first; shorter emergent leaves draw over their bases.
	for index in 7:
		var shoot: int = [0, 1, 2, 0, 1, 2, 0][index]
		var shoot_angle: float = phase + [0., 2.10, 4.30][shoot]
		var direction := Vector2.from_angle(shoot_angle)
		var origin := direction * .035 + direction.orthogonal() * .018
		var angle: float = shoot_angle + [-.46, .16, -.38, .50, -.63, .42, .12][index] + rng.randf_range(-.15, .15)
		var axis := Vector2.from_angle(angle)
		var side := axis.orthogonal()
		var reach := rng.randf_range(.77, .96) if index < 4 else rng.randf_range(.49, .76)
		var tip := axis * reach + side * rng.randf_range(-.07, .07)
		var base := origin + axis * reach * (rng.randf_range(.18, .27) if index < 4 else rng.randf_range(.04, .12))
		var delta := tip - base
		var length_value := delta.length()
		var along := delta.normalized()
		var normal := along.orthogonal()
		var bend := length_value * rng.randf_range(-.17, .17)
		var breadth := length_value * rng.randf_range(.24, .33)
		var spine := PackedVector2Array()
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		var ripple_phase := rng.randf() * TAU
		var asymmetry := rng.randf_range(.65, .92)
		for j in 21:
			var t := float(j) / 20.
			var middle := base.lerp(tip, t) + normal * bend * sin(PI * t)
			var shoulder := pow(maxf(0., sin(PI * t)), .67)
			var wave := 1. + .065 * sin(t * 11. + ripple_phase) + .035 * sin(t * 23. + ripple_phase)
			var width := breadth * shoulder * wave
			spine.append(middle * radius)
			left.append((middle + normal * width) * radius)
			right.append((middle - normal * width * asymmetry) * radius)
		# Remove duplicate base/tip vertices. They break fill/shadow triangulation.
		var outline := left.duplicate()
		for j in range(19, 0, -1): outline.append(right[j])
		var stalk := PackedVector2Array()
		for j in 7:
			var t := float(j) / 6.
			stalk.append((origin.lerp(base, t) - side * .020 * sin(t * PI)) * radius)
		blades.append({"points": outline, "left": left, "right": right, "spine": spine,
			"stalk": stalk, "tip": tip * radius, "tone": rng.randf(), "index": index,
			"light_side": rng.randf() > .5})
	queue_redraw()

func form_identity() -> String:
	return var_to_bytes([RECIPE, source_record, basal_mass, blades]).hex_encode().sha256_text()

func _draw_blades() -> void:
	_paint_polygon(basal_mass, Color(.12, .22, .14, .14 if shadow else .82))
	for blade in blades:
		if shadow:
			_stroke(blade.stalk, Color(.17, .23, .17, .12), radius * .013)
			_shadow_outline(blade.points, .145)
			continue
		var position_sample: Vector2 = blade.spine[11]
		var color := base_color().lerp(_canopy_color(position_sample, blade.tone), .69)
		color.a = .94
		_stroke(blade.stalk, Color(.10, .19, .115, .66), radius * .008)
		_paint_polygon(blade.points, color)
		# A broad pale passage follows the curved leaf, rather than splitting the
		# whole blade into two uniformly colored polygon halves.
		var wash := PackedVector2Array()
		for j in range(3, 19):
			var amount := .43 + .17 * sin(float(j) * .49 + blade.tone * 4.)
			wash.append(blade.spine[j].lerp(blade.left[j], amount))
		for j in range(18, 2, -1):
			wash.append(blade.spine[j].lerp(blade.right[j], .28))
		var pale := color.lerp(Color("e4edd1"), .34)
		pale.a = .49
		_paint_polygon(wash, pale)
		# Pigment at the base joins overlapping shoots. It is a curved passage,
		# not an additional geometric blade or a screen-space shadow.
		var root_wash := PackedVector2Array()
		for j in range(0, 11): root_wash.append(blade.spine[j].lerp(blade.right[j], .89))
		for j in range(10, 0, -1): root_wash.append(blade.spine[j].lerp(blade.left[j], .32))
		var dark := base_color().darkened(.53)
		dark.a = .25
		_paint_polygon(root_wash, dark)
		# Keep most of the perimeter a paint edge. Selective connected ink and a
		# curved midrib give the leaf structure without an all-over vein diagram.
		var contour: PackedVector2Array = blade.right if blade.index % 2 == 0 else blade.left
		_stroke(contour.slice(3, 16), Color(.06, .14, .08, .65), radius * .006)
		_stroke(blade.spine.slice(1, 19), Color(.15, .24, .13, .43), radius * .005)
		if blade.index % 3 != 1:
			for j in [7, 12]:
				var branch := PackedVector2Array([blade.spine[j], blade.spine[j + 2].lerp(contour[j + 3], .40), contour[j + 4] * .98 + blade.spine[j] * .02])
				_stroke(branch, Color(.10, .21, .11, .24), radius * .0035)

static func _mark_color(value: Color) -> Color:
	# Native stroke uniforms and mesh vertex colors share canonical inputs.
	# Keeps the established one-channel comparison bound without changing it.
	return Color8(roundi(value.r*255.), roundi(value.g*255.), roundi(value.b*255.), roundi(value.a*255.))

func _paint_polygon(points: PackedVector2Array, color: Color) -> void:
	super._paint_polygon(points, color if technical else _mark_color(color))

func _stroke(points: PackedVector2Array, color: Color, width: float) -> void:
	super._stroke(points, color if technical else _mark_color(color), width)

func _draw() -> void:
	if technical:
		super._draw()
		return
	var started := Time.get_ticks_usec()
	draw_generation += 1
	_paint_meshes.clear()
	last_build_cached = false
	_stroke_cursor = 0
	_reuse_layout = batched_ink and not shadow and not _layout_vertices.is_empty()
	last_build_reused_geometry = _reuse_layout
	var cache_key := Vector2.ZERO if shadow else sun
	if batched_ink and _light_cache.has(cache_key):
		_paint_meshes.assign(_light_cache[cache_key])
		for mesh in _paint_meshes: draw_mesh(mesh, null)
		last_build_cached = true
		last_build_usec = Time.get_ticks_usec() - started
		return
	if blades.is_empty(): return
	_draw_blades()
	_flush_paint()
	_finish_build(started, cache_key)
