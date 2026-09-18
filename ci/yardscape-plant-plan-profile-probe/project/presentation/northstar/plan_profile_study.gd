extends Node2D
const Profiles=preload("res://presentation/northstar/foliage/plant_form_profiles.gd")
const Symbol=preload("res://presentation/northstar/plan/profiled_plan_symbol.gd")

var ash:Node2D
var palo:Node2D
var mode:="pair"
var sun_direction:=Vector2(.53,-.85).normalized()
var tree_record:Dictionary={"id":"tree-01","crown_radius":1.2,"seed":8125}

func _ready()->void:
	ash=Symbol.new();ash.name="FanTexPlanSymbol";ash.configure(tree_record,Profiles.fan_tex_ash_v2());ash.position=Vector2(360,360);add_child(ash)
	palo=Symbol.new();palo.name="DesertMuseumPlanSymbol";palo.configure(tree_record,Profiles.desert_museum_palo_verde_v2());palo.position=Vector2(920,360);add_child(palo)
	set_sun_direction(sun_direction);set_mode("pair");queue_redraw()

func set_mode(value:String)->void:
	mode=value
	ash.visible=value=="pair" or value=="ash"
	palo.visible=value=="pair" or value=="palo"
	queue_redraw()

func set_sun_direction(value:Vector2)->void:
	if value.length_squared()<1e-8:return
	sun_direction=value.normalized()
	if is_instance_valid(ash):ash.set_sun_direction(sun_direction)
	if is_instance_valid(palo):palo.set_sun_direction(sun_direction)

func _draw()->void:
	draw_rect(Rect2(Vector2.ZERO,Vector2(1280,720)),Color("f3efe5"))
	if mode=="pair":
		draw_rect(Rect2(78,95,564,530),Color(0.14,0.14,0.12,.20),false,1.0)
		draw_rect(Rect2(638,95,564,530),Color(0.14,0.14,0.12,.20),false,1.0)
