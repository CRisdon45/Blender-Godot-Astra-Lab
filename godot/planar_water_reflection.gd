extends Node
## One horizontal plane, one extra camera. No recursive water or canvas capture.
## This is an opt-in quality study, not a certified Android rendering budget.
const REFLECTION_LAYER: int = 1 << 18
const CLIP_HEADER: String = "\nuniform float reflection_plane_y = 0.0;\n"
const CLIP_FRAGMENT: String = """
	// Only the dedicated reflection camera clips. Main views and shadows do not.
	if ((CAMERA_VISIBLE_LAYERS & 262144u) != 0u && !IN_SHADOW_PASS) {
		vec3 reflected_world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		if (reflected_world.y < reflection_plane_y) { discard; }
	}
"""
var viewport: SubViewport
var mirror_camera: Camera3D
var source_camera: Camera3D
var surface: ShaderMaterial
var plane_y: float = 0.0
var resolution_scale: float = 0.5
var max_dimension: int = 1024
var enabled: bool = true
var error: String = ""
var reflected_materials: Array[ShaderMaterial] = []
var shader_cache: Dictionary = {}
var fixed_foliage: Array[ShaderMaterial] = []
var source_environment: Environment
var mirror_environment: Environment

static func reflect_vector(value: Vector3) -> Vector3:
	return Vector3(value.x, -value.y, value.z)

static func mirror_transform(value: Transform3D, level: float) -> Transform3D:
	# Reflecting a basis reverses handedness. Reverse the right axis as well,
	# then project world points with THIS camera's matrix, not guessed screen UVs.
	var basis := Basis(-reflect_vector(value.basis.x), reflect_vector(value.basis.y), reflect_vector(value.basis.z))
	return Transform3D(basis, Vector3(value.origin.x, 2.0 * level - value.origin.y, value.origin.z))

static func target_size(source: Vector2i, scale: float, limit: int) -> Vector2i:
	var factor: float = minf(clampf(scale, 0.25, 1.0), float(maxi(limit, 64)) / float(maxi(maxi(source.x, source.y), 2)))
	return Vector2i(maxi(2, roundi(source.x * factor)), maxi(2, roundi(source.y * factor)))

static func clipped_code(source: String) -> String:
	# Limited adapter for the lab's inspected spatial shader families. Fail closed
	# instead of silently reflecting new unsupported materials through the basin.
	if source.count("shader_type spatial;") != 1 or source.count("void fragment()") != 1:
		return ""
	var code: String = source.replace("shader_type spatial;", "shader_type spatial;" + CLIP_HEADER)
	if code.contains("MAIN_CAM_INV_VIEW_MATRIX"):
		# A reflection should see the same cards, not a second camera-facing canopy.
		code=code.replace("MAIN_CAM_INV_VIEW_MATRIX","reflection_foliage_camera")
		code=code.replace("shader_type spatial;","shader_type spatial;\nuniform mat4 reflection_foliage_camera;\n")
	var opening: int = code.find("{", code.find("void fragment()"))
	if opening < 0:
		return ""
	return code.insert(opening + 1, CLIP_FRAGMENT)

func bind(camera: Camera3D, material: ShaderMaterial, level: float, environment: Environment) -> Error:
	if camera == null or material == null or environment == null or not is_finite(level):
		error = "Missing finite plane, camera, water material or environment"
		return ERR_INVALID_PARAMETER
	source_camera = camera
	surface = material
	plane_y = level
	source_environment = environment
	process_priority = 10
	source_camera.cull_mask &= ~REFLECTION_LAYER
	viewport = SubViewport.new()
	viewport.name = "Linear HDR planar reflection"
	viewport.size = target_size(Vector2i(camera.get_viewport().get_texture().get_size()), resolution_scale, max_dimension)
	viewport.use_hdr_2d = true # Linear HDR texture, NOT an sRGB/filmic screen copy.
	viewport.transparent_bg = false
	viewport.canvas_cull_mask = 0
	viewport.gui_disable_input = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	viewport.world_3d = camera.get_world_3d()
	mirror_camera = Camera3D.new()
	mirror_camera.name = "Reflected pool camera"
	mirror_camera.cull_mask = REFLECTION_LAYER
	viewport.add_child(mirror_camera)
	mirror_camera.current = true
	mirror_environment = source_environment.duplicate(false) as Environment
	mirror_environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	mirror_environment.tonemap_exposure = 1.0
	mirror_environment.glow_enabled = false
	mirror_environment.ssao_enabled = false # Avoid an unrelated screen-space shadow mismatch.
	mirror_camera.environment = mirror_environment
	surface.set_shader_parameter("planar_texture", viewport.get_texture())
	sync_camera()
	return OK if error.is_empty() else ERR_INVALID_DATA

func register_material(material: ShaderMaterial) -> Error:
	if material == null or material.shader == null:
		error = "Reflection material is not an inspectable ShaderMaterial"
		return ERR_INVALID_DATA
	if reflected_materials.has(material):
		return OK
	var source: Shader = material.shader
	if source.code.contains("MAIN_CAM_INV_VIEW_MATRIX"):
		fixed_foliage.append(material)
	var key: String = source.code.sha256_text()
	if not shader_cache.has(key):
		var code: String = clipped_code(source.code)
		if code.is_empty():
			error = "Unsupported reflection shader: " + source.resource_path
			return ERR_INVALID_DATA
		var clone := Shader.new()
		clone.code = code
		shader_cache[key] = clone
	material.shader = shader_cache[key]
	material.set_shader_parameter("reflection_plane_y", plane_y)
	reflected_materials.append(material)
	return OK

func sync_environment() -> void:
	if mirror_environment == null or source_environment == null:
		return
	# Sky is intentionally shared, so day/night edits propagate without reloading.
	mirror_environment.sky = source_environment.sky
	mirror_environment.ambient_light_color = source_environment.ambient_light_color
	mirror_environment.ambient_light_energy = source_environment.ambient_light_energy
	mirror_environment.ambient_light_source = source_environment.ambient_light_source

func sync_camera() -> void:
	if not is_instance_valid(source_camera) or not is_instance_valid(mirror_camera):
		return
	# Underwater cameras and off-axis frusta need a different optical contract.
	var supported: bool = source_camera.projection != Camera3D.PROJECTION_FRUSTUM and source_camera.global_position.y > plane_y + 0.01
	if not supported:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		surface.set_shader_parameter("planar_enabled", false)
		return
	viewport.size = target_size(Vector2i(source_camera.get_viewport().get_texture().get_size()), resolution_scale, max_dimension)
	mirror_camera.keep_aspect = source_camera.keep_aspect
	mirror_camera.projection = source_camera.projection
	mirror_camera.fov = source_camera.fov
	mirror_camera.size = source_camera.size
	mirror_camera.near = source_camera.near
	mirror_camera.far = source_camera.far
	# get_camera_transform() includes h/v offsets. Do not apply those twice.
	mirror_camera.global_transform = mirror_transform(source_camera.get_camera_transform(), plane_y)
	var matrix: Projection = mirror_camera.get_camera_projection() * Projection(mirror_camera.get_camera_transform().affine_inverse())
	surface.set_shader_parameter("reflection_view_projection", matrix)
	surface.set_shader_parameter("planar_enabled", enabled)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED
	for material in reflected_materials:
		material.set_shader_parameter("reflection_plane_y", plane_y)
	for material in fixed_foliage:
		material.set_shader_parameter("reflection_foliage_camera", source_camera.get_camera_transform())
	sync_environment()

func _process(_delta: float) -> void:
	sync_camera()

func snapshot() -> Dictionary:
	return {"enabled": enabled, "error": error, "plane_y": plane_y,
		"size": [viewport.size.x, viewport.size.y] if is_instance_valid(viewport) else [],
		"linear_hdr": viewport.use_hdr_2d if is_instance_valid(viewport) else false,
		"camera_position": [mirror_camera.global_position.x, mirror_camera.global_position.y, mirror_camera.global_position.z] if is_instance_valid(mirror_camera) else [],
		"material_count": reflected_materials.size(), "shader_families": shader_cache.size(), "fixed_foliage_count": fixed_foliage.size(),
		"quality_note": "One extra view; no target-device performance approval"}

func close() -> void:
	# Break texture -> viewport -> shared-world -> water-material lifetime cycles.
	if surface != null:
		surface.set_shader_parameter("planar_texture", null)
		surface.set_shader_parameter("planar_enabled", false)
	if is_instance_valid(viewport):
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		viewport.world_3d = null
		viewport.queue_free()
	viewport = null
	mirror_camera = null
	mirror_environment = null
	source_environment = null
	source_camera = null
	surface = null
	reflected_materials.clear()
	shader_cache.clear()
	fixed_foliage.clear()

func _exit_tree() -> void:
	close()
