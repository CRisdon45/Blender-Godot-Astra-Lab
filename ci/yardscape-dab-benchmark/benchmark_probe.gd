extends SceneTree
const Fixture=preload("res://presentation/northstar/spatial_fixture.gd")
const RegularTree=preload("res://presentation/northstar/foliage/dab_tree.gd")
const BatchedTree=preload("res://presentation/northstar/foliage/batched_dab_tree.gd")
const ValuePaint=preload("res://presentation/northstar/foliage/dab_value.gdshader")
const COUNTS=[1,8,24,32]
const MAX_COUNT=32
const WARMUP=12
const SAMPLES=28
var world:Node3D
var regular_root:Node3D
var batched_root:Node3D
var regular:Array[Node3D]=[]
var batched:Array[Node3D]=[]
var sun:DirectionalLight3D
var camera:Camera3D
var output:String
var run_id:String
var checks:Array=[]
var failures:Array=[]
var measurements:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks.append({"name":label,"passed":ok})
	if not ok:failures.append(label)
func family_bias(angle:float,direction:Vector2)->float:
	var alignment:=Vector2(cos(angle),sin(angle)).dot(direction)
	if alignment>.28:return .095
	if alignment<-.28:return -.095
	return 0.
func apply_regular_values(tree:Node3D,direction:Vector2)->void:
	var biases:=PackedFloat32Array()
	for family in 5:
		var p:Vector3=tree.groups[family*3].position
		biases.append(family_bias(Vector2(p.x,p.z).angle(),direction))
	var average:=0.
	for value in biases:average+=value
	average/=5.
	for i in tree.groups.size():
		var material:=ShaderMaterial.new();material.shader=ValuePaint
		var family_value:=average if i==15 else biases[int(i/3)]
		var role_value:=.006 if i==15 else .008 if i%3==0 else -.004
		material.set_shader_parameter("family_value",family_value)
		material.set_shader_parameter("role_value",role_value)
		tree.groups[i].foliage.material_override=material
func setup_scene()->void:
	world=Node3D.new();root.add_child(world)
	var env_node:=WorldEnvironment.new();var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("e8e5dc")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("e4ecf0");env.ambient_light_energy=.30
	env_node.environment=env;world.add_child(env_node)
	sun=DirectionalLight3D.new();sun.shadow_enabled=true;sun.directional_shadow_max_distance=120.;sun.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.rotation_degrees=Vector3(-48.,-32.,0.);sun.light_energy=.6;world.add_child(sun)
	camera=Camera3D.new();camera.near=.1;camera.far=150.;camera.fov=52.;camera.position=Vector3(0,30,37);world.add_child(camera);camera.look_at(Vector3(0,3.5,0),Vector3.UP);camera.make_current()
	regular_root=Node3D.new();regular_root.name="RegularTrees";world.add_child(regular_root)
	batched_root=Node3D.new();batched_root.name="BatchedTrees";world.add_child(batched_root)
	var t:Dictionary=Fixture.fresh().tree
	var direction:=Vector2(sun.global_basis.z.x,sun.global_basis.z.z).normalized()
	var spacing:=3.15
	for i in MAX_COUNT:
		var col:=i%8;var row:=int(i/8)
		var location:=Vector3((float(col)-3.5)*spacing,0.,(float(row)-1.5)*spacing)
		var a:=RegularTree.new();a.configure(t);a.position=location;regular_root.add_child(a);apply_regular_values(a,direction);regular.append(a)
		var b:=BatchedTree.new();b.configure(t);b.position=location;b.set_light_values(direction,0.);batched_root.add_child(b);batched.append(b)
	regular_root.visible=false;batched_root.visible=false
func set_condition(kind:String,count:int)->void:
	regular_root.visible=kind=="regular";batched_root.visible=kind=="batched"
	for i in MAX_COUNT:
		regular[i].visible=i<count
		batched[i].visible=i<count
func warm(frames:int)->void:
	for i in frames:
		await process_frame
		await RenderingServer.frame_post_draw
func counters()->Dictionary:
	var vp:=root.get_viewport_rid()
	return {
		"visible_objects":RenderingServer.viewport_get_render_info(vp,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),
		"visible_primitives":RenderingServer.viewport_get_render_info(vp,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
		"visible_draw_calls":RenderingServer.viewport_get_render_info(vp,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"shadow_objects":RenderingServer.viewport_get_render_info(vp,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),
		"shadow_primitives":RenderingServer.viewport_get_render_info(vp,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
		"shadow_draw_calls":RenderingServer.viewport_get_render_info(vp,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	}
func sample_block(kind:String,count:int)->Dictionary:
	set_condition(kind,count);await warm(WARMUP)
	var vp:=root.get_viewport_rid();var cpu:=PackedFloat32Array();var setup:=PackedFloat32Array();var gpu:=PackedFloat32Array();var wall:=PackedFloat32Array()
	for i in SAMPLES:
		var start:=Time.get_ticks_usec()
		await process_frame
		await RenderingServer.frame_post_draw
		wall.append(float(Time.get_ticks_usec()-start)/1000.)
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
		setup.append(RenderingServer.get_frame_setup_time_cpu())
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
	return {"cpu_ms":cpu,"setup_ms":setup,"gpu_ms":gpu,"wall_ms":wall,"counters":counters()}
func capture(name:String)->void:
	for i in 3:await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image();image.convert(Image.FORMAT_RGBA8)
	check(image.save_png(output.path_join(name+".png"))==OK,"capture "+name)
func run()->void:
	output=OS.get_environment("YARDSCAPE_DAB_BENCH_OUTPUT");run_id=OS.get_environment("YARDSCAPE_DAB_BENCH_RUN_ID")
	if run_id.length()!=36 or not output.begins_with(ProjectSettings.globalize_path("res://.local/")):push_error("Fresh benchmark output required");quit(1);return
	root.size=Vector2i(960,720);setup_scene()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	await warm(8)
	check(regular.size()==MAX_COUNT and batched.size()==MAX_COUNT,"both representations create exact requested maximum tree count")
	check(int(regular[0].stats.visible_triangles)==6516 and int(batched[0].stats.visible_triangles)==6516,"per-tree indexed triangle count is exact")
	check(int(regular[0].stats.visible_meshes)==33 and int(batched[0].stats.visible_meshes)==2,"per-tree visible mesh metadata is 33 versus 2")
	for count in COUNTS:
		var key:=str(count)
		measurements[key]={"regular":[],"batched":[]}
		measurements[key].regular.append(await sample_block("regular",count))
		measurements[key].batched.append(await sample_block("batched",count))
		measurements[key].batched.append(await sample_block("batched",count))
		measurements[key].regular.append(await sample_block("regular",count))
		var rc:Dictionary=measurements[key].regular[1].counters
		var bc:Dictionary=measurements[key].batched[1].counters
		check(int(rc.visible_primitives)==int(bc.visible_primitives),"count %d keeps visible primitive count"%count)
		check(int(rc.visible_draw_calls)>int(bc.visible_draw_calls),"count %d reduces visible draw calls"%count)
		check(int(rc.visible_objects)>int(bc.visible_objects),"count %d reduces visible rendered objects"%count)
	set_condition("regular",MAX_COUNT);await capture("01-regular-32")
	set_condition("batched",MAX_COUNT);await capture("02-batched-32")
	var report:Dictionary={"run_id":run_id,"passed":failures.is_empty(),"checks":checks,"failures":failures,"counts":COUNTS,"warmup_frames":WARMUP,"samples_per_block":SAMPLES,"alternating_order":"regular-batched-batched-regular","viewport":[960,720],"measurements":measurements,"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"scope":"same-worker relative benchmark of repeated regular 33-mesh versus batched 2-mesh dab-value trees","physical_tablet_tested":false,"performance_prediction_for_tablet":false}
	var f:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	if f==null:push_error("Cannot write benchmark report");quit(1);return
	f.store_string(JSON.stringify(report,"  "));f.close();world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
