class_name PlantInstance
extends RefCounted
## Placement identity, not a MeshInstance or mutable species definition.
## Translation + yaw only: brush shader/1 does not support arbitrary instance scaling.

var instance_id: String
var species: String
var seed: int
var stage: int
var placement: Transform3D
var revision: int = 0

static func create(id: String, species_id: String, variant_seed: int, growth_stage: int,
		position_m: Vector3, yaw_radians: float = 0.0) -> PlantInstance:
	if id.is_empty() or species_id.is_empty() or variant_seed < 0 or variant_seed > 2147483647:
		push_error("Invalid plant identity")
		return null
	if growth_stage < 0 or growth_stage > 2 or not position_m.is_finite() or not is_finite(yaw_radians):
		push_error("Invalid plant placement or illustrative growth stage")
		return null
	var result := PlantInstance.new()
	result.instance_id = id
	result.species = species_id
	result.seed = variant_seed
	result.stage = growth_stage
	result.placement = Transform3D(Basis(Vector3.UP, yaw_radians), position_m)
	return result

func set_stage(value: int) -> bool:
	if value < 0 or value > 2:
		return false
	if stage != value:
		stage = value
		revision += 1
	return true

func variant_key() -> String:
	return "%s_s%d_g%d" % [species, seed, stage]

func to_record() -> Dictionary:
	return {"schema": "plant-instance/1", "instance_id": instance_id, "species": species,
		"seed": seed, "stage": stage, "position_m": [placement.origin.x, placement.origin.y, placement.origin.z],
		"yaw_radians": placement.basis.get_euler().y, "growth_domain": "illustrative_maturity_0_to_1"}

static func from_record(value: Dictionary) -> PlantInstance:
	if value.get("schema") != "plant-instance/1" or value.get("growth_domain") != "illustrative_maturity_0_to_1":
		return null
	if not value.get("instance_id") is String or not value.get("species") is String:
		return null
	var position: Variant = value.get("position_m")
	if not position is Array or position.size() != 3:
		return null
	for number in position:
		if not (number is float or number is int) or not is_finite(float(number)):
			return null
	for key in ["seed", "stage"]:
		var number: Variant = value.get(key)
		if not (number is float or number is int) or not is_finite(float(number)) or float(number) != floorf(float(number)):
			return null
	var yaw_value: Variant = value.get("yaw_radians")
	if not (yaw_value is float or yaw_value is int) or not is_finite(float(yaw_value)):
		return null
	return create(value.instance_id, value.species, int(value.seed), int(value.stage),
		Vector3(float(position[0]), float(position[1]), float(position[2])), float(yaw_value))
