extends "res://tests/capture_hero_water.gd"
var reflection_pixels: Dictionary={}

func compare_reflection_pixels() -> void:
    var planar:=Image.load_from_file(output.path_join("after-pool.png"))
    var fallback:=Image.load_from_file(output.path_join("diagnostic-probe-fallback.png"))
    if planar==null or fallback==null or planar.get_size()!=fallback.get_size():
        check(false,"Reflection pixel comparison missing same-size real images")
        return
    var total: float=0.0
    var changed: int=0
    var count: int=0
    # Interior water only, away from flames, foliage and the chair silhouettes.
    for y in range(15):
        for x in range(40):
            var px: int=int(planar.get_width()*(0.18+float(x)*0.22/40.0))
            var py: int=int(planar.get_height()*(0.55+float(y)*0.09/15.0))
            var a: Color=planar.get_pixel(px,py)
            var b: Color=fallback.get_pixel(px,py)
            var delta: float=(absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b))/3.0
            total+=delta
            changed+=1 if delta>1.0/255.0 else 0
            count+=1
    reflection_pixels={"samples":count,"mean_absolute_rgb_delta":total/count,"changed_fraction":float(changed)/count}
    check(total/count>0.5/255.0 and float(changed)/count>0.05,"Planar reflection had no measurable effect in actual water pixels")

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
            check(scene.probe.reflection_mask==0,"Probe overrides planar radiance")
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
            scene.set_planar_enabled(false)
            await capture(scene,"diagnostic-probe-fallback",poses[0][1],poses[0][2])
            check(scene.probe.reflection_mask==2,"Fallback probe not restored")
            compare_reflection_pixels()
            scene.set_planar_enabled(true)
            check(scene.probe.reflection_mask==0,"Planar mode did not re-isolate probe")
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
        "expected_images":22,"reflection_pixel_comparison":reflection_pixels,"extra_image":"planar-source.png","renderer":"Forward+ / software Vulkan",
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
