"""Build the opt-in canopy art treatment through Blender, preserving baseline files.
Run after build_species_lab.py. Writes only assets/canopy, authoring/canopy_study,
and engine_data/canopy_catalog.json. Tutorial textures/code are not redistributed.
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
sys.path.insert(0,str(ROOT/'tools'))
from species_lab_core import RECIPES, wood_mesh
from plant_engine.canopy import VERSION, compose, selected, core_mesh, foliage_mesh, bounds
from plant_engine.recipe import canonical_bytes, content_hash
from plant_engine.catalog import atomic_write, artifact_key
from check_canopy_assets import check
OUT=ROOT/'plant_lab/assets/canopy'
AUTHOR=ROOT/'authoring/canopy_study'
OUT.mkdir(parents=True,exist_ok=True);AUTHOR.mkdir(parents=True,exist_ok=True)


def save_image(name, pixels):
    height,width,_=pixels.shape
    image=bpy.data.images.new(name,width=width,height=height,alpha=True)
    image.colorspace_settings.name='Non-Color'
    image.pixels.foreach_set(pixels.astype(np.float32).ravel())
    image.filepath_raw=str(OUT/(name+'.png'));image.file_format='PNG';image.save()
    bpy.data.images.remove(image)


def textures(species):
    n=128; yy,xx=np.mgrid[0:n,0:n]/(n-1)
    atlas=np.zeros((n,n*4,4),np.float32)
    for tile in range(4):
        r=np.random.default_rng(140+tile+(20 if species=='texas_sage' else 0))
        mask=np.zeros((n,n),bool)
        for j in range(5 if species=='desert_museum' else 4):
            cx=.5+r.uniform(-.20,.20);cy=.5+r.uniform(-.22,.22)
            angle=r.uniform(-1,1);dx=xx-cx;dy=yy-cy
            u=dx*np.cos(angle)+dy*np.sin(angle);v=-dx*np.sin(angle)+dy*np.cos(angle)
            mask |= (u/(.22 if species=='desert_museum' else .20))**2+(v/.12)**2<1
        atlas[:,tile*n:(tile+1)*n,:3]=.5
        atlas[:,tile*n:(tile+1)*n,3]=mask
    save_image(species+'_leaf_atlas',atlas)
    flower=np.zeros_like(atlas)
    for tile in range(4):
        for cx,cy in ((.35,.40),(.63,.46),(.44,.65)):
            dx=xx-cx;dy=yy-cy; angle=np.arctan2(dy,dx)
            mask=np.hypot(dx,dy)<.13+.022*np.cos(5*angle+tile*.4)
            flower[:,tile*n:(tile+1)*n,3]=np.maximum(flower[:,tile*n:(tile+1)*n,3],mask)
    flower[:,:,:3]=.5
    save_image(species+'_flower_atlas',flower)
    y,x=np.mgrid[0:256,0:512]/np.array([255,511])[:,None,None]
    rng=np.random.default_rng(610 if species=='desert_museum' else 620)
    wash=np.full_like(x,.5); marks=np.full_like(x,.5)
    for index in range(48):
        cx,cy=rng.random(2);rx=rng.uniform(.035,.10);ry=rng.uniform(.04,.13)
        d=((x-cx)/rx)**2+((y-cy)/ry)**2
        coverage=np.clip((1-d)*4,0,1)
        value=rng.uniform(.15,.85)
        wash=wash*(1-coverage)+value*coverage
    for index in range(75):
        cx,cy=rng.random(2);a=rng.uniform(-math.pi,math.pi)
        value=rng.uniform(.10,.28) if index%2 else rng.uniform(.73,.92)
        for j in range(3):
            along=(j-1)*.012
            px=cx+math.cos(a)*along;py=cy+math.sin(a)*along
            dx=x-px;dy=y-py
            u=dx*math.cos(a)+dy*np.sin(a)
            v=-dx*np.sin(a)+dy*np.cos(a)
            d=(u/.012)**2+(v/.017)**2
            coverage=np.clip((1-d)*3,0,1)
            marks=marks*(1-coverage)+value*coverage
    paint=np.stack([np.clip(wash,0,1),marks,np.full_like(x,.5),np.ones_like(x)],axis=-1)
    save_image(species+'_paint_mask',paint)


def material(name,color):
    mat=bpy.data.materials.new(name);mat.diffuse_color=(*color,1)
    return mat


def mesh_obj(name,verts,faces,mat,normals=None,uv=None):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    mesh.materials.append(mat)
    for polygon in mesh.polygons:polygon.use_smooth=True
    if normals:mesh.normals_split_custom_set_from_vertices(normals)
    if uv:
        mesh.uv_layers.new(name='UVMap')
        for loop in mesh.loops:mesh.uv_layers['UVMap'].data[loop.index].uv=uv[loop.vertex_index]
    return obj


def cards_obj(name,cards,lod,mat):
    verts=[];faces=[];normals=[];uv=[];sizes=[];colors=[]
    inflate=(1,1.20,1.38)[lod]
    for c in cards:
        w,h=[x*inflate for x in c.size];start=len(verts)
        for x,z in ((0,0),(1,0),(1,1),(0,1)):
            verts.append((c.center[0]+(x-.5)*w,c.center[1],c.center[2]+(z-.5)*h))
            normals.append(c.normal);uv.append((x,z));sizes.append((w,1-h));colors.append((c.tile/3,c.shade,c.rank,1))
        faces.extend([(start,start+1,start+2),(start,start+2,start+3)])
    obj=mesh_obj(name,verts,faces,mat,normals,uv);mesh=obj.data
    mesh.uv_layers.new(name='BrushSize')
    mesh.color_attributes.new(name='BrushData',type='FLOAT_COLOR',domain='CORNER')
    mesh.uv_layers.active_index=0;mesh.uv_layers['UVMap'].active_render=True
    for loop in mesh.loops:
        i=loop.vertex_index
        mesh.uv_layers['BrushSize'].data[loop.index].uv=sizes[i]
        mesh.color_attributes['BrushData'].data[loop.index].color=colors[i]
    return obj


def main():
    baseline=json.loads((ROOT/'plant_lab/engine_data/catalog.json').read_text())
    source_files=[Path(__file__),ROOT/'tools/plant_engine/canopy.py',ROOT/'tools/check_canopy_assets.py',
                  ROOT/'tools/species_lab_core.py',ROOT/'tools/plant_engine/coverage.py',ROOT/'tools/plant_engine/recipe.py']
    source_hash=content_hash({str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in source_files})
    for species in RECIPES:textures(species)
    shader_hash=content_hash({p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in
                            list((ROOT/'plant_lab/shaders').glob('canopy*'))+list(OUT.glob('*.png'))})
    entries=[];authoring_count=0
    for species,recipe in RECIPES.items():
        profile=recipe.data['profile']
        mats={part:material(species+'_'+part,profile['wood' if part=='wood' else ('flowers' if part=='flower' else 'leaves')][1])
              for part in ('wood','core','leaf','flower')}
        for seed in (41,73):
            lifetime={b.id for b in compose(species,seed,1.0).branches}
            for stage,maturity in enumerate((0.0,.5,1.0)):
                plant=compose(species,seed,maturity);key=f'{species}_s{seed}_g{stage}'
                topology=dataclasses.asdict(plant)
                topology.update({'schema':VERSION,'calendar_calibrated':False,
                                 'inactive_branch_ids':sorted(lifetime-{b.id for b in plant.branches})})
                topology_path=OUT/(key+'.json');atomic_write(topology_path,canonical_bytes(topology))
                lods=[]
                for lod in range(3):
                    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
                    verts,faces=wood_mesh(plant,lod);core=core_mesh(plant,lod);leaves=foliage_mesh(plant,lod)
                    flowers=selected(plant.flowers,lod)
                    objects=[mesh_obj('Wood',verts,faces,mats['wood']),
                             mesh_obj('Core',core.vertices,core.triangles,mats['core'],core.normals,core.uv),
                             mesh_obj('Leaves',leaves.vertices,leaves.triangles,mats['leaf'],leaves.normals,leaves.uv),
                             cards_obj('Flowers',flowers,lod,mats['flower'])]
                    for obj in objects:obj.select_set(True)
                    bpy.context.view_layer.objects.active=objects[0]
                    path=OUT/f'{key}_lod{lod}.glb'
                    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,
                        export_yup=True,export_apply=True,export_normals=True,export_texcoords=True,
                        export_materials='EXPORT',export_cameras=False,export_lights=False,
                        export_vertex_color='NAME',export_vertex_color_name='BrushData',export_all_vertex_colors=False)
                    counts={'wood':len(faces),'core':len(core.triangles),'leaf':len(leaves.triangles),'flower':2*len(flowers)}
                    counts['total']=sum(counts.values())
                    assert counts['total'] <= ((4300,2200,1350)[lod] if species=='desert_museum' else (2500,1500,900)[lod]),counts
                    digest=hashlib.sha256(path.read_bytes()).hexdigest()
                    entry={'lod':lod,'asset_key':artifact_key(recipe_hash=recipe.digest,source_hash=source_hash,
                          shader_hash=shader_hash,mesh_sha256=digest,seed=seed,stage=stage,lod=lod),
                          'path':'assets/canopy/'+path.name,'sha256':digest,'byte_size':path.stat().st_size,
                          'triangles':counts,'render_aabb_y_up':bounds(plant,lod,verts)}
                    check(path,entry)
                    lods.append(entry)
                    if lod==0:
                        bpy.ops.wm.save_as_mainfile(filepath=str(AUTHOR/(key+'.blend')));authoring_count+=1
                entries.append({'key':key,'species':species,'seed':seed,'stage':stage,'maturity':maturity,
                    'components':['wood','core','leaf','flower'],
                    'blueprint_id':content_hash({'style':VERSION,'source':source_hash,'recipe':recipe.digest,'species':species,'seed':seed}),
                    'design_envelope':recipe.envelope(maturity),'topology_path':'assets/canopy/'+topology_path.name,
                    'topology_sha256':hashlib.sha256(topology_path.read_bytes()).hexdigest(),'lods':lods})
    catalog={**baseline,'schema':'plant-catalog/2','compiler_version':VERSION,'variants':entries,
             'generation':content_hash({'source':source_hash,'shaders':shader_hash,'entries':entries}),
             'provenance':{'mode':'fresh_blender_canopy_study','blender':bpy.app.version_string,'source_hash':source_hash,'shader_hash':shader_hash},
             'validation':{'independent_glb_check':True,'assets_checked':36,'calendar_calibrated':False,'tablet_tested':False}}
    atomic_write(ROOT/'plant_lab/engine_data/canopy_catalog.json',canonical_bytes(catalog))
    print('CANOPY_BLENDER_BUILD_OK '+json.dumps({'assets':36,'authoring_files':authoring_count,'generation':catalog['generation']}))

if __name__=='__main__':main()
