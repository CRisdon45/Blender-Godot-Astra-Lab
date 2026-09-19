extends Node3D

const BrushTree=preload("res://presentation/northstar/foliage/profiled_batched_brush_tree.gd")
const Profiles=preload("res://presentation/northstar/foliage/plant_form_profiles.gd")
const ShrubProfiles=preload("res://presentation/northstar/foliage/shrub_form_profile.gd")

const RECIPE := "fixed-center-brush-card-cloud/2"
const SURFACE_STYLE := "northstar-muted-macro-wash/1"
const FAN_TEX_COUNT := 3
const PALO_VERDE_COUNT := 3
const TREE_COUNT := FAN_TEX_COUNT+PALO_VERDE_COUNT
const SHRUB_COUNT := 12
const EXPECTED_VISIBLE_MESHES := 36
const EXPECTED_VISIBLE_TRIANGLES := 44718
const WARMUP_SECONDS := 3.0
const SAMPLE_SECONDS := 12.0
const VISUAL_COLOR_MIN := 32
const VISUAL_READY_ATTEMPTS := 45
const EVIDENCE_MAX_WIDTH := 960

var camera:Camera3D
var status_label:Label
var elapsed:=0.0
var orbit_offset:=0.0
var samples:=PackedFloat32Array()
var reported:=false
var visual_ready:=false
var visible_meshes:=0
var visible_triangles:=0

func _ready()->void:
	_build_environment()
	_build_plantings()
	_build_hud()
	_confirm_visual_ready()

func _process(delta:float)->void:
	var angle:=orbit_offset-0.62
	if not visual_ready:
		camera.position=Vector3(cos(angle)*15.8,6.9,sin(angle)*15.8)
		camera.look_at(Vector3(0,1.65,-0.25),Vector3.UP)
		return
	elapsed+=delta
	var orbit_time:=maxf(0.0,elapsed-WARMUP_SECONDS)
	angle=orbit_offset-0.62+orbit_time*0.105
	camera.position=Vector3(cos(angle)*15.8,6.9,sin(angle)*15.8)
	camera.look_at(Vector3(0,1.65,-0.25),Vector3.UP)
	if elapsed>=WARMUP_SECONDS and not reported:
		samples.append(delta*1000.0)
		status_label.text="MEASURING RETAINED PLANTINGS  %0.1f / %0.0f s" % [minf(orbit_time,SAMPLE_SECONDS),SAMPLE_SECONDS]
	if elapsed>=WARMUP_SECONDS+SAMPLE_SECONDS and not reported:
		reported=true
		_emit_report()

func _confirm_visual_ready()->void:
	for attempt in VISUAL_READY_ATTEMPTS:
		await RenderingServer.frame_post_draw
		var image:=get_viewport().get_texture().get_image()
		var sampled_colors:=_sampled_color_count(image)
		if sampled_colors>=VISUAL_COLOR_MIN:
			var capture:=_save_image(image,"yardscape-ready.png",sampled_colors)
			if int(capture.save_error)!=OK:
				break
			print("YARDSCAPE_BENCHMARK_READY="+JSON.stringify({
				"recipe":RECIPE,
				"surface_style":SURFACE_STYLE,
				"fan_tex_trees":FAN_TEX_COUNT,
				"palo_verde_trees":PALO_VERDE_COUNT,
				"trees":TREE_COUNT,
				"shrubs":SHRUB_COUNT,
				"visible_meshes":visible_meshes,
				"visible_triangles":visible_triangles,
				"sampled_colors":sampled_colors,
				"attempt":attempt+1,
				"user_data_dir":OS.get_user_data_dir()
			}))
			var measuring_valid:bool=await _save_measuring_capture()
			if not measuring_valid:
				return
			samples.clear()
			elapsed=0.0
			visual_ready=true
			return
	push_error("Rendered viewport never reached visual evidence threshold")
	print("YARDSCAPE_VISUAL_READY_FAILED="+JSON.stringify({"minimum":VISUAL_COLOR_MIN,"attempts":VISUAL_READY_ATTEMPTS}))
	get_tree().quit(2)

func _save_measuring_capture()->bool:
	await RenderingServer.frame_post_draw
	var image:=get_viewport().get_texture().get_image()
	var capture:=_save_image(image,"yardscape-measuring.png",_sampled_color_count(image))
	if int(capture.save_error)!=OK or int(capture.sampled_colors)<VISUAL_COLOR_MIN:
		push_error("Measuring viewport capture is invalid")
		get_tree().quit(2)
		return false
	print("YARDSCAPE_MEASURING_IMAGE="+JSON.stringify(capture))
	return true

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
	var ash_profile:=Profiles.fan_tex_ash_v2()
	var palo_profile:=Profiles.desert_museum_palo_verde_v2()
	var shrub_profile:=ShrubProfiles.dense_desert_mound_v2()
	for index in TREE_COUNT:
		var column:=index%3
		var row:=index/3
		var is_ash:=index%2==0
		var species_index:=index/2
		var tree_profile:Dictionary=ash_profile if is_ash else palo_profile
		var record:={
			"id":("benchmark-fan-tex-%02d" if is_ash else "benchmark-palo-verde-%02d")%species_index,
			"x":-5.3+float(column)*5.3+float(row)*0.55,
			"y":2.25-float(row)*4.15,
			"base_elevation":0.0,
			"height":4.18+float(species_index%2)*0.16 if is_ash else 3.72+float(species_index%2)*0.14,
			"crown_radius":1.78+float(species_index%2)*0.08 if is_ash else 1.92+float(species_index%2)*0.09,
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
	assert(visible_meshes==EXPECTED_VISIBLE_MESHES)
	assert(visible_triangles==EXPECTED_VISIBLE_TRIANGLES)

func _add_plant(record:Dictionary,profile:Dictionary)->void:
	var plant:=BrushTree.new()
	plant.configure(record,profile)
	plant.set_light_values(Vector2(-0.48,-0.88))
	add_child(plant)
	assert(str(plant.stats.recipe)==RECIPE)
	assert(str(plant.stats.surface_style)==SURFACE_STYLE)
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
	detail.text="3 FAN-TEX  +  3 PALO VERDE  +  12 SHRUBS  /  MUTED MACRO WASH"
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
		"surface_style":SURFACE_STYLE,
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
		"fan_tex_trees":FAN_TEX_COUNT,
		"palo_verde_trees":PALO_VERDE_COUNT,
		"trees":TREE_COUNT,
		"shrubs":SHRUB_COUNT,
		"plantings":TREE_COUNT+SHRUB_COUNT,
		"visible_meshes":visible_meshes,
		"visible_triangles":visible_triangles
	}
	status_label.text="MEASUREMENT COMPLETE  /  %0.1f FPS AVG  /  P95 %0.2f ms"%[report.average_fps,report.p95_ms]
	status_label.add_theme_color_override("font_color",Color("a9d39c"))
	await RenderingServer.frame_post_draw
	var image:=get_viewport().get_texture().get_image()
	report.visual_capture=_save_image(image,"yardscape-complete.png",_sampled_color_count(image))
	if int(report.visual_capture.save_error)!=OK or int(report.visual_capture.sampled_colors)<VISUAL_COLOR_MIN:
		push_error("Completion viewport capture is invalid")
		get_tree().quit(2)
		return
	print("YARDSCAPE_BENCHMARK_JSON="+JSON.stringify(report))

func _save_image(image:Image,file_name:String,sampled_colors:int)->Dictionary:
	if image.get_width()>EVIDENCE_MAX_WIDTH:
		var target_height:=roundi(float(image.get_height())*float(EVIDENCE_MAX_WIDTH)/float(image.get_width()))
		image.resize(EVIDENCE_MAX_WIDTH,target_height,Image.INTERPOLATE_BILINEAR)
	var save_error:=image.save_png("user://"+file_name)
	return {
		"file":file_name,
		"width":image.get_width(),
		"height":image.get_height(),
		"sampled_colors":sampled_colors,
		"save_error":save_error
	}

func _sampled_color_count(image:Image)->int:
	if image.is_empty():return 0
	var colors:={}
	for y in range(0,image.get_height(),8):
		for x in range(0,image.get_width(),8):
			colors[image.get_pixel(x,y).to_rgba32()]=true
			if colors.size()>=256:return colors.size()
	return colors.size()

func _percentile(ordered:PackedFloat32Array,fraction:float)->float:
	if ordered.is_empty():return 0.0
	var index:=clampi(ceili(float(ordered.size())*fraction)-1,0,ordered.size()-1)
	return ordered[index]
