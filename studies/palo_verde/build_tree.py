"""Deterministic, editable palo verde study. Run with Blender 4.5.3 LTS."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import random
import sys

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
SEED = 452603
RNG = random.Random(SEED)
TAU = math.tau


def srgb(v):
    return v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4


def color(hex_value):
    s = hex_value.lstrip('#')
    return tuple(srgb(int(s[i:i+2], 16) / 255) for i in (0, 2, 4)) + (1.,)


PALETTES = {
    'PV_Bark': ['#62733c', '#6d8043', '#7b8c4c', '#869653'],
    'PV_Leaves': ['#566b2b', '#668431', '#7b9838', '#8ba241', '#9caf4a'],
    'PV_Blossoms': ['#e5bc29', '#f1cb34', '#ffdc48', '#f6d044', '#fbe263'],
    'PV_Grass': ['#6a7c35', '#829644', '#92a24a', '#a6ae57'],
    'PV_FallenPetals': ['#e6c137', '#f5d24a'],
}


class MeshBatch:
    def __init__(self, name):
        self.name = name
        self.vertices = []
        self.faces = []
        self.colors = []
        self.palette = [color(c) for c in PALETTES[name]]

    def add(self, vertices, faces, tint=None):
        offset = len(self.vertices)
        self.vertices.extend(tuple(v) for v in vertices)
        self.faces.extend(tuple(offset + i for i in f) for f in faces)
        chosen = self.palette[RNG.randrange(len(self.palette))] if tint is None else tint
        self.colors.extend([chosen] * len(vertices))

    def finish(self, collection):
        mesh = bpy.data.meshes.new(self.name + '_Mesh')
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.update()
        layer = mesh.color_attributes.new(name='Col', type='FLOAT_COLOR', domain='POINT')
        layer.data.foreach_set('color', [v for c in self.colors for v in c])
        mesh.color_attributes.active_color = layer
        obj = bpy.data.objects.new(self.name, mesh)
        collection.objects.link(obj)
        mat = bpy.data.materials.new(self.name + '_Material')
        mat.use_nodes = True
        mat.diffuse_color = (1, 1, 1, 1)
        node = mat.node_tree.nodes.get('Principled BSDF')
        node.inputs['Roughness'].default_value = .9
        node.inputs['Specular IOR Level'].default_value = .12
        vc = mat.node_tree.nodes.new('ShaderNodeVertexColor')
        vc.layer_name = 'Col'
        mat.node_tree.links.new(vc.outputs['Color'], node.inputs['Base Color'])
        obj.data.materials.append(mat)
        for p in mesh.polygons:
            p.use_smooth = self.name == 'PV_Bark'
        obj['asset_role'] = self.name.removeprefix('PV_').lower()
        return obj


def catmull(points, radii, steps=5):
    p = [Vector(points[0])] + [Vector(v) for v in points] + [Vector(points[-1])]
    result, rs = [], []
    for i in range(1, len(p)-2):
        a, b, c, d = p[i-1:i+3]
        for k in range(steps):
            t = k / steps
            result.append(.5 * ((2*b) + (-a+c)*t + (2*a-5*b+4*c-d)*t*t + (-a+3*b-3*c+d)*t*t*t))
            rs.append(radii[i-1] * (1-t) + radii[i] * t)
    result.append(Vector(points[-1]))
    rs.append(radii[-1])
    return result, rs


def tube(batch, points, radii, sides=8, steps=4):
    pts, rs = catmull(points, radii, steps)
    verts, faces = [], []
    for j, (p, r) in enumerate(zip(pts, rs)):
        direction = (pts[min(j+1, len(pts)-1)] - pts[max(0, j-1)]).normalized()
        axis = direction.cross(Vector((0, 1, 0))).normalized()
        if axis.length < .1:
            axis = direction.cross(Vector((1, 0, 0))).normalized()
        other = direction.cross(axis).normalized()
        if j == 0 and abs(p.z) < .0001:
            # An angled trunk still meets a flat ground-contact plane at its pivot.
            axis, other = Vector((1,0,0)), Vector((0,1,0))
        for i in range(sides):
            a = TAU * i / sides
            ridge = 1 + .045 * math.sin(a*3+j*.3)
            verts.append(p + ridge*r*(axis*math.cos(a)+other*math.sin(a)))
    for j in range(len(pts)-1):
        for i in range(sides):
            a = j*sides+i
            b = j*sides+(i+1) % sides
            faces.append((a, b, b+sides, a+sides))
    faces.append(tuple(reversed(range(sides))))
    faces.append(tuple((len(pts)-1)*sides+i for i in range(sides)))
    batch.add(verts, faces)


def direction():
    z = RNG.uniform(-1, 1)
    a = RNG.uniform(0, TAU)
    r = math.sqrt(1-z*z)
    return Vector((r*math.cos(a), r*math.sin(a), z))


def leaf(batch, center, axis, length):
    # Folded geometric leaflets, no alpha cards and no camera-facing billboards.
    axis = axis.normalized()
    across = axis.cross(direction()).normalized() * length * .38
    normal = axis.cross(across).normalized()
    verts = [center-axis*length*.5, center+across, center+axis*length*.5,
             center-across, center+normal*length*.13]
    batch.add(verts, [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4)])


def flower(batch, center, normal, size):
    normal = normal.normalized()
    a = normal.cross(Vector((0, 0, 1))).normalized()
    if a.length < .1:
        a = Vector((1, 0, 0))
    b = normal.cross(a).normalized()
    phase = RNG.random()*TAU
    verts, faces = [], []
    for i in range(5):
        angle = phase + i*TAU/5
        out = a*math.cos(angle)+b*math.sin(angle)
        side = normal.cross(out)
        start = len(verts)
        verts.extend([center+out*size*.10, center+out*size*.6-side*size*.31,
                      center+out*size+normal*size*.17, center+out*size*.6+side*size*.31])
        faces.extend([(start, start+1, start+2), (start, start+2, start+3)])
    batch.add(verts, faces)


def foliage_lobe(leaves, flowers, center, scale):
    # Dense overlapping radial sprays form shaded lobes while retaining branch gaps.
    for _ in range(225):
        outward = direction()
        radial = RNG.random() ** .36
        p = center + Vector(tuple(outward[i]*scale[i]*radial for i in range(3)))
        length = RNG.uniform(.055, .105)
        leaf(leaves, p, outward + Vector((.2, 0, .35)), length)
        if RNG.random() < .52:
            leaf(leaves, p+Vector((.025, .012, .04)), outward+Vector((0, .3, .25)), length*.72)
    for _ in range(105):
        outward = direction()
        radial = RNG.uniform(.55, 1.05)
        p = center + Vector(tuple(outward[i]*scale[i]*radial for i in range(3)))
        flower(flowers, p, outward+Vector((0, -.2, .3)), RNG.uniform(.033, .057))


def collection(name):
    col = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(col)
    return col


def make_tree():
    col = collection('PaloVerde_Authored')
    root = bpy.data.objects.new('PaloVerde_Root', None)
    col.objects.link(root)
    root['asset_id'] = 'palo_verde_authored_452603'
    root['species_visual_reference'] = 'Palo verde, flowering; species cultivar unconfirmed'
    root['seed'] = SEED
    root['units'] = 'meters'
    root['pivot'] = 'trunk_ground_contact'
    batches = {name: MeshBatch(name) for name in ['PV_Bark', 'PV_Leaves', 'PV_Blossoms']}
    bark, leaves, flowers = batches.values()
    tube(bark, [(0,0,0),(-.12,.02,.42),(-.30,0,.91),(-.40,.01,1.40),(-.43,.05,1.85)],
         [.32,.30,.255,.225,.15], sides=14, steps=6)
    # Deliberate scaffold: short trunk, low forks, broad asymmetric umbrella.
    scaffold = [
        ([(-.28,0,.85),(-1.05,-.02,1.8),(-2.25,-.10,2.8),(-3.65,-.15,3.65),(-4.8,-.18,4.02)], .20),
        ([(-.35,.02,1.1),(-1.0,.32,2.35),(-1.55,.50,3.60),(-2.1,.65,4.75),(-2.0,.7,5.8)], .19),
        ([(-.38,.04,1.3),(-.2,-.1,2.55),(-.42,-.15,3.8),(-.55,-.3,5.2),(-.3,-.4,6.0)], .18),
        ([(-.32,0,1.0),(.7,-.12,1.95),(1.75,-.3,2.95),(3.3,-.45,3.75),(4.7,-.55,4.4)], .23),
        ([(-.40,.03,1.4),(.12,.65,2.65),(1.0,1.2,3.9),(1.9,1.5,4.9),(2.1,1.65,5.6)], .17),
        ([(-.37,.03,1.2),(-.65,-.85,2.2),(-1.05,-1.7,3.2),(-1.2,-2.65,4.0),(-1.4,-3.3,4.6)], .145),
        ([(-.35,.08,1.45),(-1.1,1.0,2.5),(-2.0,2.0,3.55),(-2.7,3.0,4.2),(-3.0,3.5,4.65)], .15),
        ([(-.3,.02,1.1),(.55,-.85,2.0),(1.3,-1.7,2.9),(2.25,-2.6,3.7),(3.0,-3.0,4.3)], .16),
    ]
    for index, (pts, radius) in enumerate(scaffold):
        tube(bark, pts, [radius,radius*.79,radius*.48,radius*.24,.018], sides=10, steps=6)
        # Secondary and tertiary branch endpoints are attached to the real scaffold.
        for level in (2, 3, 4):
            base = Vector(pts[level])
            parent_dir = (base-Vector(pts[level-1])).normalized()
            for side in (-1, 1):
                lateral = Vector((-parent_dir.y, parent_dir.x, RNG.uniform(.5, 1.1))).normalized()
                span = RNG.uniform(.65, 1.15) if level != 4 else .55
                tip = base + lateral*side*span + parent_dir*.45 + Vector((0,0,.42))
                mid = base.lerp(tip,.54)+Vector((0,0,.12))
                tube(bark, [base,mid,tip], [radius*(.23 if level==2 else .12),.016,.006], sides=6, steps=3)
                lobe_scale = Vector((RNG.uniform(.48,.69),RNG.uniform(.42,.65),RNG.uniform(.38,.61)))
                foliage_lobe(leaves,flowers,tip,lobe_scale)
                # Smaller outer sprays add ragged fine tips rather than solid sphere edges.
                for twig in range(2):
                    twig_tip = tip + direction()*RNG.uniform(.35,.65)+Vector((0,0,.15))
                    tube(bark,[tip,tip.lerp(twig_tip,.6),twig_tip],[.008,.004,.0015],sides=5,steps=2)
                    foliage_lobe(leaves,flowers,twig_tip,lobe_scale*.53)
        foliage_lobe(leaves,flowers,Vector(pts[-1]),Vector((.63,.60,.60)))
    objects = []
    for batch in batches.values():
        obj = batch.finish(col)
        obj.parent = root
        objects.append(obj)
    return root, objects


def ground_height(x,y):
    return -.035 + .035*math.sin(x*.23)*math.sin(y*.17)


def make_ground():
    col = collection('Meadow_Set')
    mat = bpy.data.materials.new('Meadow_Ground')
    mat.diffuse_color = color('#7e9148')
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = color('#7e9148')
    bsdf.inputs['Roughness'].default_value = 1
    verts, faces = [], []
    n = 32
    for j in range(n+1):
        for i in range(n+1):
            x,y = -90+i*180/n,-90+j*180/n
            verts.append((x,y,ground_height(x,y)))
    for j in range(n):
        for i in range(n):
            a = j*(n+1)+i
            faces.append((a,a+1,a+n+2,a+n+1))
    mesh = bpy.data.meshes.new('Meadow_GroundMesh')
    mesh.from_pydata(verts,[],faces)
    obj = bpy.data.objects.new('Meadow_Ground',mesh)
    col.objects.link(obj)
    obj.data.materials.append(mat)
    grass = MeshBatch('PV_Grass')
    petals = MeshBatch('PV_FallenPetals')
    for _ in range(18000):
        x,y = RNG.uniform(-16,16),RNG.uniform(-16,16)
        if x*x+y*y < .28:
            continue
        p = Vector((x,y,ground_height(x,y)))
        h = RNG.uniform(.045,.18)
        a = RNG.random()*TAU
        w = Vector((math.cos(a)*.017,math.sin(a)*.017,0))
        grass.add([p-w,p+w,p+Vector((.028,.012,h))],[(0,1,2)])
    for _ in range(1600):
        a = RNG.random()*TAU
        r = math.sqrt(RNG.random())*5.4
        x,y = math.cos(a)*r,math.sin(a)*r*.75
        p = Vector((x,y,ground_height(x,y)+.007))
        petals.add([p+Vector((-.023,0,0)),p+Vector((0,-.015,0)),p+Vector((.024,.002,.005)),p+Vector((0,.016,0))],[(0,1,2,3)])
    grass.finish(col)
    petals.finish(col)


def set_preview():
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 1440
    scene.render.resolution_y = 1080
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = 'Standard'
    world = bpy.data.worlds.new('Pale_Blue_Sky')
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs[0].default_value = color('#abcce3')
    world.node_tree.nodes['Background'].inputs[1].default_value = .55
    scene.world = world
    data = bpy.data.lights.new('Warm_Sun','SUN')
    data.energy = 2.0
    data.angle = .12
    sun = bpy.data.objects.new('Warm_Sun',data)
    scene.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(32),math.radians(-24),math.radians(-28))
    data = bpy.data.cameras.new('Reference_Camera')
    cam = bpy.data.objects.new('Reference_Camera',data)
    scene.collection.objects.link(cam)
    cam.location = (1.6,-16.5,5.2)
    cam.rotation_euler = (Vector((0,0,3.3))-cam.location).to_track_quat('-Z','Y').to_euler()
    data.lens = 45
    scene.camera = cam


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--render',action='store_true')
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for col in list(bpy.data.collections):
        bpy.data.collections.remove(col)
    scene = bpy.context.scene
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 1
    root, tree = make_tree()
    make_ground()
    set_preview()
    out = HERE/'generated'
    assets = HERE/'godot'/'assets'
    out.mkdir(exist_ok=True)
    assets.mkdir(exist_ok=True)
    # Keep source and runtime deliveries separate: GLB contains ONLY the tree.
    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    for obj in tree:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(filepath=str(assets/'palo_verde.glb'),export_format='GLB',
        use_selection=True,export_yup=True,export_materials='EXPORT',export_extras=True)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in bpy.data.collections['Meadow_Set'].objects:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(assets/'meadow.glb'),export_format='GLB',
        use_selection=True,export_yup=True,export_materials='EXPORT')
    tree_vertices = [v.co for obj in tree for v in obj.data.vertices]
    bounds = [[min(v[i] for v in tree_vertices) for i in range(3)],
              [max(v[i] for v in tree_vertices) for i in range(3)]]
    counts = {}
    for obj in tree:
        obj.data.calc_loop_triangles()
        counts[obj.name] = {'vertices':len(obj.data.vertices),'triangles':len(obj.data.loop_triangles)}
    assert len(tree) == 3
    assert abs(bounds[0][2]) < .05, bounds
    assert bounds[1][2] > 5 and bounds[1][0]-bounds[0][0] > 9, bounds
    assert sum(c['triangles'] for c in counts.values()) < 450000, counts
    signature = hashlib.sha256(json.dumps({o.name:[tuple(v.co) for v in o.data.vertices] for o in tree},sort_keys=True).encode()).hexdigest()
    manifest = {'asset_id':root['asset_id'],'seed':SEED,'blender':bpy.app.version_string,
        'units':'meters','blender_up':'Z','gltf_godot_up':'Y','pivot':[0,0,0],
        'bounds_blender':bounds,'meshes':counts,'geometry_sha256':signature,
        'glb_sha256':hashlib.sha256((assets/'palo_verde.glb').read_bytes()).hexdigest(),
        'alpha_textures':0,'tree_materials':3,'desktop_hero_asset':True}
    (out/'asset_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    bpy.ops.wm.save_as_mainfile(filepath=str(out/'palo_verde_authored.blend'))
    if args.render:
        scene.render.filepath = str(out/'blender_preview.png')
        bpy.ops.render.render(write_still=True)
    print('PALO_VERDE_BUILD_OK '+json.dumps(manifest))


if __name__ == '__main__':
    main()
