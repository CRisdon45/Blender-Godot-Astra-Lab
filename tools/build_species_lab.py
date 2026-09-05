"""Blender adapter: compile two species, 3 illustrative stages, 2 seeds, 3 LODs.
Run: blender --background --factory-startup --python-exit-code 1 --python tools/build_species_lab.py
No baseline/courtyard files are read or modified. Original atlases; no third-party assets.
"""
from __future__ import annotations
import dataclasses
import hashlib
import json
import math
from pathlib import Path
import sys
import bpy
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(Path(__file__).resolve().parent))
from species_lab_core import PROFILES, compile_plant, cards_for_lod, wood_mesh, metrics
OUT=ROOT/'plant_lab/assets'
OUT.mkdir(parents=True,exist_ok=True)
AUTHOR=ROOT/'authoring/species_lab'
AUTHOR.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)


def atlas(species:str, flower:bool=False):
    # Four 128px original tiles. Green channel holds a restrained contour mask.
    n=128
    yy,xx=np.mgrid[0:n,0:n]/(n-1)
    image=np.ones((n,n*4,4),np.float32)
    for k in range(4):
        rng=np.random.default_rng(4000+k+(100 if flower else 0))
        mask=np.zeros((n,n),bool)
        if flower:
            # Five-lobed single bloom: texture aggregate, not botanical 3D petal mesh.
            dx,dy=xx-.5,yy-.5
            theta=np.arctan2(dy,dx); rad=np.sqrt(dx*dx+dy*dy)
            mask=rad < .29+.075*np.cos(5*theta+k*.4)
        elif species=='desert_museum':
            # Connected fine sprigs, not the old round broadleaf brush.
            mask=(abs(xx-.5)<.035)&(yy>.13)&(yy<.88)
            for j in range(5):
                y=.22+j*.125
                for sign in (-1,1):
                    cx=.5+sign*(.16+.035*math.sin(j+k)); cy=y+.025
                    a=sign*.30
                    dx,dy=xx-cx,yy-cy
                    u=dx*math.cos(a)+dy*math.sin(a); v=-dx*math.sin(a)+dy*math.cos(a)
                    mask |= (u/.18)**2+(v/.065)**2<1
        else:
            mask=((xx-.5)/.25)**2+((yy-.5)/.23)**2<1
            for j in range(9):
                a=j*math.tau/9+k*.31
                cx=.5+.24*math.cos(a);cy=.5+.24*math.sin(a)
                mask|=((xx-cx)/(.115+rng.uniform(0,.02)))**2+((yy-cy)/.10)**2<1
        eroded=mask.copy()
        for axis in (0,1):
            eroded &= np.roll(mask,1,axis)&np.roll(mask,-1,axis)
        tile=image[:,k*n:(k+1)*n]
        tile[:,:,3]=mask
        tile[:,:,1]=(~eroded & mask).astype(np.float32)
    name=f'{species}_{"flower" if flower else "leaf"}_atlas'
    img=bpy.data.images.new(name,width=n*4,height=n,alpha=True)
    img.colorspace_settings.name='Non-Color'
    img.pixels.foreach_set(image.ravel())
    img.filepath_raw=str(OUT/(name+'.png'));img.file_format='PNG';img.save();img.pack()
    return img


def material(name,color,img=None):
    mat=bpy.data.materials.new(name)
    mat.diffuse_color=(*color,1)
    mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value=(*color,1)
    bsdf.inputs['Roughness'].default_value=1
    if img:
        tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=img
        uv=mat.node_tree.nodes.new('ShaderNodeUVMap');uv.uv_map='AtlasPreview'
        mat.node_tree.links.new(uv.outputs['UV'],tex.inputs['Vector'])
        mat.node_tree.links.new(tex.outputs['Alpha'],bsdf.inputs['Alpha'])
        if hasattr(mat,'surface_render_method'):mat.surface_render_method='DITHERED'
    return mat


def make_mesh(name,verts,faces,mat):
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    mesh.materials.append(mat)
    for p in mesh.polygons:p.use_smooth=True
    return obj


def make_cards(name,cards,lod,mat):
    verts=[];faces=[];normals=[];uv=[];sizes=[];colors=[];preview=[]
    inflate=(1.0,1.27,1.6)[lod]
    for c in cards:
        w,h=[x*inflate for x in c.size];offset=len(verts)
        for x,z in ((0,0),(1,0),(1,1),(0,1)):
            verts.append((c.center[0]+(x-.5)*w,c.center[1],c.center[2]+(z-.5)*h))
            normals.append(c.normal);uv.append((x,z));sizes.append((w,1-h))
            colors.append((c.tile/3,c.shade,c.rank,1))
            preview.append(((c.tile+x)/4,z))
        faces.extend([(offset,offset+1,offset+2),(offset,offset+2,offset+3)])
    obj=make_mesh(name,verts,faces,mat);data=obj.data
    # Allocate all layers before obtaining RNA layer handles, matching the fixed
    # courtyard exporter. UVMap/BrushSize must remain TEXCOORD_0/TEXCOORD_1.
    for layer in ('UVMap','BrushSize','AtlasPreview'): data.uv_layers.new(name=layer)
    data.color_attributes.new(name='BrushData',type='FLOAT_COLOR',domain='CORNER')
    data.normals_split_custom_set_from_vertices(normals)
    data.uv_layers.active_index=0;data.uv_layers['UVMap'].active_render=True
    for loop in data.loops:
        i=loop.vertex_index
        data.uv_layers['UVMap'].data[loop.index].uv=uv[i]
        data.uv_layers['BrushSize'].data[loop.index].uv=sizes[i]
        data.uv_layers['AtlasPreview'].data[loop.index].uv=preview[i]
        data.color_attributes['BrushData'].data[loop.index].color=colors[i]
    return obj


manifest={'schema':'species-witness/1','generator_version':'0.1.0','units':'metres',
          'growth_status':'illustrative architectural stages, NOT years-after-installation predictions',
          'render_status':'pending actual Godot capture','android_device_tested':False,
          'profiles':PROFILES,'assets':[],'blender_version':bpy.app.version_string}
for species,profile in PROFILES.items():
    leaf_atlas=atlas(species);flower_atlas=atlas(species,True)
    mats=[material(f'{species}_wood',profile['wood'][1]),
          material(f'{species}_leaf',profile['leaves'][1],leaf_atlas),
          material(f'{species}_flower',profile['flowers'][1],flower_atlas)]
    runtime_mats=[material(f'{species}_{key}',profile[palette][1]) for key,palette in [('wood','wood'),('leaf','leaves'),('flower','flowers')]]
    for seed in (41,73):
        for stage,maturity in enumerate((0,.5,1)):
            plant=compile_plant(species,seed,maturity)
            key=f'{species}_s{seed}_g{stage}'
            descriptor=dataclasses.asdict(plant)
            (OUT/(key+'.json')).write_text(json.dumps(descriptor,separators=(',',':'))+'\n')
            for lod in range(3):
                bpy.ops.object.select_all(action='DESELECT')
                verts,faces=wood_mesh(plant,lod)
                objects=[make_mesh('Wood',verts,faces,mats[0]),
                         make_cards('Leaves',cards_for_lod(plant.cards,lod),lod,mats[1]),
                         make_cards('Flowers',cards_for_lod(plant.flowers,lod),lod,mats[2])]
                for i,obj in enumerate(objects):
                    obj.select_set(True)
                    obj.data.materials[0]=runtime_mats[i]
                bpy.context.view_layer.objects.active=objects[0]
                target=OUT/f'{key}_lod{lod}.glb'
                bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',use_selection=True,
                    export_yup=True,export_apply=True,export_normals=True,export_texcoords=True,
                    export_materials='EXPORT',export_cameras=False,export_lights=False,
                    export_vertex_color='NAME',export_vertex_color_name='BrushData',export_all_vertex_colors=False)
                report=metrics(plant,lod)
                report.update({'species':species,'seed':seed,'stage':stage,'lod':lod,'file':target.name,
                               'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
                manifest['assets'].append(report)
                if lod==0:
                    for i,obj in enumerate(objects):obj.data.materials[0]=mats[i]
                    # One self-contained editable .blend per species/seed/stage.
                    bpy.ops.wm.save_as_mainfile(filepath=str(AUTHOR/f'{key}.blend'))
                for obj in objects:bpy.data.objects.remove(obj,do_unlink=True)
manifest['source_sha256']={name:hashlib.sha256((ROOT/'tools'/name).read_bytes()).hexdigest()
                           for name in ('species_lab_core.py','build_species_lab.py')}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('SPECIES_BLENDER_BUILD_OK '+json.dumps({'assets':len(manifest['assets']),'authoring_files':12}))
