extends "res://presentation/northstar/foliage/dab_group.gd"
## Exact retained v2 cluster recipe; only the local dab primitive changes from
## one equatorial ring to two staggered rings.
func configure(seed_value:int,radius:float,height:float)->void:
	super.configure(seed_value,radius,height)
	stats["recipe"]="rounded-two-ring-paint-dabs/1"

func _dab(center:Vector3,direction:Vector3,roll:float,width:float,length:float,thickness:float,tone:float,radius:float,height:float,phase:float)->void:
	var basis:=_basis_from(direction,roll)
	var c:=Vector3(center.x*radius,center.y*height,center.z*radius)
	var first:=_v.size()
	var sides:=6
	var start_tip:=_v.size()
	_v.append(c+basis*Vector3(-width*.035,-length*.56,thickness*.025));_n.append(Vector3.ZERO);_colors.append(Color(tone,tone,tone,1))
	var lower:=_v.size()
	for k in sides:
		var a:=TAU*float(k)/sides
		var irregular:=1.+.075*sin(3.*a+phase)+.04*cos(5.*a-phase)
		var local:=Vector3(cos(a)*width*.82*irregular,-length*.16+length*.035*sin(2.*a+phase),sin(a)*thickness*.78*irregular)
		_v.append(c+basis*local);_n.append(Vector3.ZERO);_colors.append(Color(tone,tone,tone,1))
	var upper:=_v.size()
	for k in sides:
		var a:=TAU*(float(k)+.5)/sides
		var irregular:=1.+.075*sin(3.*a+phase)+.04*cos(5.*a-phase)
		var local:=Vector3(cos(a)*width*irregular,length*.15+length*.035*sin(2.*a+phase+.7),sin(a)*thickness*irregular)
		_v.append(c+basis*local);_n.append(Vector3.ZERO);_colors.append(Color(tone,tone,tone,1))
	var end_tip:=_v.size()
	_v.append(c+basis*Vector3(width*.06,length*.45,-thickness*.035));_n.append(Vector3.ZERO);_colors.append(Color(tone,tone,tone,1))
	for k in sides:
		_ix.append_array(PackedInt32Array([start_tip,lower+(k+1)%sides,lower+k]))
	for k in sides:
		var a:=lower+k;var b:=lower+(k+1)%sides;var c0:=upper+k;var d:=upper+(k+1)%sides
		_ix.append_array(PackedInt32Array([a,c0,b,b,c0,d]))
	for k in sides:
		_ix.append_array(PackedInt32Array([end_tip,upper+k,upper+(k+1)%sides]))
	_recompute_normals(first,_v.size())
