extends SceneTree
const Current=preload("res://presentation/northstar/spatial_fantex_ash_study.gd")
const FanTex=preload("res://presentation/northstar/foliage/fantex_ash_batched_tree.gd")
var study
var output:String
var run_id:String
var checks:Array=[]
var failures:Array=[]
var hashes:Dictionary={}
var diagnostics:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks.append({"name":label,"passed":ok})
	if not ok:failures.append(label)
func digest(image:Image)->String:return image.get_data().hex_encode().sha256_text()
func capture(name:String,fantex:bool)->Image:
	study.set_fantex_enabled(fantex)
	var layers:Array=[]
	for c in study.get_children():
		if c is CanvasLayer:layers.append([c,c.visible]);c.visible=false
	for i in 4:await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image();image.convert(Image.FORMAT_RGBA8)
	check(image.save_png(output.path_join(name+".png"))==OK,"capture "+name);hashes[name]=digest(image)
	for pair in layers:pair[0].visible=pair[1]
	return image
func close(yaw:float,pitch:float,distance:float,top:bool=false)->void:
	var t:Dictionary=study.document.tree
	study.target=Vector3(t.x,t.base_elevation+t.height*.64,-t.y);study.plan_locked=false;study.perspective=not top;study.yaw=yaw;study.pitch=pitch;study.distance=distance;study._update_camera()
	if top:study.camera.position=study.target+Vector3.UP*9.;study.camera.look_at(study.target,Vector3(0,0,-1))
func plan()->void:study.plan_locked=true;study.perspective=false;study.target=Vector3(5.,0.,-7.5);study.plan_size=20.;study._update_camera()
func courtyard()->void:study.plan_locked=false;study.perspective=true;study.target=Vector3(5.,0.,-7.);study.yaw=.55;study.pitch=.85;study.distance=22.;study._update_camera()
func valid(node:Node3D)->bool:
	for mesh_node in [node.wood,node.foliage]:
		var arrays:Array=mesh_node.mesh.surface_get_arrays(0)
		for p in arrays[Mesh.ARRAY_VERTEX]:
			if not p.is_finite():return false
		for n in arrays[Mesh.ARRAY_NORMAL]:
			if not n.is_finite() or absf(n.length()-1.)>.002:return false
	return true
func run()->void:
	output=OS.get_environment("YARDSCAPE_FANTEX_OUTPUT");run_id=OS.get_environment("YARDSCAPE_FANTEX_RUN_ID")
	if run_id.length()!=36 or not output.begins_with(ProjectSettings.globalize_path("res://.local/")):push_error("Fresh Fan-Tex output required");quit(1);return
	root.size=Vector2i(1280,900);study=load("res://northstar-fantex-ash-form.tscn").instantiate();root.add_child(study);for i in 3:await process_frame
	check(study is Current and valid(study.fantex_tree),"Fan-Tex form initializes with finite final-mesh normals")
	check(study.fantex_tree.stats.profile=="fan-tex-ash-macro-form/1","explicit presentation-only Fan-Tex profile")
	check(study.fantex_tree.stats.groups==16 and study.fantex_tree.stats.families==6,"profile keeps sixteen groups across six scaffold families")
	check(study.fantex_tree.stats.visible_meshes==2 and not study.fantex_tree.stats.alpha_blended,"candidate stays in two opaque meshes")
	check(study.fantex_tree.stats.visible_triangles<7200,"species-form tree stays below bounded 7.2k triangle ceiling")
	check(study.fantex_tree.descriptor==study.document.tree,"authoritative synthetic tree record remains unchanged")
	var signature:String=study.fantex_tree.geometry_signature();var clone:=FanTex.new();clone.configure(study.document.tree);check(clone.geometry_signature()==signature,"Fan-Tex form is deterministic");clone.free()
	diagnostics["generic_stats"]=study.generic_tree.stats;diagnostics["fantex_stats"]=study.fantex_tree.stats
	diagnostics["generic_foliage_aabb"]=study.generic_tree.foliage.mesh.get_aabb();diagnostics["fantex_foliage_aabb"]=study.fantex_tree.foliage.mesh.get_aabb()
	close(.55,.28,7.4);var front_generic:=await capture("01-front-generic",false);var front_fantex:=await capture("02-front-fantex",true);check(digest(front_generic)!=digest(front_fantex),"Fan-Tex macro form differs visibly from generic front")
	close(.55+PI*.5,.30,7.4);await capture("03-side-generic",false);await capture("04-side-fantex",true)
	close(.55+PI,.28,7.4);await capture("05-reverse-generic",false);await capture("06-reverse-fantex",true)
	close(.55,1.49,8.2,true);await capture("07-top-generic",false);await capture("08-top-fantex",true)
	plan();await capture("09-courtyard-plan-generic",false);await capture("10-courtyard-plan-fantex",true)
	courtyard();await capture("11-courtyard-generic",false);await capture("12-courtyard-fantex",true)
	close(.55,.28,7.4);study._choose("Afternoon");var afternoon:=await capture("13-afternoon-fantex",true);study._choose("Morning");var morning:=await capture("14-morning-return",true);check(digest(afternoon)!=digest(front_fantex),"Fan-Tex values respond to actual scene sun");check(digest(morning)==digest(front_fantex),"morning Fan-Tex image returns exactly")
	check(study.fantex_tree.geometry_signature()==signature,"camera/light comparisons never regenerate Fan-Tex geometry")
	var report:Dictionary={"run_id":run_id,"passed":failures.is_empty(),"checks":checks,"failures":failures,"pixel_hashes":hashes,"diagnostics":diagnostics,"candidate":study.fantex_tree.stats,"generic":study.generic_tree.stats,"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"scope":"presentation-only Fan-Tex Ash macro-form comparison using retained opaque dab language and two-mesh architecture","horticultural_size_data_applied":false,"literal_leaf_geometry":false,"tablet_performance_tested":false,"artistic_acceptance":"not_evaluated"}
	var f:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE);if f==null:push_error("Cannot write report");quit(1);return
	f.store_string(JSON.stringify(report,"  "));f.close();study.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
