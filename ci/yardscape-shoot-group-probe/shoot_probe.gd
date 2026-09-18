extends SceneTree
const Current=preload("res://presentation/northstar/spatial_shoot_group_study.gd")
const Compact=preload("res://presentation/northstar/foliage/compact_group.gd")
const Shoot=preload("res://presentation/northstar/foliage/shoot_group.gd")
var study
var baseline
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
func capture(name:String,shoot_visible:bool)->Image:
	study.group.visible=shoot_visible;baseline.visible=not shoot_visible
	var layers:Array=[]
	for c in study.get_children():
		if c is CanvasLayer:layers.append([c,c.visible]);c.visible=false
	for i in 4:await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image();image.convert(Image.FORMAT_RGBA8);check(image.save_png(output.path_join(name+".png"))==OK,"capture "+name);hashes[name]=digest(image)
	for pair in layers:pair[0].visible=pair[1]
	return image
func set_view(yaw:float,pitch:float,distance:float,top:bool=false)->void:
	study.target=study.group.position+Vector3(0,.08,0);study.plan_locked=false;study.perspective=not top;study.yaw=yaw;study.pitch=pitch;study.distance=distance;study._update_camera()
	if top:study.camera.position=study.target+Vector3.UP*6.;study.camera.look_at(study.target,Vector3(0,0,-1))
func set_courtyard_plan()->void:
	study.plan_locked=true;study.perspective=false;study.target=Vector3(5.,0.,-7.5);study.plan_size=20.;study._update_camera()
func set_courtyard_oblique()->void:
	study.plan_locked=false;study.perspective=true;study.target=Vector3(5.,0.,-7.);study.yaw=.55;study.pitch=.85;study.distance=22.;study._update_camera()
func valid(group)->bool:
	for node in [group.twig,group.foliage]:
		var a:Array=node.mesh.surface_get_arrays(0)
		for p in a[Mesh.ARRAY_VERTEX]:
			if not p.is_finite():return false
		for n in a[Mesh.ARRAY_NORMAL]:
			if not n.is_finite() or absf(n.length()-1.)>.002:return false
	return true
func run()->void:
	output=OS.get_environment("YARDSCAPE_SHOOT_OUTPUT");run_id=OS.get_environment("YARDSCAPE_SHOOT_RUN_ID")
	if run_id.length()!=36 or not output.begins_with(ProjectSettings.globalize_path("res://.local/")):push_error("Fresh output required");quit(1);return
	root.size=Vector2i(1280,900);study=load("res://northstar-shoot-foliage-group.tscn").instantiate();root.add_child(study);for i in 3:await process_frame
	var t:Dictionary=study.document.tree;baseline=Compact.new();baseline.configure(int(t.seed),t.crown_radius*.54,t.height*.30);baseline.position=study.group.position;study.derived.add_child(baseline)
	check(study is Current and valid(study.group),"shoot candidate initializes with finite final-mesh normals")
	check(study.group.stats.shoots==5 and study.group.stats.leaflet_hints==25,"second look uses five shoots and twenty-five smaller hints")
	var candidate_triangles:=int(study.group.stats.foliage_triangles)+int(study.group.stats.twig_triangles);var baseline_triangles:=int(baseline.stats.foliage_triangles)+int(baseline.stats.twig_triangles)
	check(candidate_triangles<=baseline_triangles,"five-shoot group stays at or below compact control triangle count")
	check(not study.group.stats.alpha_blended,"shoot group stays opaque")
	var signature:String=study.group.geometry_signature();var clone:=Shoot.new();clone.configure(int(t.seed),t.crown_radius*.54,t.height*.30);check(clone.geometry_signature()==signature,"shoot candidate is deterministic");clone.free()
	set_view(.55,.34,4.4);await capture("01-front-compact",false);var front:=await capture("02-front-shoot",true)
	set_view(.55+PI,.34,4.4);await capture("03-reverse-compact",false);await capture("04-reverse-shoot",true)
	set_view(.55+PI*.5,.46,4.4);await capture("05-quarter-compact",false);await capture("06-quarter-shoot",true)
	set_view(.55,1.49,5.,true);await capture("07-top-compact",false);await capture("08-top-shoot",true)
	set_view(.55,.34,4.4);study._choose("Afternoon");var afternoon:=await capture("09-afternoon-shoot",true);check(digest(afternoon)!=digest(front),"shoot group relights with sun")
	study._choose("Morning");check(digest(front)==digest(await capture("10-morning-return",true)),"morning return is exact")
	set_courtyard_plan();await capture("11-courtyard-plan",true);set_courtyard_oblique();await capture("12-courtyard-oblique",true)
	check(study.group.geometry_signature()==signature,"camera/light comparison never regenerates shoot group")
	var report:Dictionary={"run_id":run_id,"passed":failures.is_empty(),"checks":checks,"failures":failures,"pixel_hashes":hashes,"candidate":study.group.stats,"baseline":baseline.stats,"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"scope":"five-shoot small-hint second look versus retained compact literal group","whole_tree_tested":false,"tablet_performance_tested":false,"artistic_acceptance":"not_evaluated"}
	var f:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE);if f==null:push_error("Cannot write report");quit(1);return
	f.store_string(JSON.stringify(report,"  "));f.close();study.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
