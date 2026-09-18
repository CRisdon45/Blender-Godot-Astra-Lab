extends SceneTree
## Diagnostic only: three normal constructions x foliage shadow receipt.
## No shape, coverage, light, material-palette or application-state redesign.
var study
var crown: MeshInstance3D
var original_mesh: Mesh
var original_material: ShaderMaterial
var meshes: Array = []
var no_receive: ShaderMaterial
var white_mask: ShaderMaterial
var normal_view: ShaderMaterial
var output: String
var run_id: String
var checks: Array = []
var failures: Array = []
var hashes: Dictionary = {}
var diagnostics: Dictionary = {}
var snapshots: Dictionary = {}
const LABELS = ["A-current", "B-bend", "C-mesh"]

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks.append({"name": label, "passed": ok})
	if not ok: failures.append(label)
func pixels(image: Image) -> String: return image.get_data().hex_encode().sha256_text()
func shape(mesh: Mesh) -> String:
	var a: Array = mesh.surface_get_arrays(0)
	return var_to_bytes([a[Mesh.ARRAY_VERTEX], a[Mesh.ARRAY_INDEX], a[Mesh.ARRAY_TEX_UV]]).hex_encode().sha256_text()
func model_hash() -> String: return JSON.stringify(study.document, "", true, true).sha256_text()
func retained() -> String:
	var entries: Array = []
	for node in study.derived.get_children():
		if node is MeshInstance3D:
			entries.append([str(node.name), node.get_instance_id(), node.mesh.get_instance_id(), node.material_override.get_instance_id(), node.transform])
	return var_to_bytes(entries).hex_encode().sha256_text()
func material_variant(code: String) -> ShaderMaterial:
	var shader := Shader.new(); shader.code = code
	var material := ShaderMaterial.new(); material.shader = shader
	for u in original_material.shader.get_shader_uniform_list():
		var value = original_material.get_shader_parameter(u.name)
		if value != null: material.set_shader_parameter(u.name, value)
	return material
func select(mode: int, receive: bool) -> void:
	crown.mesh = meshes[mode]
	crown.material_override = original_material if receive else no_receive
func view(name: String) -> void:
	if name == "plan":
		study.plan_locked = true; study.perspective = false
		study.target = Vector3(5., 0., -7.5); study.plan_size = 20.
	elif name == "courtyard":
		study.plan_locked = false; study.perspective = true
		study.target = Vector3(5., 0., -7.); study.yaw = .55; study.pitch = .85; study.distance = 22.
	else:
		var t: Dictionary = study.document.tree
		study.plan_locked = false; study.perspective = false
		study.target = Vector3(t.x, t.base_elevation + t.height * .64, -t.y)
		study.yaw = .55 + PI; study.pitch = .28; study.distance = 6.
	study._update_camera()
func grab(name: String) -> Image:
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image(); image.convert(Image.FORMAT_RGBA8)
	check(image.save_png(output.path_join(name + ".png")) == OK, "capture " + name)
	hashes[name] = pixels(image)
	return image
func delta(a: Image, b: Image) -> Dictionary:
	var aa := a.get_data(); var bb := b.get_data()
	var rgb := 0; var alpha := 0; var maximum := 0
	for i in range(0, aa.size(), 4):
		var different := false
		for c in 3:
			var d := absi(int(aa[i+c])-int(bb[i+c])); maximum = maxi(maximum, d)
			if d > 0: different = true
		if different: rgb += 1
		if aa[i+3] != bb[i+3]: alpha += 1
	return {"rgb_changed": rgb, "alpha_changed": alpha, "max_channel": maximum}
func make_mesh_normals(a: Array) -> PackedVector3Array:
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var result := PackedVector3Array(); result.resize(v.size()); result.fill(Vector3.ZERO)
	var degenerate := 0
	for i in range(0, ix.size(), 3):
		var p := ix[i]; var q := ix[i+1]; var r := ix[i+2]
		# Godot front faces use clockwise winding. Do not weld coincident backs.
		var n := (v[r]-v[p]).cross(v[q]-v[p])
		if n.length_squared() < 1e-18: degenerate += 1; continue
		result[p] += n; result[q] += n; result[r] += n
	var zero := 0
	for i in result.size():
		if result[i].length_squared() < 1e-18: zero += 1
		else: result[i] = result[i].normalized()
	diagnostics["final_mesh_normal_build"] = {"degenerate_triangles": degenerate, "zero_vertex_normals": zero, "vertex_count": v.size(), "smoothing": "area weighted per existing vertex index; front/back indices never welded"}
	check(zero == 0 and degenerate == 0, "final mesh has no degenerate triangles or unresolved normal sums")
	return result
func winding_oracle() -> void:
	var plane := PlaneMesh.new()
	var a: Array = plane.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]; var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var face := (v[ix[2]]-v[ix[0]]).cross(v[ix[1]]-v[ix[0]]).normalized()
	check(face.dot(n[ix[0]]) > .999, "clockwise cross convention agrees with engine PlaneMesh normals")
func isolated(name: String) -> void:
	view(name)
	var flags: Array = []
	for node in study.derived.get_children():
		flags.append(node.visible); node.visible = node == study.illustrative_tree
	study.illustrative_tree.wood.visible = false
	var bg_mode: int = study.environment.background_mode
	var bg_color: Color = study.environment.background_color
	var old_clear := RenderingServer.get_default_clear_color()
	root.transparent_bg = true
	study.environment.background_mode = Environment.BG_CLEAR_COLOR
	RenderingServer.set_default_clear_color(Color(0,0,0,0))
	select(0, true); crown.material_override = white_mask
	var reference := await grab("mask-" + name)
	var alpha := reference.get_data(); var clear := 0; var solid := 0
	for i in range(3, alpha.size(), 4):
		if alpha[i] == 0: clear += 1
		if alpha[i] == 255: solid += 1
	check(clear > 1000 and solid > 100, "true cutout mask contains transparent background and solid coverage " + name)
	diagnostics["coverage_" + name] = {"clear_samples": clear, "solid_samples": solid}
	for mode in 3:
		for receive in [true, false]:
			select(mode, receive)
			var key: String = "coverage-" + name + "-" + LABELS[mode] + ("-on" if receive else "-off")
			var image := await grab(key)
			check(delta(reference, image).alpha_changed == 0, "lit material exactly matches alpha-tested mask " + key)
		crown.material_override = normal_view
		var normal_image := await grab("normals-" + name + "-" + LABELS[mode])
		check(delta(reference, normal_image).alpha_changed == 0, "normal visualization preserves actual cutout coverage " + name + LABELS[mode])
	root.transparent_bg = false
	study.environment.background_mode = bg_mode; study.environment.background_color = bg_color
	RenderingServer.set_default_clear_color(old_clear)
	var j := 0
	for node in study.derived.get_children(): node.visible = flags[j]; j += 1
	study.illustrative_tree.wood.visible = true; select(0, true)
func ground_witness() -> void:
	# Disable only visible rendering of the foliage, preserving its cast.
	var flags: Array = []
	for node in study.derived.get_children():
		flags.append(node.visible); node.visible = node == study.illustrative_tree
	study.illustrative_tree.wood.visible = false
	var old_cast: int = crown.cast_shadow
	crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	var receiver := MeshInstance3D.new(); var plane := PlaneMesh.new(); plane.size = Vector2(18,18)
	receiver.mesh = plane
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(.75,.75,.75); mat.roughness = 1.
	receiver.material_override = mat
	var t: Dictionary = study.document.tree
	receiver.position = Vector3(t.x,t.base_elevation,-t.y)
	study.add_child(receiver)
	study.plan_locked = true; study.perspective = false; study.plan_size = 12.
	study.target = Vector3(t.x,t.base_elevation,-t.y); study._update_camera()
	var casts: Array = []
	for mode in 3:
		select(mode, true); var on := await grab("ground-" + LABELS[mode] + "-on")
		select(mode, false); var off := await grab("ground-" + LABELS[mode] + "-off")
		check(pixels(on) == pixels(off), "foliage-receipt toggle retains identical ground cast " + LABELS[mode])
		casts.append(on)
	select(0, true); crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var none := await grab("ground-no-cast")
	for mode in 3:
		var d := delta(none, casts[mode]); diagnostics["cast_" + LABELS[mode]] = d
		check(d.rgb_changed > 100, "ground witness proves actual foliage casting " + LABELS[mode])
	diagnostics["ground_A_vs_C"] = delta(casts[0], casts[2])
	crown.cast_shadow = old_cast; receiver.queue_free(); await process_frame
	var j := 0
	for node in study.derived.get_children(): node.visible = flags[j]; j += 1
	study.illustrative_tree.wood.visible = true
func run() -> void:
	output = OS.get_environment("YARDSCAPE_LIGHTING_OUTPUT"); run_id = OS.get_environment("YARDSCAPE_LIGHTING_RUN_ID")
	if run_id.length()!=36 or not output.begins_with(ProjectSettings.globalize_path("res://.local/")):
		push_error("Fresh isolated lighting output required"); quit(1); return
	root.size = Vector2i(1280,900)
	study = load("res://northstar-spatial-curved-canopy.tscn").instantiate(); root.add_child(study)
	for i in 3: await process_frame
	for node in study.get_children():
		if node is CanvasLayer: node.visible = false
	crown = study.illustrative_tree.crown; original_mesh = crown.mesh; original_material = crown.material_override
	var semantic_start := model_hash(); var retained_start := retained(); var builds: int = study.build_count
	var geometric := shape(original_mesh)
	var analytic = load("res://.local/diagnostic_analytic.gd").new()
	analytic.configure(study.document.tree)
	check(shape(analytic.crown.mesh) == geometric, "single normal-expression substitution preserves every vertex index and UV")
	check(var_to_bytes(analytic.wood.mesh.surface_get_arrays(0)) == var_to_bytes(study.illustrative_tree.wood.mesh.surface_get_arrays(0)), "branch arrays remain exact")
	winding_oracle()
	var arrays: Array = original_mesh.surface_get_arrays(0)
	var analytic_arrays: Array = analytic.crown.mesh.surface_get_arrays(0)
	var final_normals := make_mesh_normals(arrays)
	var final_arrays: Array = arrays.duplicate(true); final_arrays[Mesh.ARRAY_NORMAL] = final_normals
	var final_mesh := ArrayMesh.new(); final_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, final_arrays)
	meshes = [original_mesh, analytic.crown.mesh, final_mesh]
	var current_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bend_normals: PackedVector3Array = analytic_arrays[Mesh.ARRAY_NORMAL]
	var flipped := 0; var min_alignment := 1.; var final_vs_bend := 0.
	for i in final_normals.size():
		if current_normals[i].dot(bend_normals[i]) < 0.: flipped += 1
		min_alignment = minf(min_alignment, final_normals[i].dot(bend_normals[i]))
		final_vs_bend += final_normals[i].dot(bend_normals[i])
	diagnostics["normal_census"] = {"vertices": final_normals.size(), "current_opposes_bend": flipped, "final_vs_bend_min_dot": min_alignment, "final_vs_bend_mean_dot": final_vs_bend/final_normals.size()}
	check(min_alignment > 0., "final mesh normals retain front/back orientation relative to bend normals")
	for mode in 3: check(shape(meshes[mode]) == geometric, "only normal array differs " + LABELS[mode])
	var code := original_material.shader.code
	var mode_line := "render_mode diffuse_lambert, specular_disabled;"
	check(code.count(mode_line) == 1, "known original shading mode for controlled variants")
	no_receive = material_variant(code.replace(mode_line, "render_mode diffuse_lambert, specular_disabled, shadows_disabled;"))
	var diagnostic_code := code.replace(mode_line, "render_mode unshaded;")
	white_mask = material_variant(diagnostic_code.replace("ALBEDO=color;ROUGHNESS=1.;", "ALBEDO=vec3(1.);ROUGHNESS=1.;"))
	var normal_code := diagnostic_code.replace("varying vec3 media;", "varying vec3 media; varying vec3 diagnostic_normal;")
	normal_code = normal_code.replace("void vertex(){", "void vertex(){diagnostic_normal=NORMAL;")
	normal_view = material_variant(normal_code.replace("ALBEDO=color;ROUGHNESS=1.;", "ALBEDO=normalize(diagnostic_normal)*.5+.5;ROUGHNESS=1.;"))
	check(code.count("ALBEDO=color;ROUGHNESS=1.;") == 1, "diagnostic albedo substitutions are bounded")
	diagnostics["light"] = {"rotation": [study.sun.rotation_degrees.x,study.sun.rotation_degrees.y,study.sun.rotation_degrees.z], "energy": study.sun.light_energy, "shadow_bias": study.sun.shadow_bias, "shadow_normal_bias": study.sun.shadow_normal_bias, "shadow_enabled": study.sun.shadow_enabled, "ambient_energy": study.environment.ambient_light_energy}
	diagnostics["shape_hash"] = geometric
	diagnostics["coverage_sha256"] = study.illustrative_tree.shared_coverage.get_image().get_data().hex_encode().sha256_text()
	for view_name in ["plan", "courtyard", "reverse"]:
		view(view_name); select(0, true)
		var baseline := await grab("baseline-" + view_name)
		var images: Dictionary = {}
		for mode in 3:
			for receive in [true, false]:
				select(mode, receive)
				var key: String = LABELS[mode] + ("-on" if receive else "-off")
				images[key] = await grab(view_name + "-" + key)
				check(model_hash() == semantic_start and retained() == retained_start, "state and unrelated resources preserved " + view_name + key)
			check(shape(crown.mesh) == geometric, "shape and UVs fixed " + view_name + LABELS[mode])
			check(pixels(images["A-current-on"]) == pixels(baseline), "original case matches native baseline " + view_name)
			var d := delta(images[LABELS[mode]+"-on"],images[LABELS[mode]+"-off"])
			diagnostics[view_name + "_receipt_" + LABELS[mode]] = d
		diagnostics[view_name + "_A_vs_B_no_receipt"] = delta(images["A-current-off"],images["B-bend-off"])
		diagnostics[view_name + "_B_vs_C_no_receipt"] = delta(images["B-bend-off"],images["C-mesh-off"])
		select(0, true); check(pixels(await grab("return-" + view_name)) == pixels(baseline), "exact rollback " + view_name)
	await isolated("plan"); await isolated("reverse")
	await ground_witness()
	select(0,true); view("plan")
	check(crown.mesh == original_mesh and crown.material_override == original_material, "original mesh and material references restored")
	check(model_hash() == semantic_start and retained() == retained_start and study.build_count == builds, "entire experiment leaves original project and derived build untouched")
	var report := {"run_id":run_id, "passed":failures.is_empty(), "checks":checks, "failures":failures, "pixel_hashes":hashes, "diagnostics":diagnostics, "engine":Engine.get_version_info().string, "adapter":RenderingServer.get_video_adapter_name(), "scope":"normal-array and foliage shadow-receipt matrix over existing read-only spatial adapter", "self_shadow_isolated":false, "tablet_tested":false, "artistic_acceptance":"not_evaluated"}
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	if file == null: push_error("Cannot save report"); quit(1); return
	file.store_string(JSON.stringify(report,"  ")); file.close()
	print("Lighting diagnostic checks: ", checks.size(), " failures: ", failures)
	analytic.free(); study.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
