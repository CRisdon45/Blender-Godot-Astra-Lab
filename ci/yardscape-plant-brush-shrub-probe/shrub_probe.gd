extends SceneTree

const Current=preload("res://presentation/northstar/spatial_profiled_brush_shrub_study.gd")
const Profiles=preload("res://presentation/northstar/foliage/plant_form_profiles.gd")
const ShrubProfiles=preload("res://presentation/northstar/foliage/shrub_form_profile.gd")
const Layout=preload("res://presentation/northstar/foliage/plant_form_layout.gd")
const BrushTree=preload("res://presentation/northstar/foliage/profiled_batched_brush_tree.gd")
const PlanSymbol=preload("res://presentation/northstar/plan/profiled_plan_symbol.gd")

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

func capture(name:String,mode:String)->Image:
	study.set_display_mode(mode)
	var layers:Array=[]
	for c in study.get_children():
		if c is CanvasLayer:layers.append([c,c.visible]);c.visible=false
	for i in 4:await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image();image.convert(Image.FORMAT_RGBA8)
	check(image.save_png(output.path_join(name+".png"))==OK,"capture "+name);hashes[name]=digest(image)
	for pair in layers:pair[0].visible=pair[1]
	return image

func focus(record:Dictionary,yaw:float,pitch:float,distance:float,top:=false)->void:
	study.target=Vector3(record.x,record.base_elevation+record.height*.52,-record.y)
	study.plan_locked=false;study.perspective=true;study.yaw=yaw;study.pitch=pitch;study.distance=distance;study._update_camera()
	if top:
		study.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
		study.camera.size=maxf(3.0,float(record.crown_radius)*3.3)
		study.camera.position=study.target+Vector3.UP*8.0
		study.camera.look_at(study.target,Vector3(0,0,-1))

func courtyard(yaw:=.55)->void:
	study.plan_locked=false;study.perspective=true;study.target=Vector3(8.15,1.55,-7.05);study.yaw=yaw;study.pitch=.66;study.distance=10.5;study._update_camera()

func run()->void:
	output=OS.get_environment("YARDSCAPE_SHRUB_OUTPUT");run_id=OS.get_environment("YARDSCAPE_SHRUB_RUN_ID")
	if run_id.length()!=36 or not output.begins_with(ProjectSettings.globalize_path("res://.local/")):push_error("Fresh shrub output required");quit(1);return
	root.size=Vector2i(1280,900)
	var shrub_profile:=ShrubProfiles.dense_desert_mound_v2()
	check(Profiles.input_error(shrub_profile).is_empty(),"generic shrub form profile validates through the retained schema")
	study=load("res://northstar-profile-brush-shrub.tscn").instantiate();root.add_child(study);for i in 3:await process_frame
	check(study is Current,"exact isolated retained-brush shrub study")
	var tree=study.tree_brush;var dab=study.shrub_dab;var brush=study.shrub_brush;var shrub_record:Dictionary=study.shrub_record
	check(tree.stats.recipe=="fixed-center-brush-card-cloud/2" and brush.stats.recipe==tree.stats.recipe,"shrub uses the exact retained v4 brush recipe")
	check(tree.stats.surface_style=="northstar-muted-macro-wash/1" and brush.stats.surface_style==tree.stats.surface_style,"tree and shrub use the isolated muted macro-wash surface")
	check(tree.stats.profile=="fan-tex-ash-macro-form/2" and tree.stats.cards==288 and tree.stats.visible_triangles==2582,"retained Fan-Tex v4 control remains exact")
	check(dab.descriptor==shrub_record and brush.descriptor==shrub_record,"both shrub renderers preserve the immutable shrub instance record")
	check(brush.form_profile==shrub_profile and brush.stats.profile=="dense-desert-shrub-mound/2","brush renderer consumes the explicit shrub profile")
	var phase:=Layout.phase_for_seed(int(shrub_record.seed),shrub_profile)
	check(brush.normalized_plan_lobes()==Layout.plan_lobes(shrub_profile,phase) and brush.normalized_plan_lobes()==dab.normalized_plan_lobes(),"Perspective renderers consume the exact shared shrub layout")
	check(brush.stats.groups==17 and brush.stats.cards_per_group==13 and brush.stats.cards==221,"shrub budget follows seventeen low profile groups without renderer exceptions")
	check(brush.stats.visible_meshes==2 and not brush.stats.alpha_blended and brush.stats.alpha_scissor,"shrub remains two meshes with alpha scissor, never alpha blend")
	check(brush.stats.camera_facing and brush.stats.fixed_3d_centers and not brush.stats.whole_plant_billboard and not brush.stats.solid_core,"only small fixed-center cards face the camera and no shrub core exists")
	check(int(brush.stats.visible_triangles)<int(dab.stats.visible_triangles),"retained brush shrub uses fewer indexed triangles than the dab baseline")
	check(float(brush.stats.foliage_width)>float(brush.stats.foliage_height)*1.45,"shrub foliage envelope is materially wider than tall")
	check(float(brush.stats.overall_height)<float(shrub_record.height)*1.08,"shrub geometry respects its low instance height")
	var shrub_signature:String=brush.geometry_signature();var clone:=BrushTree.new();clone.configure(shrub_record,shrub_profile)
	check(clone.geometry_signature()==shrub_signature,"shrub brush geometry is deterministic");clone.free()
	var plan:=PlanSymbol.new();plan.configure(shrub_record,shrub_profile)
	check(plan.lobes==brush.normalized_plan_lobes(),"direct Node2D Plan symbol consumes the exact shrub lobes without 3D readback")
	check(plan.stats.profile==brush.stats.profile and plan.stats.lobes==brush.stats.groups,"Plan and Perspective identify the same shrub profile and group count");plan.free()
	diagnostics["tree_brush_stats"]=tree.stats;diagnostics["shrub_dab_stats"]=dab.stats;diagnostics["shrub_brush_stats"]=brush.stats
	diagnostics["shrub_geometry_signature"]=shrub_signature;diagnostics["shrub_plan_layout_signature"]=var_to_bytes(Layout.plan_lobes(shrub_profile,phase)).hex_encode().sha256_text()
	focus(study.document.tree,.55,.28,7.4);var tree_front:=await capture("01-tree-front-brush","tree")
	focus(shrub_record,.55,.23,4.4);var shrub_front_dab:=await capture("02-shrub-front-dab","shrub_dab");var shrub_front_brush:=await capture("03-shrub-front-brush","shrub_brush")
	check(digest(shrub_front_dab)!=digest(shrub_front_brush),"shrub brush surface visibly differs from the dab baseline")
	check(digest(tree_front)!=digest(shrub_front_brush),"same retained renderer preserves visibly distinct tree and shrub forms")
	focus(shrub_record,.55+PI*.5,.24,4.4);await capture("04-shrub-side-dab","shrub_dab");await capture("05-shrub-side-brush","shrub_brush")
	focus(shrub_record,.55,1.49,4.5,true);await capture("06-shrub-top-dab","shrub_dab");await capture("07-shrub-top-brush","shrub_brush")
	focus(shrub_record,.18,.12,4.2);await capture("08-shrub-low-brush","shrub_brush")
	courtyard(.55);await capture("09-tree-shrub-courtyard","both");courtyard(.55+PI*.72);await capture("10-tree-shrub-opposite","both")
	focus(shrub_record,.55,.23,4.4);study._choose("Afternoon");var afternoon:=await capture("11-shrub-afternoon-brush","shrub_brush");study._choose("Morning");var morning:=await capture("12-shrub-morning-return","shrub_brush")
	check(digest(afternoon)!=digest(shrub_front_brush),"shrub value hierarchy responds to the actual scene sun")
	check(digest(morning)==digest(shrub_front_brush),"shrub morning image returns exactly")
	check(study.shrub_brush.geometry_signature()==shrub_signature,"camera, visibility, and light changes never regenerate shrub geometry")
	var report:Dictionary={"run_id":run_id,"passed":failures.is_empty(),"checks":checks,"failures":failures,"pixel_hashes":hashes,"diagnostics":diagnostics,"shrub_record":shrub_record,"shrub_profile":shrub_profile,"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"scope":"exact retained brush v4 renderer consuming one separate low multi-stem shrub profile and instance record, with dab and Fan-Tex controls","uses_shared_plan_layout":true,"uses_3d_mesh_readback_for_plan":false,"uses_alpha_scissor":true,"uses_alpha_blend":false,"whole_plant_billboard":false,"uses_solid_core":false,"runtime_ai":false,"tablet_performance_tested":false,"artistic_acceptance":"human_review_required"}
	var f:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE);if f==null:push_error("Cannot write report");quit(1);return
	f.store_string(JSON.stringify(report,"  "));f.close();study.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
