"""LOD0-first species-directed foliage study using opaque 3D brush meshes.

Canopy-study/4.1 intentionally treats close-view artwork as the acceptance target.
The connected procedural branch graph remains authoritative. Palo verde foliage is
placed in branch-local elongated clouds so the crown reads airy and branch-led,
while Texas sage uses many smaller crossed opaque leaf marks distributed through
the shrub volume. Support geometry is nearly invisible at LOD0 and exists only to
prevent accidental holes. No alpha foliage cards, camera-facing billboards, runtime
AI, or per-frame plant generation are used.
"""
from __future__ import annotations
from dataclasses import dataclass
import math
from typing import Iterable
from species_lab_core import (Plant, Lobe, Card, compile_plant, bezier, add,
                              sub, mul, mix, unit, dot, cross, rng_for)
from .coverage import select_coverage

VERSION = 'canopy-study/4.1-lod0-density'
UP = (0.0, 0.0, 1.0)
X = (1.0, 0.0, 0.0)
Y = (0.0, 1.0, 0.0)


def _branch_frame(branch):
    tangent = unit(sub(branch.points[-1], branch.points[-2]))
    side = cross(UP, tangent)
    if dot(side, side) < 1e-8:
        side = cross(Y, tangent)
    if dot(side, side) < 1e-8:
        side = X
    side = unit(side)
    crown_up = unit(cross(tangent, side))
    if dot(crown_up, UP) < 0.0:
        crown_up = mul(crown_up, -1.0)
    return tangent, side, crown_up


def compose(species: str, seed: int, maturity: float) -> Plant:
    plant = compile_plant(species, seed, maturity)
    h, w = plant.height, plant.spread
    tree = species == 'desert_museum'
    root = plant.branches[0]
    top = h * (.23 - .15*maturity) if tree else h*.05
    root.points = [(0,0,0),(.012*w,0,top*.28),(-.015*w,.010*w,top*.66),(0,0,top)]
    root.radius *= 1.15 if tree else 1.0

    branches = {root.id: root}
    lobes = []
    for old in plant.branches[1:]:
        i = int(old.id.split(':')[1])
        rnd = rng_for(seed, 'canopy-shape:'+old.id)
        parent = branches[old.parent]
        origin = bezier(parent.points, old.attach_t)
        if old.order == 1:
            if tree:
                angle = i*math.tau/3 + rnd.uniform(-.34,.34)
                height = h*((.84,.73,.92)[i] + rnd.uniform(-.025,.025))
                radial = w*((.30,.41,.21)[i] + rnd.uniform(-.025,.025))
            else:
                angle = i*2.39996323 + rnd.uniform(-.14,.14)
                height = h*((.30,.36,.33,.51,.58,.50,.66)[i])
                radial = w*((.26,.23,.28,.18,.16,.21,.035)[i])
            end = (math.cos(angle)*radial, math.sin(angle)*radial, height)
            delta = sub(end,origin)
            old.points = [origin,
                          add(origin,(delta[0]*.14,delta[1]*.14,delta[2]*.47)),
                          add(origin,(delta[0]*.64,delta[1]*.70,delta[2]*.86)),end]
            old.radius = root.radius*(.53 if tree else .49)
            radii = (w*.215,w*.095,h*.078) if tree else (w*.285,w*.28,h*.33)
            if not tree and i==6:
                radii=(w*.29,w*.30,h*.33)
            lobes.append(Lobe(old.id,old.id,end,radii))
            if tree:
                mid = bezier(old.points, .70)
                lobes.append(Lobe(old.id+':mid', old.id, mid, (w*.145,w*.060,h*.055)))
        else:
            j = int(old.id.split(':')[2])
            leader = parent.points[-1]
            angle = math.atan2(leader[1],leader[0]) + (-1 if j%2 else 1)*rnd.uniform(.64,1.16)
            if tree:
                radial = w*rnd.uniform(.15,.28)
                base = bezier(parent.points,min(.99,old.attach_t+.12))
                vertical = h*rnd.uniform(-.010,.115)
                end = add(base,(math.cos(angle)*radial,math.sin(angle)*radial,vertical))
                end = (end[0],end[1],min(end[2],h*.91))
                radii = (w*rnd.uniform(.135,.185),w*rnd.uniform(.060,.095),h*rnd.uniform(.052,.080))
                lobes.append(Lobe(old.id,old.id,end,radii))
            else:
                end = (math.cos(angle)*w*.25,math.sin(angle)*w*.25,h*(.40+.17*j))
                lobes.append(Lobe(old.id, old.id, end, (w*.185,w*.165,h*.215)))
            old.points = [origin,
                          add(origin,(0,0,h*(.045 if tree else .045))),
                          mix(origin,end,.70),end]
            old.radius = parent.radius*(1-parent.taper*old.attach_t)*(.58 if tree else .62)
        branches[old.id] = old

    plant.lobes = lobes
    plant.cards=[]
    plant.flowers=[]
    branch_lookup={b.id:b for b in plant.branches}
    count = 60 if tree else 42
    for lobe in lobes:
        phase=rng_for(seed,lobe.id).random()*math.tau
        if tree:
            axis0,axis1,axis2=_branch_frame(branch_lookup[lobe.branch_id])
        else:
            axis0,axis1,axis2=X,Y,UP
        for index in range(count):
            rnd=rng_for(seed,f'art:{lobe.id}:{index}')
            z=1-2*(index+.5)/count
            angle=index*2.39996323+phase
            ring=math.sqrt(max(0,1-z*z))
            local_direction=(ring*math.cos(angle),ring*math.sin(angle),z)
            radial_depth=(.28 + .78*(rnd.random()**.72)) if tree else (.22 + .82*(rnd.random()**.82))
            offset=add(add(mul(axis0,local_direction[0]*lobe.radii[0]*radial_depth),
                           mul(axis1,local_direction[1]*lobe.radii[1]*radial_depth)),
                       mul(axis2,local_direction[2]*lobe.radii[2]*radial_depth))
            center=add(lobe.center,offset)
            if tree and any(other.id!=lobe.id and sum(((center[k]-other.center[k])/other.radii[k])**2 for k in range(3))<.46 for other in lobes):
                continue
            local_normal=add(add(mul(axis0,local_direction[0]/max(lobe.radii[0],1e-9)),
                                 mul(axis1,local_direction[1]/max(lobe.radii[1],1e-9))),
                             mul(axis2,local_direction[2]/max(lobe.radii[2],1e-9)))
            local_normal=unit(local_normal)
            broad=unit(sub(center,lobe.center))
            n=unit(add(mul(local_normal,.56 if tree else .44),
                       mul(broad,.44 if tree else .56)))
            size=(.115+.125*maturity) if tree else (.066+.050*maturity)
            size*=rnd.uniform(.70,1.28) if tree else rnd.uniform(.78,1.18)
            plant.cards.append(Card(f'{lobe.id}/anchor:{index}',lobe.id,center,n,
                                    (size,size*(.50 if tree else .92)),rnd.randrange(4),
                                    min(1,max(0,center[2]/h)),rnd.random()))
            flower_every = 8 if tree else 7
            if index%flower_every==0 and z>-.22:
                plant.flowers.append(Card(f'{lobe.id}/flower:{index}',lobe.id,
                    add(center,mul(n,size*.08)),n,(size*.58,size*.58),rnd.randrange(4),
                    center[2]/h,rnd.random()))
    return plant


def selected(cards: Iterable[Card], lod: int) -> list[Card]:
    if type(lod) is not int or lod not in (0,1,2):
        raise ValueError('Invalid LOD')
    groups={}
    for card in cards:
        groups.setdefault(card.lobe_id,[]).append(card)
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


def _frame_from_normal(normal, spin):
    n=unit(normal)
    tangent=cross(UP,n)
    if dot(tangent,tangent)<1e-8:
        tangent=X
    tangent=unit(tangent)
    bitangent=unit(cross(n,tangent))
    ca,sa=math.cos(spin),math.sin(spin)
    t=unit(add(mul(tangent,ca),mul(bitangent,sa)))
    b=unit(add(mul(bitangent,ca),mul(tangent,-sa)))
    return n,t,b


def _brush_polygon(card: Card, lobe: Lobe, species: str, scale: float, spin: float,
                   crossed: bool=False) -> Surface:
    n,t,b=_frame_from_normal(card.normal,spin)
    if crossed:
        n=unit(add(mul(n,.90),mul(t,.30)))
        n,t,b=_frame_from_normal(n,spin*.31+1.08)
    tree=species=='desert_museum'
    full_w=card.size[0]*scale*(1.20 if tree else 1.18)
    full_h=card.size[1]*scale*(.90 if tree else 1.10)
    rx,ry=full_w*.5,full_h*.5
    rnd=rng_for(int(card.rank*2147483000)%2147483647,card.id+(':x' if crossed else ':a'))
    base_angles=(-2.72,-1.72,-.63,.38,1.36,2.38)
    verts=[];uv=[]
    broad=unit(sub(card.center,lobe.center))
    proxy=(unit(add(mul(card.normal,.70),mul(broad,.30))) if tree
           else unit(add(add(mul(card.normal,.46),mul(broad,.39)),mul(UP,.15))))
    for i,angle in enumerate(base_angles):
        radial=(.82,1.05,.88,1.08,.80,1.00)[i]*rnd.uniform(.94,1.06)
        x=math.cos(angle)*rx*radial
        y=math.sin(angle)*ry*radial
        bow=math.sin(angle*2.0+spin)*min(rx,ry)*(.08 if tree else .12)
        verts.append(add(card.center,add(add(mul(t,x),mul(b,y)),mul(n,bow))))
        uv.append((.5+.48*x/max(rx,1e-9),.5+.48*y/max(ry,1e-9)))
    faces=[(0,1,2),(0,2,3),(0,3,4),(0,4,5)]
    return Surface(verts,faces,[proxy]*6,uv)


def _support_ellipsoid(center, radii, sides, normal_center, phase):
    top=add(center,(0,0,radii[2]));bottom=add(center,(0,0,-radii[2]))
    verts=[top];uv=[(.5,0.0)]
    for j in range(sides):
        angle=math.tau*j/sides
        wave=1+.06*math.sin(3*angle+phase)
        verts.append(add(center,(math.cos(angle)*radii[0]*wave,math.sin(angle)*radii[1]*wave,0)))
        uv.append((.5+.48*math.cos(angle),.5+.48*math.sin(angle)))
    bottom_index=len(verts);verts.append(bottom);uv.append((.5,1.0))
    faces=[]
    for j in range(sides):
        a=1+j;b=1+(j+1)%sides
        faces.append((0,a,b));faces.append((bottom_index,b,a))
    norms=[unit(sub(p,normal_center)) for p in verts]
    return Surface(verts,faces,norms,uv)


def core_mesh(plant: Plant, lod: int) -> Surface:
    if type(lod) is not int or lod not in (0,1,2):
        raise ValueError('Invalid LOD')
    out=Surface([],[],[],[])
    tree=plant.species=='desert_museum'
    for lobe in plant.lobes:
        scale=(.085,.24,.30)[lod] if tree else (.018,.22,.52)[lod]
        radii=(lobe.radii[0]*scale,lobe.radii[1]*scale,lobe.radii[2]*scale)
        _append_surface(out,_support_ellipsoid(lobe.center,radii,4,
                        (0,0,plant.height*(.64 if tree else .44)),
                        rng_for(plant.seed,lobe.id).random()*math.tau))
    return out


def _surface_selection(plant: Plant, lod: int):
    groups={}
    for card in plant.cards:
        groups.setdefault(card.lobe_id,[]).append(card)
    tree=plant.species=='desert_museum'
    stride=(1,4,8)[lod] if tree else (1,3,6)[lod]
    result=[]
    for values in groups.values():
        result.extend(select_coverage(values,stride))
    return result


def foliage_mesh(plant: Plant, lod: int) -> Surface:
    if type(lod) is not int or lod not in (0,1,2):
        raise ValueError('Invalid LOD')
    out=Surface([],[],[],[])
    lookup={l.id:l for l in plant.lobes}
    tree=plant.species=='desert_museum'
    scale=(1.00,1.36,1.65)[lod] if tree else (.96,1.42,1.70)[lod]
    for card in _surface_selection(plant,lod):
        lobe=lookup[card.lobe_id]
        spin=rng_for(plant.seed,'brush:'+card.id).uniform(-math.pi,math.pi)
        _append_surface(out,_brush_polygon(card,lobe,plant.species,scale,spin,False))
        if not tree and lod==0:
            _append_surface(out,_brush_polygon(card,lobe,plant.species,scale*.76,spin+1.11,True))
        elif not tree and lod==1 and int(card.rank*1000003.0)%2==0:
            _append_surface(out,_brush_polygon(card,lobe,plant.species,scale*.82,spin+1.13,True))
    return out


def bounds(plant, lod, wood_vertices):
    core=core_mesh(plant,lod); foliage=foliage_mesh(plant,lod)
    lows=list(wood_vertices)+core.vertices+foliage.vertices;highs=lows.copy()
    inflate=(1,1.14,1.25)[lod]
    for c in selected(plant.flowers,lod):
        radius=.5*math.hypot(*c.size)*inflate
        lows.append(tuple(x-radius for x in c.center));highs.append(tuple(x+radius for x in c.center))
    low=[min(p[k] for p in lows) for k in range(3)]
    high=[max(p[k] for p in highs) for k in range(3)]
    return {'min':[low[0],low[2],-high[1]],'max':[high[0],high[2],-low[1]]}
