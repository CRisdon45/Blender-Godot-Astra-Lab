extends SceneTree
const Study=preload("res://presentation/northstar/plan_profile_study.gd")
const Profiles=preload("res://presentation/northstar/foliage/plant_form_profiles.gd")
const Layout=preload("res://presentation/northstar/foliage/plant_form_layout.gd")
const Symbol=preload("res://presentation/northstar/plan/profiled_plan_symbol.gd")
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
func capture(name:String)->Image:
	for i in 4:await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image();image.convert(Image.FORMAT_RGBA8)
	check(image.save_png(output.path_join(name+".png"))==OK,"capture "+name);hashes[name]=digest(image);return image
func run()->void:
	output=OS.get_environment("YARDSCAPE_PLAN_PROFILE_OUTPUT");run_id=OS.get_environment("YARDSCAPE_PLAN_PROFILE_RUN_ID")
	if run_id.length()!=36 or not output.begins_with(ProjectSettings.globalize_path("res://.local/")):push_error("Fresh Plan-profile output required");quit(1);return
	root.size=Vector2i(1280,720);study=load("res://northstar-profile-plan-symbols.tscn").instantiate();root.add_child(study);for i in 3:await process_frame
	check(study is Study,"exact direct Plan profile study")
	check(study.ash is Symbol and study.palo is Symbol,"both symbols use the same direct 2D renderer")
	check(study.ash.lobes.size()==16 and study.palo.lobes.size()==14,"Plan lobe count follows shared species layouts")
	check(study.ash.scaffold.size()==17 and study.palo.scaffold.size()==15,"Plan scaffold path count follows shared species layouts")
	var ash_profile:=Profiles.fan_tex_ash_v2();var palo_profile:=Profiles.desert_museum_palo_verde_v2()
	var ash_phase:=Layout.phase_for_seed(int(study.tree_record.seed),ash_profile);var palo_phase:=Layout.phase_for_seed(int(study.tree_record.seed),palo_profile)
	check(var_to_bytes(study.ash.lobes)==var_to_bytes(Layout.plan_lobes(ash_profile,ash_phase)),"Fan-Tex symbol consumes exact shared Plan lobes")
	check(var_to_bytes(study.palo.lobes)==var_to_bytes(Layout.plan_lobes(palo_profile,palo_phase)),"Palo symbol consumes exact shared Plan lobes")
	check(study.ash.layout_signature()!=study.palo.layout_signature(),"species profiles create distinct direct Plan layouts")
	var ash_clone:=Symbol.new();ash_clone.configure(study.tree_record,ash_profile)
	var palo_clone:=Symbol.new();palo_clone.configure(study.tree_record,palo_profile)
	check(ash_clone.layout_signature()==study.ash.layout_signature() and palo_clone.layout_signature()==study.palo.layout_signature(),"direct Plan layouts are deterministic");ash_clone.free();palo_clone.free()
	check(float(study.ash.stats.lobe_area_proxy)>float(study.palo.stats.lobe_area_proxy),"dense Fan-Tex has greater summed lobe-area proxy than airy Palo")
	diagnostics["ash_stats"]=study.ash.stats;diagnostics["palo_stats"]=study.palo.stats
	study.set_mode("ash");var ash_morning:=await capture("01-fantex-plan")
	study.set_mode("palo");var palo_morning:=await capture("02-palo-plan");check(digest(ash_morning)!=digest(palo_morning),"individual species Plan symbols are visibly distinct")
	study.set_mode("pair");var pair_morning:=await capture("03-pair-morning")
	study.set_sun_direction(Vector2(-.72,.69));var pair_afternoon:=await capture("04-pair-afternoon");check(digest(pair_morning)!=digest(pair_afternoon),"Plan value masses respond to sun direction without layout change")
	var ash_signature:=study.ash.layout_signature();var palo_signature:=study.palo.layout_signature()
	study.set_sun_direction(Vector2(.53,-.85));var pair_return:=await capture("05-pair-morning-return");check(digest(pair_return)==digest(pair_morning),"Plan morning image returns exactly")
	check(study.ash.layout_signature()==ash_signature and study.palo.layout_signature()==palo_signature,"sun changes never alter semantic plant layout")
	var report:Dictionary={"run_id":run_id,"passed":failures.is_empty(),"checks":checks,"failures":failures,"pixel_hashes":hashes,"diagnostics":diagnostics,"tree_record":study.tree_record,"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"scope":"direct 2D Plan projection from tree seed/crown radius + plant-form profile + shared plant layout; no 3D mesh readback","uses_3d_mesh_readback":false,"uses_textures":false,"runtime_ai":false,"artistic_acceptance":"not_evaluated"}
	var f:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE);if f==null:push_error("Cannot write report");quit(1);return
	f.store_string(JSON.stringify(report,"  "));f.close();study.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
