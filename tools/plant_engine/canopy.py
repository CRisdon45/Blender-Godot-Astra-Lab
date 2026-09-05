"""Original offline canopy art direction over the existing species grammar.

Opaque interior masses plus sparse edge sprays, inspired by documented Airborn /
Rogue Spirit workflows. No imported tutorial assets or code. Normal transfer is
computed analytically. Dimensions are illustrative, never calendar predictions.
"""
from __future__ import annotations
from dataclasses import dataclass, replace
import math
from typing import Iterable
from species_lab_core import (Plant, Branch, Lobe, Card, compile_plant, bezier, add,
                              sub, mul, mix, unit, dot, cross, rng_for, RECIPES)
from .coverage import select_coverage

VERSION = 'canopy-study/1.1'


def compose(species: str, seed: int, maturity: float) -> Plant:
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
                angle = i*math.tau/3 + rnd.uniform(-.28,.28)
                height = h*((.87,.73,.92)[i] + rnd.uniform(-.025,.025))
                radial = w*((.23,.34,.16)[i] + rnd.uniform(-.025,.025))
            else:
                angle = i*2.39996323 + rnd.uniform(-.12,.12)
                height = h*((.31,.36,.34,.52,.58,.51,.66)[i])
                radial = w*((.25,.24,.27,.18,.16,.20,.035)[i])
            end = (math.cos(angle)*radial, math.sin(angle)*radial, height)
            delta = sub(end,origin)
            controls = [origin, add(origin,(delta[0]*.16,delta[1]*.16,delta[2]*.49)),
                        add(origin,(delta[0]*.66,delta[1]*.70,delta[2]*.87)),end]
            old.points = controls
            old.radius = root.radius*.49
            radii = (w*.16,w*.135,h*.11) if tree else (w*.285,w*.28,h*.33)
            if not tree and i==6: radii=(w*.29,w*.30,h*.33)
            lobes.append(Lobe(old.id,old.id,end,radii))
        else:
            j = int(old.id.split(':')[2])
            leader = parent.points[-1]
            angle = math.atan2(leader[1],leader[0])
            angle += (-1 if j%2 else 1)*rnd.uniform(.62,1.12)
            if tree:
                radial = w*rnd.uniform(.10,.19)
                base = bezier(parent.points,min(.99,old.attach_t+.15))
                end = add(base,(math.cos(angle)*radial,math.sin(angle)*radial,
                                h*rnd.uniform(.025,.11)))
                end = (end[0],end[1],min(end[2],h*.91))
                radii = (w*rnd.uniform(.12,.155),w*rnd.uniform(.11,.145),h*rnd.uniform(.085,.115))
                lobes.append(Lobe(old.id,old.id,end,radii))
            else:
                end = (math.cos(angle)*w*.25,math.sin(angle)*w*.25,h*(.40+.17*j))
            old.points = [origin,add(origin,(0,0,h*(.055 if tree else .045))),mix(origin,end,.72),end]
            old.radius = parent.radius*(1-parent.taper*old.attach_t)*.62
        branches[old.id] = old
    plant.lobes=lobes
    plant.cards=[]; plant.flowers=[]
    count=48
    for lobe in lobes:
        phase=rng_for(seed,lobe.id).random()*math.tau
        for index in range(count):
            rnd=rng_for(seed,f'art:{lobe.id}:{index}')
            z=1-2*(index+.5)/count
            angle=index*2.39996323+phase
            ring=math.sqrt(max(0,1-z*z))
            direction=(ring*math.cos(angle),ring*math.sin(angle),z)
            center=add(lobe.center,tuple(direction[k]*lobe.radii[k] for k in range(3)))
            if any(other.id!=lobe.id and sum(((center[k]-other.center[k])/other.radii[k])**2 for k in range(3))<.92 for other in lobes):
                continue
            local=unit(tuple(direction[k]/lobe.radii[k] for k in range(3)))
            global_n=unit(sub(center,(0,0,h*(.64 if tree else .44))))
            n=unit(add(mul(local,.55 if tree else .48),mul(global_n,.45 if tree else .52)))
            size=(.14+.16*maturity) if tree else (.085+.065*maturity)
            size*=rnd.uniform(.85,1.18)
            plant.cards.append(Card(f'{lobe.id}/spray:{index}',lobe.id,center,n,
                                    (size,size*(.78 if tree else .9)),rnd.randrange(4),
                                    min(1,max(0,center[2]/h)),rnd.random()))
            if index%4==0 and z>-.25:
                plant.flowers.append(Card(f'{lobe.id}/flower:{index}',lobe.id,
                    add(center,mul(direction,size*.14)),n,(size*.66,size*.66),rnd.randrange(4),
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


def _surface(center, radii, rings, sides, phase=0.0, shrink=1.0):
    """Closed UV sphere with non-degenerate pole fans and outward winding."""
    verts=[]; norms=[]; uvs=[]
    def point(theta,phi):
        d=(math.sin(phi)*math.cos(theta),math.sin(phi)*math.sin(theta),math.cos(phi))
        wave=1+.070*math.sin(3*theta+phase)*math.sin(phi)**2+.035*math.cos(5*theta-phi+phase)*math.sin(phi)
        p=add(center,tuple(d[k]*radii[k]*wave*shrink for k in range(3)))
        n=unit(tuple(d[k]/radii[k] for k in range(3)))
        return p,n
    verts.append(add(center,(0,0,radii[2]*shrink))); norms.append((0,0,1));uvs.append((.5,0))
    for i in range(1,rings):
        for j in range(sides+1):
            theta=math.tau*j/sides; phi=math.pi*i/rings
            p,n=point(theta,phi);verts.append(p);norms.append(n);uvs.append((j/sides,i/rings))
    bottom=len(verts);verts.append(add(center,(0,0,-radii[2]*shrink)));norms.append((0,0,-1));uvs.append((.5,1))
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


def core_mesh(plant: Plant, lod: int) -> Surface:
    if type(lod) is not int or lod not in (0,1,2):raise ValueError('Invalid LOD')
    out=Surface([],[],[],[])
    tree=plant.species=='desert_museum'
    for lobe in plant.lobes:
        rings=(5,4,3)[lod] if tree else (7,5,4)[lod]
        sides=(8,6,5)[lod] if tree else (10,8,6)[lod]
        part=_surface(lobe.center,lobe.radii,rings,sides,
                      rng_for(plant.seed,lobe.id).random()*math.tau,
                      .94 if tree else .965)
        start=len(out.vertices)
        out.vertices.extend(part.vertices)
        out.triangles.extend(tuple(i+start for i in face) for face in part.triangles)
        for p,n in zip(part.vertices,part.normals):
            overall=unit(sub(p,(0,0,plant.height*(.64 if tree else .44))))
            out.normals.append(unit(add(mul(n,.55 if tree else .48),mul(overall,.45 if tree else .52))))
        out.uv.extend(part.uv)
    return out


def bounds(plant, lod, wood_vertices):
    core=core_mesh(plant,lod)
    lows=list(wood_vertices)+core.vertices;highs=lows.copy()
    inflate=(1,1.20,1.38)[lod]
    for c in selected(plant.cards,lod)+selected(plant.flowers,lod):
        radius=.5*math.hypot(*c.size)*inflate
        lows.append(tuple(x-radius for x in c.center));highs.append(tuple(x+radius for x in c.center))
    low=[min(p[k] for p in lows) for k in range(3)]
    high=[max(p[k] for p in highs) for k in range(3)]
    return {'min':[low[0],low[2],-high[1]],'max':[high[0],high[2],-low[1]]}
