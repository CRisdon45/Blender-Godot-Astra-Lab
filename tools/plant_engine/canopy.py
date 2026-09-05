"""Original offline foliage-module art direction over the species grammar.

Canopy-study/2 keeps a recessed opaque support volume but moves the visible
silhouette to many smaller, branch-aware opaque foliage modules. Sparse flowers
remain cutout brushes. No third-party tutorial assets or code are included.
Normal grouping is computed analytically during compilation, not on the tablet.
"""
from __future__ import annotations
from dataclasses import dataclass
import math
from typing import Iterable
from species_lab_core import (Plant, Lobe, Card, compile_plant, bezier, add,
                              sub, mul, mix, unit, dot, cross, rng_for)
from .coverage import select_coverage

VERSION = 'canopy-study/2.0'
UP = (0.0, 0.0, 1.0)


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
                # Deliberately unequal leaders: a palo verde should not read as a topiary.
                angle = i*math.tau/3 + rnd.uniform(-.31,.31)
                height = h*((.89,.72,.94)[i] + rnd.uniform(-.025,.025))
                radial = w*((.22,.35,.15)[i] + rnd.uniform(-.025,.025))
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
            radii = (w*.145,w*.115,h*.095) if tree else (w*.285,w*.28,h*.33)
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
                radii = (w*rnd.uniform(.105,.135),w*rnd.uniform(.085,.115),h*rnd.uniform(.065,.095))
                lobes.append(Lobe(old.id,old.id,end,radii))
            else:
                end = (math.cos(angle)*w*.25,math.sin(angle)*w*.25,h*(.40+.17*j))
            old.points = [origin,add(origin,(0,0,h*(.055 if tree else .045))),mix(origin,end,.72),end]
            old.radius = parent.radius*(1-parent.taper*old.attach_t)*.62
        branches[old.id] = old
    plant.lobes = lobes
    # Cards are retained as deterministic surface/flower anchors. Leaf rendering in
    # this study is opaque module geometry; only flowers consume cutout cards.
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
            global_n=unit(sub(center,(0,0,h*(.64 if tree else .44))))
            n=unit(add(mul(local,.54 if tree else .44),mul(global_n,.46 if tree else .56)))
            size=(.13+.14*maturity) if tree else (.075+.055*maturity)
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


def _ellipsoid(center, radii, rings, sides, phase=0.0, shrink=1.0, normal_center=None,
               normal_local_weight=.5):
    """Low-poly asymmetric ellipsoid with shared canopy normals and no alpha."""
    verts=[]; norms=[]; uvs=[]
    normal_center = normal_center or center
    def point(theta,phi):
        d=(math.sin(phi)*math.cos(theta),math.sin(phi)*math.sin(theta),math.cos(phi))
        wave=1+.075*math.sin(3*theta+phase)*math.sin(phi)**2+.040*math.cos(5*theta-phi+phase)*math.sin(phi)
        p=add(center,tuple(d[k]*radii[k]*wave*shrink for k in range(3)))
        local=unit(tuple(d[k]/max(radii[k],1e-9) for k in range(3)))
        broad=unit(sub(p,normal_center))
        n=unit(add(mul(local,normal_local_weight),mul(broad,1-normal_local_weight)))
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
    """Nested artist-like cluster layout: close adds smaller infill, far keeps silhouette anchors."""
    tree=plant.species=='desert_museum'
    # Ordered by silhouette importance so LODs are nested rather than regenerated.
    pattern = [
        (0.00, 0.00, 0.02, 1.00),
        (-.34, .18, -.08, .78),
        (.30, -.22, .10, .76),
        (.05, .31, .24, .68),
        (-.08, -.32, .18, .64),
        (.34, .13, -.18, .58),
    ] if tree else [
        (0.00, 0.00, 0.00, 1.00),
        (-.28, .18, -.14, .80),
        (.27, -.20, .08, .80),
        (.05, .29, .22, .72),
        (-.08, -.28, .18, .70),
        (.25, .12, -.18, .64),
        (-.24, -.10, .30, .60),
    ]
    keep=(5,3,2)[lod] if tree else (7,4,2)[lod]
    forward,right=_frame_for_lobe(plant,lobe)
    result=[]
    for index,(a,b,c,scale) in enumerate(pattern[:keep]):
        rnd=rng_for(plant.seed,f'module:{lobe.id}:{index}')
        a+=rnd.uniform(-.045,.045);b+=rnd.uniform(-.045,.045);c+=rnd.uniform(-.035,.035)
        offset=add(add(mul(forward,a*lobe.radii[0]),mul(right,b*lobe.radii[1])),mul(UP,c*lobe.radii[2]))
        center=add(lobe.center,offset)
        # Flatten tree sprays along depth; sage modules overlap as a continuous mound.
        if tree:
            radii=(lobe.radii[0]*(.63*scale)*rnd.uniform(.92,1.08),
                   lobe.radii[1]*(.46*scale)*rnd.uniform(.90,1.10),
                   lobe.radii[2]*(.72*scale)*rnd.uniform(.90,1.10))
        else:
            radii=(lobe.radii[0]*(.54*scale)*rnd.uniform(.92,1.08),
                   lobe.radii[1]*(.52*scale)*rnd.uniform(.92,1.08),
                   lobe.radii[2]*(.54*scale)*rnd.uniform(.92,1.08))
        result.append((center,radii,rnd.random()*math.tau))
    return result


def core_mesh(plant: Plant, lod: int) -> Surface:
    """Recessed support volume: it closes holes but should not dominate close art."""
    if type(lod) is not int or lod not in (0,1,2):raise ValueError('Invalid LOD')
    out=Surface([],[],[],[])
    tree=plant.species=='desert_museum'
    for lobe in plant.lobes:
        rings=(4,3,3)[lod] if tree else (5,4,3)[lod]
        sides=(6,5,4)[lod] if tree else (8,6,5)[lod]
        part=_ellipsoid(lobe.center,lobe.radii,rings,sides,
                        rng_for(plant.seed,lobe.id).random()*math.tau,
                        .56 if tree else .70,
                        (0,0,plant.height*(.64 if tree else .44)),
                        .56 if tree else .43)
        _append_surface(out,part)
    return out


def foliage_mesh(plant: Plant, lod: int) -> Surface:
    """Visible opaque foliage modules; these carry silhouette and most canopy detail."""
    if type(lod) is not int or lod not in (0,1,2):raise ValueError('Invalid LOD')
    out=Surface([],[],[],[])
    tree=plant.species=='desert_museum'
    for lobe in plant.lobes:
        for module_index,(center,radii,phase) in enumerate(_module_centers(plant,lobe,lod)):
            rings=(3,3,2)[lod]
            sides=(6,5,4)[lod] if tree else (6,6,5)[lod]
            part=_ellipsoid(center,radii,rings,sides,phase,1.0,
                            (0,0,plant.height*(.64 if tree else .44)),
                            .50 if tree else .40)
            _append_surface(out,part)
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
