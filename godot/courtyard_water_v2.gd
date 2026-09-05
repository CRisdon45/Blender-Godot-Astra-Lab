extends "res://courtyard_hero_water.gd"
## Opt-in camera-coupled reflection and receiver-light study; previous study stays intact.
const V2_WATER=preload("res://shaders/water_v2.gdshader")
const V2_BASIN=preload("res://shaders/basin_v2.gdshader")
const V2_SPILL=preload("res://shaders/spillway_v2.gdshader")
var reflection_view: SubViewport
var reflection_camera: Camera3D
var reflection_environment: Environment
var clipped_shaders: Dictionary={}
var fixed_foliage: Array[ShaderMaterial]=[]
var reflection_objects: int=0

func _ready() -> void:
    super._ready()
    water._pool_material.shader=V2_WATER
    for material in water._materials:
        if material!=water._pool_material:
            material.shader=V2_SPILL
    for material in basin_materials:
        material.shader=V2_BASIN
        material.set_shader_parameter("water_level",water.snapshot().water_level)
        for child in get_children():
            if child is DirectionalLight3D and String(child.name)=="Warm afternoon sunlight":
                material.set_shader_parameter("sun_direction",child.global_basis.z.normalized())
    if water.rebuild_contacts()!=OK:
        push_error("V2_CONTACT_REBIND_FAILED")
        return
    configure_reflection_objects(self)
    reflection_view=SubViewport.new()
    reflection_view.name="Water reflected scene"
    reflection_view.size=Vector2i(600,450)
    reflection_view.world_3d=get_viewport().world_3d
    reflection_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    reflection_view.msaa_3d=Viewport.MSAA_2X
    add_child(reflection_view)
    reflection_camera=Camera3D.new()
    reflection_view.add_child(reflection_camera)
    reflection_camera.cull_mask=4
    reflection_camera.current=true
    for child in get_children():
        if child is WorldEnvironment:
            reflection_environment=child.environment.duplicate() as Environment
            # Avoid applying the main filmic curve twice to the intermediate image.
            # The viewport is still a bounded color buffer, not HDR transport proof.
            reflection_environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
            reflection_camera.environment=reflection_environment
    water._pool_material.set_shader_parameter("planar_color",reflection_view.get_texture())
    water._pool_material.set_shader_parameter("planar_enabled",true)
    set_recipe("clear")
    for material in basin_materials:
        material.set_shader_parameter("caustic_strength",1.65)
    sync_reflection()
    set_water_phase(2.0)
    print("WATER_V2_READY ",reflection_objects)

func configure_reflection_objects(node: Node) -> void:
    if node is MeshInstance3D:
        var mesh:=node as MeshInstance3D
        if mesh.mesh==null:
            return
        if mesh!=water._pool and mesh.visible:
            var receiver: bool=false
            for surface in range(mesh.mesh.get_surface_count()):
                if mesh.get_active_material(surface) in basin_materials:
                    receiver=true
            if not receiver:
                mesh.layers|=4
                reflection_objects+=1
        for surface in range(mesh.mesh.get_surface_count()):
            var mat:=mesh.get_active_material(surface) as ShaderMaterial
            if mat==null:
                continue
            if mat.shader==V2_SPILL:
                var bound: AABB=mesh.global_transform*mesh.get_aabb()
                mat.set_shader_parameter("sheet_top",bound.end.y)
                mesh.extra_cull_margin=maxf(mesh.extra_cull_margin,0.02)
            elif mat.shader==ARCH or mat.shader==FOLIAGE_SHADER:
                var key: String=mat.shader.resource_path
                if not clipped_shaders.has(key):
                    var shader:=Shader.new()
                    var code: String=mat.shader.code
                    code=code.replace("void vertex()", "uniform float reflection_clip_y=0.3225;\nvoid vertex()")
                    if mat.shader==ARCH:
                        code=code.replace("void fragment(){", "void fragment(){\nif(CAMERA_VISIBLE_LAYERS==4u && world_pos.y<reflection_clip_y){discard;}")
                    else:
                        code=code.replace("void vertex()", "uniform vec3 foliage_right=vec3(1,0,0);\nuniform vec3 foliage_up=vec3(0,1,0);\nvarying vec3 reflected_foliage_position;\nvoid vertex()")
                        code=code.replace("normalize(MAIN_CAM_INV_VIEW_MATRIX[0].xyz)","foliage_right")
                        code=code.replace("normalize(MAIN_CAM_INV_VIEW_MATRIX[1].xyz)","foliage_up")
                        code=code.replace("VERTEX = (inverse(MODEL_MATRIX)", "reflected_foliage_position=world_position;\n    VERTEX = (inverse(MODEL_MATRIX)")
                        code=code.replace("void fragment() {", "void fragment() {\nif(CAMERA_VISIBLE_LAYERS==4u && reflected_foliage_position.y<reflection_clip_y){discard;}")
                    shader.code=code
                    clipped_shaders[key]=shader
                var is_foliage: bool=mat.shader==FOLIAGE_SHADER
                mat.shader=clipped_shaders[key]
                mat.set_shader_parameter("reflection_clip_y",water.snapshot().water_level)
                if is_foliage:
                    fixed_foliage.append(mat)
    for child in node.get_children():
        configure_reflection_objects(child)

func sync_reflection() -> void:
    if not is_instance_valid(reflection_camera):
        return
    var size: Vector2i=get_viewport().get_visible_rect().size
    var width: int=mini(768,maxi(64,size.x/2))
    reflection_view.size=Vector2i(width,maxi(64,roundi(float(width)*size.y/maxi(size.x,1))))
    var level: float=water.snapshot().water_level
    var eye: Vector3=camera.global_position
    eye.y=2.0*level-eye.y
    var forward: Vector3=-camera.global_basis.z
    var up: Vector3=camera.global_basis.y
    forward.y=-forward.y
    up.y=-up.y
    reflection_camera.global_position=eye
    reflection_camera.look_at(eye+forward,up)
    reflection_camera.fov=camera.fov
    reflection_camera.near=camera.near
    reflection_camera.far=camera.far
    reflection_camera.keep_aspect=camera.keep_aspect
    var projection: Projection=reflection_camera.get_camera_projection()
    var view: Projection=Projection(reflection_camera.global_transform.affine_inverse())
    water._pool_material.set_shader_parameter("planar_view_projection",projection*view)
    for material in fixed_foliage:
        material.set_shader_parameter("foliage_right",camera.global_basis.x.normalized())
        material.set_shader_parameter("foliage_up",camera.global_basis.y.normalized())

func _process(delta: float) -> void:
    super._process(delta)
    sync_reflection()

func set_water_phase(seconds: float) -> void:
    super.set_water_phase(seconds)
    sync_reflection()

func set_night(enabled: bool) -> void:
    super.set_night(enabled)
    if reflection_environment!=null:
        for child in get_children():
            if child is WorldEnvironment:
                reflection_environment.ambient_light_energy=child.environment.ambient_light_energy
    sync_reflection()

func study_snapshot() -> Dictionary:
    var state: Dictionary=super.study_snapshot()
    state["version"]="v2-planar-receiver"
    state["reflection_objects"]=reflection_objects
    state["reflection_size"]=str(reflection_view.size) if reflection_view!=null else "unbound"
    state["reflection_mask"]=reflection_camera.cull_mask if reflection_camera!=null else 0
    state["caustics"]="art-directed receiver network, not photon tracing"
    return state

func _exit_tree() -> void:
    # Break the material -> viewport texture -> shared world reference before teardown.
    if water!=null and water._pool_material!=null:
        water._pool_material.set_shader_parameter("planar_color",null)
    if is_instance_valid(reflection_view):
        reflection_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
        reflection_view.world_3d=null
