extends SceneTree
const Current=preload("res://presentation/northstar/spatial_group_study.gd")
const Group=preload("res://presentation/northstar/foliage/compact_group.gd")
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
	check(image.save_png(output.path_join(name+".png"))==OK,"capture "+name)
	hashes[name]=digest(image)
	for pair in layers:pair[0].visible=pair[1]
	return image
func set_group_view(yaw_value:float,pitch_value:float,distance_value:float,orthographic:bool=false)->void:
	study.target=study.group.position+Vector3(0,.08,0)
	study.plan_locked=false;study.perspective=not orthographic
	study.yaw=yaw_value;study.pitch=pitch_value;study.distance=distance_value
	study._update_camera()
func geometry_valid(group)->Dictionary:
	var bad:=0;var nonunit:=0;var vertices:=0;var triangles:=0
	for node in [group.twig,group.foliage]:
		var a:Array=node.mesh.surface_get_arrays(0)
		vertices+=a[Mesh.ARRAY_VERTEX].size();triangles+=int(a[Mesh.ARRAY_INDEX].size()/3)
		for p in a[Mesh.ARRAY_VERTEX]:
			if not p.is_finite():bad+=1
		for n in a[Mesh.ARRAY_NORMAL]:
			if not n.is_finite() or absf(n.length()-1.)>.002:nonunit+=1
		for index in a[Mesh.ARRAY_INDEX]:
			if index<0 or index>=a[Mesh.ARRAY_VERTEX].size():bad+=1
	return {"bad":bad,"nonunit":nonunit,"vertices":vertices,"triangles":triangles}
func run()->void:
	output=OS.get_environment("YARDSCAPE_GROUP_OUTPUT");run_id=OS.get_environment("YARDSCAPE_GROUP_RUN_ID")
	if run_id.length()!=36 or not output.begins_with(ProjectSettings.globalize_path("res://.local/")):
		push_error("Fresh isolated output required");quit(1);return
	root.size=Vector2i(1280,900)
	study=load("res://northstar-foliage-group.tscn").instantiate();root.add_child(study)
	for i in 3:await process_frame
	check(study is Current and study.study_ready,"compact group runs in retained spatial material courtyard")
	check(study.group.descriptor.seed==int(study.document.tree.seed),"group retains deterministic source seed")
	var validity:=geometry_valid(study.group);diagnostics["geometry"]=validity
	check(validity.bad==0 and validity.nonunit==0,"finite indexed geometry with unit final-mesh normals")
	check(validity.triangles<1200,"compact group stays below 1200 indexed triangles")
	check(study.group.stats.subforms==11 and study.group.stats.mesh_surfaces==2,"eleven interleaved forms plus one twig surface")
	check(not study.group.stats.alpha_blended,"foliage uses closed opaque geometry, not alpha cards")
	var aabb:AABB=study.group.foliage.mesh.get_aabb().merge(study.group.twig.mesh.get_aabb())
	diagnostics["aabb"]={"position":[aabb.position.x,aabb.position.y,aabb.position.z],"size":[aabb.size.x,aabb.size.y,aabb.size.z]}
	check(aabb.size.x<study.group.descriptor.radius*1.65 and aabb.size.z<study.group.descriptor.radius*1.65,"group remains compact inside bounded crown fraction")
	check(aabb.position.y>-.08 and aabb.end.y<study.group.descriptor.height*.90,"group stays vertically compact around branch tip")
	var signature:String=study.group.geometry_signature()
	var clone:=Group.new();clone.configure(study.group.descriptor.seed,study.group.descriptor.radius,study.group.descriptor.height)
	check(clone.geometry_signature()==signature,"same seed and dimensions reproduce exact group")
	var alternate:=Group.new();alternate.configure(study.group.descriptor.seed+1,study.group.descriptor.radius,study.group.descriptor.height)
	check(alternate.geometry_signature()!=signature,"alternate seed changes local orientation without changing grammar")
	clone.free();alternate.free()
	study._choose("Plan");await capture("01-courtyard-plan")
	study._choose("Orbit");study._choose("Perspective");await capture("02-courtyard-oblique")
	set_group_view(.55,.34,4.4);var front:=await capture("03-group-front")
	set_group_view(.55+PI,.34,4.4);await capture("04-group-reverse")
	set_group_view(.55+PI*.5,.46,4.4);await capture("05-group-quarter")
	set_group_view(.55,1.49,5.0,true)
	study.camera.position=study.target+Vector3.UP*6.;study.camera.look_at(study.target,Vector3(0,0,-1))
	await capture("06-group-top")
	set_group_view(.55,.34,4.4)
	study._choose("Afternoon");var afternoon:=await capture("07-afternoon")
	check(digest(afternoon)!=digest(front),"sun change visibly relights the same group")
	study._choose("Morning");check(digest(front)==digest(await capture("08-morning-return")),"morning return restores exact group image")
	var flags:Array=[]
	for node in study.derived.get_children():flags.append(node.visible);node.visible=node==study.group
	var old_bg:Color=study.environment.background_color;study.environment.background_color=Color.BLACK
	var white:=StandardMaterial3D.new();white.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;white.albedo_color=Color.WHITE
	var twig_mat=study.group.twig.material_override;var foliage_mat=study.group.foliage.material_override
	study.group.twig.material_override=white;study.group.foliage.material_override=white
	set_group_view(.55,.34,4.4);await capture("09-silhouette-front")
	set_group_view(.55+PI,.34,4.4);await capture("10-silhouette-reverse")
	study.group.twig.material_override=twig_mat;study.group.foliage.material_override=foliage_mat
	study.environment.background_color=old_bg
	var i:=0
	for node in study.derived.get_children():node.visible=flags[i];i+=1
	check(study.group.geometry_signature()==signature,"all camera/light/material review leaves group geometry exact")
	var report:Dictionary={"run_id":run_id,"passed":failures.is_empty(),"checks":checks,"failures":failures,
		"pixel_hashes":hashes,"diagnostics":diagnostics,"candidate":study.group.stats,
		"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),
		"scope":"one compact generic foliage group in existing spatial material courtyard",
		"species_claimed":false,"whole_tree_tested":false,"tablet_performance_tested":false,"artistic_acceptance":"not_evaluated"}
	var f:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	if f==null:push_error("Cannot write report");quit(1);return
	f.store_string(JSON.stringify(report,"  "));f.close()
	study.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
