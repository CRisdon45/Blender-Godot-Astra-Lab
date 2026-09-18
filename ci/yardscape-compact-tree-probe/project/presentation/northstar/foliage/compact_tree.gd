extends Node3D
## Generic whole-tree witness. Reuses the previous branch gesture and the new
## compact group; no species claim, LOD system, crown-light guide or runtime AI.
const Skeleton = preload("res://presentation/northstar/canopy/illustrative_tree.gd")
const Group = preload("res://presentation/northstar/foliage/compact_group.gd")
const RECIPE := "compact-group-tree/2"
var descriptor: Dictionary={}
var skeleton: Node3D
var groups: Array[Node3D]=[]
var stats: Dictionary={}

func configure(t: Dictionary)->void:
	assert(Skeleton.input_error(t).is_empty())
	assert(get_child_count()==0)
	descriptor=t.duplicate(true)
	position=Vector3(t.x,t.base_elevation,-t.y)
	# Build the exact retained branch gesture from the prior generic witness.
	skeleton=Skeleton.new();skeleton.configure(t);skeleton.position=Vector3.ZERO
	skeleton.crown.visible=false
	add_child(skeleton)
	var anchors:=_anchors(t)
	var group_radius:float=t.crown_radius*.54
	var group_height:float=t.height*.30
	var total_triangles:=int(skeleton.wood.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()/3)
	var primary_count:=0
	var secondary_count:=0
	for i in anchors.size():
		var anchor:Dictionary=anchors[i]
		var group:=Group.new()
		group.configure(int(t.seed)+7919*(i+1),group_radius,group_height)
		var bounds:AABB=group.foliage.mesh.get_aabb().merge(group.twig.mesh.get_aabb())
		var normalized:Vector3=anchor.position
		var target:=Vector3(normalized.x*t.crown_radius,normalized.y*t.height,normalized.z*t.crown_radius)
		var scale_value:float=anchor.scale
		group.scale=Vector3.ONE*scale_value
		group.rotation.y=float(anchor.angle)
		group.rotation.z=float(anchor.tilt)
		# Keep each differently transformed group's geometric center on the retained
		# branch anchor. This changes hierarchy/orientation, not anchor locations.
		group.position=target-group.basis*bounds.get_center()
		group.name="Group%02d"%i
		add_child(group);groups.append(group)
		if anchor.role=="primary":primary_count+=1
		elif anchor.role=="secondary":secondary_count+=1
		total_triangles+=int(group.stats.foliage_triangles)+int(group.stats.twig_triangles)
	stats={"recipe":RECIPE,"groups":groups.size(),"primary_groups":primary_count,"secondary_groups":secondary_count,
		"visible_meshes":1+groups.size()*2,"visible_triangles":total_triangles,"alpha_blended":false,
		"source_record_unchanged":true,"hierarchical_transforms":true}

func _anchors(t:Dictionary)->Array[Dictionary]:
	var rng:=RandomNumberGenerator.new();rng.seed=int(t.seed)
	var phase:=rng.randf()*TAU
	var result:Array[Dictionary]=[]
	for j in 5:
		var angle:float=phase+[0.,1.16,2.62,3.76,5.10][j]
		var direction:=Vector3(cos(angle),0.,sin(angle))
		var side:=Vector3(-sin(angle),0.,cos(angle))
		var reach:float=[.58,.48,.63,.50,.61][j]
		var level:float=[.65,.80,.69,.83,.73][j]
		var center:=direction*reach;center.y=level
		result.append({"position":center,"angle":angle,"scale":1.0,"tilt":.10,"role":"primary"})
		for k in 2:
			var at:=center+side*(-.23 if k==0 else .22)-direction*.12
			at.y+=-.065 if k==0 else .075
			result.append({"position":at,"angle":angle+.45*float(k*2-1),"scale":.80,
				"tilt":(-.21 if k==0 else .21),"role":"secondary"})
	result.append({"position":Vector3(-.08,.90,.06),"angle":phase+.8,"scale":.88,"tilt":-.06,"role":"leader"})
	return result

func geometry_signature()->String:
	var data:Array=[descriptor,skeleton.wood.mesh.surface_get_arrays(0)]
	for group in groups:data.append([group.transform,group.geometry_signature()])
	return var_to_bytes(data).hex_encode().sha256_text()
