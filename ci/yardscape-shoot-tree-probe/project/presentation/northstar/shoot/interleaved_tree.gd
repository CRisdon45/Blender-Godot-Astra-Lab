extends Node3D
## Generic whole-tree representation built from the tested compact shoot.
## Reuses the prior tapered branch gesture and its 16 branch-scale anchors.
const BranchTree = preload("res://presentation/northstar/canopy/illustrative_tree.gd")
const CompactShoot = preload("res://presentation/northstar/shoot/compact_shoot.gd")
const RECIPE = "interleaved-compact-shoot-tree/1"
var descriptor: Dictionary = {}
var branch_source: Node3D
var shoots: Array[Node3D] = []
var stats: Dictionary = {}

func configure(source: Dictionary) -> void:
	assert(source.has_all(["id","x","y","base_elevation","height","crown_radius","seed"]))
	assert(get_child_count()==0)
	descriptor=source.duplicate(true)
	position=Vector3(source.x,source.base_elevation,-source.y)
	branch_source=BranchTree.new()
	branch_source.configure(source)
	branch_source.position=Vector3.ZERO
	branch_source.crown.visible=false
	branch_source.crown.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(branch_source)
	var anchors:=_anchors(source)
	var rng:=RandomNumberGenerator.new();rng.seed=int(source.seed)+51409
	for i in anchors.size():
		var item: Dictionary=anchors[i]
		var shoot:=CompactShoot.new()
		shoot.name="Shoot%02d"%i
		shoot.configure(source)
		shoot.position=item.position
		var outward:=Vector2(item.position.x,item.position.z).angle()
		shoot.rotation=Vector3(
			rng.randf_range(-.32,.32)+(.16 if i%3==0 else 0.),
			-outward+PI*.5+rng.randf_range(-.35,.35),
			rng.randf_range(-.28,.28))
		var scale_value: float=rng.randf_range(.61,.82)
		if i==anchors.size()-1: scale_value=.78
		shoot.scale=Vector3.ONE*scale_value
		add_child(shoot);shoots.append(shoot)
	var shoot_triangles:=0
	for shoot in shoots:
		shoot_triangles+=int(shoot.stats.foliage_triangles)+int(shoot.stats.twig_triangles)
	stats={"recipe":RECIPE,"shoot_count":shoots.size(),"leaf_count":shoots.size()*7,
		"shoot_triangles":shoot_triangles,"branch_triangles":int(branch_source.stats.branch_triangles),
		"total_tree_triangles":shoot_triangles+int(branch_source.stats.branch_triangles),
		"visible_mesh_instances":1+shoots.size()*2,"alpha_foliage":false}

func _anchors(source: Dictionary) -> Array[Dictionary]:
	var radius: float=float(source.crown_radius)
	var height: float=float(source.height)
	var rng:=RandomNumberGenerator.new();rng.seed=int(source.seed)
	var phase: float=rng.randf()*TAU
	var result: Array[Dictionary]=[]
	var trunk2:=Vector3(-.055*radius,.36*height,.025*radius)
	var trunk3:=Vector3(.035*radius,.52*height,0.)
	for j in 5:
		var angle: float=phase+[0.,1.16,2.62,3.76,5.10][j]
		var direction:=Vector3(cos(angle),0.,sin(angle))
		var side:=Vector3(-sin(angle),0.,cos(angle))
		var reach: float=[.58,.48,.63,.50,.61][j]
		var level: float=[.65,.80,.69,.83,.73][j]
		var center:=Vector3(direction.x*reach*radius,level*height,direction.z*reach*radius)
		result.append({"position":center,"angle":angle,"tier":"main"})
		for k in 2:
			var at:=center+side*(-.23 if k==0 else .22)*radius-direction*.12*radius
			at.y+=(-.065 if k==0 else .075)*height
			result.append({"position":at,"angle":angle+.45*float(k*2-1),"tier":"side"})
	var leader:=Vector3(-.08*radius,.90*height,.06*radius)
	result.append({"position":leader,"angle":phase+.8,"tier":"leader"})
	return result

func geometry_signature() -> String:
	var parts: Array=[descriptor,branch_source.wood.mesh.surface_get_arrays(0)]
	for shoot in shoots:
		parts.append([shoot.transform,shoot.geometry_signature()])
	return var_to_bytes(parts).hex_encode().sha256_text()
