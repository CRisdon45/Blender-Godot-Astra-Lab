import bpy, math, random, os
from mathutils import Vector
random.seed(28)
OUT=os.path.dirname(os.path.abspath(__file__))
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for d in bpy.data.materials: bpy.data.materials.remove(d)

def mat(name, color, rough=.5, noise=0, scale=5, metallic=0):
 m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
 n=m.node_tree.nodes; p=n.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1); p.inputs['Roughness'].default_value=rough; p.inputs['Metallic'].default_value=metallic
 if noise:
  t=n.new('ShaderNodeTexNoise'); t.inputs['Scale'].default_value=scale; t.inputs['Detail'].default_value=3
  b=n.new('ShaderNodeBump'); b.inputs['Strength'].default_value=noise; b.inputs['Distance'].default_value=.065
  m.node_tree.links.new(t.outputs['Fac'],b.inputs['Height']); m.node_tree.links.new(b.outputs['Normal'],p.inputs['Normal'])
 return m
stone=mat('Warm ivory limestone',(.73,.68,.57),.78,.28,100)
grout=mat('Sandstone joints',(.43,.41,.35),.85)
wall=mat('Cream concrete blocks',(.67,.63,.53),.85,.2,85)
wood=mat('Honey teak',(.36,.205,.09),.48,.24,6)
# Stretch generated noise to suggest grain along timber.
n=wood.node_tree.nodes; tex=next(n for n in n if n.type=='TEX_NOISE'); coord=n.new('ShaderNodeTexCoord'); mapping=n.new('ShaderNodeVectorMath'); mapping.operation='MULTIPLY'; mapping.inputs[1].default_value=(1,35,35); wood.node_tree.links.new(coord.outputs['Generated'],mapping.inputs[0]); wood.node_tree.links.new(mapping.outputs['Vector'],tex.inputs['Vector'])
metal=mat('Pergola powder coated charcoal',(.055,.065,.067),.36,metallic=.35)
fabric=mat('Natural linen upholstery',(.88,.86,.77),.87,.13,160)
green=mat('Olive accent cushions',(.29,.36,.09),.9,.12,130)
soil=mat('Planter earth',(.14,.115,.07),1)
pebble=[mat('River gravel '+str(i),(.25+i*.055,.24+i*.051,.205+i*.043),.95) for i in range(5)]
leaves=[mat('Agave foliage '+str(i),c,.65) for i,c in enumerate([(.20,.32,.20),(.29,.40,.19),(.16,.29,.27),(.38,.46,.20)])]
treeleaves=[mat('Tree canopy '+str(i),c,.85) for i,c in enumerate([(.25,.36,.09),(.37,.46,.14),(.47,.54,.20),(.18,.29,.08)])]
bark=mat('Tree bark',(.25,.20,.125),.92,.5,15)
water=mat('Pool clear turquoise water',(.055,.48,.60),.11)
p=water.node_tree.nodes.get('Principled BSDF'); p.inputs['Transmission Weight'].default_value=.7; p.inputs['IOR'].default_value=1.333
nt=water.node_tree; t=nt.nodes.new('ShaderNodeTexNoise'); t.inputs['Scale'].default_value=8; t.inputs['Detail'].default_value=3; b=nt.nodes.new('ShaderNodeBump'); b.inputs['Strength'].default_value=.25; b.inputs['Distance'].default_value=.075; nt.links.new(t.outputs['Fac'],b.inputs['Height']); nt.links.new(b.outputs['Normal'],p.inputs['Normal'])
tile=mat('Pool blue mosaic',(.11,.45,.53),.32,.15,80)
foam=mat('Waterfall silver highlights',(.67,.90,.96),.2)

def cube(name,loc,dim,ma,bevel=0):
 v=[(a*dim[0]/2,b*dim[1]/2,c*dim[2]/2) for a,b,c in [(-1,-1,-1),(-1,-1,1),(-1,1,-1),(-1,1,1),(1,-1,-1),(1,-1,1),(1,1,-1),(1,1,1)]]; d=bpy.data.meshes.new(name); d.from_pydata(v,[],[(0,4,6,2),(1,3,7,5),(0,1,5,4),(2,6,7,3),(0,2,3,1),(4,5,7,6)]); d.update(); o=bpy.data.objects.new(name,d); bpy.context.collection.objects.link(o); o.location=loc
 if ma:o.data.materials.append(ma)
 if bevel: mod=o.modifiers.new('Soft finished edges','BEVEL'); mod.width=bevel; mod.segments=2; o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
 return o
def uv(name,loc,sc,ma,seg=12,rings=8):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,location=loc); o=bpy.context.object; o.name=name; o.scale=sc; o.data.materials.append(ma)
 for f in o.data.polygons:f.use_smooth=True
 return o
def rod(name,a,b,r,ma,verts=10):
 a,b=Vector(a),Vector(b); d=b-a; bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=d.length,location=(a+b)/2); o=bpy.context.object; o.name=name; o.rotation_euler=d.to_track_quat('Z','Y').to_euler(); o.data.materials.append(ma); return o
def mesh(name,v,f,ma):
 d=bpy.data.meshes.new(name); d.from_pydata(v,[],f); d.update(); o=bpy.data.objects.new(name,d); bpy.context.collection.objects.link(o); o.data.materials.append(ma); return o

# A true recessed basin: paving stops at its edges.
cube('Landscape foundation',(0,3,-.9),(22,25,.5),soil)
cube('Pool floor',(0,2,-.72),(8,7,.18),tile)
for x in [-4.10,4.10]:cube('Pool side wall',(x,2,-.32),(.2,7.4,.85),tile)
for y in [-1.60,5.60]:cube('Pool end wall',(0,y,-.32),(8.4,.2,.85),tile)
cube('Shallow lounging shelf',(0,-.45,-.18),(7.98,2.1,.9),tile)
cube('Water surface',(0,2,.305),(7.99,7.18,.035),water)
# Large format paving with narrow visible joints.
for ix in range(15):
 for iy in range(15):
  x=-9+ix*1.3; y=-7+iy*1.3
  # Clip tile rectangles against pool opening.
  xa,xb=x-.645,x+.645; ya,yb=y-.645,y+.645
  rects=[(xa,xb,ya,yb)]
  if xb>-4.25 and xa<4.25 and yb>-1.75 and ya<5.75:
   rects=[]
   if xa< -4.25:rects.append((xa,-4.25,ya,yb))
   if xb>4.25:rects.append((4.25,xb,ya,yb))
   l,r=max(xa,-4.25),min(xb,4.25)
   if ya< -1.75:rects.append((l,r,ya,-1.75))
   if yb>5.75:rects.append((l,r,5.75,yb))
  for a,b,c,d in rects:
   if b>a and d>c:cube('Limestone paving',((a+b)/2,(c+d)/2,.12),(b-a,d-c,.22),stone,.014)
for x in [-4.12,4.12]:cube('Pool coping',(x,2,.27),(.27,7.5,.16),stone,.025)
for y in [-1.62,5.62]:cube('Pool coping',(0,y,.27),(8,.27,.16),stone,.025)

# Boundary masonry.
cube('Rear wall mortar',(0,10.4,1.65),(20,.28,3.3),grout)
for row in range(9):
 for col in range(23):
  x=-10+col*.9+(row%2)*.45
  cube('Rear masonry block',(x,10.21,.2+row*.36),(.887,.22,.348),wall,.012)
cube('Right boundary wall',(8.5,3.2,1.65),(.25,14.5,3.3),wall,.025)
for y in range(-4,11):
 for z in range(1,9):cube('Right masonry horizontal joint',(8.366,y,z*.36),(.006,1,.012),grout)

# Raised stacked-stone water wall, three bowls and twin spillways.
cube('Water feature core',(-1.4,5.94,.85),(6,.57,1.3),grout)
for row in range(7):
 for col in range(12):
  x=-4.4+col*.5+(row%2)*.23
  if x<1.6:cube('Split face limestone veneer',(x,5.635,.31+row*.17),(.48,.10+random.random()*.045,.155),stone,.018)
cube('Water feature cap',(-1.4,5.94,1.53),(6.2,.77,.15),stone,.025)
def bowl(x,y,z,r,ma):
 v=[]; f=[]; profile=[(0,-.03),(.40,.0),(.76,.15),(1,.38),(.94,.40),(.70,.20),(.30,.10),(0,.10)]
 for rr,zz in profile:
  for j in range(40):a=j*math.tau/40; v.append((x+rr*r*math.cos(a),y+rr*r*math.sin(a),z+zz*r))
 for k in range(len(profile)-1):
  for j in range(40):a=k*40+j; b=k*40+(j+1)%40; f.append((a,b,b+40,a+40))
 return mesh('Cast bronze fire bowl',v,f,ma)
fire=mat('Golden flame', (1,.27,.015),.4); p=fire.node_tree.nodes.get('Principled BSDF'); p.inputs['Emission Color'].default_value=(1,.21,.008,1); p.inputs['Emission Strength'].default_value=5
for x in [-3.7,-1.4,.9]:
 bowl(x,5.94,1.62,.48,metal)
 for i in range(9):
  xx=x+random.uniform(-.22,.22); yy=5.94+random.uniform(-.18,.18); h=random.uniform(.22,.65)
  v=[]; f=[]
  for k in range(7):
   for j in range(8):
    a=j*math.tau/8; r=.065*(1-k/6)+.009; v.append((xx+r*math.cos(a)+.05*math.sin(k*1.2+i),yy+r*math.sin(a),1.79+h*k/6))
  for k in range(6):
   for j in range(8):a=k*8+j; b=k*8+(j+1)%8; f.append((a,b,b+8,a+8))
  mesh('Sculpted flame',v,f,fire)
for x in [-2.65,.1]:
 cube('Stainless spillway',(x,5.56,1.40),(1.0,.19,.06),metal,.01)
 v=[]; f=[]
 for k in range(25):
  t=k/24; y=5.48-.48*t; z=1.41-1.1*t*t
  for j in range(21):v.append((x-.47+j*.047,y+.012*math.sin(j*2+k),z+.014*math.sin(j*3+k)))
 for k in range(24):
  for j in range(20):a=k*21+j; f.append((a,a+1,a+22,a+21))
 mesh('Continuous cascading water',v,f,water)
 for j in range(16):
  xx=x+random.uniform(-.47,.47)
  for k in range(7):
   t=k/7; u=(k+1)/7; rod('Waterfall glint',(xx,5.48-.48*t,1.41-1.1*t*t),(xx+.009,5.48-.48*u,1.41-1.1*u*u),.006,foam,5)
 for i in range(30):uv('Waterfall splash',(x+random.uniform(-.55,.55),5+random.uniform(-.18,.18),.34),(.025,.07,.012),foam,8,4)

def pergola(cx,cy,w,d,z):
 for x in [cx-w/2,cx+w/2]:
  for y in [cy-d/2,cy+d/2]:cube('Pergola steel upright',(x,y,z/2),(.20,.20,z),metal,.025)
 for y in [cy-d/2,cy+d/2]:cube('Pergola fascia',(cx,y,z),(w+.22,.21,.25),metal,.02)
 for x in [cx-w/2,cx+w/2]:cube('Pergola side beam',(x,cy,z),(.21,d,.25),metal,.02)
 for i in range(27):cube('Teak shade slat',(cx-w/2+.10+i*(w-.2)/26,cy,z-.04),(.135,d-.15,.12),wood,.01)
pergola(4.6,8,5.1,3.5,3.8)

def chair(name,x,y,ang=0,w=.85):
 # Parent assembly lets the same detailed armchair face different directions.
 parts=[]
 def c(n,l,d,m,b=.025):o=cube(name+' '+n,l,d,m,b); parts.append(o); return o
 for xx in [-w/2,w/2]:
  for yy in [-.32,.35]:c('leg',(xx,yy,.35),(.065,.065,.70),wood)
  c('arm',(xx,0,.82),(.085,.95,.075),wood)
 c('seat frame',(0,0,.40),(w,.83,.10),wood)
 c('seat cushion',(0,-.025,.52),(w-.05,.79,.18),fabric,.065)
 o=c('back cushion',(0,.34,.87),(w-.03,.17,.61),fabric,.06); o.rotation_euler.x=math.radians(10)
 c('back rail',(0,.44,.98),(w,.065,.06),wood)
 for o in parts:
  a,b=o.location.x,o.location.y; o.location.x=x+a*math.cos(ang)-b*math.sin(ang); o.location.y=y+a*math.sin(ang)+b*math.cos(ang); o.location.z+=.25; o.rotation_euler.z+=ang
chair('Pergola sofa',4.7,8.6,0,2.5)
for x in [3.85,4.65,5.45]:cube('Sofa pillow',(x,8.8,1.20),(.70,.20,.47),fabric,.09)
cube('Olive pillow',(5.45,8.62,1.18),(.42,.22,.42),green,.065)
chair('Left lounge chair',2.8,7.6,-.25)
chair('Right lounge chair',6.7,7.7,.3)
def table(x,y,w,d):
 for xx in [-w/2+.08,w/2-.08]:
  for yy in [-d/2+.08,d/2-.08]:cube('Table steel leg',(x+xx,y+yy,.47),(.055,.055,.45),metal,.012)
 for i in range(6):cube('Teak table board',(x,y-d/2+(i+.5)*d/6,.72),(w,d/6-.012,.075),wood,.012)
table(4.7,7.3,1.75,.8)
chair('Patio armchair',-5.5,-4.2,-.15,1.15)
chair('Patio loveseat',-6,-1.9,math.pi/2,1.9)
table(-4.9,-2.7,2,1.2)

def lounger(x,y):
 for dx in [-.39,.39]:
  rod('Chaise frame',(x+dx,y-.85,.42),(x+dx,y+.10,.47),.028,metal)
  rod('Chaise reclined back',(x+dx,y+.10,.47),(x+dx,y+.95,1.17),.028,metal)
  rod('Chaise front foot',(x+dx,y-.72,.31),(x+dx,y-.58,.45),.026,metal)
  rod('Chaise rear support',(x+dx,y+.65,.31),(x+dx,y+.1,.47),.026,metal)
 cube('Chaise ivory sling seat',(x,y-.37,.47),(.77,1.05,.045),fabric,.02)
 o=cube('Chaise ivory sling back',(x,y+.51,.81),(.77,1.11,.045),fabric,.02); o.rotation_euler.x=math.radians(39)
lounger(1.5,-.52); lounger(2.75,-.52)
bpy.ops.mesh.primitive_cylinder_add(vertices=40,radius=.30,depth=.42,location=(.45,-1,.52)); bpy.context.object.data.materials.append(stone); bpy.context.object.name='Round submerged side table'

# Sculpted pointed agave leaves, each with a raised central ridge.
def agave(x,y,z,s=1,blue=False):
 v=[]; f=[]
 for i in range(30):
  a=i*2.39996; outer=i/29; length=s*(.48+.62*outer); spread=.18+.95*outer; height=s*(1.1-.62*outer); width=s*(.065+.035*outer)
  start=len(v)
  for k in range(8):
   t=k/7; rr=length*spread*t; zz=z+height*(math.sin(t*math.pi*.65))+.04; ww=width*math.sin(math.pi*t)**.7
   for side in [-1,0,1]:v.append((x+rr*math.cos(a)+side*ww*math.sin(a),y+rr*math.sin(a)-side*ww*math.cos(a),zz+(.045*s*math.sin(math.pi*t) if side==0 else 0)))
  for k in range(7):
   for j in range(2):q=start+k*3+j; f.append((q,q+1,q+4,q+3))
 o=mesh('Blue agave' if blue else 'Sculpted agave rosette',v,f,leaves[2 if blue else random.choice([0,1,3])]); sol=o.modifiers.new('Leaf thickness','SOLIDIFY'); sol.thickness=.006
def planter(x,y,w=1.4,d=1.4,h=.65):
 cube('Planter soil',(x,y,h+.20),(w-.15,d-.15,.1),soil)
 for xx in [x-w/2,x+w/2]:cube('Limestone planter wall',(xx,y,h/2+.22),(.13,d+.13,h),stone,.025)
 for yy in [y-d/2,y+d/2]:cube('Limestone planter wall',(x,yy,h/2+.22),(w,.13,h),stone,.025)
 for i in range(45):
  px=x+random.uniform(-w/2+.1,w/2-.1); py=y+random.uniform(-d/2+.1,d/2-.1); uv('Planter river pebble',(px,py,h+.26),(.06,.045,.028),random.choice(pebble),8,4)
 return h+.26
z=planter(5.8,-4,2.1,1.7,.8); agave(5.8,-4,z,1.55)
for x,y,s in [(-5,1,1.1),(-5,5,1.0),(7,5,1), (7,-.2,.85),(2.1,6.4,.65),(7.3,8.9,.7)]:
 z=planter(x,y,1.2,1.2,.5); agave(x,y,z,s,blue=(y<1))
for x in [-7,-5.6,-3.9,-2.2,0,1.3,7.5]:agave(x,9.7,.3,random.uniform(.65,1.05))
# Inset path on the right.
cube('Gravel path base',(7.6,2,.26),(1.1,12,.08),grout)
for i in range(12):cube('Stepping slab',(7.6,-3.5+i*1.03,.32),(.94,.90,.09),stone,.01)

# Trees: combined leaf mesh per tree for efficient rendering.
def tree(x,y,s):
 rod('Tree trunk',(x,y,0),(x,y,3.4*s),.13*s,bark)
 v=[]; f=[]
 for branch in range(10):
  a=random.random()*math.tau; rr=random.uniform(.6,1.5)*s; end=(x+rr*math.cos(a),y+rr*math.sin(a),random.uniform(3.8,5.8)*s)
  rod('Tree branch',(x,y,2*s),end,.045*s,bark)
  for j in range(170):
   dx,dy,dz=[random.gauss(0,.48*s) for _ in range(3)]; p=Vector((end[0]+dx,end[1]+dy,end[2]+dz)); a=random.random()*math.tau; u=Vector((math.cos(a),math.sin(a),random.uniform(-.5,.5)))*random.uniform(.07,.14)*s; w=Vector((-math.sin(a),math.cos(a),.6))*.047*s; idx=len(v); v.extend([p-u,p+w,p+u,p-w]); f.append((idx,idx+1,idx+2,idx+3))
 o=mesh('Fine textured tree canopy',v,f,treeleaves[0])
 for m in treeleaves[1:]:o.data.materials.append(m)
 for p in o.data.polygons:p.material_index=random.randrange(4)
for x,s in [(-10,1.2),(-7,1.15),(-3,1.05),(.6,.95),(4,1.1),(8,1.2),(11,1.25)]:tree(x,12+random.random()*2,s)

# Foreground covered terrace frames the view.
cube('Foreground stucco column',(-6,-.6,2.85),(.55,.65,5.7),stone,.025)
cube('Overhead heavy timber beam',(-1,-.6,5.65),(13,.36,.48),wood,.025)
for x in [-7,-4,-1,2,5]:cube('Terrace timber rafter',(x,-3.6,5.90),(.25,6.3,.33),wood,.018)
cube('Terrace ivory roof',(-1,-3.8,6.15),(13,6.4,.13),fabric)

# Gate and diagonal bracing.
cube('Garden gate',(7.45,10.01,1.45),(1.35,.14,2.55),wood,.02)
for x in [6.85,7.45,8.05]:cube('Gate steel stile',(x,9.92,1.45),(.045,.045,2.5),metal)
for z in [.23,2.67]:cube('Gate steel rail',(7.45,9.91,z),(1.28,.05,.05),metal)
rod('Gate diagonal',(6.88,9.90,.26),(7.42,9.90,2.64),.025,metal)
rod('Gate diagonal',(7.48,9.90,2.64),(8.02,9.90,.26),.025,metal)

world=bpy.data.worlds.new('Clear blue desert sky'); bpy.context.scene.world=world; world.use_nodes=True
nt=world.node_tree; nt.nodes.clear(); sky=nt.nodes.new('ShaderNodeTexSky'); sky.sky_type='HOSEK_WILKIE'; sky.sun_direction=Vector((-0.5,-0.4,0.75)).normalized(); sky.turbidity=2.2
bg=nt.nodes.new('ShaderNodeBackground'); bg.inputs['Strength'].default_value=.35; out=nt.nodes.new('ShaderNodeOutputWorld'); nt.links.new(sky.outputs[0],bg.inputs[0]); nt.links.new(bg.outputs[0],out.inputs[0])
bpy.ops.object.light_add(type='SUN',location=(-8,-3,12)); sun=bpy.context.object; sun.name='Afternoon sunlight'; sun.data.energy=2.3; sun.data.angle=math.radians(4); sun.rotation_euler=(math.radians(30),math.radians(-25),math.radians(-30))
bpy.ops.object.camera_add(location=(5,-9,3.3)); cam=bpy.context.object; cam.name='Reference composition'; cam.rotation_euler=(Vector((0,4,1.6))-cam.location).to_track_quat('-Z','Y').to_euler(); cam.data.lens=25; bpy.context.scene.camera=cam
scene=bpy.context.scene; scene.render.engine='CYCLES'; scene.cycles.samples=56; scene.cycles.use_denoising=True
scene.render.resolution_x=1400; scene.render.resolution_y=1050; scene.render.resolution_percentage=100
scene.world.color=(.3,.5,.7); scene.view_settings.view_transform='AgX'; scene.render.image_settings.file_format='PNG'; scene.render.filepath=os.path.join(OUT,'pool_recreation.png')
scene['Reference']='User supplied backyard reference; inferred dimensions, procedural reconstruction.'
scene['Scene notes']='Editable geometry and procedural materials. Still-frame waterfalls and flames. Camera: Reference composition.'
nt=world.node_tree; nt.nodes.clear(); bg=nt.nodes.new('ShaderNodeBackground'); bg.inputs['Color'].default_value=(.46,.70,1,1); bg.inputs['Strength'].default_value=.65; out=nt.nodes.new('ShaderNodeOutputWorld'); nt.links.new(bg.outputs[0],out.inputs[0])
sun.rotation_euler=(math.radians(25),math.radians(-30),math.radians(-110)); sun.data.energy=3; scene.view_settings.exposure=.65
bpy.data.objects['Terrace ivory roof'].hide_render=True
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'pool_recreation.blend'))
bpy.ops.render.render(write_still=True)


