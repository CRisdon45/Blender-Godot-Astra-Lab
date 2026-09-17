extends SceneTree
## Startup bisection only. Writes one tiny marker before/after each potentially
## blocking operation so a killed worker still tells us the last completed stage.
var output: String
func mark(stage: String) -> void:
	var f:=FileAccess.open(output.path_join("stage-"+stage+".txt"),FileAccess.WRITE)
	if f!=null:
		f.store_string(stage+"\n");f.close()
func _initialize() -> void:
	output=OS.get_environment("YARDSCAPE_SHOOT_OUTPUT")
	if output.is_empty(): quit(2); return
	mark("01-enter")
	var script=load("res://presentation/northstar/shoot/compact_shoot.gd")
	mark("02-script-loaded")
	var shoot=script.new()
	mark("03-shoot-created")
	var tree={"id":"bootstrap-tree","x":8.25,"y":8.5,"base_elevation":0.45,"height":3.5,"crown_radius":1.2,"seed":8125}
	mark("04-before-configure")
	shoot.configure(tree)
	mark("05-configured")
	shoot.free()
	var scene=load("res://northstar-spatial-shoot.tscn")
	mark("06-scene-loaded")
	var study=scene.instantiate()
	mark("07-scene-instantiated")
	root.add_child(study)
	mark("08-added-to-tree")
	await process_frame
	mark("09-frame")
	study.queue_free()
	await process_frame
	mark("10-done")
	quit(0)
