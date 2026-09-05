extends Node3D

var camera: Camera3D
var origin: Transform3D
var target=Vector3(0,1.8,-3)
var dragging=false

func _ready() -> void:
	camera=get_node("Reference camera")
	origin=camera.transform
	if "--capture" in OS.get_cmdline_user_args():capture_validation()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode==KEY_R:camera.transform=origin
		if event.keycode==KEY_I:
			var overlay=get_node("Illustration finish")
			overlay.visible=not overlay.visible
			get_node("Reference camera/Fine architectural contours").visible=overlay.visible
		if event.keycode==KEY_F12:save_capture("res://captures/manual.png")
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_RIGHT:dragging=event.pressed
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:camera.position=target+(camera.position-target)*0.94
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:camera.position=target+(camera.position-target)*1.06
	if event is InputEventMouseMotion and dragging:
		var offset=camera.position-target
		offset=offset.rotated(Vector3.UP,-event.relative.x*0.004)
		offset=offset.rotated(camera.global_basis.x,-event.relative.y*0.004)
		camera.position=target+offset; camera.look_at(target)

func save_capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var result=get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURE_SAVED ",path," result=",result)

func capture_validation() -> void:
	for i in range(45):await get_tree().process_frame
	await save_capture("res://captures/godot_courtyard.png")
	for i in range(40):await get_tree().process_frame
	await save_capture("res://captures/godot_animation_check.png")
	print("EDITABLE_SCENE_CAPTURE_OK")
	get_tree().quit()
