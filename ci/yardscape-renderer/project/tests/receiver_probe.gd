extends SceneTree
## Public synthetic component probe, not the private application's scene suite.
const Leaf = preload("res://presentation/northstar/regions/broadleaf_receiver.gd")
const PreviousLeaf = preload("res://presentation/northstar/regions/broadleaf.gd")
const Context = preload("res://presentation/northstar/regions/planting_context.gd")
var checks: Array = []
var failures: Array = []
var hashes: Dictionary = {}
var diagnostics: Dictionary = {}
var view: SubViewport
var output: String
var run_id: String

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks.append({"name":label,"passed":ok})
	if not ok: failures.append(label)

func snapshot(name: String) -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	hashes[name] = image.get_data().hex_encode().sha256_text()
	check(image.save_png(output.path_join(name+".png")) == OK,"capture "+name)
	return image

func same(a: Image,b: Image) -> bool:
	return a.get_size() == b.get_size() and a.get_data() == b.get_data()

func difference(a: Image,b: Image) -> Dictionary:
	var aa := a.get_data()
	var bb := b.get_data()
	var alpha := 0
	var rgb := 0
	var maximum := 0
	var covered := 0
	var luma_delta := 0.0
	for i in range(0,aa.size(),4):
		if aa[i+3] != bb[i+3]: alpha += 1
		var changed := false
		for c in 3:
			var d := absi(int(aa[i+c])-int(bb[i+c]))
			maximum = maxi(maximum,d)
			if d>0: changed = true
		if changed: rgb += 1
		if aa[i+3]>128:
			covered += 1
			luma_delta += (float(bb[i])+bb[i+1]+bb[i+2]-aa[i]-aa[i+1]-aa[i+2])/765.0
	return {"alpha_changed":alpha,"rgb_changed":rgb,"max_channel":maximum,
		"covered":covered,"mean_luma_delta":luma_delta/maxi(1,covered)}

func caster() -> Dictionary:
	return {"id":"synthetic-crown","at":Vector2(.45,-.30),"radius":1.10,
		"height":1.8,"seed":37.0,"family":0,
		"lobes":PackedVector4Array([Vector4(0,0,.72,0),Vector4(.32,.18,.42,0)])}

func place(node: Node2D) -> void:
	node.position = Vector2(256,256)
	node.scale = Vector2(210,210)
	view.add_child(node)

func run() -> void:
	output = OS.get_environment("YARDSCAPE_PUBLIC_OUTPUT")
	run_id = OS.get_environment("YARDSCAPE_PUBLIC_RUN_ID")
	if run_id.length()!=36 or not output.begins_with(ProjectSettings.globalize_path("res://.local/")):
		push_error("Fresh isolated public output required");quit(1);return
	view = SubViewport.new()
	view.size = Vector2i(512,512)
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var record: Array = ["public-leaf-A",0.0,24.0,1.0,.6,"broadleaf","green"]
	var morning := Vector2(-.7,-.7).normalized()
	var afternoon := Vector2(.8,-.6).normalized()
	var leaf := Leaf.new()
	leaf.setup(record)
	leaf.apply_appearance(false,morning)
	place(leaf)
	var old := PreviousLeaf.new()
	old.setup(record)
	old.apply_appearance(false,morning)
	old.visible = false
	place(old)
	var geometry: String = leaf.form_identity()
	check(geometry == old.form_identity(),"candidate preserves predecessor geometry and identity")
	var receiver: Dictionary = leaf.receiver_descriptor()
	check(receiver.receiver_only and receiver.lobes.is_empty(),"receiver has no casting silhouette")
	var records: Array = [receiver,caster()]
	var context: Dictionary = Context.build(records,morning,.35)
	check(context.ok,"synthetic receiver context builds")
	if not context.ok: finish();return
	check(context.receivers[receiver.id].count == 1,"one supported higher crown shades leaf")
	check(context.receivers["synthetic-crown"].count == 0,"receiver never becomes a caster")
	var bad: Dictionary = receiver.duplicate(true)
	bad.receiver_only = "yes"
	check(not Context.build([bad],morning,.35).ok,"invalid receiver flag is rejected")
	bad = receiver.duplicate(true)
	bad.erase("receiver_only")
	check(not Context.build([bad],morning,.35).ok,"empty ordinary caster silhouette is rejected")
	check(not Context.build(records,Vector2.ZERO,.35).ok,"zero sunlight vector is rejected")
	leaf.apply_received_shade(context.receivers[receiver.id],false)
	var off := await snapshot("01-shade-off")
	var generation: int = leaf.draw_generation
	var material_id: int = leaf.material.get_instance_id()
	leaf.apply_received_shade(context.receivers[receiver.id],true)
	var on := await snapshot("02-shade-on")
	var delta := difference(off,on)
	diagnostics["off_on"] = delta
	check(delta.rgb_changed>1000,"shade visibly changes covered color pixels")
	check(delta.mean_luma_delta<-.01,"shade darkens leaf rather than repainting bright marks")
	check(delta.alpha_changed == 0,"all alpha samples remain exact through shade toggle")
	check(leaf.draw_generation == generation,"uniform-only toggle does not rebuild paint")
	check(leaf.form_identity() == geometry,"shade preserves exact deterministic blade geometry")
	var holes := 0
	var inside := 0
	for y in range(46,466):
		for x in range(46,466):
			if Vector2(x-256,y-256).length()<205.0:
				inside += 1
				if off.get_pixel(x,y).a == 0: holes += 1
	diagnostics["transparent_samples_inside_nominal_radius"] = holes
	check(holes>inside/5,"real open gaps remain inside nominal radius")
	leaf.apply_received_shade(context.receivers[receiver.id],false)
	check(same(off,await snapshot("03-off-restored")),"shade-off restores exact predecessor-material pixels")
	leaf.visible = false
	old.visible = true
	check(same(off,await snapshot("04-original-leaf")),"zero-neighbor candidate matches original leaf shader")
	old.visible = false
	leaf.visible = true
	for i in 6:
		leaf.apply_received_shade(context.receivers[receiver.id],true)
		leaf.apply_received_shade(context.receivers[receiver.id],false)
	check(same(off,await snapshot("05-toggle-return")),"repeated uniform toggles restore exact image")
	check(leaf.material.get_instance_id() == material_id,"toggles preserve material object")
	check(view.get_child_count() == 2,"toggles do not accumulate scene nodes")
	leaf.apply_received_shade(context.receivers[receiver.id],true)
	leaf.position += Vector2(35,22)
	leaf.scale = Vector2(160,160)
	await snapshot("06-pan-zoom")
	leaf.position = Vector2(256,256)
	leaf.scale = Vector2(210,210)
	check(same(on,await snapshot("07-view-return")),"camera transform return restores exact shaded image")
	leaf.apply_appearance(false,afternoon)
	var alternate: Dictionary = Context.build(records,afternoon,.35)
	check(alternate.ok,"changed-sun context builds")
	leaf.apply_received_shade(alternate.receivers[receiver.id],true)
	var afternoon_image := await snapshot("08-afternoon")
	check(not same(on,afternoon_image),"sun change visibly updates leaf shading")
	check(difference(on,afternoon_image).alpha_changed == 0,"sun change preserves leaf coverage")
	leaf.apply_appearance(false,morning)
	leaf.apply_received_shade(context.receivers[receiver.id],true)
	check(same(on,await snapshot("09-light-return")),"sun return restores exact shaded image")
	check(leaf.form_identity() == geometry,"all navigation and light changes preserve geometry")
	leaf.batched_ink = false
	leaf.invalidate_media()
	var native_image := await snapshot("10-native-strokes")
	var parity := difference(on,native_image)
	diagnostics["native_mesh"] = parity
	check(parity.max_channel<=1,"native and batched stroke color agreement within one channel")
	leaf.batched_ink = true
	leaf.invalidate_media()
	check(same(on,await snapshot("11-cache-rebuilt")),"discarding media caches reproduces exact shaded image")
	leaf.apply_appearance(true,morning)
	leaf.apply_received_shade(context.receivers[receiver.id],true)
	var technical := await snapshot("12-technical-on")
	leaf.apply_received_shade(context.receivers[receiver.id],false)
	check(same(technical,await snapshot("13-technical-off")),"received shade cannot affect Technical pixels")
	leaf.visible = false
	old.apply_appearance(true,morning)
	old.visible = true
	check(same(technical,await snapshot("14-technical-original")),"Technical image matches retained original")
	check(leaf.form_identity() == geometry,"Technical toggles preserve stored blade forms")
	for i in 6:
		var r: Array = ["synthetic-seed-%d"%i,0.0,24.0,[.4,.8,1.6][i%3],.8,"broadleaf","green"]
		var a := Leaf.new();a.setup(r)
		var b := Leaf.new();b.setup(r)
		check(a.form_identity() == b.form_identity(),"deterministic seed-size case %d"%i)
		var valid := true
		for blade in a.blades:
			if Geometry2D.triangulate_polygon(blade.points).is_empty():valid=false
			for point in blade.points:
				if not point.is_finite() or point.length()>a.radius:valid=false
		check(valid,"finite bounded triangulated leaf case %d"%i)
		a.free();b.free()
	finish()

func finish() -> void:
	var report := {"run_id":run_id,"kind":"public synthetic receiving-shade component probe",
		"passed":failures.is_empty(),"checks":checks,"failures":failures,"pixel_hashes":hashes,
		"diagnostics":diagnostics,"engine":Engine.get_version_info().string,
		"adapter":RenderingServer.get_video_adapter_name(),"artistic_acceptance":"not_evaluated",
		"limits":["Synthetic isolated generic leaf, not the app's whole courtyard",
		"Not the six private scene regression suites","Not shared Plan/3D integration",
		"No tablet, frame-time, horticultural, or visual acceptance claim"]}
	var f := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	if f == null:push_error("Cannot retain report");quit(1);return
	f.store_string(JSON.stringify(report,"  "));f.close()
	print("Public component checks: ",checks.size()," failures: ",failures.size())
	quit(0 if failures.is_empty() else 1)
