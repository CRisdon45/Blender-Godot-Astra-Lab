extends "res://courtyard.gd"
## Explicit opt-in foliage study. The original saved and builder scenes are unchanged.
const FOLIAGE_SHADER = preload("res://shaders/anime_foliage.gdshader")
var foliage_surfaces: int = 0

func scene_asset_path() -> String:
	return "res://assets/anime/courtyard_anime.glb"

func apply_materials(node: Node) -> void:
	super.apply_materials(node)
	if not node is MeshInstance3D:
		return
	var instance := node as MeshInstance3D
	for surface in range(instance.mesh.get_surface_count()):
		var source := instance.mesh.surface_get_material(surface)
		var label: String = source.resource_name if source != null else String(node.name)
		if not label.begins_with("Anime foliage"):
			continue
		var mat := ShaderMaterial.new()
		mat.shader = FOLIAGE_SHADER
		mat.set_shader_parameter("brush_atlas", load("res://assets/anime/brush_atlas.png"))
		instance.set_surface_override_material(surface, mat)
		instance.extra_cull_margin = 1.5
		# Raw cards have a fixed XY orientation; do not let imported LODs erase them.
		instance.lod_bias = 100.0
		foliage_surfaces += 1
