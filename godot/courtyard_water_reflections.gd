extends "res://courtyard_hero_water.gd"
## Second opt-in water study. Prior water/foliage scenes and authored assets preserved.
const PlanarReflection = preload("res://planar_water_reflection.gd")
const PLANAR_WATER = preload("res://shaders/planar_pool_water.gdshader")
const CAUSTIC_BASIN = preload("res://shaders/caustic_basin.gdshader")
const FALLING_FILM = preload("res://shaders/falling_water_film.gdshader")
var mirror: PlanarReflection
var reflection_ready: bool = false
var reflected_meshes: int = 0

func _ready() -> void:
	super._ready()
	if water._pool_material == null:
		return
	water._pool_material.shader = PLANAR_WATER
	water._pool_material.set_shader_parameter("surface_strength",0.55)
	water._pool_material.set_shader_parameter("reflection_distortion",0.09)
	for material in water._materials:
		if material != water._pool_material:
			material.shader = FALLING_FILM
			material.set_shader_parameter("water_level",water.snapshot().water_level)
	for sheet in water._sheets:
		var mesh: MeshInstance3D=sheet.mesh
		var material: ShaderMaterial=mesh.get_active_material(sheet.surface)
		var bounds: AABB=mesh.global_transform * mesh.get_aabb()
		material.set_shader_parameter("sheet_top",bounds.end.y)
	for material in basin_materials:
		material.shader = CAUSTIC_BASIN
		material.set_shader_parameter("plaster",Color(0.69,0.81,0.81,1.0))
		material.set_shader_parameter("caustic_strength",2.1)
	if water.rebuild_contacts() != OK:
		push_error("PLANAR_STUDY_CONTACT_REBIND_FAILED")
		return
	probe.visible=false
	var environment: Environment
	for child in get_children():
		if child is WorldEnvironment:
			environment=child.environment
		if child is DirectionalLight3D and String(child.name)=="Warm afternoon sunlight":
			for material in basin_materials:
				material.set_shader_parameter("sun_to_surface",child.global_basis.z.normalized())
	mirror=PlanarReflection.new()
	mirror.name="Pool planar reflection"
	add_child(mirror)
	if mirror.bind(camera,water._pool_material,water.snapshot().water_level,environment)!=OK:
		push_error("PLANAR_BIND_FAILED: "+mirror.error)
		return
	register_reflected_geometry(self)
	if not mirror.error.is_empty():
		push_error("PLANAR_MATERIAL_FAILED: "+mirror.error)
		return
	reflection_ready=true
	set_water_phase(2.0)
	print("PLANAR_WATER_READY ",JSON.stringify(study_snapshot()))

func register_reflected_geometry(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mesh==water._pool or mesh==_contours or mesh.mesh==null:
			return
		var receiver: bool=false
		for surface_index in range(mesh.mesh.get_surface_count()):
			var mat := mesh.get_active_material(surface_index) as ShaderMaterial
			if mat in basin_materials:
				receiver=true
		if receiver:
			return
		for surface_index in range(mesh.mesh.get_surface_count()):
			var mat := mesh.get_active_material(surface_index) as ShaderMaterial
			if mirror.register_material(mat)!=OK:
				return
		mesh.layers |= PlanarReflection.REFLECTION_LAYER
		reflected_meshes+=1
	for child in node.get_children():
		if child != mirror:
			register_reflected_geometry(child)

func _process(delta: float) -> void:
	super._process(delta)
	if reflection_ready:
		mirror.plane_y=water.snapshot().water_level # Child updates after navigation, once per frame.

func set_water_phase(seconds: float) -> void:
	super.set_water_phase(seconds)
	if reflection_ready:
		mirror.sync_camera()

func set_night(enabled: bool) -> void:
	super.set_night(enabled)
	if reflection_ready:
		mirror.sync_environment()

func study_snapshot() -> Dictionary:
	var state: Dictionary=super.study_snapshot()
	state["study"]="planar-reflection-and-receiver-light"
	state["reflection_ready"]=reflection_ready
	state["reflected_meshes"]=reflected_meshes
	state["mirror"]=mirror.snapshot() if is_instance_valid(mirror) else {}
	return state
