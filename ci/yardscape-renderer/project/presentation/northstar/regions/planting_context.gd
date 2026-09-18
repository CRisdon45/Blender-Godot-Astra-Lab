extends RefCounted
## Bounded receiver context from immutable illustrative plant descriptors.
## Only higher/later supported crowns can shade a lower receiver. No nearest-
## neighbor planting, moved positions, reseeded geometry, or silent truncation.
const MAX_NEIGHBORS=8

static func describe(plant) -> Dictionary:
	return {"id":str(plant.record[0]),"at":Vector2(plant.record[1],24.-plant.record[2]),
		"radius":float(plant.record[3]),"height":float(plant.record[4]),
		"seed":float(absi(str(plant.record[0]).hash())%1000),
		"family":0 if plant.record[5]=="tree" else 1 if plant.record[5]=="shrub" else 2,
		"lobes":plant.crown_lobes.duplicate()}

static func build(records: Array, sun: Vector2, slope: float) -> Dictionary:
	if not sun.is_finite() or sun.length_squared()<1e-9 or not is_finite(slope) or slope<0.:
		return {"ok":false,"reason":"invalid_light"}
	if records.size()>128:return {"ok":false,"reason":"record_limit"}
	var ids: Dictionary={}
	for r in records:
		if not r is Dictionary or not r.has_all(["id","at","radius","height","seed","family","lobes"]):
			return {"ok":false,"reason":"invalid_record"}
		if not r.at is Vector2 or not r.lobes is PackedVector4Array:
			return {"ok":false,"reason":"invalid_record"}
		if not r.id is String:return {"ok":false,"reason":"invalid_id"}
		for key in ["radius","height","seed","family"]:
			if typeof(r[key]) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(r[key]):
				return {"ok":false,"reason":"invalid_dimensions"}
		if r.family not in [0,1,2]:return {"ok":false,"reason":"invalid_family"}
		if str(r.id).is_empty() or ids.has(r.id):return {"ok":false,"reason":"invalid_id"}
		ids[r.id]=true
		if not r.at.is_finite() or not is_finite(r.radius) or r.radius<=0. or not is_finite(r.height) or r.height<0.:
			return {"ok":false,"reason":"invalid_dimensions"}
		# A receiver-only descriptor has no casting silhouette. Its radius is
		# used for coordinates/culling, never as a replacement alpha mask.
		if r.has("receiver_only") and not r.receiver_only is bool:
			return {"ok":false,"reason":"invalid_receiver_flag"}
		if (r.lobes.is_empty() and not r.get("receiver_only",false)) or r.lobes.size()>10:
			return {"ok":false,"reason":"invalid_lobes"}
		for lobe in r.lobes:
			if not lobe.is_finite() or lobe.z<=0. or Vector2(lobe.x,lobe.y).length()+lobe.z>1.02:return {"ok":false,"reason":"invalid_lobes"}
	var receivers: Dictionary={}
	var maximum:=0
	for i in records.size():
		var receiver: Dictionary=records[i]
		var casts:=PackedVector4Array();var contacts:=PackedVector4Array();var metadata:=PackedVector4Array();var lobes:=PackedVector4Array()
		var sources: Array[String]=[]
		for j in records.size():
			var caster: Dictionary=records[j]
			if caster.get("receiver_only",false):continue
			# Equal-height tie follows the existing draw sequence, not ID sorting.
			if caster.height<receiver.height or (caster.height==receiver.height and j<=i):continue
			var delta: Vector2=caster.at-receiver.at
			var projection: Vector2=delta-sun*(caster.height-receiver.height)*slope
			var bound: float=(caster.radius+receiver.radius)*1.15
			if minf(delta.length(),projection.length())>bound:continue
			if sources.size()>=MAX_NEIGHBORS:return {"ok":false,"reason":"neighbor_limit","receiver":receiver.id}
			sources.append(caster.id)
			var centre: Vector2=projection/receiver.radius
			var contact: Vector2=delta/receiver.radius
			var scale: float=caster.radius/receiver.radius
			casts.append(Vector4(centre.x,centre.y,scale,.78))
			contacts.append(Vector4(contact.x,contact.y,scale,.58))
			metadata.append(Vector4(caster.seed,caster.lobes.size(),caster.family,0.))
			var padded: PackedVector4Array=caster.lobes.duplicate();padded.resize(10);lobes.append_array(padded)
		maximum=maxi(maximum,sources.size())
		casts.resize(8);contacts.resize(8);metadata.resize(8);lobes.resize(80)
		receivers[receiver.id]={"count":sources.size(),"cast":casts,"contact":contacts,"meta":metadata,"lobes":lobes,"sources":sources}
	return {"ok":true,"receivers":receivers,"maximum":maximum,"identity":var_to_bytes([records,sun,slope]).hex_encode().sha256_text()}

static func apply(plant, data: Dictionary, enabled: bool) -> void:
	for material in [plant.paint,plant.marks.material]:
		material.set_shader_parameter("neighbor_count",data.count if enabled else 0)
		if not enabled:continue
		material.set_shader_parameter("neighbor_cast",data.cast)
		material.set_shader_parameter("neighbor_contact",data.contact)
		material.set_shader_parameter("neighbor_meta",data.meta)
		material.set_shader_parameter("neighbor_lobes",data.lobes)
