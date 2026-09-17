extends SceneTree
const Current=preload("res://presentation/northstar/spatial_batched_dab_value_study.gd")
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
func capture(name:String,batch:bool)->Image:
	study.set_batch_enabled(batch)
	var layers:Array=[]
	for c in study.get_children():
		if c is CanvasLayer:layers.append([c,c.visible]);c.visible=false
	for i in 4:await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image();image.convert(Image.FORMAT_RGBA8)
	check(image.save_png(output.path_join(name+".png"))==OK,"capture "+name);hashes[name]=digest(image)
	for pair in layers:pair[0].visible=pair[1]
	return image
func plan()->void:study.plan_locked=true;study.perspective=false;study.target=Vector3(5.,0.,-7.5);study.plan_size=20.;study._update_camera()
func courtyard()->void:study.plan_locked=false;study.perspective=true;study.target=Vector3(5.,0.,-7.);study.yaw=.55;study.pitch=.85;study.distance=22.;study._update_camera()
func close(yaw:float,pitch:float,distance:float,top:bool=false)->void:
	var t:Dictionary=study.document.tree;study.target=Vector3(t.x,t.base_elevation+t.height*.66,-t.y);study.plan_locked=false;study.perspective=not top;study.yaw=yaw;study.pitch=pitch;study.distance=distance;study._update_camera()
	if top:study.camera.position=study.target+Vector3.UP*9.;study.camera.look_at(study.target,Vector3(0,0,-1))
func changed_pixels(a:Image,b:Image)->int:
	var aa:=a.get_data();var bb:=b.get_data();var count:=0
	for i in range(0,aa.size(),4):
		if aa[i]!=bb[i] or aa[i+1]!=bb[i+1] or aa[i+2]!=bb[i+2]:count+=1
	return count
func run()->void:
	output=OS.get_environment("YARDSCAPE_DAB_BATCH_OUTPUT");run_id=OS.get_environment("YARDSCAPE_DAB_BATCH_RUN_ID")
	if run_id.length()!=36 or not output.begins_with(ProjectSettings.globalize_path("res://.local/")):push_error("Fresh batch output required");quit(1);return
	root.size=Vector2i(1280,900);study=load("res://northstar-batched-dab-value-tree.tscn").instantiate();root.add_child(study);for i in 3:await process_frame
	check(study is Current,"exact batched opt-in scene")
	check(study.dab_tree.stats.visible_triangles==6516 and study.batched_tree.stats.visible_triangles==6516,"batching preserves exact indexed triangle count")
	check(study.dab_tree.stats.visible_meshes==33 and study.batched_tree.stats.visible_meshes==2,"visible mesh instances reduce from 33 to 2")
	check(study.batched_tree.descriptor==study.document.tree,"batched tree uses exact source record")
	check(not study.batched_tree.stats.alpha_blended,"batched foliage remains opaque")
	var signature:String=study.batched_tree.geometry_signature();var source_hash:=JSON.stringify(study.document.tree,"",true,true).sha256_text()
	plan();var plan_regular:=await capture("01-plan-regular",false);var plan_batch:=await capture("02-plan-batched",true);diagnostics["plan_changed_pixels"]=changed_pixels(plan_regular,plan_batch)
	courtyard();var courtyard_regular:=await capture("03-courtyard-regular",false);var courtyard_batch:=await capture("04-courtyard-batched",true);diagnostics["courtyard_changed_pixels"]=changed_pixels(courtyard_regular,courtyard_batch)
	close(.55,.28,7.2);var front_regular:=await capture("05-front-regular",false);var front_batch:=await capture("06-front-batched",true);diagnostics["front_changed_pixels"]=changed_pixels(front_regular,front_batch)
	close(.55+PI,.28,7.2);var reverse_regular:=await capture("07-reverse-regular",false);var reverse_batch:=await capture("08-reverse-batched",true);diagnostics["reverse_changed_pixels"]=changed_pixels(reverse_regular,reverse_batch)
	close(.55,1.49,8.,true);var top_regular:=await capture("09-top-regular",false);var top_batch:=await capture("10-top-batched",true);diagnostics["top_changed_pixels"]=changed_pixels(top_regular,top_batch)
	close(.55,.28,7.2);study._choose("Afternoon");var afternoon:=await capture("11-afternoon-batched",true);check(digest(afternoon)!=digest(front_batch),"batched tree responds to actual scene sun")
	study._choose("Morning");var morning:=await capture("12-morning-return",true);check(digest(morning)==digest(front_batch),"morning batched image returns exactly")
	check(study.batched_tree.geometry_signature()==signature,"camera/light changes never regenerate batched geometry")
	check(JSON.stringify(study.document.tree,"",true,true).sha256_text()==source_hash,"source tree record remains unchanged")
	var report:Dictionary={"run_id":run_id,"passed":failures.is_empty(),"checks":checks,"failures":failures,"pixel_hashes":hashes,"diagnostics":diagnostics,"regular":study.dab_tree.stats,"batched":study.batched_tree.stats,"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"scope":"appearance and invariant comparison of exact retained hierarchy-value tree before/after two-mesh batching","tablet_performance_tested":false,"artistic_acceptance":"not_evaluated"}
	var f:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE);if f==null:push_error("Cannot write report");quit(1);return
	f.store_string(JSON.stringify(report,"  "));f.close();study.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
