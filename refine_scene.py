import bpy, os, math
from mathutils import Vector
OUT=os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.open_mainfile(filepath=os.path.join(OUT,'pool_recreation.blend'))
s=bpy.context.scene
c=s.camera; c.location=(5,-9,3.3); c.rotation_euler=(Vector((0,4,1.6))-c.location).to_track_quat('-Z','Y').to_euler(); c.data.lens=25
nt=s.world.node_tree; nt.nodes.clear(); bg=nt.nodes.new('ShaderNodeBackground'); bg.inputs['Color'].default_value=(.46,.70,1,1); bg.inputs['Strength'].default_value=.65; out=nt.nodes.new('ShaderNodeOutputWorld'); nt.links.new(bg.outputs[0],out.inputs[0])
sun=bpy.data.objects['Afternoon sunlight']; sun.rotation_euler=(math.radians(25),math.radians(-30),math.radians(-110)); sun.data.energy=3
s.view_settings.exposure=.65
s.render.resolution_percentage=100; s.cycles.samples=56
for o in bpy.data.objects:
 if o.name.startswith('Terrace ivory roof'):o.hide_render=True
s.render.filepath=os.path.join(OUT,'pool_recreation.png')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'pool_recreation.blend'))
bpy.ops.render.render(write_still=True)
