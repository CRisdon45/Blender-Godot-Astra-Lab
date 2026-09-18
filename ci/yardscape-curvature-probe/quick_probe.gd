extends SceneTree
const Current = preload("res://presentation/northstar/spatial_curved_canopy_study.gd")
const Previous = preload("res://presentation/northstar/canopy/illustrative_tree.gd")
var study
var old
var output: String
var hashes: Dictionary = {}
var checks: Array = []
var failures: Array = []
var run_id: String
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks.append({"name":label,"passed":ok})
	if not ok: failures.append(label)
func grab(name: String, curved: bool) -> void:
	old.visible=not curved
	study.illustrative_tree.visible=curved
	var layers: Array=[]
	for c in study.get_children():
		if c is CanvasLayer: layers.append([c,c.visible]);c.visible=false
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image();image.convert(Image.FORMAT_RGBA8)
	check(image.save_png(output.path_join(name+".png"))==OK,"capture "+name)
	hashes[name]=image.get_data().hex_encode().sha256_text()
	for item in layers:item[0].visible=item[1]
func run() -> void:
	output=OS.get_environment("YARDSCAPE_CANOPY_OUTPUT")
	run_id=OS.get_environment("YARDSCAPE_CANOPY_RUN_ID")
	if run_id.length()!=36 or not output.begins_with(ProjectSettings.globalize_path("res://.local/")):
		push_error("Fresh output required");quit(1);return
	root.size=Vector2i(1280,900)
	study=load("res://northstar-spatial-curved-canopy.tscn").instantiate();root.add_child(study)
	for i in 3: await process_frame
	old=Previous.new();old.configure(study.document.tree);study.derived.add_child(old)
	check(study is Current,"exact new opt-in scene")
	check(var_to_bytes(old.wood.mesh.surface_get_arrays(0))==var_to_bytes(study.illustrative_tree.wood.mesh.surface_get_arrays(0)),"branch mesh arrays exactly unchanged")
	check(old.descriptor==study.illustrative_tree.descriptor,"same source record")
	check(study.illustrative_tree.stats.curved_sprays==old.stats.folded_sprays,"same 64 sprays")
	await grab("01-plan-folded",false);await grab("02-plan-curved",true)
	study._choose("Orbit");study._choose("Perspective")
	await grab("03-courtyard-folded",false);await grab("04-courtyard-curved",true)
	var t: Dictionary=study.document.tree
	study.target=Vector3(t.x,t.base_elevation+t.height*.64,-t.y)
	study.pitch=.28;study.yaw=.55;study.distance=6.;study.perspective=false;study.plan_locked=false;study._update_camera()
	await grab("05-close-folded",false);await grab("06-close-curved",true)
	study.yaw+=PI;study._update_camera()
	await grab("07-reverse-folded",false);await grab("08-reverse-curved",true)
	study.yaw-=PI;study._update_camera()
	study.illustrative_tree.crown.material_override.set_shader_parameter("coverage_enabled",false)
	await grab("09-close-unmasked",true)
	study.illustrative_tree.crown.material_override.set_shader_parameter("coverage_enabled",true)
	await grab("10-cutout-return",true)
	check(hashes["10-cutout-return"]==hashes["06-close-curved"],"cutout toggle exactly restores image")
	var report: Dictionary={"run_id":run_id,"passed":failures.is_empty(),"checks":checks,"failures":failures,"pixel_hashes":hashes,"adapter":RenderingServer.get_video_adapter_name(),"engine":Engine.get_version_info().string,"candidate":study.illustrative_tree.stats,"baseline":old.stats,"scope":"quick curvature/orientation comparison, not full regression","artistic_acceptance":"not_evaluated"}
	var f:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	if f==null:push_error("Cannot retain report");quit(1);return
	f.store_string(JSON.stringify(report,"  "));f.close()
	study.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
