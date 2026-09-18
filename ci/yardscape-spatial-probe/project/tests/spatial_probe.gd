extends SceneTree
const Current = preload("res://presentation/northstar/spatial_material_study.gd")
const Baseline = preload("res://presentation/northstar/spatial_study.gd")
var study
var output: String
var run_id: String
var checks: Array = []
var failures: Array = []
var hashes: Dictionary = {}
var diagnostics: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"passed":ok})
	if not ok: failures.append(label)
func semantic() -> String: return JSON.stringify(study.document,"",true,true).sha256_text()
func geometry() -> String:
	var data: Array = []
	for node in study.derived.get_children():
		if node is MeshInstance3D:
			var surfaces: Array = []
			for i in node.mesh.get_surface_count(): surfaces.append(node.mesh.surface_get_arrays(i))
			data.append([str(node.name),node.transform,node.mesh.get_aabb(),surfaces])
	return var_to_bytes(data).hex_encode().sha256_text()
func objects() -> Array:
	var data: Array = [study.derived.get_instance_id(),study.camera.get_instance_id(),study.sun.get_instance_id()]
	for n in study.derived.get_children():
		data.append([n.get_instance_id(),n.mesh.get_instance_id()])
	return data
func unrelated_materials() -> Array:
	var data: Array = []
	for n in study.derived.get_children():
		var id:=str(n.name)
		if id in ["lawn","bed","bed-rim","tree-trunk","boundary-wall","lamp-head","lamp-post"] or id.begins_with("crown-"):
			data.append([id,n.material_override.get_instance_id()])
	return data
func camera_state() -> Array:
	return [study.camera.transform,study.camera.projection,study.camera.size,study.target,study.plan_locked,study.perspective]
func image_hash(image: Image) -> String: return image.get_data().hex_encode().sha256_text()
func grab(name: String) -> Image:
	var layers: Array = []
	for child in study.get_children():
		if child is CanvasLayer:
			layers.append([child,child.visible]);child.visible = false
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image();image.convert(Image.FORMAT_RGBA8)
	check(image.save_png(output.path_join(name+".png"))==OK,"capture "+name)
	hashes[name]=image_hash(image)
	for pair in layers: pair[0].visible=pair[1]
	return image
func sample(image: Image,point: Vector3) -> Color:
	var pixel: Vector2 = study.camera.unproject_position(point)
	return image.get_pixel(clampi(roundi(pixel.x),0,image.get_width()-1),clampi(roundi(pixel.y),0,image.get_height()-1))
func avg(c: Color) -> float: return (c.r+c.g+c.b)/3.
func diff(a: Image,b: Image) -> int:
	var aa:=a.get_data();var bb:=b.get_data();var count:=0
	for i in range(0,aa.size(),4):
		if aa[i]!=bb[i] or aa[i+1]!=bb[i+1] or aa[i+2]!=bb[i+2]: count+=1
	return count
func press_m() -> void:
	var e:=InputEventKey.new();e.keycode=KEY_M;e.pressed=true
	Input.parse_input_event(e);await process_frame
	e=InputEventKey.new();e.keycode=KEY_M;e.pressed=false
	Input.parse_input_event(e);await process_frame
func run() -> void:
	output=OS.get_environment("YARDSCAPE_SPATIAL_OUTPUT")
	run_id=OS.get_environment("YARDSCAPE_SPATIAL_RUN_ID")
	if run_id.length()!=36 or not output.begins_with(ProjectSettings.globalize_path("res://.local/")):
		push_error("Isolated output required");quit(1);return
	root.size=Vector2i(1280,900)
	var scene=load("res://northstar-spatial-materials.tscn")
	study=scene.instantiate();root.add_child(study)
	for i in 3: await process_frame
	check(study is Current and study.study_ready,"opt-in material scene initializes over shared spatial renderer")
	check(study.plan_locked and not study.perspective,"initial view is orthographic Plan")
	check(study.derived.get_child_count()==29,"same 29 spatial meshes, including real pool shell and structural tree")
	var original_document: Dictionary = study.document.duplicate(true)
	var semantic_start:=semantic();var geometry_start:=geometry();var nodes_start:=objects();var untouched:=unrelated_materials()
	var builds_start: int = study.build_count
	var plan_camera:=camera_state()
	study.set_materials_enabled(false)
	var plan_off:=await grab("01-plan-baseline")
	await press_m()
	check(study.materials_enabled,"real M input enables material candidate")
	var plan_on:=await grab("02-plan-materials")
	var plan_changed:=diff(plan_off,plan_on);diagnostics["plan_changed_color_pixels"]=plan_changed
	check(plan_changed>10000,"candidate changes visible water and paving in Plan")
	check(semantic()==semantic_start and geometry()==geometry_start,"material change preserves exact semantic data and all mesh arrays")
	check(objects()==nodes_start and study.build_count==builds_start,"material toggle preserves all mesh/node identities without rebuilding")
	check(unrelated_materials()==untouched,"lawn, proxy plants, wall and lamp materials unchanged")
	var pool: Dictionary = study.document.pool
	var shallow:=sample(plan_on,Vector3(pool.x+pool.width*.45,pool.shelf_elevation,-(pool.y+.65)))
	var deep:=sample(plan_on,Vector3(pool.x+pool.width*.45,pool.floor_elevation,-(pool.y+3.5)))
	diagnostics["shallow_rgb"]=[shallow.r,shallow.g,shallow.b];diagnostics["deep_rgb"]=[deep.r,deep.g,deep.b]
	check(avg(shallow)>avg(deep)+.04,"actual shallow shelf sample reads lighter than deeper floor")
	study.set_material_groups(false,true)
	var paving_only:=await grab("03-paving-only")
	var pool_point:=Vector3(3.,-1.5,-8.)
	check(sample(paving_only,pool_point)==sample(plan_off,pool_point),"paving-only group leaves chosen basin sample exact")
	study.set_material_groups(true,false)
	var water_only:=await grab("04-water-only")
	var deck_point:=Vector3(.7,.2,-7.)
	check(sample(water_only,deck_point)==sample(plan_off,deck_point),"water-only group leaves chosen paving sample exact")
	study.set_material_groups(true,true)
	check(image_hash(plan_on)==image_hash(await grab("05-groups-return")),"independent material groups restore exact Plan")
	study._choose("Orbit");study._choose("Perspective")
	check(not study.plan_locked and study.perspective,"retained Orbit/Perspective controls select real perspective camera")
	var orbit_state:=camera_state()
	study.set_materials_enabled(false)
	var orbit_off:=await grab("06-orbit-baseline")
	study.set_materials_enabled(true)
	var orbit_on:=await grab("07-orbit-materials")
	check(diff(orbit_off,orbit_on)>10000,"same 3D meshes show candidate from oblique perspective")
	check(geometry()==geometry_start and semantic()==semantic_start,"projection switch does not change project or spatial meshes")
	study._choose("Plan")
	check(camera_state()==plan_camera,"Plan return restores exact prior camera and scale")
	check(image_hash(plan_on)==image_hash(await grab("08-plan-return")),"Plan return restores exact material image")
	study._choose("Orbit")
	check(camera_state()==orbit_state,"Orbit return restores previous perspective framing")
	check(image_hash(orbit_on)==image_hash(await grab("09-orbit-return")),"Orbit return restores exact material image")
	study._choose("Afternoon")
	var afternoon:=await grab("10-afternoon")
	check(diff(orbit_on,afternoon)>1000,"real spatial sun change alters shading")
	study._choose("Night")
	var night:=await grab("11-night")
	check(diff(orbit_on,night)>1000,"night lighting affects lit materials rather than a frozen illustration")
	check(not study.sun.visible and study.lamp.visible,"night uses existing local lamp with directional light disabled")
	study._choose("Morning")
	check(image_hash(orbit_on)==image_hash(await grab("12-sun-return")),"Morning return restores exact spatial material image")
	var yaw_start: float=study.yaw;var pitch_start: float=study.pitch
	var material_ids: Array=[]
	for id in study._style_materials: material_ids.append(study._style_materials[id].get_instance_id())
	for i in 16:
		study.yaw=yaw_start+TAU*float(i)/16.
		study.pitch=.85+.12*sin(TAU*float(i)/16.)
		study._update_camera()
		await grab("orbit-%02d"%i)
	check(semantic()==semantic_start and geometry()==geometry_start and objects()==nodes_start,"sampled full orbit changes no scene/project geometry")
	var after_ids: Array=[]
	for id in study._style_materials: after_ids.append(study._style_materials[id].get_instance_id())
	check(after_ids==material_ids and study.build_count==builds_start,"sampled orbit reuses all style materials with no regeneration")
	study.yaw=yaw_start;study.pitch=pitch_start;study._update_camera()
	check(image_hash(orbit_on)==image_hash(await grab("13-motion-return")),"sampled orbit return restores exact image")
	study._choose("Water")
	var exposed:=await grab("14-surface-hidden")
	check(not study.derived.get_node("Water").visible and diff(exposed,orbit_on)>0,"water visibility control exposes the actual submerged geometry")
	study._choose("Water")
	check(image_hash(orbit_on)==image_hash(await grab("15-water-return")),"surface visibility return is exact")
	study._choose("Plan")
	# Explicit test fixture resize/rebuild. This is NOT the private edit/undo path.
	study.document=original_document.duplicate(true);study.document.pool.width=4.25
	study._build();study._update_camera()
	check(study.derived.get_node("pool-floor").mesh.size.x==4.25 and study.derived.get_node("Water").mesh.size.x==4.25,"display resize rebuild preserves shared pool/water width")
	check(study.derived.get_node("coping-east").material_override is ShaderMaterial,"style rebinds after fixture geometry rebuild")
	await grab("16-fixture-width-change")
	study.document=original_document.duplicate(true);study._build();study._update_camera()
	check(geometry()==geometry_start and semantic()==semantic_start,"restoring synthetic fixture rebuilds exact original geometry")
	check(image_hash(plan_on)==image_hash(await grab("17-rebuild-return")),"restored geometry and materials reproduce original Plan image")
	study.set_materials_enabled(false)
	check(image_hash(plan_off)==image_hash(await grab("18-baseline-return")),"materials OFF restores original baseline after all changes")
	study.queue_free();await process_frame;await process_frame
	study=Baseline.new();root.add_child(study)
	for i in 3:await process_frame
	var pristine:=await grab("19-pristine-baseline")
	check(image_hash(pristine)==image_hash(plan_off),"disabled candidate matches separate untouched baseline renderer on same display adapter")
	var report: Dictionary={"run_id":run_id,"scope":"Shared spatial renderer and candidate materials over synthetic display adapter","passed":failures.is_empty(),"checks":checks,"failures":failures,"pixel_hashes":hashes,"diagnostics":diagnostics,"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"initial_semantic_hash":semantic_start,"initial_mesh_hash":geometry_start,"private_edit_undo_save_tested":false,"continuous_temporal_stability":"16 sampled orbit poses and exact return only","tablet_performance_tested":false,"artistic_acceptance":"not_evaluated"}
	var file:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	if file==null:push_error("Cannot retain report");quit(1);return
	file.store_string(JSON.stringify(report,"  "));file.close()
	print("Spatial checks: ",checks.size()," failures: ",failures)
	study.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
