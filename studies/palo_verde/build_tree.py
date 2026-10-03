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
        self.normals = []
        self.palette = [color(c) for c in PALETTES[name]]

    def add(self, vertices, faces, tint=None, normals=None):
        offset = len(self.vertices)
        self.vertices.extend(tuple(v) for v in vertices)
        self.faces.extend(tuple(offset + i for i in f) for f in faces)
        chosen = self.palette[RNG.randrange(len(self.palette))] if tint is None else tint
        self.colors.extend([chosen] * len(vertices))
        self.normals.extend(normals if normals is not None else [None]*len(vertices))

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
            p.use_smooth = self.name in ('PV_Bark', 'PV_Leaves')
        if all(v is not None for v in self.normals):
            mesh.normals_split_custom_set_from_vertices(self.normals)
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


def leaf(batch, center, axis, length, shade_normal=None):
    # Folded geometric leaflets, no alpha cards and no camera-facing billboards.
    axis = axis.normalized()
    if shade_normal is not None:
        axis = (axis-shade_normal*axis.dot(shade_normal)).normalized()
        across = shade_normal.cross(axis).normalized()*length*.38
    else:
        across = axis.cross(direction()).normalized()*length*.38
    normal = axis.cross(across).normalized()
    verts = [center-axis*length*.5, center+across, center+axis*length*.5,
             center-across, center+normal*length*.13]
    shading = (shade_normal if shade_normal is not None else normal).normalized()
    batch.add(verts, [(4,1,0),(4,2,1),(4,3,2),(4,0,3)], normals=[tuple(shading)]*5)


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


def foliage_core(batch, center, scale):
    # Irregular inner mass groups values; outer leaves conceal its silhouette.
    verts, faces, normals = [], [], []
    sides, rings = 12, 7
    for j in range(rings+1):
        polar = math.pi*j/rings
        for i in range(sides):
            a = TAU*i/sides
            unit = Vector((math.sin(polar)*math.cos(a),math.sin(polar)*math.sin(a),math.cos(polar)))
            radius = .70 + .06*math.sin(a*3+polar*5)
            verts.append(center+Vector(tuple(unit[k]*scale[k]*radius for k in range(3))))
            normals.append(tuple(Vector(tuple(unit[k]/scale[k] for k in range(3))).normalized()))
    for j in range(rings):
        for i in range(sides):
            a = j*sides+i
            b = j*sides+(i+1)%sides
            if j == 0:
                faces.append((a,b+sides,a+sides))
            elif j == rings-1:
                faces.append((a,b,b+sides))
            else:
                faces.append((a,b,b+sides,a+sides))
    batch.add(verts,[tuple(reversed(f)) for f in faces],tint=color('#82932e'),normals=normals)


def foliage_lobe(leaves, flowers, center, scale, leaf_count=760, bloom_count=230):
    # Canopy-directed normals give smooth authored mass shading without confetti.
    foliage_core(leaves,center,scale)
    for _ in range(leaf_count):
        outward = direction()
        radial = RNG.uniform(.68,1.05)
        p = center + Vector(tuple(outward[i]*scale[i]*radial for i in range(3)))
        length = RNG.uniform(.075, .14)
        leaf(leaves,p,direction()+Vector((.2,0,.25)),length,outward)
        if RNG.random() < .28:
            leaf(leaves,p+Vector((.025,.012,.04)),direction(),length*.72,outward)
    for _ in range(bloom_count):
        outward = direction()
        radial = RNG.uniform(.78, 1.10)
        p = center + Vector(tuple(outward[i]*scale[i]*radial for i in range(3)))
        flower(flowers,p,outward+Vector((0,-.2,.3)),RNG.uniform(.038,.063))


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
    anchors = [Vector(p) for points,_ in scaffold for p in points[2:]]
    crowns = []
    for y in (-2.25,-.75,.85,2.35):
        for x in (-4.1,-2.05,0,2.0,4.05):
            if abs(x)>3 and abs(y)>2:
                continue
            height = 5.05 - .051*x*x - .047*y*y
            crowns.append((Vector((x+RNG.uniform(-.25,.25),y,height+RNG.uniform(-.17,.17))),Vector((1.28,1.05,.86))))
    for y in (-.85,.85):
        for x in (-2.5,-.85,.8,2.4):
            height = 5.95 - .045*x*x
            crowns.append((Vector((x,y,height)),Vector((1.0,.95,.83))))
    for center,scale in crowns:
        base = min(anchors,key=lambda p:(p-center).length_squared)
        middle = base.lerp(center,.55)+Vector((0,0,.18))
        tube(bark,[base,middle,center],[.037,.021,.006],sides=7,steps=4)
        foliage_lobe(leaves,flowers,center,scale)
        for side in (-1,1):
            tuft = center+Vector((side*scale.x*.62,RNG.uniform(-.4,.4),RNG.uniform(-.12,.3)))
            tube(bark,[center,center.lerp(tuft,.55),tuft],[.008,.004,.0015],sides=5,steps=2)
            foliage_lobe(leaves,flowers,tuft,scale*RNG.uniform(.55,.66),leaf_count=260,bloom_count=100)
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
    bpy.ops.wm.save_as_mainfile(filepath=str(out/'palo_verde_authored.blend'), compress=True)
    if args.render:
        scene.render.filepath = str(out/'blender_preview.png')
        bpy.ops.render.render(write_still=True)
    print('PALO_VERDE_BUILD_OK '+json.dumps(manifest))


if __name__ == '__main__':
    main()
