extends SceneTree
## Display-only whole-plan probe using exact region/control classes over a
## declared synthetic geometry adapter. Not the application's persistence suite.
const Current = preload("res://presentation/northstar/regions/broadleaf_shade_study.gd")
const Previous = preload("res://presentation/northstar/regions/broadleaf_study.gd")
const Leaf = preload("res://presentation/northstar/regions/broadleaf_receiver.gd")
const Fixture = preload("res://presentation/northstar/fixture.gd")
var checks: Array=[]
var failures: Array=[]
var hashes: Dictionary={}
var diagnostics: Dictionary={}
var view: SubViewport
var paper: ColorRect
var out: String
var run_id: String

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"passed":ok})
	if not ok:failures.append(label)

func digest(image: Image) -> String:
	return image.get_data().hex_encode().sha256_text()

func capture(world: Node2D,name: String,scale_value: float=50.,at: Vector2=Vector2(160,170)) -> Image:
	var parent:=world.get_parent()
	var index:=world.get_index()
	var old_position:=world.position
	var old_scale:=world.scale
	world.reparent(view,false);world.position=at;world.scale=Vector2.ONE*scale_value
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image:=view.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	hashes[name]=digest(image)
	check(image.save_png(out.path_join(name+".png"))==OK,"capture "+name)
	world.reparent(parent,false);parent.move_child(world,index)
	world.position=old_position;world.scale=old_scale
	return image

func key_press(code: Key) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.pressed=true
	Input.parse_input_event(event);await process_frame
	event=InputEventKey.new();event.keycode=code;event.pressed=false
	Input.parse_input_event(event);await process_frame

func identity(study) -> String:
	var data: Array=[Fixture.plants(),Fixture.surfaces()]
	for paint in study.paints:data.append([paint.node.polygon,paint.node.position])
	for plant in study.plants:
		if plant is Leaf:data.append([plant.identifier,plant.position,plant.radius,plant.cast_height,plant.form_identity()])
	return var_to_bytes(data).hex_encode().sha256_text()

func objects(study) -> Array:
	var data: Array=[]
	for child in study.world.get_children():data.append(child.get_instance_id())
	for paint in study.paints:data.append(paint.material.get_instance_id())
	for plant in study.plants:
		if plant is Leaf:data.append(plant.material.get_instance_id())
	return data

func generations(study) -> Array:
	var data: Array=[]
	for plant in study.plants:
		if plant is Leaf:data.append(plant.draw_generation)
	return data

func delta(a: Image,b: Image,mask: Image=null) -> Dictionary:
	var aa:=a.get_data();var bb:=b.get_data()
	var mm:=mask.get_data() if mask!=null else PackedByteArray()
	var changed:=0;var escaped:=0;var alpha:=0;var maximum:=0
	for i in range(0,aa.size(),4):
		var different:=false
		for c in 3:
			var d:=absi(int(aa[i+c])-int(bb[i+c]));maximum=maxi(maximum,d)
			if d>0:different=true
		if different:
			changed+=1
			if not mm.is_empty() and mm[i+3]==0:escaped+=1
		if aa[i+3]!=bb[i+3]:alpha+=1
	return {"changed_color_pixels":changed,"outside_leaf_coverage":escaped,"changed_alpha_samples":alpha,"max_channel":maximum}

func leaf_mask(study,name: String) -> Image:
	var flags: Array=[]
	for child in study.world.get_children():
		flags.append(child.visible);child.visible=child is Leaf
	paper.visible=false;view.transparent_bg=true
	var image:=await capture(study.world,name)
	var i:=0
	for child in study.world.get_children():child.visible=flags[i];i+=1
	paper.visible=true;view.transparent_bg=false
	return image

func pool_delta(study,a: Image,b: Image) -> int:
	var points:=PackedVector2Array()
	for p in study.paints:
		if p.kind==2:
			for v in p.node.polygon:points.append((v+p.node.position)*50.+Vector2(160,170))
	var changed:=0
	var bounds:=Rect2(points[0],Vector2.ZERO)
	for p in points:bounds=bounds.expand(p)
	for y in range(floori(bounds.position.y),ceili(bounds.end.y)):
		for x in range(floori(bounds.position.x),ceili(bounds.end.x)):
			if Geometry2D.is_point_in_polygon(Vector2(x+.5,y+.5),points) and a.get_pixel(x,y)!=b.get_pixel(x,y):changed+=1
	return changed

func run() -> void:
	run_id=OS.get_environment("YARDSCAPE_PUBLIC_RUN_ID")
	out=OS.get_environment("YARDSCAPE_REGION_OUTPUT")
	if run_id.length()!=36 or not out.begins_with(ProjectSettings.globalize_path("res://.local/")):
		push_error("Fresh isolated plan output required");quit(1);return
	view=SubViewport.new();view.size=Vector2i(1120,1560);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	paper=ColorRect.new();paper.color=Color("f4f3ec");paper.size=view.size;view.add_child(paper)
	var scene=load("res://northstar-regions.tscn")
	var study=scene.instantiate();root.add_child(study)
	await process_frame;await process_frame
	check(study is Current,"scene entrypoint uses actual receiving-shade orchestration")
	check(study.broadleaf_receiving and study.receiving_shade and study.grouped_broadleaf,"current U O B defaults")
	check(study.plants.size()==Fixture.plants().size(),"complete synthetic planting arrangement instantiated")
	check(study.paints.size()==10,"all ten synthetic display surfaces present")
	var ids: Array=[]
	for p in study.plants:
		if p is Leaf:ids.append(p.identifier)
	check(ids.size()==7,"all seven original-layout broadleaves are receivers")
	var initial:=identity(study)
	var on:=await capture(study.world,"01-plan-shade-on")
	var middle:=await capture(study.world,"02-middle-shade-on",200.,Vector2(-1600,-1400))
	await capture(study.world,"03-west-shade-on",225.,Vector2(225,-1970))
	var context_hash: String=study.broadleaf_context.identity
	var builds: int=study.broadleaf_context_builds
	var original_nodes:=objects(study)
	var mask_on:=await leaf_mask(study,"04-leaf-coverage-on")
	# Screenshot capture reparents the canvas and may reissue cached draw commands.
	# Observe U in place after those transitions have settled, not across captures.
	await process_frame;await process_frame
	var stationary_before:=generations(study)
	await process_frame;await process_frame
	check(generations(study)==stationary_before,"idle frames do not rebuild retained blade paint")
	await key_press(KEY_U)
	var stationary_after:=generations(study)
	check(stationary_after==stationary_before,"U alone does not rebuild retained blade paint")
	diagnostics["stationary_U_generations"]={"before":stationary_before,"after":stationary_after}
	check(not study.broadleaf_receiving,"injected U dispatch turns leaf shade off")
	var off:=await capture(study.world,"05-plan-shade-off")
	await capture(study.world,"06-middle-shade-off",200.,Vector2(-1600,-1400))
	await capture(study.world,"07-west-shade-off",225.,Vector2(225,-1970))
	var mask_off:=await leaf_mask(study,"08-leaf-coverage-off")
	var difference:=delta(off,on,mask_off);diagnostics["plan_off_on"]=difference
	check(difference.changed_color_pixels>0,"received shade changes actual whole-plan overlap pixels")
	check(difference.outside_leaf_coverage==0,"every changed scene pixel is within actual broadleaf coverage")
	check(delta(mask_off,mask_on).changed_alpha_samples==0,"all seven leaves retain exact alpha including gaps")
	var pool_changed:=pool_delta(study,off,on);diagnostics["pool_pixels_changed"]=pool_changed
	check(pool_changed==0,"all sampled pool-interior pixels remain exact")
	check(identity(study)==initial,"shade toggle preserves fixed polygons and plant geometry")
	check(objects(study)==original_nodes,"shade toggle preserves scene nodes and all material identities")
	diagnostics["generations_after_capture_sequence"]=generations(study)
	check(study.broadleaf_context_builds==builds and study.broadleaf_context.identity==context_hash,"U reuses exact spatial context")
	# Same display adapter on the real predecessor class. Not a golden full-app image.
	var predecessor:=Previous.new();predecessor.size=Vector2(1280,800);root.add_child(predecessor)
	await process_frame;predecessor.set_process_input(false)
	var before:=await capture(predecessor.world,"09-predecessor-plan")
	check(digest(off)==digest(before),"U-off matches real predecessor renderer under identical adapter")
	predecessor.queue_free();await process_frame
	await key_press(KEY_U)
	check(study.broadleaf_receiving,"injected U restores leaf shade")
	check(digest(on)==digest(await capture(study.world,"10-plan-return")),"U return restores exact whole plan")
	await key_press(KEY_O)
	check(not study.receiving_shade,"injected O disables global receiving shade")
	var no_overlap:=await capture(study.world,"11-global-shade-off")
	await key_press(KEY_U)
	check(digest(no_overlap)==digest(await capture(study.world,"12-global-off-u-off")),"U cannot override disabled O")
	await key_press(KEY_U);await key_press(KEY_O)
	check(digest(on)==digest(await capture(study.world,"13-uo-return")),"U O control return restores exact whole plan")
	study._choose("Technical")
	var technical:=await capture(study.world,"14-technical-u-on")
	await key_press(KEY_U)
	check(digest(technical)==digest(await capture(study.world,"15-technical-u-off")),"U cannot alter Technical view")
	await key_press(KEY_U);study._choose("Northstar")
	study._choose("Afternoon")
	var afternoon:=await capture(study.world,"16-afternoon-plan")
	check(digest(afternoon)!=digest(on),"changed sunlight affects full plan")
	check(identity(study)==initial,"changed light preserves geometry and fixed layout")
	study._choose("Morning")
	check(digest(on)==digest(await capture(study.world,"17-morning-return")),"sun return restores exact plan")
	await capture(study.world,"18-zoomed-detail",240.,Vector2(-2000,-1800))
	check(digest(middle)==digest(await capture(study.world,"19-detail-return",200.,Vector2(-1600,-1400))),"view round trip restores exact detail")
	for key in [KEY_B,KEY_A,KEY_S,KEY_O,KEY_W,KEY_P,KEY_I,KEY_G,KEY_V,KEY_C]:
		await key_press(key);await key_press(key)
	check(digest(on)==digest(await capture(study.world,"20-all-controls-return")),"all actual inherited comparison controls restore current plan")
	check(identity(study)==initial,"all comparison returns restore source geometry")
	var count: int=study.world.get_child_count()
	for i in 4:
		await key_press(KEY_U);await key_press(KEY_U)
	check(study.world.get_child_count()==count,"repeated U toggles do not accumulate nodes")
	check(digest(on)==digest(await capture(study.world,"21-toggle-loop-return")),"repeated U loops restore exact plan")
	for p in study.plants:
		if p is Leaf:p.invalidate_media()
	check(digest(on)==digest(await capture(study.world,"22-cache-rebuilt")),"leaf cache rebuild preserves scene pixels")
	study.export_busy=true
	var guard_before: bool=study.broadleaf_receiving
	await key_press(KEY_U)
	check(study.broadleaf_receiving==guard_before,"export-busy guard rejects U input")
	study.export_busy=false
	var pos: Vector2=study.world.position;var scale_before: Vector2=study.world.scale
	await study.export_sheet()
	check(study.export_count==1 and FileAccess.file_exists(study.export_path),"actual region export writes fresh PNG")
	check(study.world.position==pos and study.world.scale==scale_before,"export restores original view transform")
	check(identity(study)==initial,"export preserves immutable fixture geometry")
	check(digest(on)==digest(await capture(study.world,"23-after-export")),"after export whole plan is unchanged")
	diagnostics["plant_count"]=study.plants.size();diagnostics["receiver_ids"]=ids
	diagnostics["receiver_sources"]= {}
	for id in ids:diagnostics.receiver_sources[id]=study.broadleaf_context.receivers[id].sources
	var report: Dictionary={"run_id":run_id,"kind":"display-only whole-plan native probe","passed":failures.is_empty(),"checks":checks,"failures":failures,"pixel_hashes":hashes,"diagnostics":diagnostics,"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"fixture_identity":initial,"artistic_acceptance":"not_accepted","limits":["Synthetic fixed polygon adapter replaces private model/projection/persistence","Region, broadleaf orchestration and shaders are exact excerpts","Actual U/O and inherited comparison paths are executed over this adapter","Not the six original application regression suites","Not shared Plan/3D integration or physical-tablet performance"]}
	var f:=FileAccess.open(out.path_join("report.json"),FileAccess.WRITE)
	if f==null:push_error("Report could not be saved");quit(1);return
	f.store_string(JSON.stringify(report,"  "));f.close()
	print("Display plan checks: ",checks.size()," failures: ",failures)
	study.queue_free();view.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
