extends SceneTree

const Current=preload("res://presentation/northstar/spatial_profiled_wash_volume_study.gd")
const Profiles=preload("res://presentation/northstar/foliage/plant_form_profiles.gd")
const Layout=preload("res://presentation/northstar/foliage/plant_form_layout.gd")
const VolumeTree=preload("res://presentation/northstar/foliage/profiled_batched_wash_tree.gd")

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

func capture(name:String,volume:bool)->Image:
	study.set_volume_enabled(volume)
	var layers:Array=[]
	for c in study.get_children():
		if c is CanvasLayer:layers.append([c,c.visible]);c.visible=false
	for i in 4:await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image();image.convert(Image.FORMAT_RGBA8)
	check(image.save_png(output.path_join(name+".png"))==OK,"capture "+name);hashes[name]=digest(image)
	for pair in layers:pair[0].visible=pair[1]
	return image

func close(yaw:float,pitch:float,distance:float,top:=false)->void:
	var t:Dictionary=study.document.tree
	study.target=Vector3(t.x,t.base_elevation+t.height*.63,-t.y);study.plan_locked=false;study.perspective=not top;study.yaw=yaw;study.pitch=pitch;study.distance=distance;study._update_camera()
	if top:study.camera.position=study.target+Vector3.UP*9.;study.camera.look_at(study.target,Vector3(0,0,-1))

func courtyard()->void:
	study.plan_locked=false;study.perspective=true;study.target=Vector3(5.,0.,-7.);study.yaw=.55;study.pitch=.85;study.distance=22.;study._update_camera()

func plan_signature(profile:Dictionary)->String:
	var phase:=Layout.phase_for_seed(int(study.document.tree.seed),profile)
	return var_to_bytes(Layout.plan_lobes(profile,phase)).hex_encode().sha256_text()

func validate_profile(profile:Dictionary,expected_groups:int,label:String)->String:
	study.set_profile(profile)
	var brush=study.brush_tree;var volume=study.volume_tree
	check(brush.descriptor==study.document.tree and volume.descriptor==study.document.tree,label+" renderers preserve the authoritative tree record")
	check(brush.normalized_plan_lobes()==volume.normalized_plan_lobes(),label+" brush and volume renderers use identical normalized Plan lobes")
	var phase:=Layout.phase_for_seed(int(study.document.tree.seed),profile)
	check(volume.normalized_plan_lobes()==Layout.plan_lobes(profile,phase),label+" volume renderer consumes the exact shared layout")
	check(volume.stats.groups==expected_groups and volume.stats.volumes==expected_groups*2,label+" creates two bounded volumes per shared profile group")
	check(volume.stats.visible_meshes==2 and not volume.stats.alpha_blended and not volume.stats.alpha_scissor,label+" candidate is two opaque meshes without alpha foliage")
	check(volume.stats.closed_lobe_volumes and not volume.stats.whole_plant_billboard and not volume.stats.single_crown_core,label+" candidate uses separate closed 3D lobes, not a billboard or single crown core")
	check(float(volume.stats.foliage_width)>0. and float(volume.stats.foliage_height)>0. and int(volume.stats.foliage_triangles)>0,label+" candidate emits finite visible foliage geometry")
	var signature:String=volume.geometry_signature();var clone:=VolumeTree.new();clone.configure(study.document.tree,profile)
	check(clone.geometry_signature()==signature,label+" wash-volume geometry is deterministic");clone.free()
	diagnostics[label.to_lower().replace(" ","_")+"_brush_stats"]=brush.stats
	diagnostics[label.to_lower().replace(" ","_")+"_volume_stats"]=volume.stats
	return signature

func run()->void:
	output=OS.get_environment("YARDSCAPE_VOLUME_OUTPUT");run_id=OS.get_environment("YARDSCAPE_VOLUME_RUN_ID")
	if run_id.length()!=36 or not output.begins_with(ProjectSettings.globalize_path("res://.local/")):push_error("Fresh wash-volume output required");quit(1);return
	root.size=Vector2i(1280,900)
	var ash_profile:=Profiles.fan_tex_ash_v2();var palo_profile:=Profiles.desert_museum_palo_verde_v2()
	check(Profiles.input_error(ash_profile).is_empty() and Profiles.input_error(palo_profile).is_empty(),"retained form profiles validate")
	study=load("res://northstar-profile-wash-volume.tscn").instantiate();root.add_child(study);for i in 3:await process_frame
	check(study is Current,"exact isolated profile-driven wash-volume study")
	var ash_plan_signature:=plan_signature(ash_profile);var ash_signature:=validate_profile(ash_profile,16,"Fan-Tex")
	close(.55,.28,7.4);var ash_front_brush:=await capture("01-fantex-front-brush",false);var ash_front_volume:=await capture("02-fantex-front-volume",true);check(digest(ash_front_brush)!=digest(ash_front_volume),"Fan-Tex wash volume visibly differs from retained brush cards")
	close(.55+PI*.5,.30,7.4);await capture("03-fantex-side-brush",false);await capture("04-fantex-side-volume",true)
	close(.55,1.49,8.2,true);await capture("05-fantex-top-brush",false);await capture("06-fantex-top-volume",true)
	courtyard();await capture("07-fantex-courtyard-brush",false);await capture("08-fantex-courtyard-volume",true)
	var palo_plan_signature:=plan_signature(palo_profile);var palo_signature:=validate_profile(palo_profile,14,"Palo Verde")
	close(.55,.27,7.5);var palo_front_brush:=await capture("09-palo-front-brush",false);var palo_front_volume:=await capture("10-palo-front-volume",true);check(digest(palo_front_brush)!=digest(palo_front_volume),"Palo wash volume visibly differs from retained brush cards");check(digest(palo_front_volume)!=digest(ash_front_volume),"same volume builder preserves visibly distinct species forms")
	close(.55,1.49,8.2,true);await capture("11-palo-top-brush",false);await capture("12-palo-top-volume",true)
	close(.55,.27,7.5);study._choose("Afternoon");var afternoon:=await capture("13-palo-afternoon-volume",true);study._choose("Morning");var morning:=await capture("14-palo-morning-return",true)
	check(digest(afternoon)!=digest(palo_front_volume),"wash-volume hierarchy values respond to the actual scene sun")
	check(digest(morning)==digest(palo_front_volume),"wash-volume morning image returns exactly")
	check(study.volume_tree.geometry_signature()==palo_signature,"camera and light changes never regenerate volume geometry")
	check(plan_signature(ash_profile)==ash_plan_signature and plan_signature(palo_profile)==palo_plan_signature,"volume experiment never changes shared Plan layouts")
	diagnostics["ash_plan_layout_signature"]=ash_plan_signature;diagnostics["palo_plan_layout_signature"]=palo_plan_signature;diagnostics["ash_geometry_signature"]=ash_signature;diagnostics["palo_geometry_signature"]=palo_signature
	var report:Dictionary={"run_id":run_id,"passed":failures.is_empty(),"checks":checks,"failures":failures,"pixel_hashes":hashes,"diagnostics":diagnostics,"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"scope":"profile-driven closed 3D wash volumes over unchanged shared layout, compared with retained brush cards","uses_shared_plan_layout":true,"uses_3d_mesh_readback_for_plan":false,"uses_closed_lobe_volumes":true,"uses_alpha_scissor":false,"uses_alpha_blend":false,"whole_plant_billboard":false,"single_crown_core":false,"runtime_ai":false,"tablet_performance_tested":false,"artistic_acceptance":"human_review_required"}
	var f:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE);if f==null:push_error("Cannot write report");quit(1);return
	f.store_string(JSON.stringify(report,"  "));f.close();study.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
