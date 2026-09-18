extends SceneTree
const Current=preload("res://presentation/northstar/spatial_dab_tree_study.gd")
const CompactTree=preload("res://presentation/northstar/foliage/compact_tree.gd")
const DabTree=preload("res://presentation/northstar/foliage/dab_tree.gd")
var study
var compact
var output:String
var run_id:String
var checks:Array=[]
var failures:Array=[]
var hashes:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:checks.append({"name":label,"passed":ok});if not ok:failures.append(label)
func digest(image:Image)->String:return image.get_data().hex_encode().sha256_text()
func capture(name:String,dab_visible:bool)->Image:
	study.dab_tree.visible=dab_visible;compact.visible=not dab_visible
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
	output=OS.get_environment("YARDSCAPE_DAB_TREE_OUTPUT");run_id=OS.get_environment("YARDSCAPE_DAB_TREE_RUN_ID")
	if run_id.length()!=36 or not output.begins_with(ProjectSettings.globalize_path("res://.local/")):push_error("Fresh output required");quit(1);return
	root.size=Vector2i(1280,900);study=load("res://northstar-dab-tree.tscn").instantiate();root.add_child(study);for i in 3:await process_frame
	compact=CompactTree.new();compact.configure(study.document.tree);study.derived.add_child(compact)
	check(study is Current and study.dab_tree.descriptor==study.document.tree,"dab tree runs from exact source tree record")
	check(study.dab_tree.groups.size()==16 and study.dab_tree.stats.primary_groups==5 and study.dab_tree.stats.secondary_groups==10,"same sixteen hierarchy-aware branch anchors")
	check(study.dab_tree.stats.visible_triangles<study.compact_tree_triangles if false else study.dab_tree.stats.visible_triangles<10000,"dab tree stays below 10k indexed triangles")
	check(not study.dab_tree.stats.alpha_blended,"dab tree remains opaque")
	var signature:String=study.dab_tree.geometry_signature();var clone:=DabTree.new();clone.configure(study.document.tree);check(clone.geometry_signature()==signature,"dab tree assembly is deterministic");clone.free()
	plan();await capture("01-plan-compact",false);await capture("02-plan-dab",true)
	courtyard();await capture("03-courtyard-compact",false);await capture("04-courtyard-dab",true)
	close(.55,.28,7.2);var front:=await capture("05-front-compact",false);var dab_front:=await capture("06-front-dab",true)
	close(.55+PI,.28,7.2);await capture("07-reverse-compact",false);await capture("08-reverse-dab",true)
	close(.55,1.49,8.,true);await capture("09-top-compact",false);await capture("10-top-dab",true)
	close(.55,.28,7.2);study._choose("Afternoon");var afternoon:=await capture("11-afternoon-dab",true);check(digest(afternoon)!=digest(dab_front),"same dab tree relights with sun")
	study._choose("Morning");check(digest(dab_front)==digest(await capture("12-morning-return",true)),"morning return is exact")
	check(study.dab_tree.geometry_signature()==signature,"camera/light comparisons never regenerate dab tree")
	var report:Dictionary={"run_id":run_id,"passed":failures.is_empty(),"checks":checks,"failures":failures,"pixel_hashes":hashes,"candidate":study.dab_tree.stats,"baseline":compact.stats,"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"scope":"hierarchy-aware dab-group whole tree versus retained compact-group tree","tablet_performance_tested":false,"artistic_acceptance":"not_evaluated"}
	var f:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE);if f==null:push_error("Cannot write report");quit(1);return
	f.store_string(JSON.stringify(report,"  "));f.close();study.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
