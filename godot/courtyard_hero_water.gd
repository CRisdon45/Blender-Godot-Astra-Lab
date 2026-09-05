extends "res://courtyard_anime.gd"
## Opt-in water lookdev. Original scenes, meshes and materials stay unchanged.
const HERO_WATER = preload("res://shaders/hero_water.gdshader")
const HERO_BASIN = preload("res://shaders/hero_basin.gdshader")
const HERO_SPILL = preload("res://shaders/hero_spillway.gdshader")
var basin_materials: Array[ShaderMaterial] = []
var painted_foliage: Array[ShaderMaterial] = []
var probe: ReflectionProbe
var pool_lights: Array[OmniLight3D] = []
var night_mode := false

func _ready() -> void:
	super._ready()
	if water._pool_material == null:
		push_error("HERO_WATER_REQUIRES_BOUND_POOL")
		return
	# The controller already cloned and retained these materials. Swap the look,
	# not its geometry-derived contacts, clock, visibility tracking or W behavior.
	for material in water._materials:
		var original: String = material.shader.resource_path
		material.shader = HERO_WATER if original == water.WATER_PATH else HERO_SPILL
		material.set_shader_parameter("water_level",water.snapshot().water_level)
	if water.rebuild_contacts() != OK:
		push_error("HERO_CONTACT_REBIND_FAILED")
		return
	water._pool.layers = 2 # Omit self from the scene reflection capture.
	configure_receivers(self)
	probe = ReflectionProbe.new()
	probe.name = "Pool surroundings reflection"
	probe.size = Vector3(22,12,24)
	probe.position = Vector3(0,3,-3)
	probe.origin_offset = Vector3(0,-2,0)
	probe.box_projection = true
	probe.cull_mask = 1
	probe.reflection_mask = 2
	probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	probe.enable_shadows = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(probe)
	for x in [-3.6,3.6]:
		var lamp := OmniLight3D.new()
		lamp.name = "Pool light study"
		lamp.position = Vector3(x,-0.12,-2.6)
		lamp.light_color = Color("9addf5")
		lamp.omni_range = 6.0
		lamp.light_cull_mask = 2 # Study lamps illuminate the basin/water, not the whole yard.
		lamp.light_energy = 0.0
		add_child(lamp)
		pool_lights.append(lamp)
	set_illustration(true)
	set_water_phase(2.0)
	print("HERO_WATER_READY ",JSON.stringify(water.snapshot()))

func configure_receivers(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var label := String(mesh.name).replace("_"," ")
		if label.begins_with("Waterfall silver highlights"):
			mesh.visible=false # Remove the old bright rods/splash geometry, not the sheets.
		for surface in range(mesh.mesh.get_surface_count()):
			var active := mesh.get_active_material(surface) as ShaderMaterial
			if active != null and active.shader == FOLIAGE_SHADER:
				painted_foliage.append(active)
			var original := mesh.mesh.surface_get_material(surface)
			if original != null and original.resource_name == "Pool blue mosaic":
				var mat := ShaderMaterial.new()
				mat.shader=HERO_BASIN
				mat.set_shader_parameter("water_level",water.snapshot().water_level)
				mesh.set_surface_override_material(surface,mat)
				mesh.layers |= 2
				basin_materials.append(mat)
	for child in node.get_children():
		configure_receivers(child)

func _process(delta: float) -> void:
	super._process(delta)
	for material in basin_materials:
		material.set_shader_parameter("water_time",water.water_time)

func set_water_phase(seconds: float) -> void:
	water.water_time=seconds
	water.advance(0.0)
	for material in basin_materials:
		material.set_shader_parameter("water_time",seconds)

func set_illustration(enabled: bool) -> void:
	super.set_illustration(enabled)
	# The old full-screen spatial copy overwrites transparent water with the
	# pre-water opaque screen. Keep the later canvas ink pass, omit that copy.
	_contours.visible=false
	var post := _overlay.get_child(0).material as ShaderMaterial
	post.set_shader_parameter("grain_strength",0.004)
	post.set_shader_parameter("line_strength",0.16)

func set_night(enabled: bool) -> void:
	night_mode=enabled
	for material in painted_foliage:
		material.set_shader_parameter("paint_illumination",0.10 if enabled else 1.0)
	water._pool_material.set_shader_parameter("scatter_illumination",0.10 if enabled else 1.0)
	for material in basin_materials:
		material.set_shader_parameter("caustic_daylight",0.0 if enabled else 1.0)
	for child in get_children():
		if child is DirectionalLight3D:
			var sun := child as DirectionalLight3D
			var main_sun: bool=String(sun.name)=="Warm afternoon sunlight"
			sun.light_energy=(0.12 if main_sun else 0.025) if enabled else (1.6 if main_sun else 0.12)
		if child is WorldEnvironment:
			var env: Environment=child.environment
			env.ambient_light_energy=0.12 if enabled else 0.4
			var sky := env.sky.sky_material as ProceduralSkyMaterial
			sky.sky_top_color=Color("102448") if enabled else Color("8bcdf4")
			sky.sky_horizon_color=Color("456078") if enabled else Color("c6e8fa")
			sky.ground_bottom_color=Color("171c25") if enabled else Color("b5aa8f")
			sky.ground_horizon_color=Color("456078") if enabled else Color("c6e8fa")
	for lamp in pool_lights:
		lamp.light_energy=2.2 if enabled else 0.0
	# Move to dirty the once-updated local probe after changing the lighting.
	probe.position.x=0.0001 if enabled else 0.0

func _unhandled_input(event: InputEvent) -> void:
	if _capturing:
		return
	super._unhandled_input(event)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_N:
		set_night(not night_mode)
