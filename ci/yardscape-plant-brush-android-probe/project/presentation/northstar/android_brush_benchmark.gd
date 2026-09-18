extends Node3D

const BrushTree=preload("res://presentation/northstar/foliage/profiled_batched_brush_tree.gd")
const Profiles=preload("res://presentation/northstar/foliage/plant_form_profiles.gd")
const ShrubProfiles=preload("res://presentation/northstar/foliage/shrub_form_profile.gd")

const RECIPE := "fixed-center-brush-card-cloud/2"
const TREE_COUNT := 6
const SHRUB_COUNT := 12
const WARMUP_SECONDS := 3.0
const SAMPLE_SECONDS := 12.0

var camera:Camera3D
var status_label:Label
var elapsed:=0.0
var orbit_offset:=0.0
var samples:=PackedFloat32Array()
var reported:=false
var visible_meshes:=0
var visible_triangles:=0

func _ready()->void:
	_build_environment()
	_build_plantings()
	_build_hud()
	print("YARDSCAPE_BENCHMARK_READY="+JSON.stringify({
		"recipe":RECIPE,
		"trees":TREE_COUNT,
		"shrubs":SHRUB_COUNT,
		"visible_meshes":visible_meshes,
		"visible_triangles":visible_triangles
	}))

func _process(delta:float)->void:
	elapsed+=delta
	var orbit_time:=maxf(0.0,elapsed-WARMUP_SECONDS)
	var angle:=orbit_offset-0.62+orbit_time*0.105
	camera.position=Vector3(cos(angle)*15.8,6.9,sin(angle)*15.8)
	camera.look_at(Vector3(0,1.65,-0.25),Vector3.UP)
	if elapsed>=WARMUP_SECONDS and not reported:
		samples.append(delta*1000.0)
		status_label.text="MEASURING RETAINED PLANTINGS  %0.1f / %0.0f s" % [minf(orbit_time,SAMPLE_SECONDS),SAMPLE_SECONDS]
	if elapsed>=WARMUP_SECONDS+SAMPLE_SECONDS and not reported:
		reported=true
		_emit_report()

func _unhandled_input(event:InputEvent)->void:
	if event is InputEventScreenDrag:
		orbit_offset-=event.relative.x*0.0035
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		orbit_offset-=event.relative.x*0.0035

func _build_environment()->void:
	var world:=WorldEnvironment.new()
	var environment:=Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color("e2decf")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("d9d3c4")
	environment.ambient_light_energy=0.82
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	world.environment=environment
	add_child(world)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-52,-31,0)
	sun.light_color=Color("fff1cf")
	sun.light_energy=1.18
	sun.shadow_enabled=true
	add_child(sun)
	var ground:=MeshInstance3D.new()
	var box:=BoxMesh.new();box.size=Vector3(19.0,0.18,12.0)
	ground.mesh=box;ground.position=Vector3(0,-0.11,0)
	var ground_material:=StandardMaterial3D.new()
	ground_material.albedo_color=Color("c8bd9d")
	ground_material.roughness=1.0
	ground.material_override=ground_material
	add_child(ground)
	camera=Camera3D.new()
	camera.fov=46.0
	camera.near=0.08
	camera.far=60.0
	add_child(camera)

func _build_plantings()->void:
	var tree_profile:=Profiles.fan_tex_ash_v2()
	var shrub_profile:=ShrubProfiles.dense_desert_mound_v2()
	for index in TREE_COUNT:
		var column:=index%3
		var row:=index/3
		var record:={
			"id":"benchmark-tree-%02d"%index,
			"x":-5.3+float(column)*5.3+float(row)*0.55,
			"y":2.25-float(row)*4.15,
			"base_elevation":0.0,
			"height":4.1+float(index%2)*0.22,
			"crown_radius":1.76+float((index+1)%3)*0.08,
			"seed":41011+index*977
		}
		_add_plant(record,tree_profile)
	for index in SHRUB_COUNT:
		var column:=index%6
		var row:=index/6
		var record:={
			"id":"benchmark-shrub-%02d"%index,
			"x":-6.4+float(column)*2.55+float(row)*0.28,
			"y":-0.10-float(row)*2.42,
			"base_elevation":0.0,
			"height":1.16+float(index%3)*0.07,
			"crown_radius":0.82+float((index+2)%4)*0.035,
			"seed":73001+index*613
		}
		_add_plant(record,shrub_profile)

func _add_plant(record:Dictionary,profile:Dictionary)->void:
	var plant:=BrushTree.new()
	plant.configure(record,profile)
	plant.set_light_values(Vector2(-0.48,-0.88))
	add_child(plant)
	assert(str(plant.stats.recipe)==RECIPE)
	visible_meshes+=int(plant.stats.visible_meshes)
	visible_triangles+=int(plant.stats.visible_triangles)

func _build_hud()->void:
	var layer:=CanvasLayer.new();add_child(layer)
	var panel:=ColorRect.new()
	panel.position=Vector2(28,26);panel.size=Vector2(720,126)
	panel.color=Color(0.075,0.084,0.071,0.88)
	layer.add_child(panel)
	var title:=Label.new()
	title.position=Vector2(52,43)
	title.text="YARD-SCAPE / RETAINED PLANTING ANDROID PROBE"
	title.add_theme_font_size_override("font_size",26)
	title.add_theme_color_override("font_color",Color("f3edda"))
	layer.add_child(title)
	var detail:=Label.new()
	detail.position=Vector2(53,80)
	detail.text="6 FAN-TEX TREES  +  12 LOW SHRUBS  /  36 MESHES  /  OPAQUE BRUSH CARDS"
	detail.add_theme_font_size_override("font_size",16)
	detail.add_theme_color_override("font_color",Color("bdc99f"))
	layer.add_child(detail)
	status_label=Label.new()
	status_label.position=Vector2(53,111)
	status_label.text="WARMING UP RENDER LOOP"
	status_label.add_theme_font_size_override("font_size",16)
	status_label.add_theme_color_override("font_color",Color("e6c981"))
	layer.add_child(status_label)

func _emit_report()->void:
	var ordered:=samples.duplicate();ordered.sort()
	var total:=0.0
	var over_16:=0
	var over_33:=0
	for value in samples:
		total+=value
		if value>16.667:over_16+=1
		if value>33.333:over_33+=1
	var average_ms:=total/maxf(1.0,float(samples.size()))
	var viewport_size:=get_viewport().get_visible_rect().size
	var report:={
		"schema":"yardscape-android-render-loop/1",
		"recipe":RECIPE,
		"engine":Engine.get_version_info().get("string","unknown"),
		"os":OS.get_name(),
		"os_version":OS.get_version(),
		"model":OS.get_model_name(),
		"rendering_method":RenderingServer.get_current_rendering_method(),
		"video_adapter":RenderingServer.get_video_adapter_name(),
		"video_vendor":RenderingServer.get_video_adapter_vendor(),
		"viewport_width":roundi(viewport_size.x),
		"viewport_height":roundi(viewport_size.y),
		"warmup_seconds":WARMUP_SECONDS,
		"sample_seconds":SAMPLE_SECONDS,
		"sample_count":samples.size(),
		"average_ms":snappedf(average_ms,0.001),
		"average_fps":snappedf(1000.0/maxf(average_ms,0.001),0.01),
		"median_ms":snappedf(_percentile(ordered,0.50),0.001),
		"p95_ms":snappedf(_percentile(ordered,0.95),0.001),
		"p99_ms":snappedf(_percentile(ordered,0.99),0.001),
		"max_ms":snappedf(ordered[ordered.size()-1] if not ordered.is_empty() else 0.0,0.001),
		"frames_over_16_667_ms":over_16,
		"frames_over_33_333_ms":over_33,
		"trees":TREE_COUNT,
		"shrubs":SHRUB_COUNT,
		"plantings":TREE_COUNT+SHRUB_COUNT,
		"visible_meshes":visible_meshes,
		"visible_triangles":visible_triangles
	}
	status_label.text="MEASUREMENT COMPLETE  /  %0.1f FPS AVG  /  P95 %0.2f ms"%[report.average_fps,report.p95_ms]
	status_label.add_theme_color_override("font_color",Color("a9d39c"))
	print("YARDSCAPE_BENCHMARK_JSON="+JSON.stringify(report))

func _percentile(ordered:PackedFloat32Array,fraction:float)->float:
	if ordered.is_empty():return 0.0
	var index:=clampi(ceili(float(ordered.size())*fraction)-1,0,ordered.size()-1)
	return ordered[index]
