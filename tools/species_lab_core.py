"""Deterministic species-witness compiler. Pure Python; Blender is only an adapter.
Coordinates: metres, Z up. Growth stage is illustrative, NOT a calibrated age.
All LODs sample the same branch graph and persistent card IDs. No runtime AI.
"""
from __future__ import annotations
from dataclasses import dataclass, field
import hashlib
import math
import random
V = tuple[float, float, float]
TAU = math.tau

def add(a: V, b: V) -> V: return tuple(x+y for x,y in zip(a,b))
def sub(a: V, b: V) -> V: return tuple(x-y for x,y in zip(a,b))
def mul(a: V, n: float) -> V: return tuple(x*n for x in a)
def dot(a: V,b: V) -> float: return sum(x*y for x,y in zip(a,b))
def cross(a: V,b: V) -> V: return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def unit(a: V) -> V: return mul(a, 1/max(math.sqrt(dot(a,a)), 1e-9))
def mix(a: V,b: V,t:float) -> V: return add(mul(a,1-t),mul(b,t))
def rng_for(seed:int, key:str) -> random.Random:
    return random.Random(int.from_bytes(hashlib.sha256(f'{seed}:{key}'.encode()).digest()[:8], 'big'))
def bezier(p:list[V], t:float) -> V:
    q=list(p)
    while len(q)>1: q=[mix(a,b,t) for a,b in zip(q,q[1:])]
    return q[0]

@dataclass
class Branch:
    id: str
    parent: str | None
    attach_t: float
    points: list[V]
    radius: float
    order: int
    taper: float = .91
@dataclass
class Lobe:
    id: str
    branch_id: str
    center: V
    radii: V
@dataclass
class Card:
    id: str
    lobe_id: str
    center: V
    normal: V
    size: tuple[float,float]
    tile: int
    shade: float
    rank: float
@dataclass
class Plant:
    species: str
    seed: int
    maturity: float
    height: float
    spread: float
    branches: list[Branch] = field(default_factory=list)
    lobes: list[Lobe] = field(default_factory=list)
    cards: list[Card] = field(default_factory=list)
    flowers: list[Card] = field(default_factory=list)

PROFILES = {
    'desert_museum': {
        'name': 'Desert Museum palo verde', 'botanical': "Parkinsonia x 'Desert Museum'",
        'cultivar': 'Desert Museum', 'family': 'open_vase_tree',
        'installed_m': [2.60,1.60], 'mature_m': [7.60,7.60],
        'dimension_status': 'mature target within published range; installed size illustrative, not container-size certified',
        'leaves': [[.17,.27,.14],[.34,.46,.21],[.61,.66,.35]],
        'wood': [[.16,.25,.13],[.31,.41,.19],[.49,.55,.28]],
        'flowers': [[.51,.35,.05],[.89,.66,.07],[1.0,.87,.29]],
        'source': 'https://extension.arizona.edu/es/publication/arboles-de-mezquite-y-palo-verde-para-el-paisaje-urbano',
        'phenology': 'yellow spring bloom, possible later pulses; exact dates and litter rates uncalibrated',
    },
    'texas_sage': {
        'name': 'Texas sage, natural form', 'botanical': 'Leucophyllum frutescens',
        'cultivar': None, 'family': 'basal_woody_shrub',
        'installed_m': [.60,.65], 'mature_m': [1.83,1.83],
        'dimension_status': 'generic AMWUA landscape target; cultivar must be selected for production',
        'leaves': [[.24,.31,.27],[.45,.54,.46],[.68,.73,.62]],
        'wood': [[.23,.23,.18],[.39,.38,.28],[.57,.54,.40]],
        'flowers': [[.31,.16,.35],[.59,.32,.65],[.83,.59,.83]],
        'source': 'https://www.amwua.org/plants/texas-sage',
        'phenology': 'summer/fall monsoon-related bloom pulses; generally low litter; local post-bloom drop possible',
    }
}

def compile_plant(species:str, seed:int=41, maturity:float=1.0) -> Plant:
    if species not in PROFILES: raise ValueError(f'Unknown species: {species}')
    if not math.isfinite(maturity) or not 0<=maturity<=1: raise ValueError('maturity must be in [0,1]')
    p=PROFILES[species]
    h=p['installed_m'][0]+(p['mature_m'][0]-p['installed_m'][0])*maturity
    w=p['installed_m'][1]+(p['mature_m'][1]-p['installed_m'][1])*maturity**1.15
    plant=Plant(species, seed, maturity, h, w)
    tree=species=='desert_museum'
    trunk_top=h*(.35-.17*maturity) if tree else h*.055
    trunk=Branch('root',None,0,[(0,0,0),(.018*w,0,trunk_top*.3),(-.013*w,.008*w,trunk_top*.7),(0,0,trunk_top)],
                 (.035+.12*maturity) if tree else .020*h,0, .40 if tree else .50)
    plant.branches.append(trunk)
    count=3 if tree else 7
    for i in range(count):
        r=rng_for(seed, f'leader:{i}')
        a=i*TAU/count+r.uniform(-.20,.20)
        height=h*(r.uniform(.74,.87) if tree else (r.uniform(.30,.37) if i<3 else (r.uniform(.51,.59) if i<6 else .67)))
        radial=w*(r.uniform(.25,.32) if tree else (r.uniform(.26,.30) if i<3 else (r.uniform(.16,.22) if i<6 else .045)))
        tip=(math.cos(a)*radial,math.sin(a)*radial,height)
        attach=.65+.32*(i/max(1,count-1))
        start=bezier(trunk.points,attach)
        c1=add(start,(math.cos(a)*radial*.10,math.sin(a)*radial*.10,(height-start[2])*.44))
        c2=(math.cos(a+.12)*radial*.60,math.sin(a+.12)*radial*.60,start[2]+(height-start[2])*.78)
        b=Branch(f'leader:{i}','root',attach,[start,c1,c2,tip],trunk.radius*(.49 if tree else .48),1, .72 if tree else .78)
        plant.branches.append(b)
        if tree:
            # Size changes architecture, not just a uniform transform.
            for j,t in enumerate((.42,.58,.73,.87)):
                if j==0 and maturity<.18: continue
                rr=rng_for(seed,f'secondary:{i}:{j}')
                ang=a+(-1 if j%2 else 1)*rr.uniform(.50,1.0)
                radial2=w*rr.uniform(.28,.36)
                end=(math.cos(ang)*radial2,math.sin(ang)*radial2,h*(.61+.055*j+rr.uniform(-.035,.035)))
                origin=bezier(b.points,t)
                child=Branch(f'secondary:{i}:{j}',b.id,t,[origin,add(origin,(0,0,h*.11)),mix(origin,end,.73),end],b.radius*(1-b.taper*t)*.68,2)
                plant.branches.append(child)
                plant.lobes.append(Lobe(child.id,child.id,end,(w*.14,w*.105,h*.062)))
            plant.lobes.append(Lobe(b.id,b.id,tip,(w*.15,w*.115,h*.080)))
        else:
            # Low shoulders, middle masses and a crown: a shrub, not a miniature tree.
            plant.lobes.append(Lobe(b.id,b.id,tip,(w*(.25 if i<3 else .29),w*(.24 if i<3 else .27),h*(.30 if i<3 else .32))))
            for j,t in enumerate((.50,.76)):
                if j==0 and maturity<.2: continue
                origin=bezier(b.points,t)
                ang=a+(-1 if j else 1)*.68
                end=(math.cos(ang)*w*.28,math.sin(ang)*w*.28,h*(.47+.16*j))
                child=Branch(f'twig:{i}:{j}',b.id,t,[origin,mix(origin,end,.28),mix(origin,end,.72),end],b.radius*(1-b.taper*t)*.60,2)
                plant.branches.append(child)
    total_per_lobe=88 if tree else 100
    max_brush=(.26+.23*maturity) if tree else (.18+.11*maturity)
    for li,l in enumerate(plant.lobes):
        phase=rng_for(seed,l.id).random()*TAU
        for j in range(total_per_lobe):
            rr=rng_for(seed,f'{l.id}/leaf:{j}')
            z=1-2*(j+.5)/total_per_lobe
            angle=j*2.399963229728653+phase
            radius=math.sqrt(max(0,1-z*z))
            direction=(radius*math.cos(angle),radius*math.sin(angle),z)
            offset=tuple(direction[k]*l.radii[k]*rr.uniform(.91,1.0) for k in range(3))
            center=add(l.center,offset)
            # Reject deep covered brushes without removing the volumetric outer shell.
            covered=any(other.id!=l.id and sum(((center[k]-other.center[k])/other.radii[k])**2 for k in range(3))<.68 for other in plant.lobes)
            if covered: continue
            local=unit(tuple(direction[k]/l.radii[k] for k in range(3)))
            overall=unit(sub(center,(0,0,h*(.66 if tree else .40))))
            normal=unit(add(mul(local,.24 if tree else .48),mul(overall,.76 if tree else .52)))
            size=max_brush*rr.uniform(.84,1.12)
            card=Card(f'{l.id}/leaf:{j}',l.id,center,normal,(size,size*(.74 if tree else .90)),rr.randrange(4),.5+.4*z,rr.random())
            plant.cards.append(card)
            if j%3==0 and z>-.55:
                flower_center=add(center,mul(direction,max_brush*.10))
                plant.flowers.append(Card(f'{l.id}/flower:{j}',l.id,flower_center,normal,(size*.43,size*.43),rr.randrange(4),.5+.4*z,rr.random()))
    return plant

def cards_for_lod(cards:list[Card],lod:int) -> list[Card]:
    if lod not in (0,1,2): raise ValueError('LOD must be 0, 1 or 2')
    stride=(1,2,4)[lod]
    by_lobe={}
    for c in cards: by_lobe.setdefault(c.lobe_id,[]).append(c)
    return [c for values in by_lobe.values() for c in sorted(values,key=lambda v:(v.rank,v.id))[::stride]]

def wood_mesh(plant:Plant,lod:int):
    vertices=[]; faces=[]
    sides=((7,5,4) if plant.species=='desert_museum' else (5,4,3))[lod]
    segments=((8,5,3) if plant.species=='desert_museum' else (4,3,2))[lod]
    for b in plant.branches:
        steps=segments if b.order<2 else max(2,segments-3)
        points=[bezier(b.points,i/steps) for i in range(steps+1)]
        offset=len(vertices)
        previous_u=None
        for i,p in enumerate(points):
            tangent=unit(sub(points[min(i+1,steps)],points[max(0,i-1)]))
            reference=(0,1,0) if abs(tangent[1])<.9 else (1,0,0)
            u=unit(cross(tangent,reference))
            if previous_u is not None and dot(u,previous_u)<0: u=mul(u,-1)
            v=unit(cross(tangent,u)); previous_u=u
            radius=b.radius*(1-b.taper*(i/steps))
            for k in range(sides): vertices.append(add(p,mul(add(mul(u,math.cos(k*TAU/sides)),mul(v,math.sin(k*TAU/sides))),radius)))
            if i:
                for k in range(sides):
                    a=offset+(i-1)*sides+k; bb=offset+(i-1)*sides+(k+1)%sides
                    faces.extend([(a,bb,bb+sides),(a,bb+sides,a+sides)])
        for k in range(1,sides-1):
            faces.append((offset,offset+k+1,offset+k))
            end=offset+steps*sides; faces.append((end,end+k,end+k+1))
    return vertices,faces

def metrics(plant:Plant,lod:int) -> dict:
    v,f=wood_mesh(plant,lod)
    leaf=cards_for_lod(plant.cards,lod); flowers=cards_for_lod(plant.flowers,lod)
    lows=[list(p) for p in v]; highs=[list(p) for p in v]
    for c in leaf+flowers:
        inflate=(1.0,1.27,1.6)[lod]
        r=.5*math.hypot(*c.size)*inflate
        lows.append([x-r for x in c.center]); highs.append([x+r for x in c.center])
    return {'wood_triangles':len(f),'leaf_cards':len(leaf),'flower_cards':len(flowers),
            'total_triangles':len(f)+2*(len(leaf)+len(flowers)),
            'safe_aabb_z_up':[[min(p[k] for p in lows) for k in range(3)],[max(p[k] for p in highs) for k in range(3)]],
            'nominal_height_m':plant.height,'nominal_spread_m':plant.spread}
