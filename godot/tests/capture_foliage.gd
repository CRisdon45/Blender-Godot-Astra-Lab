extends SceneTree
## Actual Forward+ frame capture, not a synthetic picture or viewport mock-up.
var output: String = ""
var records: Array = []
var problems: Array = []

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for unused in range(count):
		await process_frame

func save_frame(scene, name: String, position: Vector3, aim: Vector3) -> void:
	scene.camera.position = position
	scene.camera.look_at(aim)
	await frames(5)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		problems.append("Empty image: " + name)
		return
	var result: Error = image.save_png(output.path_join(name + ".png"))
	if result != OK:
		problems.append("Image save failed: " + name)
		return
	records.append({"file": name + ".png", "width": image.get_width(), "height": image.get_height(),
		"camera": [position.x, position.y, position.z], "aim": [aim.x, aim.y, aim.z],
		"water": scene.water.snapshot()})
	print("FOLIAGE_FRAME ", name)

func collect_meshes(node: Node, meshes: Array) -> void:
	if node is MeshInstance3D:
		meshes.append(node)
	for child in node.get_children():
		collect_meshes(child, meshes)

func check_cards(scene) -> void:
	var meshes: Array = []
	collect_meshes(scene, meshes)
	var surfaces: int = 0
	var checked: int = 0
	for mesh in meshes:
		for surface in range(mesh.mesh.get_surface_count()):
			var material: Material = mesh.get_active_material(surface)
			if not material is ShaderMaterial or material.shader.resource_path != "res://shaders/anime_foliage.gdshader":
				continue
			surfaces += 1
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var sizes: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if uvs.size() != vertices.size() or sizes.size() != vertices.size() or normals.size() != vertices.size():
				problems.append("Missing UV/UV2/normal stream")
				continue
			for i in range(0, indices.size(), 3):
				var centers: Array[Vector3] = []
				for k in range(3):
					var ix: int = indices[i+k]
					var offset: Vector2 = Vector2(uvs[ix].x-.5, .5-uvs[ix].y) * sizes[ix]
					centers.append(vertices[ix]-Vector3(offset.x, offset.y, 0))
					if sizes[ix].x <= 0 or sizes[ix].y <= 0 or not normals[ix].is_finite():
						problems.append("Invalid brush dimensions or normal")
				if centers[0].distance_to(centers[1]) > .005 or centers[0].distance_to(centers[2]) > .005:
					problems.append("Exporter/shader card-center contract failed")
					break
				checked += 1
	if surfaces != 12:
		problems.append("Expected seven crowns and five shrubs; surfaces=" + str(surfaces))
	print("FOLIAGE_MESH_CHECK ", JSON.stringify({"surfaces":surfaces,"triangles_checked":checked,"errors":problems}))

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	if output.is_empty() or not output.is_absolute_path() or DisplayServer.get_name() == "headless":
		push_error("FOLIAGE_CAPTURE_REQUIRES_DISPLAY_AND_ABSOLUTE_OUTPUT")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var poses: Array = [
		["courtyard", Vector3(4,3.3,10), Vector3(0,1.8,-3)],
		["pool-close", Vector3(2.4,2.7,4.8), Vector3(0,1.8,-3)],
		["trees", Vector3(-4.4,5.5,-5.1), Vector3(-3.0,5.1,-13.0)],
		["shrubs", Vector3(-7.3,2.45,-5.5), Vector3(-7.7,1.2,-9.65)],
	]
	for mode in ["before", "after"]:
		var path: String = "res://courtyard.tscn" if mode == "before" else "res://courtyard_anime.tscn"
		var packed := load(path) as PackedScene
		if packed == null:
			problems.append("Could not load " + path)
			continue
		var scene = packed.instantiate()
		root.add_child(scene)
		await frames(4)
		if mode == "after":
			check_cards(scene)
		scene.set_process(false)
		scene.water.water_time = 2.0
		scene.water.advance(0.0)
		scene.set_illustration(true)
		for pose in poses:
			await save_frame(scene, mode + "-" + pose[0], pose[1], pose[2])
		if mode == "after":
			var meshes: Array = []
			collect_meshes(scene, meshes)
			for instance in meshes:
				var label: String = String(instance.name).replace("_", " ")
				if label.contains("Fine architectural contours"):
					continue
				instance.visible = label.begins_with("Anime tree 2")
			var file := FileAccess.open("res://assets/anime/build_manifest.json", FileAccess.READ)
			var info: Dictionary = JSON.parse_string(file.get_as_text())
			file.close()
			var plant: Dictionary = info.plants[2]
			var point: Array = plant.origin
			var target: Vector3 = Vector3(float(point[0]),float(point[2])+3.3*float(plant.scale),-float(point[1]))
			for index in range(12):
				var angle: float = float(index)*TAU/12.0
				var eye: Vector3 = target+Vector3(sin(angle)*10.0,1.0,cos(angle)*10.0)
				await save_frame(scene,"tree-orbit-%02d" % index,eye,target)
		scene.queue_free()
		scene = null
		packed = null
		await frames(4)
	var report: Dictionary = {"status":"captured" if problems.is_empty() else "failed",
		"renderer":"Godot Forward+ Linux software Vulkan", "engine":Engine.get_version_info(),
		"images":records,"errors":problems,"visual_acceptance":"not_approved",
		"performance_certified":false,"matched_water_time":2.0}
	var manifest := FileAccess.open(output.path_join("foliage-review.json"),FileAccess.WRITE)
	manifest.store_string(JSON.stringify(report,"\t"))
	manifest.close()
	print("FOLIAGE_REVIEW_DONE ",JSON.stringify({"images":records.size(),"errors":problems}))
	quit(0 if problems.is_empty() and records.size()==20 else 1)
