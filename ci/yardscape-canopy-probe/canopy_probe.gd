extends SceneTree
const Current = preload("res://presentation/northstar/spatial_canopy_study.gd")
const Baseline = preload("res://presentation/northstar/spatial_material_study.gd")
const CanopyForm = preload("res://presentation/northstar/canopy/illustrative_tree.gd")
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
func semantic() -> String:return JSON.stringify(study.document,"",true,true).sha256_text()
func retained() -> Array:
	var data: Array=[]
	for n in study.derived.get_children():
		if n is MeshInstance3D:
			data.append([str(n.name),n.get_instance_id(),n.mesh.get_instance_id(),n.material_override.get_instance_id(),n.transform])
	return data
func geometry() -> String:
	var data: Array=[]
	for n in study.derived.get_children():
		if n is MeshInstance3D:
			var arrays: Array=[]
			for i in n.mesh.get_surface_count():arrays.append(n.mesh.surface_get_arrays(i))
			data.append([str(n.name),n.transform,arrays])
	return var_to_bytes(data).hex_encode().sha256_text()
func camera_state() -> Array:
	return [study.target,study.plan_size,study.yaw,study.pitch,study.distance,study.plan_locked,study.perspective,study.camera.transform]
func capture(name: String) -> Image:
	var layers: Array=[]
	for c in study.get_children():
		if c is CanvasLayer:layers.append([c,c.visible]);c.visible=false
	for i in 4:await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image();image.convert(Image.FORMAT_RGBA8)
	check(image.save_png(output.path_join(name+".png"))==OK,"capture "+name)
	hashes[name]=digest(image)
	for pair in layers:pair[0].visible=pair[1]
	return image
func key_press(key: Key) -> void:
	var e:=InputEventKey.new();e.keycode=key;e.pressed=true;Input.parse_input_event(e);await process_frame
	e=InputEventKey.new();e.keycode=key;e.pressed=false;Input.parse_input_event(e);await process_frame
func triangle_count(mesh: Mesh) -> int:
	var total:=0
	for i in mesh.get_surface_count():
		var arrays:=mesh.surface_get_arrays(i)
		total+=int(arrays[Mesh.ARRAY_INDEX].size()/3) if arrays[Mesh.ARRAY_INDEX]!=null else int(arrays[Mesh.ARRAY_VERTEX].size()/3)
	return total
func valid_tree(tree) -> bool:
	for node in [tree.crown,tree.wood]:
		var a: Array=node.mesh.surface_get_arrays(0)
		for p in a[Mesh.ARRAY_VERTEX]:
			if not p.is_finite() or p.y<-.001 or p.y>tree.descriptor.height+.001 or Vector2(p.x,p.z).length()>tree.descriptor.crown_radius+.001:return false
		for n in a[Mesh.ARRAY_NORMAL]:
			if not n.is_finite() or absf(n.length()-1.)>.002:return false
		for i in a[Mesh.ARRAY_INDEX]:
			if i<0 or i>=a[Mesh.ARRAY_VERTEX].size():return false
	return true
func set_close(top: bool=false) -> void:
	var t: Dictionary=study.document.tree
	study.target=Vector3(t.x,t.base_elevation+t.height*.64,-t.y)
	study.pitch=1.49 if top else .28
	study.yaw=.55;study.distance=6.0;study.perspective=false;study.plan_locked=false;study._update_camera()
func mask(name: String,top: bool) -> void:
	set_close(top)
	if top:
		study.camera.position=study.target+Vector3.UP*8.
		study.camera.look_at(study.target,Vector3(0,0,-1))
	var visible: Array=[]
	for n in study.derived.get_children():visible.append(n.visible);n.visible=n==study.illustrative_tree
	var white:=StandardMaterial3D.new();white.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;white.albedo_color=Color.WHITE
	var mats: Array=[]
	for n in [study.illustrative_tree.wood,study.illustrative_tree.crown]:mats.append(n.material_override);n.material_override=white
	var background: Color=study.environment.background_color;study.environment.background_color=Color.BLACK
	await capture(name)
	study.environment.background_color=background
	var index:=0
	for n in study.derived.get_children():n.visible=visible[index];index+=1
	study.illustrative_tree.wood.material_override=mats[0];study.illustrative_tree.crown.material_override=mats[1]
func run() -> void:
	output=OS.get_environment("YARDSCAPE_CANOPY_OUTPUT");run_id=OS.get_environment("YARDSCAPE_CANOPY_RUN_ID")
	if run_id.length()!=36 or not output.begins_with(ProjectSettings.globalize_path("res://.local/")):
		push_error("Fresh isolated canopy output required");quit(1);return
	root.size=Vector2i(1280,900)
	study=load("res://northstar-spatial-canopy.tscn").instantiate();root.add_child(study)
	for i in 3:await process_frame
	check(study is Current and study.study_ready,"candidate runs in the existing shared material courtyard")
	var doc:=semantic();var geo:=geometry();var keep:=retained();var builds: int=study.build_count
	var shape: String=study.illustrative_tree.geometry_signature()
	check(valid_tree(study.illustrative_tree),"finite bounded meshes and unit shading normals")
	check(study.illustrative_tree.descriptor==study.document.tree,"all source tree values and qualifiers remain unchanged")
	check(study.illustrative_tree.position==Vector3(study.document.tree.x,study.document.tree.base_elevation,-study.document.tree.y),"tree root retains exact project placement")
	var old_triangles:=0
	for n in study.derived.get_children():
		if str(n.name).begins_with("crown-") or n.name=="tree-trunk":old_triangles+=triangle_count(n.mesh)
	diagnostics["proxy_triangles"]=old_triangles;diagnostics["candidate"]=study.illustrative_tree.stats
	var new_triangles:=triangle_count(study.illustrative_tree.wood.mesh)+triangle_count(study.illustrative_tree.crown.mesh)
	check(new_triangles<old_triangles,"candidate submits fewer tree triangles than the seven-sphere proxy")
	check(study.illustrative_tree.get_child_count()==2,"candidate has two mesh surfaces and no foliage cards")
	study.set_canopy_enabled(false)
	var plan_off:=await capture("01-plan-proxy")
	await key_press(KEY_T);check(study.canopy_enabled,"actual T input selects illustrative canopy")
	var plan_on:=await capture("02-plan-canopy")
	check(digest(plan_on)!=digest(plan_off),"canopy visibly changes Plan")
	var plan_camera:=camera_state()
	study._choose("Orbit");study._choose("Perspective")
	var orbit_camera:=camera_state()
	study.set_canopy_enabled(false);var orbit_off:=await capture("03-orbit-proxy")
	study.set_canopy_enabled(true);var orbit_on:=await capture("04-orbit-canopy")
	check(digest(orbit_on)!=digest(orbit_off),"canopy visibly changes Perspective")
	set_close();study.set_canopy_enabled(false);await capture("05-close-proxy")
	study.set_canopy_enabled(true);await capture("06-close-canopy")
	await mask("07-top-mask",true)
	await mask("08-side-mask",false)
	study.target=orbit_camera[0];study.plan_size=orbit_camera[1];study.yaw=orbit_camera[2];study.pitch=orbit_camera[3];study.distance=orbit_camera[4];study.plan_locked=false;study.perspective=true;study._update_camera()
	check(digest(orbit_on)==digest(await capture("09-view-return")),"close and mask views restore exact courtyard image")
	study._choose("Afternoon");await capture("10-afternoon")
	study._choose("Night");await capture("11-night")
	study._choose("Morning")
	check(digest(orbit_on)==digest(await capture("12-light-return")),"changed sunlight returns to exact morning image")
	for i in 48:
		var event:=InputEventMouseMotion.new();event.position=Vector2(500,500);event.relative=Vector2(-TAU/48./.008,0.);event.button_mask=MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(event);await process_frame
		if i%6==0:await capture("motion-%02d"%int(i/6))
	check(study.yaw>orbit_camera[2]+6.0,"actual injected pointer motion orbits the spatial camera")
	study.yaw=orbit_camera[2];study.pitch=orbit_camera[3];study._update_camera()
	check(digest(orbit_on)==digest(await capture("13-motion-return")),"pointer orbit restores exact original image")
	check(retained()==keep and geometry()==geo and semantic()==doc and study.build_count==builds,"view light and canopy controls preserve all retained scene data and objects")
	check(study.illustrative_tree.geometry_signature()==shape,"orbit never reseeds or regenerates the tree")
	await key_press(KEY_T)
	check(digest(orbit_off)==digest(await capture("14-proxy-return")),"T restores exact original proxy and its shadows")
	await key_press(KEY_T);await key_press(KEY_M);await capture("15-materials-off")
	await key_press(KEY_M)
	check(digest(orbit_on)==digest(await capture("16-materials-return")),"independent M material toggle restores canopy courtyard")
	study._choose("Plan")
	check(camera_state()==plan_camera,"original Plan camera state is preserved")
	check(digest(plan_on)==digest(await capture("17-plan-return")),"Plan return restores canopy scene")
	study._build();study._update_camera()
	check(study.illustrative_tree.geometry_signature()==shape and semantic()==doc,"derived scene rebuild reproduces deterministic tree")
	check(digest(plan_on)==digest(await capture("18-rebuild-return")),"derived rebuild restores complete Plan image")
	var t: Dictionary=study.document.tree.duplicate(true)
	var bad: Dictionary=t.duplicate(true);bad.height=0.
	check(not CanopyForm.input_error(bad).is_empty(),"invalid height is rejected")
	var alternate_signature: String=""
	for i in 3:
		var a:=CanopyForm.new();var b:=CanopyForm.new();var trial:=t.duplicate(true);trial.seed=int(t.seed)+i
		a.configure(trial);b.configure(trial)
		check(a.geometry_signature()==b.geometry_signature() and valid_tree(a),"deterministic finite alternate seed %d"%i)
		if i==1:alternate_signature=a.geometry_signature()
		a.free();b.free()
	check(alternate_signature!=shape,"changed seed changes generic tree shape")
	study.queue_free();await process_frame;await process_frame
	study=Baseline.new();root.add_child(study);for i in 3:await process_frame
	check(digest(plan_off)==digest(await capture("19-original-baseline")),"disabled candidate exactly matches separate prior material scene")
	var report: Dictionary={"run_id":run_id,"passed":failures.is_empty(),"checks":checks,"failures":failures,"pixel_hashes":hashes,"diagnostics":diagnostics,"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"tree_signature":shape,"source_semantic_hash":doc,"scope":"generic spatial canopy and actual camera/toggle input over unchanged read-only adapters","tablet_performance_tested":false,"species_accuracy_claimed":false,"artistic_acceptance":"not_evaluated","temporal_limit":"48 real input increments with eight saved views and exact return, not frame-time or dense per-frame analysis"}
	var f:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	if f==null:push_error("Cannot write canopy report");quit(1);return
	f.store_string(JSON.stringify(report,"  "));f.close();print("Canopy checks: ",checks.size()," failures: ",failures)
	study.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
