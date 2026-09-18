extends SceneTree
const Current=preload("res://presentation/northstar/spatial_dab_value_study.gd")
const Baseline=preload("res://presentation/northstar/foliage/dab_tree.gd")
const Candidate=preload("res://presentation/northstar/foliage/dab_value_tree.gd")
var study
var baseline
var output:String
var run_id:String
var checks:Array=[]
var failures:Array=[]
var hashes:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks.append({"name":label,"passed":ok})
	if not ok:failures.append(label)
func digest(image:Image)->String:return image.get_data().hex_encode().sha256_text()
func capture(name:String,candidate_visible:bool)->Image:
	study.value_tree.visible=candidate_visible;baseline.visible=not candidate_visible
	var layers:Array=[]
	for c in study.get_children():
		if c is CanvasLayer:layers.append([c,c.visible]);c.visible=false
	for i in 4:await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image();image.convert(Image.FORMAT_RGBA8);check(image.save_png(output.path_join(name+".png"))==OK,"capture "+name);hashes[name]=digest(image)
	for pair in layers:pair[0].visible=pair[1]
	return image
func plan()->void:study.plan_locked=true;study.perspective=false;study.target=Vector3(5.,0.,-7.5);study.plan_size=20.;study._update_camera()
func courtyard()->void:study.plan_locked=false;study.perspective=true;study.target=Vector3(5.,0.,-7.);study.yaw=.55;study.pitch=.85;study.distance=22.;study._update_camera()
func close(yaw:float,pitch:float,distance:float,top:bool=false)->void:
	var t:Dictionary=study.document.tree;study.target=Vector3(t.x,t.base_elevation+t.height*.66,-t.y);study.plan_locked=false;study.perspective=not top;study.yaw=yaw;study.pitch=pitch;study.distance=distance;study._update_camera()
	if top:study.camera.position=study.target+Vector3.UP*9.;study.camera.look_at(study.target,Vector3(0,0,-1))
func run()->void:
	output=OS.get_environment("YARDSCAPE_VALUE_OUTPUT");run_id=OS.get_environment("YARDSCAPE_VALUE_RUN_ID")
	if run_id.length()!=36 or not output.begins_with(ProjectSettings.globalize_path("res://.local/")):push_error("Fresh output required");quit(1);return
	root.size=Vector2i(1280,900);study=load("res://northstar-dab-value-tree.tscn").instantiate();root.add_child(study);for i in 3:await process_frame
	baseline=Baseline.new();baseline.configure(study.document.tree);study.derived.add_child(baseline)
	check(study is Current and study.value_tree.geometry_signature()==baseline.geometry_signature(),"candidate preserves exact dab-tree geometry and transforms")
	check(study.value_tree.stats.visible_triangles==baseline.stats.visible_triangles and study.value_tree.stats.visible_meshes==baseline.stats.visible_meshes,"candidate preserves triangle and visible-mesh counts")
	check(study.value_tree.value_targets.size()==16 and study.value_tree.stats.value_min<study.value_tree.stats.value_max,"sixteen groups receive bounded hierarchy value targets")
	check(not study.value_tree.stats.alpha_blended,"value candidate remains opaque")
	var signature:String=study.value_tree.geometry_signature();var pigment:String=study.value_tree.pigment_signature();var clone:=Candidate.new();clone.configure(study.document.tree);check(clone.geometry_signature()==signature and clone.pigment_signature()==pigment,"geometry and value assignment are deterministic");clone.free()
	plan();await capture("01-plan-baseline",false);await capture("02-plan-values",true)
	courtyard();await capture("03-courtyard-baseline",false);await capture("04-courtyard-values",true)
	close(.55,.28,7.2);var front:=await capture("05-front-baseline",false);var value_front:=await capture("06-front-values",true)
	check(digest(front)!=digest(value_front),"value organization changes the lit tree without moving geometry")
	close(.55+PI,.28,7.2);await capture("07-reverse-baseline",false);await capture("08-reverse-values",true)
	close(.55,1.49,8.,true);await capture("09-top-baseline",false);await capture("10-top-values",true)
	close(.55,.28,7.2);study._choose("Afternoon");var afternoon:=await capture("11-afternoon-values",true);check(digest(afternoon)!=digest(value_front),"actual sun change still relights grouped pigment")
	study._choose("Morning");check(digest(value_front)==digest(await capture("12-morning-return",true)),"morning return restores exact candidate image")
	check(study.value_tree.geometry_signature()==signature and study.value_tree.pigment_signature()==pigment,"camera/light comparison never regenerates geometry or value assignment")
	var report:Dictionary={"run_id":run_id,"passed":failures.is_empty(),"checks":checks,"failures":failures,"pixel_hashes":hashes,"candidate":study.value_tree.stats,"baseline":baseline.stats,"value_targets":Array(study.value_tree.value_targets),"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"scope":"same dab-tree geometry with branch-hierarchy pigment values versus original local dab values","tablet_performance_tested":false,"artistic_acceptance":"not_evaluated"}
	var f:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE);if f==null:push_error("Cannot write report");quit(1);return
	f.store_string(JSON.stringify(report,"  "));f.close();study.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
