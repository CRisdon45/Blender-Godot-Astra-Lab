extends Node3D
## Generic whole-tree representation built from the tested compact shoot.
## Reuses the prior tapered branch gesture and its 16 branch-scale paths.
const BranchTree = preload("res://presentation/northstar/canopy/illustrative_tree.gd")
const CompactShoot = preload("res://presentation/northstar/shoot/compact_shoot.gd")
const RECIPE = "interleaved-compact-shoot-tree/2"
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
	var anchors: Array[Dictionary]=_anchors(source)
	var rng:=RandomNumberGenerator.new();rng.seed=int(source.seed)+51409
	var radius: float=float(source.crown_radius)
	for i in anchors.size():
		var item: Dictionary=anchors[i]
		var shoot:=CompactShoot.new()
		shoot.name="Shoot%02d"%i
		shoot.configure(source)
		shoot.position=item.position
		var axis: Vector3=item.direction.normalized()
		# Keep a rising branch gesture but stop every shoot from standing upright.
		axis.y=maxf(axis.y,.18)
		axis=axis.normalized()
		var x_axis: Vector3=Vector3.UP.cross(axis).normalized()
		if x_axis.length_squared()<.05:x_axis=Vector3.RIGHT
		var z_axis: Vector3=x_axis.cross(axis).normalized()
		shoot.basis=Basis(x_axis,axis,z_axis).orthonormalized()
		shoot.rotate_object_local(Vector3.UP,rng.randf_range(-.48,.48))
		var radial_fraction: float=Vector2(item.position.x,item.position.z).length()/radius
		var nominal: float=rng.randf_range(.56,.76)
		if item.tier=="inner":nominal=rng.randf_range(.62,.80)
		if item.tier=="leader":nominal=.70
		var envelope: float=clampf((1.06-radial_fraction)/.34,.42,.82)
		var scale_value: float=minf(nominal,envelope)
		shoot.scale=Vector3.ONE*scale_value
		add_child(shoot);shoots.append(shoot)
	var shoot_triangles:=0
	for shoot in shoots:
		shoot_triangles+=int(shoot.stats.foliage_triangles)+int(shoot.stats.twig_triangles)
	stats={"recipe":RECIPE,"shoot_count":shoots.size(),"leaf_count":shoots.size()*7,
		"shoot_triangles":shoot_triangles,"branch_triangles":int(branch_source.stats.branch_triangles),
		"total_tree_triangles":shoot_triangles+int(branch_source.stats.branch_triangles),
		"visible_mesh_instances":1+shoots.size()*2,"alpha_foliage":false}

func _scaled(p: Vector3,radius: float,height: float) -> Vector3:
	return Vector3(p.x*radius,p.y*height,p.z*radius)

func _anchors(source: Dictionary) -> Array[Dictionary]:
	var radius: float=float(source.crown_radius)
	var height: float=float(source.height)
	var rng:=RandomNumberGenerator.new();rng.seed=int(source.seed)
	var phase: float=rng.randf()*TAU
	var result: Array[Dictionary]=[]
	var trunk2:=Vector3(-.055,.36,.025)
	var trunk3:=Vector3(.035,.52,0.)
	for j in 5:
		var angle: float=phase+[0.,1.16,2.62,3.76,5.10][j]
		var direction:=Vector3(cos(angle),0.,sin(angle))
		var side:=Vector3(-sin(angle),0.,cos(angle))
		var reach: float=[.58,.48,.63,.50,.61][j]
		var level: float=[.65,.80,.69,.83,.73][j]
		var center:=direction*reach;center.y=level
		var start: Vector3=trunk2 if j%2==0 else trunk3
		var elbow:=start.lerp(center,.50);elbow.y-=.04
		var main_position:=_scaled(center,radius,height)
		var main_direction:=(_scaled(center,radius,height)-_scaled(elbow,radius,height)).normalized()
		result.append({"position":main_position,"direction":main_direction,"tier":"main"})
		for k in 2:
			var outer:=center+side*(-.23 if k==0 else .22)-direction*.12
			outer.y+=-.065 if k==0 else .075
			var branch_direction:=(_scaled(outer,radius,height)-_scaled(elbow,radius,height)).normalized()
			# Alternate outer and inner placement along the same authored side branch.
			var anchor_norm: Vector3=outer if k==0 else elbow.lerp(outer,.58)
			result.append({"position":_scaled(anchor_norm,radius,height),"direction":branch_direction,"tier":"outer" if k==0 else "inner"})
	var leader:=Vector3(-.08,.90,.06)
	result.append({"position":_scaled(leader,radius,height),"direction":(_scaled(leader,radius,height)-_scaled(trunk3,radius,height)).normalized(),"tier":"leader"})
	return result

func geometry_signature() -> String:
	var parts: Array=[descriptor,branch_source.wood.mesh.surface_get_arrays(0)]
	for shoot in shoots:
		parts.append([shoot.transform,shoot.geometry_signature()])
	return var_to_bytes(parts).hex_encode().sha256_text()
