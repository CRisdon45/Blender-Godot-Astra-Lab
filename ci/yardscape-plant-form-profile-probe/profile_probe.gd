extends SceneTree
const Current=preload("res://presentation/northstar/spatial_profiled_plant_form_study.gd")
const Profiles=preload("res://presentation/northstar/foliage/plant_form_profiles.gd")
const ProfiledTree=preload("res://presentation/northstar/foliage/profiled_batched_dab_tree.gd")
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
func capture(name:String,profiled:bool)->Image:
	study.set_profiled_enabled(profiled)
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
func run()->void:
	output=OS.get_environment("YARDSCAPE_PROFILE_OUTPUT");run_id=OS.get_environment("YARDSCAPE_PROFILE_RUN_ID")
	if run_id.length()!=36 or not output.begins_with(ProjectSettings.globalize_path("res://.local/")):push_error("Fresh profile output required");quit(1);return
	root.size=Vector2i(1280,900)
	var profile:=Profiles.fan_tex_ash_v2()
	check(Profiles.input_error(profile).is_empty(),"retained Fan-Tex form profile validates")
	var broken:=profile.duplicate(true);broken.families.angle_offsets=broken.families.angle_offsets.slice(0,5)
	check(not Profiles.input_error(broken).is_empty(),"malformed family profile is rejected")
	study=load("res://northstar-profiled-fantex-ash.tscn").instantiate();root.add_child(study);for i in 3:await process_frame
	check(study is Current,"exact profile-equivalence opt-in scene")
	check(study.profiled_tree.stats.profile==study.reference_tree.stats.profile,"profile ID retained")
	check(study.profiled_tree.stats.visible_meshes==2 and study.profiled_tree.stats.visible_triangles==6614,"profiled tree retains two meshes and 6,614 triangles")
	check(study.profiled_tree.descriptor==study.document.tree and study.profiled_tree.form_profile==profile,"source record and profile remain explicit")
	var reference_signature:String=study.reference_tree.geometry_signature()
	var profiled_signature:String=study.profiled_tree.geometry_signature()
	check(profiled_signature==reference_signature,"profile-driven geometry exactly matches hard-coded Fan-Tex v2 arrays")
	var clone:=ProfiledTree.new();clone.configure(study.document.tree,profile);check(clone.geometry_signature()==profiled_signature,"profile-driven tree is deterministic");clone.free()
	diagnostics["reference_stats"]=study.reference_tree.stats;diagnostics["profiled_stats"]=study.profiled_tree.stats
	close(.55,.28,7.4);var front_ref:=await capture("01-front-reference",false);var front_profile:=await capture("02-front-profiled",true);check(digest(front_ref)==digest(front_profile),"front pixels exactly match")
	close(.55+PI*.5,.30,7.4);var side_ref:=await capture("03-side-reference",false);var side_profile:=await capture("04-side-profiled",true);check(digest(side_ref)==digest(side_profile),"side pixels exactly match")
	close(.55,1.49,8.2,true);var top_ref:=await capture("05-top-reference",false);var top_profile:=await capture("06-top-profiled",true);check(digest(top_ref)==digest(top_profile),"top pixels exactly match")
	plan();var plan_ref:=await capture("07-plan-reference",false);var plan_profile:=await capture("08-plan-profiled",true);check(digest(plan_ref)==digest(plan_profile),"Plan pixels exactly match")
	close(.55,.28,7.4);study._choose("Afternoon");var afternoon:=await capture("09-afternoon-profiled",true);study._choose("Morning");var morning:=await capture("10-morning-return",true);check(digest(afternoon)!=digest(front_profile),"profiled values respond to actual scene sun");check(digest(morning)==digest(front_profile),"profiled morning image returns exactly")
	check(study.profiled_tree.geometry_signature()==profiled_signature,"camera/light comparisons never regenerate profile-driven geometry")
	var report:Dictionary={"run_id":run_id,"passed":failures.is_empty(),"checks":checks,"failures":failures,"pixel_hashes":hashes,"diagnostics":diagnostics,"profile":profile,"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"scope":"exact reproduction of retained Fan-Tex v2 through validated normalized plant-form data and one generic two-mesh builder","horticultural_facts_in_profile":false,"tablet_performance_tested":false}
	var f:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE);if f==null:push_error("Cannot write report");quit(1);return
	f.store_string(JSON.stringify(report,"  "));f.close();study.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
