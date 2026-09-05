"""Refine the procedural source and export a self-contained Godot asset."""
import bpy, bmesh, math, random, os, json
import numpy as np
from mathutils import Vector
ROOT=os.path.dirname(os.path.abspath(__file__))
ASSETS=os.path.join(ROOT,'godot','assets')
random.seed(613)
bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT,'pool_recreation.blend'))

def mesh(name,v,f,materials,indices=None):
 d=bpy.data.meshes.new(name); d.from_pydata(v,[],f); d.update()
 o=bpy.data.objects.new(name,d); bpy.context.collection.objects.link(o)
 for m in materials:d.materials.append(m)
 if indices:
  for p,i in zip(d.polygons,indices):p.material_index=i
 return o
def cube(name,c,size,material):
 v=[(c[0]+a*size[0]/2,c[1]+b*size[1]/2,c[2]+z*size[2]/2) for a,b,z in [(-1,-1,-1),(-1,-1,1),(-1,1,-1),(-1,1,1),(1,-1,-1),(1,-1,1),(1,1,-1),(1,1,1)]]
 return mesh(name,v,[(0,4,6,2),(1,3,7,5),(0,1,5,4),(2,6,7,3),(0,2,3,1),(4,5,7,6)],[material])

# Replace coarse draft rosettes with longer, tapered, smoothly curved leaves.
old=[o for o in bpy.data.objects if o.name.startswith(('Sculpted agave','Blue agave'))]
for o in old:
 vs=[o.matrix_world@v.co for v in o.data.vertices]; x=sum(p.x for p in vs)/len(vs); y=sum(p.y for p in vs)/len(vs); z=min(p.z for p in vs)
 s=(max(p.x for p in vs)-min(p.x for p in vs))/2.4
 if y< -2:s*=.80; x-=1.1
 ma=o.data.materials[0]; bpy.data.objects.remove(o,do_unlink=True)
 v=[]; f=[]
 for i in range(46):
  a=i*2.39996; ring=i/45; reach=s*(.17+1.12*ring); height=s*(1.45-1.12*ring); width=s*(.075+.065*ring)
  start=len(v)
  for k in range(17):
   t=k/16; r=reach*t**1.15; h=height*(1-(1-t)**1.45)
   for j in range(5):
    side=(j-2)/2; w=width*math.sin(math.pi*t)**.8
    v.append((x+r*math.cos(a)+w*side*math.sin(a),y+r*math.sin(a)-w*side*math.cos(a),z+h+.022*s*(1-abs(side))*math.sin(math.pi*t)))
  for k in range(16):
   for j in range(4):q=start+k*5+j; f.append((q,q+1,q+6,q+5))
 new=mesh('Refined agave foliage',v,f,[ma])
 for p in new.data.polygons:p.use_smooth=True

# Denser broadleaf trees, built as single meshes with varied leaf normals/colors.
old=[o for o in bpy.data.objects if o.name.startswith('Fine textured tree canopy')]
for o in old:
 vs=[v.co for v in o.data.vertices]; x=(min(p.x for p in vs)+max(p.x for p in vs))/2; y=(min(p.y for p in vs)+max(p.y for p in vs))/2; z=(min(p.z for p in vs)+max(p.z for p in vs))/2
 mats=list(o.data.materials); bpy.data.objects.remove(o,do_unlink=True)
 v=[]; f=[]; inds=[]
 for cl in range(24):
  a=random.random()*math.tau; rr=random.random()**.5*1.35; cz=z+random.uniform(-.7,1.1)
  cx=x+rr*math.cos(a); cy=y+rr*math.sin(a)
  for j in range(380):
   p=Vector((cx+random.gauss(0,.41),cy+random.gauss(0,.41),cz+random.gauss(0,.40)))
   a=random.random()*math.tau; u=Vector((math.cos(a),math.sin(a),random.uniform(-.85,.85))).normalized()*random.uniform(.07,.13)
   w=u.cross(Vector((random.random(),random.random(),1))).normalized()*random.uniform(.035,.065); idx=len(v)
   v.extend([p-u,p-u*.4+w,p+u*.55+w*.7,p+u,p+u*.55-w*.7,p-u*.4-w]); f.append(tuple(range(idx,idx+6))); inds.append(random.randrange(len(mats)))
 mesh('Dense broadleaf tree',v,f,mats,inds)

# Extend rear boundary beyond the camera's left edge and fill the sparse beds.
wall=bpy.data.materials['Cream concrete blocks']; stone=bpy.data.materials['Warm ivory limestone']; wood=bpy.data.materials['Honey teak']
for row in range(9):
 for col in range(30):cube('Boundary extension',(-10.5-col*.90+(row%2)*.45,10.21,.2+row*.36),(.888,.22,.348),wall)
# Original beam ended in the picture; extend it beyond frame.
for o in bpy.data.objects:
 if o.location.x>4.5 and o.location.y< -2.3:o.location.x-=1.1
 if o.name.startswith('Overhead heavy timber beam'):o.scale.x=1.8
 if o.name.startswith('Terrace ivory roof'):o.hide_render=False
 if o.name.startswith('Patio '):o.location.x+=5.3; o.location.y-=3.0
 if o.name.startswith('Table ') and o.location.x<0:o.location.x+=5.3; o.location.y-=3.0
 if o.name.startswith('Teak table board') and o.location.x<0:o.location.x+=5.3; o.location.y-=3.0
 if o.name.startswith('Continuous cascading water'):
  # Actual flowing sheet is supplied by a Godot shader with shared geometry.
  pass

# Add flowering stems, shrubs and creepers to make planted spaces read as gardens.
green=bpy.data.materials['Agave foliage 1']; flower=bpy.data.materials.new('Coral flowers'); flower.diffuse_color=(.63,.26,.22,1)
def rod(v,f,a,b,r):
 a,b=Vector(a),Vector(b); n=(b-a).normalized(); u=n.cross(Vector((0,0,1)))
 if u.length<.001:u=n.cross(Vector((1,0,0)))
 u.normalize(); w=n.cross(u); ix=len(v)
 for p in [a,b]:
  for j in range(6):v.append(p+r*(u*math.cos(j*math.tau/6)+w*math.sin(j*math.tau/6)))
 for j in range(6):f.append((ix+j,ix+(j+1)%6,ix+(j+1)%6+6,ix+j+6))
v=[]; f=[]; petals=[]; pf=[]
for x in [-7.7,-4.8,-1.4,1.8,7.6]:
 for stem in range(14):
  a=(x+random.uniform(-.3,.3),9.75+random.uniform(-.2,.2),.25); b=(a[0]+random.uniform(-.2,.2),a[1],random.uniform(1.1,2.7)); rod(v,f,a,b,.013)
  for k in range(10):
   p=Vector(a).lerp(Vector(b),k/10); ang=random.random()*math.tau; u=Vector((math.cos(ang),math.sin(ang),.5))*.18; w=Vector((-math.sin(ang),math.cos(ang),0))*.042; ix=len(v); v.extend([p,p+u*.65+w,p+u,p+u*.65-w]); f.append((ix,ix+1,ix+2,ix+3))
   if k>5:
    q=p+u; ix=len(petals)
    for j in range(5):petals.append(q+Vector((math.cos(j*math.tau/5),-.2,math.sin(j*math.tau/5)))*.044)
    pf.append(tuple(range(ix,ix+5)))
mesh('Climbing green stems',v,f,[green]); mesh('Coral blossom clusters',petals,pf,[flower])

# Add a planted centerpiece to the foreground table.
v=[]; f=[]
for k in range(9):
 for j in range(40):
  a=j*math.tau/40; r=.35*math.sin((.25+k/8*.35)*math.pi); v.append((-4.9+r*math.cos(a),-2.7+r*math.sin(a),.77+k*.025))
for k in range(8):
 for j in range(40):q=k*40+j; f.append((q,k*40+(j+1)%40,(k+1)*40+(j+1)%40,q+40))
mesh('Tabletop ceramic planter',v,f,[stone])

# Portable seamless material detail map, used with Godot world-space mapping.
rng=np.random.default_rng(11); N=512; yy,xx=np.mgrid[0:N,0:N]/N
grain=.5+.12*np.sin(xx*math.tau*34+1.7*np.sin(yy*math.tau*2))+.07*np.sin(xx*math.tau*91+3*np.sin(yy*math.tau))
grain+=rng.normal(0,.035,(N,N)); stone_noise=np.clip(.5+rng.normal(0,.14,(N,N)),0,1)
for name,arr in [('wood_grain',grain),('stone_grain',stone_noise)]:
 img=bpy.data.images.new(name,width=N,height=N); rgba=np.ones((N,N,4),np.float32); rgba[:,:,:3]=np.clip(arr[:,:,None],0,1); img.pixels.foreach_set(rgba.ravel()); img.filepath_raw=os.path.join(ASSETS,name+'.png'); img.file_format='PNG'; img.save()

# Match the tabletop centerpiece to the repositioned furniture.
for o in bpy.data.objects:
 if o.name.startswith('Tabletop ceramic planter'):o.location.x+=5.3; o.location.y-=3.0
# Correct winding on the handmade box primitives before exporting to a rasterizer.
for o in bpy.data.objects:
 if o.type=='MESH' and len(o.data.vertices)==8 and len(o.data.polygons)==6:
  bm=bmesh.new(); bm.from_mesh(o.data); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(o.data); bm.free(); o.data.update()
# Separate the vertical sheet from the horizontal pool for Godot's flow shader.
sheet=bpy.data.materials.new('Cascading water sheet'); sheet.diffuse_color=(.25,.65,.8,1)
for o in bpy.data.objects:
 if o.name.startswith('Continuous cascading water'):o.data.materials.clear(); o.data.materials.append(sheet)
# Save the detailed authoring scene before flattening export geometry.
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'pool_godot_source.blend'))
print('Authoring scene saved. Consolidating geometry.',flush=True)
# Collapse static objects into material groups, retaining water/foliage categories.
deps=bpy.context.evaluated_depsgraph_get(); groups={}
for o in list(bpy.context.scene.objects):
 if o.type!='MESH' or o.hide_render:continue
 e=o.evaluated_get(deps); d=e.to_mesh(); matrix=o.matrix_world
 for p in d.polygons:
  ma=d.materials[p.material_index] if d.materials else stone
  key=ma.name if ma else stone.name
  if key not in groups:groups[key]=[[],[],[]]
  v,f,normals=groups[key]; ix=len(v); v.extend([tuple(matrix@d.vertices[i].co) for i in p.vertices]); f.append(tuple(range(ix,ix+len(p.vertices))))
  normal_matrix=matrix.to_3x3().inverted().transposed()
  normals.extend([tuple((normal_matrix@d.corner_normals[i].vector).normalized()) for i in p.loop_indices])
 e.to_mesh_clear()
for o in list(bpy.context.scene.objects):bpy.data.objects.remove(o,do_unlink=True)
palette={}
for key,(v,f,normals) in groups.items():
 ma=bpy.data.materials.get(key); palette[key]=list(ma.diffuse_color)
 # Explicit PBR values, supported by glTF; runtime shaders replace these by name.
 ma.use_nodes=True; nt=ma.node_tree; nt.nodes.clear(); p=nt.nodes.new('ShaderNodeBsdfPrincipled'); p.inputs['Base Color'].default_value=ma.diffuse_color; p.inputs['Roughness'].default_value=.75; out=nt.nodes.new('ShaderNodeOutputMaterial'); nt.links.new(p.outputs[0],out.inputs[0])
 o=mesh(key,v,f,[ma])
 for p in o.data.polygons:p.use_smooth=True
 o.data.normals_split_custom_set(normals)
 if 'foliage' in key or 'Tree canopy' in key:
  ma.surface_render_method='DITHERED'
with open(os.path.join(ASSETS,'palette.json'),'w') as f:json.dump(palette,f,indent=2)
bpy.ops.export_scene.gltf(filepath=os.path.join(ASSETS,'backyard.glb'),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False)
print('GODOT_EXPORT_OK',flush=True)
