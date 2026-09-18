extends SceneTree
const Current=preload("res://presentation/northstar/spatial_species_profile_contrast_study.gd")
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
func capture(name:String,palo:bool)->Image:
	study.set_palo_enabled(palo)
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
	study.target=Vector3(t.x,t.base_elevation+t.height*.62,-t.y);study.plan_locked=false;study.perspective=not top;study.yaw=yaw;study.pitch=pitch;study.distance=distance;study._update_camera()
	if top:study.camera.position=study.target+Vector3.UP*9.;study.camera.look_at(study.target,Vector3(0,0,-1))
func plan()->void:study.plan_locked=true;study.perspective=false;study.target=Vector3(5.,0.,-7.5);study.plan_size=20.;study._update_camera()
func courtyard()->void:study.plan_locked=false;study.perspective=true;study.target=Vector3(5.,0.,-7.);study.yaw=.55;study.pitch=.85;study.distance=22.;study._update_camera()
func run()->void:
	output=OS.get_environment("YARDSCAPE_PALO_OUTPUT");run_id=OS.get_environment("YARDSCAPE_PALO_RUN_ID")
	if run_id.length()!=36 or not output.begins_with(ProjectSettings.globalize_path("res://.local/")):push_error("Fresh Palo Verde output required");quit(1);return
	root.size=Vector2i(1280,900)
	var ash_profile:=Profiles.fan_tex_ash_v2();var palo_profile:=Profiles.desert_museum_palo_verde_v1()
	check(Profiles.input_error(ash_profile).is_empty() and Profiles.input_error(palo_profile).is_empty(),"both species form profiles validate")
	study=load("res://northstar-desert-museum-profile.tscn").instantiate();root.add_child(study);for i in 3:await process_frame
	check(study is Current,"exact species-profile contrast scene")
	check(study.ash_tree is ProfiledTree and study.palo_tree is ProfiledTree,"both species use the same generic builder")
	check(study.palo_tree.stats.profile=="desert-museum-palo-verde-macro-form/1","explicit Desert Museum profile")
	check(study.palo_tree.stats.groups==13 and study.palo_tree.stats.families==5,"Palo profile uses thirteen airy crown groups across five scaffold families")
	check(study.palo_tree.stats.visible_meshes==2 and not study.palo_tree.stats.alpha_blended,"Palo candidate remains two opaque meshes")
	check(study.palo_tree.stats.visible_triangles<6000,"Palo profile remains under six thousand indexed triangles")
	check(study.palo_tree.stats.visible_triangles<study.ash_tree.stats.visible_triangles,"airy Palo profile uses fewer indexed triangles than Fan-Tex profile")
	check(study.palo_tree.descriptor==study.document.tree and study.ash_tree.descriptor==study.document.tree,"species profiles do not alter authoritative tree instance record")
	check(study.palo_tree.geometry_signature()!=study.ash_tree.geometry_signature(),"contrasting species profiles produce distinct geometry")
	var signature:String=study.palo_tree.geometry_signature();var clone:=ProfiledTree.new();clone.configure(study.document.tree,palo_profile);check(clone.geometry_signature()==signature,"Palo profile is deterministic");clone.free()
	var bark:Color=study.palo_tree.wood.material_override.albedo_color
	check(bark.g>bark.r and bark.g>bark.b,"Palo profile presents green photosynthetic wood cue")
	diagnostics["ash_stats"]=study.ash_tree.stats;diagnostics["palo_stats"]=study.palo_tree.stats
	close(.55,.27,7.5);var ash_front:=await capture("01-front-fantex",false);var palo_front:=await capture("02-front-palo",true);check(digest(ash_front)!=digest(palo_front),"front view visibly distinguishes species forms")
	close(.55+PI*.5,.29,7.5);await capture("03-side-fantex",false);await capture("04-side-palo",true)
	close(.55+PI,.27,7.5);await capture("05-reverse-fantex",false);await capture("06-reverse-palo",true)
	close(.55,1.49,8.2,true);var ash_top:=await capture("07-top-fantex",false);var palo_top:=await capture("08-top-palo",true);check(digest(ash_top)!=digest(palo_top),"top view visibly distinguishes species forms")
	plan();await capture("09-plan-fantex",false);await capture("10-plan-palo",true)
	courtyard();await capture("11-courtyard-fantex",false);await capture("12-courtyard-palo",true)
	close(.55,.27,7.5);study._choose("Afternoon");var afternoon:=await capture("13-afternoon-palo",true);study._choose("Morning");var morning:=await capture("14-morning-return",true);check(digest(afternoon)!=digest(palo_front),"Palo hierarchy values respond to actual scene sun");check(digest(morning)==digest(palo_front),"Palo morning image returns exactly")
	check(study.palo_tree.geometry_signature()==signature,"camera/light comparisons never regenerate Palo geometry")
	var report:Dictionary={"run_id":run_id,"passed":failures.is_empty(),"checks":checks,"failures":failures,"pixel_hashes":hashes,"diagnostics":diagnostics,"ash_profile":ash_profile,"palo_profile":palo_profile,"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"scope":"second contrasting species morphology through exact same profile-driven opaque two-mesh tree builder","literal_leaf_geometry":false,"seasonal_bloom_layer":false,"horticultural_size_data_applied":false,"tablet_performance_tested":false,"artistic_acceptance":"not_evaluated"}
	var f:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE);if f==null:push_error("Cannot write report");quit(1);return
	f.store_string(JSON.stringify(report,"  "));f.close();study.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
