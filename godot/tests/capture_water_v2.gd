extends "res://tests/capture_hero_water.gd"
## Compare preserved previous water to the new opt-in study with identical poses and phase.
func run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="):
            output=arg.trim_prefix("--output=")
    if not output.is_absolute_path() or DisplayServer.get_name()=="headless":
        push_error("V2_REQUIRES_DISPLAY_AND_ABSOLUTE_OUTPUT")
        quit(1)
        return
    check(DirAccess.make_dir_recursive_absolute(output)==OK,"Output creation failed")
    var poses: Array=[
        ["pool",Vector3(2.4,2.7,4.8),Vector3(0,0.65,-2.7)],
        ["grazing",Vector3(-3.3,1.1,2.2),Vector3(0,0.45,-4.3)],
        ["sheer",Vector3(-3.8,1.8,-1.2),Vector3(-2.65,0.75,-4.7)],
        ["courtyard",Vector3(4,3.3,10),Vector3(0,1.8,-3)],
        ["shelf",Vector3(4.6,4.8,3.9),Vector3(0,0.05,-0.6)]]
    for version in ["before","after"]:
        var path: String="res://courtyard_hero_water.tscn" if version=="before" else "res://courtyard_water_v2.tscn"
        var packed:=load(path) as PackedScene
        if packed==null:
            errors.append("Scene missing: "+path)
            continue
        var scene=packed.instantiate()
        if not scene.has_method("set_water_phase"):
            errors.append("Actual script failed to load: "+path)
            scene.free()
            continue
        root.add_child(scene)
        await frames(12)
        scene.set_process(false)
        scene.set_illustration(true)
        check(scene.water.snapshot().error.is_empty(),version+": binding error")
        check(scene.water.snapshot().impact_segments_xz.size()==2,version+": contacts lost")
        for index in range(3 if version=="before" else 5):
            var pose=poses[index]
            await capture(scene,version+"-"+pose[0],pose[1],pose[2])
        if version=="after":
            check(scene.fixed_foliage.size()==12,"Reflection/main foliage geometry differs")
            check(scene.reflection_camera.cull_mask==4,"Reflection layer isolation failed")
            check((scene.water._pool.layers&4)==0,"Recursive water reflection")
            check(int(scene.water._pool_material.get_shader_parameter("impact_count"))==2,"Shader swap lost contacts")
            check(scene.reflection_objects>10,"Reflected scene incomplete")
            check(is_equal_approx(scene.reflection_camera.global_position.y+scene.camera.global_position.y,2.0*scene.water.snapshot().water_level),"Camera not mirrored about measured water")
            check(scene.reflection_view.size.x<=768,"Unbounded reflection resolution")
            scene.water.set_flow(false)
            await capture(scene,"after-flow-off",poses[0][1],poses[0][2])
            check(not scene.water.snapshot().flow_enabled,"Flow-off not bound")
            scene.water.set_flow(true)
            for entry in [[1,"depth"],[2,"transmission"],[3,"reflection"],[4,"receiver"]]:
                scene.water._pool_material.set_shader_parameter("debug_view",entry[0])
                await capture(scene,"diagnostic-"+entry[1],poses[0][1],poses[0][2])
            for material in scene.basin_materials:
                material.set_shader_parameter("caustic_daylight",0.0)
            await capture(scene,"diagnostic-receiver-no-caustics",poses[0][1],poses[0][2])
            for material in scene.basin_materials:
                material.set_shader_parameter("caustic_daylight",1.0)
            scene.water._pool_material.set_shader_parameter("debug_view",0)
            scene.water._pool_material.set_shader_parameter("planar_enabled",false)
            await capture(scene,"diagnostic-probe-fallback",poses[0][1],poses[0][2])
            scene.water._pool_material.set_shader_parameter("planar_enabled",true)
            scene.set_night(true)
            await frames(8)
            await capture(scene,"night-pool",poses[0][1],poses[0][2])
            scene.set_night(false)
            await frames(8)
            for step in range(6):
                await capture(scene,"motion-%02d"%step,poses[0][1],poses[0][2],2.0+step*0.24)
            for material in scene.basin_materials:
                check(is_equal_approx(float(material.get_shader_parameter("water_time")),3.2),"Receiver clock mismatch")
            var reflected: Image=scene.reflection_view.get_texture().get_image()
            check(reflected!=null and not reflected.is_empty(),"Empty reflection buffer")
            if reflected!=null and not reflected.is_empty():
                check(reflected.save_png(output.path_join("planar-source.png"))==OK,"Reflection PNG failed")
        scene.queue_free()
        scene=null
        packed=null
        await frames(8)
    await frames(8)
    var report: Dictionary={"images":images,"errors":errors,"engine":Engine.get_version_info(),
        "expected_images":22,"extra_image":"planar-source.png","renderer":"Forward+ / software Vulkan",
        "visual_acceptance":"pending_user_review","performance_certified":false}
    var file:=FileAccess.open(output.path_join("water-v2-review.json"),FileAccess.WRITE)
    if file==null:
        push_error("V2_MANIFEST_WRITE_FAILED")
        quit(1)
        return
    file.store_string(JSON.stringify(report,"\t"))
    file.close()
    print("WATER_V2_DONE ",JSON.stringify({"images":images.size(),"errors":errors}))
    quit(0 if errors.is_empty() and images.size()==22 else 1)
