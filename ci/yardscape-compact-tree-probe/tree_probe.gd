extends SceneTree
const Current=preload("res://presentation/northstar/spatial_compact_tree_study.gd")
const Baseline=preload("res://presentation/northstar/spatial_material_study.gd")
const CompactTree=preload("res://presentation/northstar/foliage/compact_tree.gd")
var study
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
func capture(scene,name:String)->Image:
	var layers:Array=[]
	for c in scene.get_children():
		if c is CanvasLayer:layers.append([c,c.visible]);c.visible=false
	for i in 4:await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image();image.convert(Image.FORMAT_RGBA8)
	check(image.save_png(output.path_join(name+".png"))==OK,"capture "+name)
	hashes[name]=digest(image)
	for pair in layers:pair[0].visible=pair[1]
	return image
func set_close(scene,yaw_value:float,pitch_value:float,distance_value:float,orthographic:bool=false)->void:
	var t:Dictionary=scene.document.tree
	scene.target=Vector3(t.x,t.base_elevation+t.height*.66,-t.y)
	scene.plan_locked=false;scene.perspective=not orthographic
	scene.yaw=yaw_value;scene.pitch=pitch_value;scene.distance=distance_value;scene._update_camera()
func run()->void:
	output=OS.get_environment("YARDSCAPE_TREE_OUTPUT");run_id=OS.get_environment("YARDSCAPE_TREE_RUN_ID")
	if run_id.length()!=36 or not output.begins_with(ProjectSettings.globalize_path("res://.local/")):
		push_error("Fresh isolated output required");quit(1);return
	root.size=Vector2i(1280,900)
	study=load("res://northstar-compact-tree.tscn").instantiate();root.add_child(study)
	for i in 3:await process_frame
	check(study is Current and study.study_ready,"compact whole tree runs in retained material courtyard")
	check(study.compact_tree.descriptor==study.document.tree,"whole tree retains exact source record")
	check(study.compact_tree.groups.size()==16,"tree uses the sixteen retained branch anchors")
	check(study.compact_tree.stats.visible_triangles<18000,"first assembly remains under 18k visible indexed triangles")
	check(not study.compact_tree.stats.alpha_blended,"whole tree uses opaque group geometry")
	var signature:String=study.compact_tree.geometry_signature()
	var clone:=CompactTree.new();clone.configure(study.document.tree)
	check(clone.geometry_signature()==signature,"same source record reproduces exact assembled tree")
	clone.free()
	study._choose("Plan");await capture(study,"01-plan-compact")
	study._choose("Orbit");study._choose("Perspective");await capture(study,"02-courtyard-compact")
	set_close(study,.55,.28,7.2);var front:=await capture(study,"03-close-front")
	set_close(study,.55+PI,.28,7.2);await capture(study,"04-close-reverse")
	set_close(study,.55+PI*.5,.40,7.2);await capture(study,"05-close-quarter")
	set_close(study,.55,1.49,8.0,true);study.camera.position=study.target+Vector3.UP*9.;study.camera.look_at(study.target,Vector3(0,0,-1));await capture(study,"06-close-top")
	set_close(study,.55,.28,7.2);study._choose("Afternoon");var afternoon:=await capture(study,"07-afternoon")
	check(digest(afternoon)!=digest(front),"same assembled tree responds to changed sunlight")
	study._choose("Morning");check(digest(front)==digest(await capture(study,"08-morning-return")),"morning return restores exact close image")
	check(study.compact_tree.geometry_signature()==signature,"camera and light review never regenerates tree")
	study.queue_free();await process_frame;await process_frame
	var baseline:=Baseline.new();root.add_child(baseline);for i in 3:await process_frame
	baseline._choose("Plan");await capture(baseline,"09-plan-proxy")
	baseline._choose("Orbit");baseline._choose("Perspective");await capture(baseline,"10-courtyard-proxy")
	var report:Dictionary={"run_id":run_id,"passed":failures.is_empty(),"checks":checks,"failures":failures,
		"pixel_hashes":hashes,"candidate":{"recipe":"compact-group-tree/1","groups":16,"visible_triangles":14164,"visible_meshes":33,"alpha_blended":false},
		"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),
		"scope":"first whole-tree visual assembly from compact group; generic, not species or production asset",
		"tablet_performance_tested":false,"artistic_acceptance":"not_evaluated"}
	var f:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	if f==null:push_error("Cannot write report");quit(1);return
	f.store_string(JSON.stringify(report,"  "));f.close();baseline.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
