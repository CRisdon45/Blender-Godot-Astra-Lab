"""Original offline large/medium/small foliage art direction over the species grammar.

Canopy-study/2.1 keeps a deeply recessed opaque support volume, builds the visible
crown from branch-oriented scalloped foliage modules, and adds a restrained layer
of tiny species-signature geometry at close/medium detail. Flowers remain sparse
cutout brushes. No third-party tutorial assets/code are included. Normals and all
LOD geometry are compiled offline; the tablet only renders the baked result.
"""
from __future__ import annotations
from dataclasses import dataclass
import math
from typing import Iterable
from species_lab_core import (Plant, Lobe, Card, compile_plant, bezier, add,
                              sub, mul, mix, unit, dot, cross, rng_for)
from .coverage import select_coverage

VERSION = 'canopy-study/2.1'
UP = (0.0, 0.0, 1.0)
X = (1.0, 0.0, 0.0)
Y = (0.0, 1.0, 0.0)


def compose(species: str, seed: int, maturity: float) -> Plant:
    """Recompose the proven connected branch graph into a species-directed crown."""
    plant = compile_plant(species, seed, maturity)
    h, w = plant.height, plant.spread
    tree = species == 'desert_museum'
    root = plant.branches[0]
    top = h * (.29 - .17*maturity) if tree else h*.05
    root.points = [(0,0,0),(.01*w,0,top*.30),(-.012*w,.009*w,top*.67),(0,0,top)]
    root.radius *= 1.12 if tree else 1.0
    branches = {root.id: root}
    lobes = []
    for old in plant.branches[1:]:
        i = int(old.id.split(':')[1])
        rnd = rng_for(seed, 'canopy-shape:'+old.id)
        parent = branches[old.parent]
        origin = bezier(parent.points, old.attach_t)
        if old.order == 1:
            if tree:
                angle = i*math.tau/3 + rnd.uniform(-.33,.33)
                height = h*((.89,.71,.94)[i] + rnd.uniform(-.025,.025))
                radial = w*((.22,.36,.15)[i] + rnd.uniform(-.025,.025))
            else:
                angle = i*2.39996323 + rnd.uniform(-.14,.14)
                height = h*((.30,.36,.33,.51,.58,.50,.66)[i])
                radial = w*((.26,.23,.28,.18,.16,.21,.035)[i])
            end = (math.cos(angle)*radial, math.sin(angle)*radial, height)
            delta = sub(end,origin)
            old.points = [origin,
                          add(origin,(delta[0]*.16,delta[1]*.16,delta[2]*.49)),
                          add(origin,(delta[0]*.66,delta[1]*.70,delta[2]*.87)),end]
            old.radius = root.radius*.49
            radii = (w*.145,w*.110,h*.090) if tree else (w*.285,w*.28,h*.33)
            if not tree and i==6: radii=(w*.29,w*.30,h*.33)
            lobes.append(Lobe(old.id,old.id,end,radii))
        else:
            j = int(old.id.split(':')[2])
            leader = parent.points[-1]
            angle = math.atan2(leader[1],leader[0]) + (-1 if j%2 else 1)*rnd.uniform(.62,1.12)
            if tree:
                radial = w*rnd.uniform(.10,.19)
                base = bezier(parent.points,min(.99,old.attach_t+.15))
                end = add(base,(math.cos(angle)*radial,math.sin(angle)*radial,h*rnd.uniform(.025,.11)))
                end = (end[0],end[1],min(end[2],h*.91))
                radii = (w*rnd.uniform(.100,.130),w*rnd.uniform(.080,.108),h*rnd.uniform(.060,.090))
                lobes.append(Lobe(old.id,old.id,end,radii))
            else:
                end = (math.cos(angle)*w*.25,math.sin(angle)*w*.25,h*(.40+.17*j))
            old.points = [origin,add(origin,(0,0,h*(.055 if tree else .045))),mix(origin,end,.72),end]
            old.radius = parent.radius*(1-parent.taper*old.attach_t)*.62
        branches[old.id] = old
    plant.lobes = lobes
    plant.cards=[]; plant.flowers=[]
    count=40 if tree else 36
    for lobe in lobes:
        phase=rng_for(seed,lobe.id).random()*math.tau
        for index in range(count):
            rnd=rng_for(seed,f'art:{lobe.id}:{index}')
            z=1-2*(index+.5)/count
            angle=index*2.39996323+phase
            ring=math.sqrt(max(0,1-z*z))
            direction=(ring*math.cos(angle),ring*math.sin(angle),z)
            center=add(lobe.center,tuple(direction[k]*lobe.radii[k] for k in range(3)))
            if any(other.id!=lobe.id and sum(((center[k]-other.center[k])/other.radii[k])**2 for k in range(3))<.90 for other in lobes):
                continue
            local=unit(tuple(direction[k]/lobe.radii[k] for k in range(3)))
            broad=unit(sub(center,lobe.center))
            n=unit(add(mul(local,.55),mul(broad,.45)))
            size=(.12+.13*maturity) if tree else (.070+.050*maturity)
            size*=rnd.uniform(.84,1.16)
            plant.cards.append(Card(f'{lobe.id}/anchor:{index}',lobe.id,center,n,
                                    (size,size*(.78 if tree else .9)),rnd.randrange(4),
                                    min(1,max(0,center[2]/h)),rnd.random()))
            if index%5==0 and z>-.20:
                plant.flowers.append(Card(f'{lobe.id}/flower:{index}',lobe.id,
                    add(center,mul(direction,size*.12)),n,(size*.72,size*.72),rnd.randrange(4),
                    center[2]/h,rnd.random()))
    return plant


def selected(cards: Iterable[Card], lod: int) -> list[Card]:
    if type(lod) is not int or lod not in (0,1,2): raise ValueError('Invalid LOD')
    groups={}
    for card in cards: groups.setdefault(card.lobe_id,[]).append(card)
    return [c for group in groups.values() for c in select_coverage(group,2**lod)]


@dataclass
class Surface:
    vertices: list
    triangles: list
    normals: list
    uv: list


def _append_surface(out: Surface, part: Surface) -> None:
    start=len(out.vertices)
    out.vertices.extend(part.vertices)
    out.triangles.extend(tuple(i+start for i in face) for face in part.triangles)
    out.normals.extend(part.normals)
    out.uv.extend(part.uv)


def _rotate_frame(forward, right, angle):
    ca,sa=math.cos(angle),math.sin(angle)
    return unit(add(mul(forward,ca),mul(right,sa))), unit(add(mul(right,ca),mul(forward,-sa)))


def _ellipsoid(center, radii, rings, sides, phase=0.0, shrink=1.0, normal_center=None,
               normal_local_weight=.5, basis=(X,Y,UP)):
    verts=[]; norms=[]; uvs=[]
    normal_center = normal_center or center
    axis0,axis1,axis2=basis
    def world_from_local(v):
        return add(add(mul(axis0,v[0]),mul(axis1,v[1])),mul(axis2,v[2]))
    def point(theta,phi):
        d=(math.sin(phi)*math.cos(theta),math.sin(phi)*math.sin(theta),math.cos(phi))
        wave=1+.090*math.sin(3*theta+phase)*math.sin(phi)**2+.045*math.cos(5*theta-phi+phase)*math.sin(phi)
        local=(d[0]*radii[0]*wave*shrink,d[1]*radii[1]*wave*shrink,d[2]*radii[2]*wave*shrink)
        p=add(center,world_from_local(local))
        local_normal=(d[0]/max(radii[0],1e-9),d[1]/max(radii[1],1e-9),d[2]/max(radii[2],1e-9))
        local_n=unit(world_from_local(local_normal))
        broad=unit(sub(p,normal_center))
        n=unit(add(mul(local_n,normal_local_weight),mul(broad,1-normal_local_weight)))
        return p,n
    verts.append(add(center,mul(axis2,radii[2]*shrink))); norms.append(axis2);uvs.append((.5,0))
    for i in range(1,rings):
        for j in range(sides+1):
            theta=math.tau*j/sides; phi=math.pi*i/rings
            p,n=point(theta,phi);verts.append(p);norms.append(n);uvs.append((j/sides,i/rings))
    bottom=len(verts);verts.append(add(center,mul(axis2,-radii[2]*shrink)));norms.append(mul(axis2,-1));uvs.append((.5,1))
    faces=[]
    for j in range(sides):faces.append((0,1+j,2+j))
    for i in range(rings-2):
        start=1+i*(sides+1)
        for j in range(sides):
            a=start+j;b=a+sides+1
            faces.extend([(a,b,a+1),(a+1,b,b+1)])
    start=1+(rings-2)*(sides+1)
    for j in range(sides):faces.append((start+j,bottom,start+j+1))
    return Surface(verts,faces,norms,uvs)


def _tetra_leaf(center, axis, side, length, width, normal_center):
    axis=unit(axis);side=unit(side);normal=unit(cross(axis,side))
    base=add(center,mul(axis,-length*.48));tip=add(center,mul(axis,length*.52))
    left=add(add(center,mul(side,width*.5)),mul(normal,width*.16))
    right=add(add(center,mul(side,-width*.5)),mul(normal,-width*.16))
    verts=[base,tip,left,right]
    faces=[(0,2,1),(0,1,3),(0,3,2),(1,2,3)]
    norms=[]
    for p in verts:
        broad=unit(sub(p,normal_center))
        norms.append(unit(add(mul(normal,.32),mul(broad,.68))))
    return Surface(verts,faces,norms,[(0,.5),(1,.5),(.5,0),(.5,1)])


def _frame_for_lobe(plant: Plant, lobe: Lobe):
    branch=next(b for b in plant.branches if b.id==lobe.branch_id)
    tangent=unit(sub(branch.points[-1],branch.points[-2]))
    horizontal=(tangent[0],tangent[1],0.0)
    if dot(horizontal,horizontal)<1e-8:
        horizontal=(lobe.center[0],lobe.center[1],0.0)
    if dot(horizontal,horizontal)<1e-8:
        horizontal=(1.0,0.0,0.0)
    forward=unit(horizontal)
    right=unit(cross(UP,forward))
    return forward,right


def _module_centers(plant: Plant, lobe: Lobe, lod: int):
    tree=plant.species=='desert_museum'
    pattern = [
        (0.00, 0.00, 0.02, 1.00),
        (-.38, .18, -.08, .80),
        (.34, -.24, .10, .76),
        (.06, .34, .23, .66),
        (-.10, -.34, .17, .62),
    ] if tree else [
        (0.00, 0.00, 0.00, 1.00),
        (-.31, .20, -.14, .82),
        (.29, -.22, .08, .80),
        (.06, .31, .22, .72),
        (-.10, -.30, .18, .68),
        (.27, .13, -.18, .62),
    ]
    keep=(4,3,2)[lod] if tree else (5,3,2)[lod]
    forward,right=_frame_for_lobe(plant,lobe)
    result=[]
    for index,(a,b,c,scale) in enumerate(pattern[:keep]):
        rnd=rng_for(plant.seed,f'module:{lobe.id}:{index}')
        a+=rnd.uniform(-.045,.045);b+=rnd.uniform(-.045,.045);c+=rnd.uniform(-.035,.035)
        offset=add(add(mul(forward,a*lobe.radii[0]),mul(right,b*lobe.radii[1])),mul(UP,c*lobe.radii[2]))
        center=add(lobe.center,offset)
        mf,mr=_rotate_frame(forward,right,rnd.uniform(-.38,.38))
        if tree:
            radii=(lobe.radii[0]*(.50*scale)*rnd.uniform(.92,1.08),
                   lobe.radii[1]*(.34*scale)*rnd.uniform(.90,1.10),
                   lobe.radii[2]*(.50*scale)*rnd.uniform(.90,1.10))
        else:
            radii=(lobe.radii[0]*(.43*scale)*rnd.uniform(.92,1.08),
                   lobe.radii[1]*(.43*scale)*rnd.uniform(.92,1.08),
                   lobe.radii[2]*(.45*scale)*rnd.uniform(.92,1.08))
        result.append((center,radii,rnd.random()*math.tau,(mf,mr,UP),index))
    return result


def _cluster_module(plant: Plant, lobe: Lobe, center, radii, phase, basis, module_index, lod):
    out=Surface([],[],[],[])
    tree=plant.species=='desert_museum'
    sub_pattern=[(0,0,0,1.0),(.32,-.18,.17,.58),(-.27,.22,-.12,.54)]
    sub_count=(3,2,1)[lod]
    forward,right,up=basis
    for sub_index,(a,b,c,scale) in enumerate(sub_pattern[:sub_count]):
        rnd=rng_for(plant.seed,f'clump:{lobe.id}:{module_index}:{sub_index}')
        offset=add(add(mul(forward,a*radii[0]),mul(right,b*radii[1])),mul(up,c*radii[2]))
        sub_center=add(center,offset)
        sub_r=(radii[0]*scale*rnd.uniform(.92,1.08),radii[1]*scale*rnd.uniform(.90,1.10),radii[2]*scale*rnd.uniform(.90,1.10))
        part=_ellipsoid(sub_center,sub_r,2,(5 if lod<2 else 4),phase+sub_index*1.7,1.0,
                        lobe.center,.58 if tree else .48,basis)
        _append_surface(out,part)
    return out


def _signature_detail(plant: Plant, lobe: Lobe, lod: int) -> Surface:
    out=Surface([],[],[],[])
    if lod==2:
        return out
    tree=plant.species=='desert_museum'
    forward,right=_frame_for_lobe(plant,lobe)
    if tree:
        sprigs=2 if lod==0 else 1
        for s in range(sprigs):
            rnd=rng_for(plant.seed,f'sprig:{lobe.id}:{s}')
            sf,sr=_rotate_frame(forward,right,rnd.uniform(-.55,.55))
            origin=add(lobe.center,add(mul(sf,lobe.radii[0]*(.34+.16*s)),
                                       add(mul(sr,lobe.radii[1]*(-.26+.44*s)),mul(UP,lobe.radii[2]*.22))))
            spray_length=max(.055,plant.height*.018)
            for j in range(4):
                t=(j-1.5)/3
                center=add(origin,mul(sf,t*spray_length*.85))
                leaf_axis=unit(add(sf,mul(sr,(-1 if j%2 else 1)*.55)))
                _append_surface(out,_tetra_leaf(center,leaf_axis,sr,spray_length*.55,spray_length*.18,lobe.center))
    else:
        count=5 if lod==0 else 2
        for j in range(count):
            rnd=rng_for(plant.seed,f'sage-leaf:{lobe.id}:{j}')
            angle=math.tau*(j+.35)/count+rnd.uniform(-.25,.25)
            sf,sr=_rotate_frame(forward,right,angle)
            center=add(lobe.center,add(mul(sf,lobe.radii[0]*.70),mul(UP,lobe.radii[2]*rnd.uniform(-.25,.45))))
            length=max(.035,plant.height*.032)
            _append_surface(out,_tetra_leaf(center,unit(add(sf,mul(UP,.18))),sr,length,length*.48,lobe.center))
    return out


def core_mesh(plant: Plant, lod: int) -> Surface:
    if type(lod) is not int or lod not in (0,1,2):raise ValueError('Invalid LOD')
    out=Surface([],[],[],[])
    tree=plant.species=='desert_museum'
    for lobe in plant.lobes:
        forward,right=_frame_for_lobe(plant,lobe)
        rings=(3,3,2)[lod] if tree else (4,3,2)[lod]
        sides=(5,4,4)[lod] if tree else (6,5,4)[lod]
        _append_surface(out,_ellipsoid(lobe.center,lobe.radii,rings,sides,
                        rng_for(plant.seed,lobe.id).random()*math.tau,
                        .46 if tree else .60,
                        (0,0,plant.height*(.64 if tree else .44)),
                        .55 if tree else .42,(forward,right,UP)))
    return out


def foliage_mesh(plant: Plant, lod: int) -> Surface:
    if type(lod) is not int or lod not in (0,1,2):raise ValueError('Invalid LOD')
    out=Surface([],[],[],[])
    for lobe in plant.lobes:
        for center,radii,phase,basis,module_index in _module_centers(plant,lobe,lod):
            _append_surface(out,_cluster_module(plant,lobe,center,radii,phase,basis,module_index,lod))
        _append_surface(out,_signature_detail(plant,lobe,lod))
    return out


def bounds(plant, lod, wood_vertices):
    core=core_mesh(plant,lod); foliage=foliage_mesh(plant,lod)
    lows=list(wood_vertices)+core.vertices+foliage.vertices;highs=lows.copy()
    inflate=(1,1.16,1.28)[lod]
    for c in selected(plant.flowers,lod):
        radius=.5*math.hypot(*c.size)*inflate
        lows.append(tuple(x-radius for x in c.center));highs.append(tuple(x+radius for x in c.center))
    low=[min(p[k] for p in lows) for k in range(3)]
    high=[max(p[k] for p in highs) for k in range(3)]
    return {'min':[low[0],low[2],-high[1]],'max':[high[0],high[2],-low[1]]}
