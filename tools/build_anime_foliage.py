"""Bake original anime foliage into a NEW courtyard asset. Run with Blender --background.

No downloaded artist meshes/textures. Source courtyard and baseline assets are read-only.
Small brush cards occupy authored 3D crowns, with ellipsoid-derived custom normals.
The Godot shader rotates individual cards, never the tree, around fixed centers.
"""
from __future__ import annotations
import hashlib
import json
import math
from pathlib import Path
import random
import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'godot' / 'assets' / 'anime'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE = ROOT / 'pool_godot_source.blend'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
random.seed(20260905)


def mesh(name, vertices, faces, material):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    data.materials.append(material)
    return obj


def material(name, color):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    return mat


leaf = material('Anime foliage brushes', (.26, .40, .16))
wood = material('Anime branching wood', (.26, .24, .16))
coral = material('Anime grouped blossoms', (.65, .31, .28))

# Eight original, connected brush silhouettes: full central mass, a few leaf lobes,
# no scattered alpha confetti. RGB is white; only alpha is sampled by Godot.
N = 256
yy, xx = np.mgrid[0:N, 0:N] / (N - 1)
atlas = np.ones((2*N, 4*N, 4), np.float32)
for index in range(8):
    rng = random.Random(1800 + index)
    mask = ((xx-.50)/.24)**2 + ((yy-.50)/.22)**2 < 1
    for j in range(13):
        angle = j * math.tau/13 + rng.uniform(-.12, .12)
        radius = rng.uniform(.19, .27)
        cx, cy = .5+radius*math.cos(angle), .5+radius*math.sin(angle)
        a = angle + rng.uniform(-.45, .45)
        dx, dy = xx-cx, yy-cy
        u, v = dx*math.cos(a)+dy*math.sin(a), -dx*math.sin(a)+dy*math.cos(a)
        mask |= (u/rng.uniform(.10, .15))**2 + (v/rng.uniform(.055, .08))**2 < 1
    tile = atlas[(index//4)*N:(index//4+1)*N, (index%4)*N:(index%4+1)*N]
    tile[:, :, 3] = mask.astype(np.float32)
img = bpy.data.images.new('Original foliage brush atlas', width=4*N, height=2*N, alpha=True)
img.pixels.foreach_set(atlas.ravel())
img.filepath_raw = str(OUT / 'brush_atlas.png')
img.file_format = 'PNG'
img.save()

# Retain the true original tree locations and size from the authoring scene.
roots = []
for obj in bpy.data.objects:
    if obj.name.startswith('Tree trunk') and obj.type == 'MESH':
        points = [obj.matrix_world @ v.co for v in obj.data.vertices]
        lo, hi = min(p.z for p in points), max(p.z for p in points)
        roots.append((sum(p.x for p in points)/len(points),
                      sum(p.y for p in points)/len(points), lo, (hi-lo)/3.4))
roots.sort()
assert len(roots) == 7, f'Expected 7 source trunks, found {len(roots)}'
removed = []
for obj in list(bpy.data.objects):
    if obj.name.startswith(('Dense broadleaf tree', 'Tree trunk', 'Tree branch',
                            'Climbing green stems', 'Coral blossom clusters')):
        removed.append(obj.name)
        bpy.data.objects.remove(obj, do_unlink=True)


def tube(name, points, radii):
    verts, faces = [], []
    points = [Vector(p) for p in points]
    # Interpolated Catmull-Rom centerline, continuous taper instead of straight spokes.
    samples = []
    for i in range(len(points)-1):
        p0, p1 = points[max(0, i-1)], points[i]
        p2, p3 = points[i+1], points[min(len(points)-1, i+2)]
        for k in range(7):
            t = k/7
            p = .5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t)
            samples.append((p, radii[i]*(1-t)+radii[i+1]*t))
    samples.append((points[-1], radii[-1]))
    for i, (p, r) in enumerate(samples):
        tangent = (samples[min(i+1, len(samples)-1)][0]-samples[max(i-1, 0)][0]).normalized()
        u = tangent.cross(Vector((0,1,0)))
        if u.length < .01: u = tangent.cross(Vector((1,0,0)))
        u.normalize()
        v = tangent.cross(u).normalized()
        for j in range(8):
            verts.append(p+r*(u*math.cos(j*math.tau/8)+v*math.sin(j*math.tau/8)))
        if i:
            for j in range(8):
                a=(i-1)*8+j; b=(i-1)*8+(j+1)%8
                faces.append((a,b,b+8,a+8))
    faces.extend([tuple(reversed(range(8))), tuple(range(len(verts)-8,len(verts)))])
    obj = mesh(name, verts, faces, wood)
    for poly in obj.data.polygons: poly.use_smooth = True
    return obj


stats = []
# Authored lobes overlap into a single asymmetrical crown with shoulders and openings.
TREE_LOBES = [
    ((-.98,-.12,4.35),(1.05,.87,.76)), ((1.0,.05,4.48),(1.05,.83,.79)),
    ((-.56,.73,4.90),(.94,.86,.86)), ((.59,.71,5.12),(.95,.79,.89)),
    ((-.50,-.56,5.00),(.96,.80,.87)), ((.71,-.55,5.22),(.93,.78,.85)),
    ((-.17,.07,5.63),(.99,.89,.82)), ((-.04,-.03,4.48),(.95,.83,.73)),
    ((-1.30,.33,4.80),(.69,.63,.70)), ((1.29,.25,5.03),(.68,.64,.72)),
]
SHRUB_LOBES = [
    ((0,0,.61),(.57,.48,.47)), ((-.43,.04,.46),(.44,.42,.34)),
    ((.41,.11,.53),(.44,.40,.39)), ((-.12,-.29,.47),(.48,.36,.38)),
    ((.13,.24,.66),(.45,.38,.39)),
]


def crown(name, origin, scale, lobes, count, brush, seed):
    rng = random.Random(seed)
    vertices, faces, normals, uv, uv2, colors = [], [], [], [], [], []
    origin = Vector(origin)
    cards = 0
    for li, (center, radii) in enumerate(lobes):
        center, radii = Vector(center), Vector(radii)
        phase = rng.random()*math.tau
        for j in range(count):
            # Deterministic sphere coverage with mild bounded jitter; no Gaussian escapees.
            z = 1-2*(j+.5)/count
            a = j*2.39996322972865 + phase
            rr = math.sqrt(max(0, 1-z*z))
            direction = Vector((rr*math.cos(a),rr*math.sin(a),z))
            shell = rng.uniform(.86,1.02)
            offset = Vector(tuple(direction[k]*radii[k] for k in range(3))) * shell
            p = center+offset
            local_n = Vector(tuple(direction[k]/radii[k] for k in range(3))).normalized()
            # Group normals: broad crown response with a softer per-lobe component.
            crown_center = Vector((0,0,4.83 if count > 60 else .43))
            global_n = Vector(((p.x-crown_center.x)*.62, (p.y-crown_center.y)*.75,
                               (p.z-crown_center.z)*1.10)).normalized()
            n = (local_n*.48 + global_n*.52).normalized()
            p = origin+p*scale
            w = brush*scale*rng.uniform(.84,1.16)
            h = w*rng.uniform(.84,1.03)
            idx = len(vertices)
            # Blender XZ plane -> Godot XY plane. Exporter flips both UV V channels.
            for qx,qy in [(0,0),(1,0),(1,1),(0,1)]:
                vertices.append(p+Vector(((qx-.5)*w,0,(qy-.5)*h)))
                normals.append(tuple(n))
                uv.append((qx,qy))
                uv2.append((w,1-h))
                # Same occlusion throughout each small brush; no random rainbow leaves.
                shade = max(.0,min(1.0,.50+.42*direction.z))
                colors.append((rng.randrange(8)/7 if qx==0 and qy==0 else colors[-1][0],shade,0.0,1.0))
            faces.append((idx,idx+1,idx+2,idx+3))
            cards += 1
    obj = mesh(name, vertices, faces, leaf)
    data = obj.data
    # Allocate every custom-data layer before obtaining RNA layer handles.
    # Adding a layer can invalidate handles returned by earlier .new() calls.
    data.uv_layers.new(name='UVMap')
    data.uv_layers.new(name='BrushSize')
    data.color_attributes.new(name='BrushData', type='FLOAT_COLOR', domain='CORNER')
    for poly in data.polygons: poly.use_smooth=True
    if hasattr(data, 'use_auto_smooth'): data.use_auto_smooth=True
    data.normals_split_custom_set_from_vertices(normals)
    data.uv_layers.active_index = 0
    data.uv_layers['UVMap'].active_render = True
    for loop in data.loops:
        i=loop.vertex_index
        data.uv_layers['UVMap'].data[loop.index].uv=uv[i]
        data.uv_layers['BrushSize'].data[loop.index].uv=uv2[i]
        data.color_attributes['BrushData'].data[loop.index].color=colors[i]
    # Read back by name, not through cached handles, before allowing export.
    for loop in data.loops:
        i=loop.vertex_index
        actual_uv=data.uv_layers['UVMap'].data[loop.index].uv
        actual_size=data.uv_layers['BrushSize'].data[loop.index].uv
        actual_color=data.color_attributes['BrushData'].data[loop.index].color
        assert max(abs(a-b) for a,b in zip(actual_uv,uv[i])) < 1e-5
        assert max(abs(a-b) for a,b in zip(actual_size,uv2[i])) < 1e-5
        assert max(abs(a-b) for a,b in zip(actual_color,colors[i])) < 1e-5
    stats.append({'name':name,'cards':cards,'origin':list(origin),'scale':scale})


for index, (x,y,z,s) in enumerate(roots):
    # Every tree keeps its original footprint, but not the old starburst branches.
    def p(a,b,c): return (x+a*s,y+b*s,z+c*s)
    tube(f'Anime tree {index} main trunk', [p(0,0,0),p(.02,.01,1.3),p(-.12,.02,2.7),p(.12,.03,4.05),p(-.05,.09,5.5)],
         [q*s for q in (.15,.14,.105,.063,.012)])
    for j,(a,b,h) in enumerate([(-1.1,-.13,4.75),(.98,.03,4.95),(-.48,.74,5.25),(.62,-.47,5.55)]):
        tube(f'Anime tree {index} leader {j}', [p(-.03,0,1.7+j*.26),p(a*.35,b*.3,2.9+j*.17),p(a*.75,b*.72,h-.9),p(a,b,h)],
             [q*s for q in (.09,.071,.045,.009)])
    crown(f'Anime tree {index} crown', (x,y,z), s, TREE_LOBES, 85, .64, 711+index)

for index, (x,y,s) in enumerate([(-7.7,9.58,1.48),(-4.8,9.54,1.65),(-1.4,9.58,1.47),(1.8,9.56,1.60),(7.6,9.56,1.44)]):
    crown(f'Anime shrub {index}', (x,y,.27), s, SHRUB_LOBES, 48, .29, 819+index)
    for j in range(3):
        tube(f'Anime shrub {index} stem {j}', [(x,y,.26),(x+(j-1)*.12,y,.55),(x+(j-1)*.24,y+.05,.92)], [.035,.023,.008])
    # A few grouped blooms, not a picket fence of isolated dot flowers.
    rng = random.Random(920+index)
    v,f=[],[]
    for j in range(6):
        a=j*2.399963; c=Vector((x+.46*s*math.cos(a),y+.32*s*math.sin(a),.27+s*(.88+.06*math.sin(a))))
        for flower in range(3):
            q=c+Vector((rng.uniform(-.08,.08),rng.uniform(-.06,.06),rng.uniform(-.03,.03)))
            start=len(v)
            v.append(q)
            for k in range(20):
                ang=k*math.tau/20; r=.057*(.76+.24*math.cos(5*ang))
                v.append(q+Vector((r*math.cos(ang),r*math.sin(ang),.019*math.cos(ang))))
            for k in range(20):f.append((start,start+1+k,start+1+(k+1)%20))
    mesh(f'Anime shrub {index} flower groups',v,f,coral)


# Eevee authoring material; Godot supplies the per-brush facing transform at runtime.
leaf.use_nodes = True
nt = leaf.node_tree
nt.nodes.clear()
uvnode = nt.nodes.new('ShaderNodeTexCoord')
attr = nt.nodes.new('ShaderNodeVertexColor'); attr.layer_name = 'BrushData'
sep = nt.nodes.new('ShaderNodeSeparateColor'); nt.links.new(attr.outputs['Color'], sep.inputs[0])
def mathnode(operation, a=None, b=None):
    node=nt.nodes.new('ShaderNodeMath'); node.operation=operation
    for index, value in enumerate([a,b]):
        if value is None: continue
        if isinstance(value,(int,float)):node.inputs[index].default_value=value
        else:nt.links.new(value,node.inputs[index])
    return node.outputs[0]
variant=mathnode('ROUND',mathnode('MULTIPLY',sep.outputs[0],7))
col=mathnode('DIVIDE',mathnode('MODULO',variant,4),4)
row=mathnode('DIVIDE',mathnode('FLOOR',mathnode('DIVIDE',variant,4)),2)
offset=nt.nodes.new('ShaderNodeCombineXYZ');nt.links.new(col,offset.inputs['X']);nt.links.new(row,offset.inputs['Y'])
scaleuv=nt.nodes.new('ShaderNodeVectorMath');scaleuv.operation='MULTIPLY';scaleuv.inputs[1].default_value=(.25,.5,1)
nt.links.new(uvnode.outputs['UV'],scaleuv.inputs[0])
add=nt.nodes.new('ShaderNodeVectorMath');add.operation='ADD';nt.links.new(scaleuv.outputs[0],add.inputs[0]);nt.links.new(offset.outputs[0],add.inputs[1])
tex=nt.nodes.new('ShaderNodeTexImage');tex.image=img;nt.links.new(add.outputs[0],tex.inputs['Vector'])
transparent=nt.nodes.new('ShaderNodeBsdfTransparent')
diffuse=nt.nodes.new('ShaderNodeBsdfDiffuse');diffuse.inputs['Color'].default_value=(.35,.49,.23,1)
mix=nt.nodes.new('ShaderNodeMixShader');nt.links.new(tex.outputs['Alpha'],mix.inputs[0]);nt.links.new(transparent.outputs[0],mix.inputs[1]);nt.links.new(diffuse.outputs[0],mix.inputs[2])
output=nt.nodes.new('ShaderNodeOutputMaterial');nt.links.new(mix.outputs[0],output.inputs[0])
if hasattr(leaf,'surface_render_method'):leaf.surface_render_method='DITHERED'
else:leaf.blend_method='CLIP'

# Save fully editable authoring source. No baseline or original source overwritten.
authoring = ROOT / 'authoring'
authoring.mkdir(exist_ok=True)
img.pack()
bpy.ops.wm.save_as_mainfile(filepath=str(authoring/'courtyard_anime.blend'))

# Merge static architecture by material, exactly as the existing exporter does.
# Keep new authored brush meshes separate to retain UV2 and custom normals.
deps=bpy.context.evaluated_depsgraph_get()
groups={}
keep=[]
for obj in list(bpy.context.scene.objects):
    if obj.type!='MESH' or obj.hide_render:
        bpy.data.objects.remove(obj,do_unlink=True)
        continue
    if obj.name.startswith('Anime '):
        keep.append(obj)
        continue
    evaluated=obj.evaluated_get(deps)
    data=evaluated.to_mesh()
    matrix=obj.matrix_world
    normal_matrix=matrix.to_3x3().inverted().transposed()
    if hasattr(data,'calc_normals_split'): data.calc_normals_split()
    for poly in data.polygons:
        mat=data.materials[poly.material_index]
        key=mat.name
        verts,faces,normals=groups.setdefault(key,([],[],[]))
        start=len(verts)
        verts.extend([tuple(matrix@data.vertices[i].co) for i in poly.vertices])
        faces.append(tuple(range(start,start+len(poly.vertices))))
        for li in poly.loop_indices:
            normal=data.corner_normals[li].vector if hasattr(data,'corner_normals') else data.loops[li].normal
            normals.append(tuple((normal_matrix@normal).normalized()))
    evaluated.to_mesh_clear()
    bpy.data.objects.remove(obj,do_unlink=True)
for name,(verts,faces,normals) in groups.items():
    obj=mesh(name,verts,faces,bpy.data.materials[name])
    for poly in obj.data.polygons:poly.use_smooth=True
    if hasattr(obj.data,'use_auto_smooth'):obj.data.use_auto_smooth=True
    obj.data.normals_split_custom_set(normals)
for mat in bpy.data.materials:
    mat.use_nodes=True
    nt=mat.node_tree
    nt.nodes.clear()
    bsdf=nt.nodes.new('ShaderNodeBsdfPrincipled')
    bsdf.inputs['Base Color'].default_value=mat.diffuse_color
    bsdf.inputs['Roughness'].default_value=.9
    output=nt.nodes.new('ShaderNodeOutputMaterial')
    nt.links.new(bsdf.outputs[0],output.inputs[0])
    mat.use_backface_culling=False
bpy.ops.export_scene.gltf(filepath=str(OUT/'courtyard_anime.glb'),export_format='GLB',export_apply=True,
                          export_cameras=False,export_lights=False,export_yup=True,
                          export_vertex_color='NAME',export_vertex_color_name='BrushData',
                          export_all_vertex_colors=False)
manifest={'schema':1,'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
          'blender':bpy.app.version_string,'removed_objects':removed,'plants':stats,
          'tree_count':len(roots),'shrub_count':5,'total_brush_cards':sum(p['cards'] for p in stats),
          'whole_plant_billboarding':False,'camera_facing_element':'individual small brush',
          'wind':False,'lod':False,'species_certified':False,'visual_acceptance':'pending',
          'limitations':['generic broadleaf and flowering mound studies, not species assets',
                        'art-directed foliage lighting; not a botanical or scattering simulation']}
(OUT/'build_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('ANIME_FOLIAGE_BUILD_OK '+json.dumps(manifest),flush=True)
