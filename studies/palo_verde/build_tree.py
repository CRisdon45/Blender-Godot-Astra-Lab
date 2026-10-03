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
    'PV_Bark': ['#697d49', '#748952', '#809459', '#899d61'],
    'PV_Leaves': ['#526b32', '#64813a', '#739141', '#88a44b', '#96af54'],
    'PV_Blossoms': ['#e5bc29', '#f1cb34', '#ffdc48', '#f6d044', '#fbe263'],
    'PV_Grass': ['#58713b', '#698342', '#7a944a', '#8ea458'],
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
    verts = [center-axis*length*.5,
             center-axis*length*.23+across*.88,
             center+axis*length*.23+across*.88,
             center+axis*length*.5,
             center+axis*length*.23-across*.88,
             center-axis*length*.23-across*.88,
             center+normal*length*.10]
    shading = (shade_normal if shade_normal is not None else normal).normalized()
    batch.add(verts,[(6,(i+1)%6,i) for i in range(6)],normals=[tuple(shading)]*7)


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


def collection(name):
    col = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(col)
    return col


def along(points, t):
    """Sample the same smoothed centerline that is used by the parent tube."""
    pts, _ = catmull(points, [1.0]*len(points), steps=12)
    segment = min(int(t*(len(pts)-1)), len(pts)-2)
    fraction = t*(len(pts)-1)-segment
    return pts[segment].lerp(pts[segment+1],fraction), (pts[segment+1]-pts[segment]).normalized()


def branch_points(origin, heading, length):
    heading = heading.normalized()
    bend = direction()*length*.12
    return [origin, origin+heading*length*.30+bend,
            origin+heading*length*.65-bend*.45+Vector((0,0,length*.05)),
            origin+heading*length+Vector((0,0,length*.08))]


def spray(bark, leaves, flowers, origin, heading, length, flowering):
    """Leaves and racemes grow ON a fine twig, rather than in a sphere shell."""
    points = branch_points(origin, heading, length)
    tube(bark,points,[.0038,.0026,.0015,.0006],sides=5,steps=2)
    heading = heading.normalized()
    across = heading.cross(Vector((0,0,1))).normalized()
    if across.length < .1:
        across = Vector((1,0,0))
    up = across.cross(heading).normalized()
    for index in range(8):
        t = .15+index*.105
        point, tangent = along(points,t)
        # Paired pinnate leaflets; varying individual normals preserve leaf shape.
        for side in (-1,1):
            leaf_axis = (across*side*.8+tangent*.45+up*RNG.uniform(-.2,.2)).normalized()
            size = RNG.uniform(.065,.108)*(1-.24*t)
            leaf_center = point+leaf_axis*size*.48
            shade = (up*.6+Vector((0,0,1))*.5+direction()*.35).normalized()
            leaf(leaves,leaf_center,leaf_axis,size,shade)
        if RNG.random() < flowering:
            # Uneven groups of blossoms follow the stems, with air between sprays.
            for _ in range(RNG.randint(2,4)):
                radial = direction()
                bloom_point = point+radial*RNG.uniform(.028,.105)
                flower(flowers,bloom_point,(radial+Vector((0,0,.6))).normalized(),RNG.uniform(.026,.044))
    for _ in range(2):
        flower(flowers,Vector(points[-1])+direction()*.038,direction()+Vector((0,0,.6)),RNG.uniform(.024,.037))


def make_tree():
    col = collection('PaloVerde_Authored')
    root = bpy.data.objects.new('PaloVerde_Root', None)
    col.objects.link(root)
    root['asset_id'] = 'palo_verde_authored_452603'
    root['species_visual_reference'] = 'Palo verde, flowering; species cultivar unconfirmed'
    root['seed'] = SEED
    root['units'] = 'meters'
    root['pivot'] = 'trunk_ground_contact'
    root['design_revision'] = 'desktop_branch_attached_sprays'
    trunk = MeshBatch('PV_Bark')
    bark, leaves, flowers = (MeshBatch(name) for name in ('PV_Bark','PV_Leaves','PV_Blossoms'))
    # A short leaning trunk, staggered forks, elbows and unequal leaders.
    tube(trunk, [(0,0,0),(-.17,.03,.45),(-.35,.04,.92),(-.57,.10,1.48),(-.67,.12,2.08)],
         [.34,.31,.275,.23,.105],sides=20,steps=8)
    scaffold = [
        ([(-.34,.03,.92),(-1.0,-.06,1.86),(-1.65,-.20,2.72),(-2.55,-.33,3.08),(-3.52,-.29,3.76),(-4.50,-.30,4.10)],.205),
        ([(-.55,.09,1.43),(-.83,.26,2.30),(-1.38,.42,3.02),(-1.54,.46,4.00),(-2.0,.38,4.76),(-2.33,.30,5.39)],.172),
        ([(-.62,.09,1.8),(-.63,-.13,2.73),(-.31,-.32,3.40),(-.48,-.28,4.46),(-.15,-.12,5.44),(-.40,-.03,5.95)],.157),
        ([(-.40,.04,1.1),(.20,-.09,1.86),(.96,-.18,2.48),(1.61,-.13,3.33),(2.65,-.32,3.63),(3.65,-.47,4.16),(4.67,-.52,4.56)],.22),
        ([(-.57,.11,1.52),(-.14,.58,2.48),(.59,.90,3.14),(.92,1.0,4.08),(1.55,.94,4.71),(1.83,.87,5.63)],.155),
        ([(-.55,.09,1.42),(-.84,-.61,2.36),(-1.09,-1.24,2.91),(-1.09,-1.96,3.69),(-1.43,-2.71,4.20),(-1.21,-3.05,4.61)],.145),
        ([(-.59,.12,1.7),(-1.08,.74,2.54),(-1.73,1.42,3.18),(-1.88,2.20,3.72),(-2.74,2.90,4.08),(-2.92,3.21,4.80)],.14),
        ([(-.42,.06,1.2),(.13,-.54,1.92),(.56,-1.22,2.72),(1.43,-1.66,3.17),(1.95,-2.40,3.91),(2.67,-2.84,4.33)],.166),
        ([(-.57,.10,1.52),(-.24,.73,2.32),(.35,1.50,2.97),(1.39,2.0,3.43),(2.09,2.60,4.14),(2.37,2.83,4.79)],.14),
    ]
    for points, radius in scaffold:
        tube(trunk,points,[radius*(1-t*.96)**1.35 for t in [i/(len(points)-1) for i in range(len(points))]],sides=16,steps=7)
    # Fuse only structural wood. Preserve fine twigs as geometry below.
    wood = trunk.finish(col)
    bpy.context.view_layer.objects.active = wood
    wood.select_set(True)
    remesh = wood.modifiers.new('Joined_Organic_Forks','REMESH')
    remesh.mode = 'VOXEL'
    remesh.voxel_size = .018
    remesh.use_smooth_shade = True
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    smooth = wood.modifiers.new('Soften_Fork_Junctions','SMOOTH')
    smooth.factor = .65
    smooth.iterations = 5
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    for polygon in wood.data.polygons:
        polygon.use_smooth = True
    # Remeshing may interpolate attributes; replace wood color consistently.
    layer = wood.data.color_attributes.get('Col')
    if layer is None:
        layer = wood.data.color_attributes.new(name='Col',type='FLOAT_COLOR',domain='POINT')
    layer.data.foreach_set('color',[v for vertex in wood.data.vertices for v in color('#788b52')])
    wood.data.color_attributes.active_color = layer
    wood.select_set(False)
    sprig_count = 0
    for branch_index,(points,radius) in enumerate(scaffold):
        # Spiral side branches do not produce repeated spherical crown units.
        for index in range(10):
            t = .39+index*.064+RNG.uniform(-.014,.014)
            origin,tangent = along(points,t)
            outward = Vector((origin.x,origin.y,0)).normalized()
            sideways = tangent.cross(Vector((0,0,1))).normalized()
            phase = index*2.399+branch_index*.83
            heading = tangent*.35+sideways*math.sin(phase)*.78+outward*.18+Vector((0,0,.64+.25*math.cos(phase)))
            branch_length = RNG.uniform(1.10,1.90)*(1-.20*abs(origin.x)/5)
            branch = branch_points(origin,heading,branch_length)
            tube(bark,branch,[.030,.020,.010,.0024],sides=8,steps=4)
            flowering = RNG.uniform(.58,.94)
            for j in range(7):
                child_origin,child_tangent = along(branch,.26+j*.113)
                phase2 = phase+j*2.399+RNG.uniform(-.3,.3)
                cross = child_tangent.cross(Vector((0,0,1))).normalized()
                child_heading = (child_tangent*.60+cross*math.sin(phase2)*.70+Vector((0,0,.24+.18*math.cos(phase2)))).normalized()
                child_length = RNG.uniform(.56,.95)
                child = branch_points(child_origin,child_heading,child_length)
                tube(bark,child,[.009,.0055,.003,.0009],sides=6,steps=3)
                for k in range(7):
                    twig_origin,twig_tangent = along(child,.16+k*.133)
                    twig_cross = twig_tangent.cross(Vector((0,0,1))).normalized()
                    twig_heading = twig_tangent*.48+twig_cross*((-1 if k%2 else 1)*.74)+Vector((0,0,RNG.uniform(.12,.50)))
                    spray(bark,leaves,flowers,twig_origin,twig_heading,RNG.uniform(.22,.48),flowering)
                    sprig_count += 1
                spray(bark,leaves,flowers,Vector(child[-1]),child_heading,RNG.uniform(.28,.46),flowering)
                sprig_count += 1
    # Incorporate fused scaffold into the stable bark role, leaving three meshes.
    fine = bark.finish(col)
    bpy.ops.object.select_all(action='DESELECT')
    wood.select_set(True)
    fine.select_set(True)
    bpy.context.view_layer.objects.active = wood
    bpy.ops.object.join()
    wood.name = 'PV_Bark'
    # Angled tube rings and voxel smoothing can cross the placement plane.
    for vertex in wood.data.vertices:
        vertex.co.z = max(0.0, vertex.co.z)
    # Both sources share one identical shader role; unify the material slots.
    wood.data.materials.clear()
    wood.data.materials.append(bpy.data.materials['PV_Bark_Material'])
    for polygon in wood.data.polygons:
        polygon.material_index = 0
    objects = [wood,leaves.finish(col),flowers.finish(col)]
    for obj in objects:
        obj.parent = root
    root['flowering_sprays'] = sprig_count
    return root, objects


def ground_height(x,y):
    return -.025 + .05*math.sin(x*.24)*math.sin(y*.18) + max(0.,abs(y)-8)*.013


def make_ground():
    col = collection('Meadow_Set')
    mat = bpy.data.materials.new('Meadow_Ground')
    mat.diffuse_color = color('#7e9148')
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = color('#7e9148')
    bsdf.inputs['Roughness'].default_value = 1
    verts, faces = [], []
    n = 110
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
    for _ in range(110000):
        x,y = RNG.uniform(-16,16),RNG.uniform(-16,16)
        if x*x+y*y < .28:
            continue
        p = Vector((x,y,ground_height(x,y)))
        h = RNG.uniform(.075,.24)
        a = RNG.random()*TAU
        w = Vector((math.cos(a)*.020,math.sin(a)*.020,0))
        grass.add([p-w,p+w,p+Vector((.026,.014,h*.65))-w*.40,p+Vector((.026,.014,h*.65))+w*.40,p+Vector((.055,.023,h))],[(0,1,3,2),(2,3,4)])
    for _ in range(7500):
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
    scene.cycles.samples = 32
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 1000
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = 'AgX'
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
    cam.location = (1.7,-19.7,5.3)
    cam.rotation_euler = (Vector((0,0,3.7))-cam.location).to_track_quat('-Z','Y').to_euler()
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
    assert sum(c['triangles'] for c in counts.values()) < 3000000, counts
    signature = hashlib.sha256(json.dumps({o.name:[tuple(v.co) for v in o.data.vertices] for o in tree},sort_keys=True).encode()).hexdigest()
    manifest = {'asset_id':root['asset_id'],'seed':SEED,'blender':bpy.app.version_string,
        'units':'meters','blender_up':'Z','gltf_godot_up':'Y','pivot':[0,0,0],
        'bounds_blender':bounds,'meshes':counts,'geometry_sha256':signature,
        'glb_sha256':hashlib.sha256((assets/'palo_verde.glb').read_bytes()).hexdigest(),
        'flowering_sprays':root['flowering_sprays'],'design_revision':root['design_revision'],'alpha_textures':0,'tree_materials':3,'desktop_hero_asset':True}
    (out/'asset_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    bpy.ops.wm.save_as_mainfile(filepath=str(out/'palo_verde_authored.blend'), compress=True)
    if args.render:
        scene.render.filepath = str(out/'blender_preview.png')
        bpy.ops.render.render(write_still=True)
    print('PALO_VERDE_BUILD_OK '+json.dumps(manifest))


if __name__ == '__main__':
    main()
