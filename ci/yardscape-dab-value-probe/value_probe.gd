extends SceneTree
const Current=preload("res://presentation/northstar/spatial_dab_value_study.gd")
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
	var layers:Array=[]
	for c in study.get_children():
		if c is CanvasLayer:layers.append([c,c.visible]);c.visible=false
	for i in 4:await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image();image.convert(Image.FORMAT_RGBA8)
	check(image.save_png(output.path_join(name+".png"))==OK,"capture "+name);hashes[name]=digest(image)
	for pair in layers:pair[0].visible=pair[1]
	return image
func plan()->void:
	study.plan_locked=true;study.perspective=false;study.target=Vector3(5.,0.,-7.5);study.plan_size=20.;study._update_camera()
func courtyard()->void:
	study.plan_locked=false;study.perspective=true;study.target=Vector3(5.,0.,-7.);study.yaw=.55;study.pitch=.85;study.distance=22.;study._update_camera()
func close(yaw:float,pitch:float,distance:float,top:bool=false)->void:
	var t:Dictionary=study.document.tree
	study.target=Vector3(t.x,t.base_elevation+t.height*.66,-t.y);study.plan_locked=false;study.perspective=not top;study.yaw=yaw;study.pitch=pitch;study.distance=distance;study._update_camera()
	if top:
		study.camera.position=study.target+Vector3.UP*9.;study.camera.look_at(study.target,Vector3(0,0,-1))
func group_transforms()->String:
	var data:Array=[]
	for group in study.dab_tree.groups:data.append(group.transform)
	return var_to_bytes(data).hex_encode().sha256_text()
func material_ids()->Array:
	var data:Array=[]
	for group in study.dab_tree.groups:data.append(group.foliage.material_override.get_instance_id())
	return data
func values_copy()->PackedFloat32Array:return study.value_state().family.duplicate()
func value_span(values:PackedFloat32Array)->float:
	if values.is_empty():return 0.
	var low:float=values[0]
	var high:float=values[0]
	for value in values:
		low=minf(low,value);high=maxf(high,value)
	return high-low
func same_family_triplets(values:PackedFloat32Array)->bool:
	for family in 5:
		var base:float=values[family*3]
		for j in [1,2]:
			if absf(values[family*3+j]-base)>1e-6:return false
	return true
func run()->void:
	output=OS.get_environment("YARDSCAPE_DAB_VALUE_OUTPUT");run_id=OS.get_environment("YARDSCAPE_DAB_VALUE_RUN_ID")
	if run_id.length()!=36 or not output.begins_with(ProjectSettings.globalize_path("res://.local/")):
		push_error("Fresh value output required");quit(1);return
	root.size=Vector2i(1280,900);study=load("res://northstar-dab-value-tree.tscn").instantiate();root.add_child(study)
	for i in 3:await process_frame
	check(study is Current,"exact hierarchy-value opt-in scene")
	check(study.dab_tree.groups.size()==16,"retained sixteen dab groups")
	check(study.dab_tree.stats.visible_triangles==6516,"retained dab-tree geometry count")
	check(not study.dab_tree.stats.alpha_blended,"retained opaque dab geometry")
	var geometry:String=study.dab_tree.geometry_signature();var transforms:String=group_transforms();var source_hash:=JSON.stringify(study.document.tree,"",true,true).sha256_text()
	var morning_values:=values_copy();diagnostics["morning_family_values"]=morning_values
	check(same_family_triplets(morning_values),"three groups in each major branch family share one family value")
	check(value_span(morning_values)>.03,"morning produces visible branch-family value range")
	study.set_values_enabled(false);var baseline_materials:=material_ids()
	plan();var plan_base:=await capture("01-plan-baseline")
	study.set_values_enabled(true);var plan_value:=await capture("02-plan-values")
	check(digest(plan_base)!=digest(plan_value),"hierarchy values visibly change Plan")
	study.set_values_enabled(false);check(digest(plan_base)==digest(await capture("03-plan-baseline-return")),"baseline Plan returns exactly")
	study.set_values_enabled(true);courtyard();var courtyard_value:=await capture("04-courtyard-values")
	close(.55,.28,7.2);study.set_values_enabled(false);var front_base:=await capture("05-front-baseline")
	study.set_values_enabled(true);var front_value:=await capture("06-front-values")
	check(digest(front_base)!=digest(front_value),"hierarchy values visibly change front view")
	close(.55+PI,.28,7.2);study.set_values_enabled(false);var reverse_base:=await capture("07-reverse-baseline")
	study.set_values_enabled(true);var reverse_value:=await capture("08-reverse-values")
	check(digest(reverse_base)!=digest(reverse_value),"hierarchy values visibly change reverse view")
	close(.55,1.49,8.,true);study.set_values_enabled(false);var top_base:=await capture("09-top-baseline")
	study.set_values_enabled(true);var top_value:=await capture("10-top-values")
	check(digest(top_base)!=digest(top_value),"hierarchy values visibly change top view")
	study._choose("Afternoon");var afternoon_values:=values_copy();diagnostics["afternoon_family_values"]=afternoon_values
	check(var_to_bytes(morning_values)!=var_to_bytes(afternoon_values),"actual scene sun changes branch-family value organization")
	close(.55,.28,7.2);var afternoon:=await capture("11-afternoon-values")
	study._choose("Morning");var morning_return:=await capture("12-morning-return")
	check(digest(morning_return)==digest(front_value),"morning value image returns exactly")
	check(study.dab_tree.geometry_signature()==geometry and group_transforms()==transforms,"value/light comparisons preserve exact tree geometry and transforms")
	check(JSON.stringify(study.document.tree,"",true,true).sha256_text()==source_hash,"source tree record remains unchanged")
	study.set_values_enabled(false);check(material_ids()==baseline_materials,"value toggle restores exact baseline material objects")
	var report:Dictionary={"run_id":run_id,"passed":failures.is_empty(),"checks":checks,"failures":failures,"pixel_hashes":hashes,"diagnostics":diagnostics,"candidate":study.dab_tree.stats,"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"scope":"material-only five-family hierarchy value organization on exact retained dab tree","artistic_acceptance":"not_evaluated","tablet_performance_tested":false}
	var f:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	if f==null:push_error("Cannot write report");quit(1);return
	f.store_string(JSON.stringify(report,"  "));f.close();study.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
