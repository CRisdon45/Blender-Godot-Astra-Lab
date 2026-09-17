extends SceneTree
var study
var output: String
var run_id: String
var checks: Array=[]
var failures: Array=[]
var hashes: Dictionary={}
var diagnostics: Dictionary={}
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"passed":ok})
	if not ok: failures.append(label)
func digest(image: Image) -> String: return image.get_data().hex_encode().sha256_text()
func grab(name: String) -> Image:
	print("SHOOT_STAGE capture_begin ",name)
	var layers: Array=[]
	for c in study.get_children():
		if c is CanvasLayer: layers.append([c,c.visible]);c.visible=false
	for i in 2: await process_frame
	print("SHOOT_STAGE frame_ready ",name)
	await RenderingServer.frame_post_draw
	print("SHOOT_STAGE frame_drawn ",name)
	var image:=root.get_texture().get_image();image.convert(Image.FORMAT_RGBA8)
	check(image.save_png(output.path_join(name+".png"))==OK,"capture "+name)
	hashes[name]=digest(image)
	for pair in layers: pair[0].visible=pair[1]
	print("SHOOT_STAGE capture_end ",name)
	return image
func isolate() -> Array:
	var saved: Array=[]
	for n in study.derived.get_children():
		saved.append([n,n.visible]);n.visible=(n==study.compact_shoot)
	return saved
func restore(saved: Array) -> void:
	for pair in saved: pair[0].visible=pair[1]
func shoot_center() -> Vector3:
	var t: Dictionary=study.document.tree
	return Vector3(t.x,t.base_elevation+.64*t.height,-t.y)
func isolated_camera(kind: String) -> void:
	var center:=shoot_center()
	if kind=="top":
		study.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;study.camera.size=2.6
		study.camera.position=center+Vector3.UP*5.;study.camera.look_at(center,Vector3(0,0,-1))
	else:
		study.camera.projection=Camera3D.PROJECTION_PERSPECTIVE;study.camera.fov=42.
		var offset:=Vector3(1.7,.55,2.2) if kind=="front" else Vector3(-1.7,.48,-2.2)
		study.camera.position=center+offset;study.camera.look_at(center,Vector3.UP)
func all_finite_and_bounded() -> bool:
	var t: Dictionary=study.document.tree
	var root_point:=Vector3(t.x,t.base_elevation,-t.y)
	for node in [study.compact_shoot.twig,study.compact_shoot.foliage]:
		var a: Array=node.mesh.surface_get_arrays(0)
		for p in a[Mesh.ARRAY_VERTEX]:
			if not p.is_finite(): return false
			var world: Vector3=study.compact_shoot.global_transform*p
			if Vector2(world.x-root_point.x,world.z-root_point.z).length()>t.crown_radius*1.01: return false
			if world.y<t.base_elevation-.001 or world.y>t.base_elevation+t.height+.001: return false
		for n in a[Mesh.ARRAY_NORMAL]:
			if not n.is_finite() or absf(n.length()-1.)>.003: return false
	return true
func run() -> void:
	print("SHOOT_STAGE run_enter")
	output=OS.get_environment("YARDSCAPE_SHOOT_OUTPUT");run_id=OS.get_environment("YARDSCAPE_SHOOT_RUN_ID")
	if run_id.length()!=36 or not output.begins_with(ProjectSettings.globalize_path("res://.local/")):
		push_error("Fresh isolated shoot output required");quit(1);return
	root.size=Vector2i(800,600)
	print("SHOOT_STAGE before_scene")
	study=load("res://northstar-spatial-shoot.tscn").instantiate();root.add_child(study)
	print("SHOOT_STAGE scene_added")
	for i in 2: await process_frame
	print("SHOOT_STAGE scene_ready")
	check(study.study_ready,"retained spatial courtyard initializes")
	check(study.compact_shoot.stats.leaf_count==7,"compact group contains seven closed leaf forms")
	check(not study.compact_shoot.stats.alpha_foliage,"first look uses no alpha foliage")
	check(study.compact_shoot.stats.mesh_surfaces==2,"shoot is twig plus foliage mesh")
	check(all_finite_and_bounded(),"shoot stays finite and inside source tree bounds")
	var initial_geometry: String=study.compact_shoot.geometry_signature()
	var source_hash:=JSON.stringify(study.document.tree,"",true,true).sha256_text()
	var foliage_arrays: Array=study.compact_shoot.foliage.mesh.surface_get_arrays(0)
	check(foliage_arrays[Mesh.ARRAY_NORMAL].size()==foliage_arrays[Mesh.ARRAY_VERTEX].size(),"final-mesh normal count matches foliage vertices")
	diagnostics["stats"]=study.compact_shoot.stats;diagnostics["source_tree_hash"]=source_hash
	print("SHOOT_STAGE checks_ready")
	var saved:=isolate()
	isolated_camera("top");await grab("01-isolated-top")
	isolated_camera("front");var front:=await grab("02-isolated-front")
	isolated_camera("reverse");var reverse:=await grab("03-isolated-reverse")
	check(digest(front)!=digest(reverse),"closed 3D shoot has distinct front and reverse views")
	restore(saved)
	study._choose("Plan");var plan_shoot:=await grab("04-courtyard-plan-shoot")
	study.set_shoot_enabled(false);var plan_proxy:=await grab("05-courtyard-plan-proxy")
	check(digest(plan_shoot)!=digest(plan_proxy),"representation changes Plan context")
	study.set_shoot_enabled(true);study._choose("Orbit");study._choose("Perspective")
	var orbit_shoot:=await grab("06-courtyard-orbit-shoot")
	study.set_shoot_enabled(false);var orbit_proxy:=await grab("07-courtyard-orbit-proxy")
	check(digest(orbit_shoot)!=digest(orbit_proxy),"representation changes Perspective context")
	check(study.compact_shoot.geometry_signature()==initial_geometry,"view changes do not regenerate shoot geometry")
	check(JSON.stringify(study.document.tree,"",true,true).sha256_text()==source_hash,"source tree record stays unchanged")
	var report: Dictionary={"run_id":run_id,"passed":failures.is_empty(),"checks":checks,"failures":failures,"pixel_hashes":hashes,"diagnostics":diagnostics,"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"geometry_hash":initial_geometry,"scope":"small seven-view look at one compact generic 3D foliage shoot","artistic_acceptance":"not_evaluated","tablet_performance_tested":false,"whole_tree_tested":false}
	var f:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	if f==null:push_error("Cannot retain shoot report");quit(1);return
	f.store_string(JSON.stringify(report,"  "));f.close()
	print("SHOOT_STAGE report_written failures=",failures)
	study.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
