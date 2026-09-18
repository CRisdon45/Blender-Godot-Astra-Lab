extends "res://presentation/northstar/canopy/illustrative_tree.gd"
## Curvature/orientation comparison only. Inherited branch bytes and group
## anchors stay fixed. Sixty-four opaque sprays, not sixty-four literal leaves.
const CURVED_RECIPE = "curved-foliage-groups/3"
var _surface_uv := PackedVector2Array()

func configure(t: Dictionary) -> void:
	super.configure(t)
	stats["recipe"] = CURVED_RECIPE
	stats["curved_sprays"] = stats["folded_sprays"]
	stats.erase("folded_sprays")

func _bend(x: float, z: float, phase: float) -> float:
	return .44*(1.-x*x)-.18*z*z+.19*x*z+.08*sin(2.*z+phase)

func _mass(center: Vector3, extent: Vector3, angle: float, phase: float) -> void:
	# Same four centres as the predecessor. Only contour, curvature and orientation
	# change; no additional foliage groups or RNG calls in the inherited builder.
	for j in 4:
		var spin: float = angle+phase*.43+[-.45,1.22,3.49,5.81][j]
		var tilt: float = [-.75,.22,.92,-.38][j]+.22*sin(phase*1.3+j)
		var roll: float = [-.35,.55,-.60,.18][j]+.15*cos(phase+j*1.7)
		var rotation := Basis(Vector3.UP,spin)*Basis(Vector3.RIGHT,tilt)*Basis(Vector3.FORWARD,roll)
		var offset := Basis(Vector3.UP,angle)*Vector3(extent.x*[-.38,.40,-.16,.14][j],extent.y*[-.42,.18,.48,-.10][j],extent.z*[-.24,.20,.35,-.37][j])
		var c := _point(center+offset)
		var rx := extent.x*_radius*.76
		var rz := extent.z*_radius*.78
		var guide := Vector3(c.x/_radius,(c.y/_height-.69)*3.,c.z/_radius).normalized()
		var sides := 18
		var rings := 3
		var stride := 1+sides*rings
		var start := _v.size()
		for face in 2:
			var sign_value := 1. if face==0 else -1.
			for ring in range(rings+1):
				var count := 1 if ring==0 else sides
				var r := float(ring)/rings
				for k in count:
					var u := TAU*float(k)/sides
					# Unequal, rounded lobing instead of five repeated star points.
					var edge := .90+.075*sin(3.*u+phase)+.045*cos(7.*u-phase*.6)+.025*sin(11.*u+.3)
					var x := cos(u)*r*edge
					var z := sin(u)*r*edge
					var y := rx*(_bend(x,z,phase)+sign_value*.035*(1.-r*r))
					var point := _bounded(c+rotation*Vector3(rx*x,y,rz*z))
					var dx := -.88*x+.19*z
					var dz := -.36*z+.19*x+.16*cos(2.*z+phase)
					var normal := (rotation*Vector3(-dx,1.,-dz*rx/rz)*sign_value).normalized()
					_surface_uv.append(Vector2(x*.5+.5,z*.5+.5))
					_v.append(point)
					_n.append(normal.lerp(guide,.56).normalized())
			var base := start+face*stride
			for k in sides:
				var a := base+1+k
				var b := base+1+(k+1)%sides
				_triangle(base,a,b,face==1)
			for ring in range(rings-1):
				for k in sides:
					var a := base+1+ring*sides+k
					var b := base+1+ring*sides+(k+1)%sides
					var c_next := a+sides
					var d := b+sides
					_triangle(a,c_next,b,face==1)
					_triangle(b,c_next,d,face==1)

func _triangle(a: int,b: int,c: int,reverse: bool) -> void:
	_ix.append_array(PackedInt32Array([a,c,b] if reverse else [a,b,c]))

func _finish(label: String) -> MeshInstance3D:
	if label=="BranchGesture": return super._finish(label)
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=_v;arrays[Mesh.ARRAY_NORMAL]=_n;arrays[Mesh.ARRAY_INDEX]=_ix
	arrays[Mesh.ARRAY_TEX_UV]=_surface_uv
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node:=MeshInstance3D.new();node.name=label;node.mesh=mesh;add_child(node)
	_v=PackedVector3Array();_n=PackedVector3Array();_ix=PackedInt32Array();_surface_uv=PackedVector2Array()
	return node
