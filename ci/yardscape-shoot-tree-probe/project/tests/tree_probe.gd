extends SceneTree
var study
var output: String
var run_id: String
var checks: Array=[]
var failures: Array=[]
var hashes: Dictionary={}
var diagnostics: Dictionary={}
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"passed":ok})
	if not ok:failures.append(label)
func digest(image: Image) -> String:return image.get_data().hex_encode().sha256_text()
func grab(name: String) -> Image:
	var layers: Array=[]
	for c in study.get_children():
		if c is CanvasLayer:layers.append([c,c.visible]);c.visible=false
	for i in 2:await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image();image.convert(Image.FORMAT_RGBA8)
	check(image.save_png(output.path_join(name+".png"))==OK,"capture "+name)
	hashes[name]=digest(image)
	for pair in layers:pair[0].visible=pair[1]
	return image
func tree_center() -> Vector3:
	var t: Dictionary=study.document.tree
	return Vector3(t.x,t.base_elevation+t.height*.64,-t.y)
func close_view(reverse: bool=false,top: bool=false) -> void:
	var c:=tree_center()
	if top:
		study.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;study.camera.size=3.6
		study.camera.position=c+Vector3.UP*7.;study.camera.look_at(c,Vector3(0,0,-1));return
	study.camera.projection=Camera3D.PROJECTION_PERSPECTIVE;study.camera.fov=42.
	var offset:=Vector3(3.0,.65,3.7) if not reverse else Vector3(-3.0,.58,-3.7)
	study.camera.position=c+offset;study.camera.look_at(c,Vector3.UP)
func finite_tree() -> bool:
	var t: Dictionary=study.document.tree
	var root_point:=Vector3(t.x,t.base_elevation,-t.y)
	for shoot in study.interleaved_tree.shoots:
		for node in [shoot.twig,shoot.foliage]:
			var arrays: Array=node.mesh.surface_get_arrays(0)
			for p in arrays[Mesh.ARRAY_VERTEX]:
				if not p.is_finite():return false
				var world: Vector3=shoot.global_transform*p
				if Vector2(world.x-root_point.x,world.z-root_point.z).length()>float(t.crown_radius)*1.12:return false
				if world.y<t.base_elevation-.01 or world.y>t.base_elevation+t.height+.08:return false
			for n in arrays[Mesh.ARRAY_NORMAL]:
				if not n.is_finite() or absf(n.length()-1.)>.003:return false
	return true
func run() -> void:
	output=OS.get_environment("YARDSCAPE_TREE_OUTPUT");run_id=OS.get_environment("YARDSCAPE_TREE_RUN_ID")
	if run_id.length()!=36 or not output.begins_with(ProjectSettings.globalize_path("res://.local/")):
		push_error("Fresh tree output required");quit(1);return
	root.size=Vector2i(960,720)
	study=load("res://northstar-spatial-interleaved-tree.tscn").instantiate();root.add_child(study)
	for i in 2:await process_frame
	check(study.study_ready,"retained spatial material courtyard initializes")
	check(study.interleaved_tree.stats.shoot_count==16,"tree uses the sixteen retained branch-scale anchors")
	check(study.interleaved_tree.stats.leaf_count==112,"sixteen compact groups contain 112 closed leaf forms")
	check(not study.interleaved_tree.stats.alpha_foliage,"whole tree keeps opaque foliage")
	check(finite_tree(),"all shoot geometry is finite and remains within bounded crown envelope")
	var geometry: String=study.interleaved_tree.geometry_signature()
	var source_hash:=JSON.stringify(study.document.tree,"",true,true).sha256_text()
	diagnostics["stats"]=study.interleaved_tree.stats;diagnostics["source_tree_hash"]=source_hash
	study._choose("Plan");var plan_new:=await grab("01-plan-tree")
	study.set_tree_enabled(false);var plan_proxy:=await grab("02-plan-proxy")
	check(digest(plan_new)!=digest(plan_proxy),"Plan distinguishes shoot tree from structural proxy")
	study.set_tree_enabled(true);study._choose("Orbit");study._choose("Perspective")
	var orbit_new:=await grab("03-orbit-tree")
	study.set_tree_enabled(false);var orbit_proxy:=await grab("04-orbit-proxy")
	check(digest(orbit_new)!=digest(orbit_proxy),"Perspective distinguishes shoot tree from structural proxy")
	study.set_tree_enabled(true);close_view(false,false);var close:=await grab("05-close-front")
	close_view(true,false);var reverse:=await grab("06-close-reverse")
	check(digest(close)!=digest(reverse),"whole tree has distinct front and reverse appearance")
	close_view(false,true);await grab("07-close-top")
	study._choose("Afternoon");var afternoon:=await grab("08-top-afternoon")
	check(digest(afternoon)!=hashes["07-close-top"],"tree responds to retained changed sunlight")
	check(study.interleaved_tree.geometry_signature()==geometry,"camera and light changes do not regenerate tree")
	check(JSON.stringify(study.document.tree,"",true,true).sha256_text()==source_hash,"source tree record remains unchanged")
	var report: Dictionary={"run_id":run_id,"passed":failures.is_empty(),"checks":checks,"failures":failures,"pixel_hashes":hashes,"diagnostics":diagnostics,"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"geometry_hash":geometry,"scope":"small native look at whole generic tree assembled from tested compact 3D shoots","artistic_acceptance":"not_evaluated","tablet_performance_tested":false,"species_fidelity_claimed":false}
	var f:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	if f==null:push_error("Cannot retain tree report");quit(1);return
	f.store_string(JSON.stringify(report,"  "));f.close()
	study.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
