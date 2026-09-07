import * as THREE from 'three/webgpu';
import { DESERT_MUSEUM_PALO_VERDE, resolveGrowth, validateSpeciesRecipe } from './recipes.js';

const UP = new THREE.Vector3(0, 1, 0);
const X = new THREE.Vector3(1, 0, 0);
const GOLDEN_ANGLE = Math.PI * (3 - Math.sqrt(5));

class RNG {
  constructor(seed = 41) { this.state = (seed >>> 0) || 1; }
  next() { let t = this.state += 0x6D2B79F5; t = Math.imul(t ^ t >>> 15, t | 1); t ^= t + Math.imul(t ^ t >>> 7, t | 61); return ((t ^ t >>> 14) >>> 0) / 4294967296; }
  range(a, b) { return a + (b - a) * this.next(); }
  signed(v = 1) { return this.range(-v, v); }
  int(a, b) { return Math.floor(this.range(a, b + 1)); }
}
function hashSeed(seed, label) { let h = seed >>> 0; for (let i = 0; i < label.length; i++) h = Math.imul(h ^ label.charCodeAt(i), 16777619) >>> 0; return h || 1; }
function target() { return { positions: [], normals: [], variation: [], uv: [], indices: [] }; }
function geom(d) { const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.Float32BufferAttribute(d.positions, 3)); g.setAttribute('normal', new THREE.Float32BufferAttribute(d.normals, 3)); g.setAttribute('variation', new THREE.Float32BufferAttribute(d.variation, 1)); g.setAttribute('uv', new THREE.Float32BufferAttribute(d.uv, 2)); g.setIndex(d.indices); g.computeBoundingBox(); g.computeBoundingSphere(); return g; }
function frame(direction) { const n = direction.clone().normalize(); const ref = Math.abs(n.dot(UP)) > .93 ? X : UP; const u = new THREE.Vector3().crossVectors(n, ref).normalize(); const v = new THREE.Vector3().crossVectors(n, u).normalize(); return { n, u, v }; }
function branch(id, order, p0, p1, p2, p3, r0, r1, parent = null, leader = 0) { return { id, order, parent, leader, curve: new THREE.CubicBezierCurve3(p0, p1, p2, p3), radius0: r0, radius1: r1 }; }
function pushVertex(out, p, n, variation, u = 0, v = 0) { out.positions.push(p.x, p.y, p.z); out.normals.push(n.x, n.y, n.z); out.variation.push(variation); out.uv.push(u, v); }

function addTube(out, b, scale = 1) {
  const samples = b.order === 0 ? 15 : b.order === 1 ? 10 : b.order === 2 ? 7 : 5, sides = b.order === 0 ? 8 : b.order === 1 ? 6 : 5, base = out.positions.length / 3;
  let previous = null;
  for (let j = 0; j <= samples; j++) {
    const t = j / samples, p = b.curve.getPoint(t), tangent = b.curve.getTangent(Math.min(.999, Math.max(.001, t))); let { u, v } = frame(tangent); if (previous && u.dot(previous) < 0) { u.multiplyScalar(-1); v.multiplyScalar(-1); } previous = u.clone();
    const radius = THREE.MathUtils.lerp(b.radius1, b.radius0, Math.pow(1 - t, .72)) * scale;
    for (let s = 0; s < sides; s++) { const a = s / sides * Math.PI * 2, radial = u.clone().multiplyScalar(Math.cos(a)).addScaledVector(v, Math.sin(a)); const q = p.clone().addScaledVector(radial, radius * (1 + .025 * Math.sin(a * 3 + t * 7 + b.order))); pushVertex(out, q, radial, .52 + b.order * .034 + t * .028); }
  }
  for (let j = 0; j < samples; j++) for (let s = 0; s < sides; s++) { const a = base + j * sides + s, bb = base + j * sides + (s + 1) % sides, c = base + (j + 1) * sides + s, d = base + (j + 1) * sides + (s + 1) % sides; out.indices.push(a, c, bb, bb, c, d); }
}
function atlasUV(tile, x, y) { const inset = .006; return [(tile + inset + x * (1 - inset * 2)) / 4, inset + y * (1 - inset * 2)]; }
function addClusterPlane(out, center, proxy, width, height, spin, tile, variation, tilt = 0) {
  const n = proxy.clone().normalize(); let t = new THREE.Vector3().crossVectors(UP, n); if (t.lengthSq() < 1e-7) t.copy(X); t.normalize(); let b = new THREE.Vector3().crossVectors(n, t).normalize(); const c = Math.cos(spin), s = Math.sin(spin); const rt = t.clone().multiplyScalar(c).addScaledVector(b, s).normalize(), rb = b.clone().multiplyScalar(c).addScaledVector(t, -s).normalize(); t = rt; b = rb;
  const physicalN = n.clone().multiplyScalar(1 - Math.abs(tilt)).addScaledVector(t, tilt).normalize(), base = out.positions.length / 3;
  for (const [x,y] of [[-.5,-.5],[.5,-.5],[.5,.5],[-.5,.5]]) { const p = center.clone().addScaledVector(t, x * width).addScaledVector(b, y * height).addScaledVector(physicalN, Math.sin((x + y) * Math.PI) * width * .018); const [u,v] = atlasUV(tile, x + .5, y + .5); pushVertex(out, p, n, variation, u, v); }
  out.indices.push(base, base + 1, base + 2, base, base + 2, base + 3);
}
function addVolumetricCluster(out, center, proxy, width, height, rng, variation, tile, layers = 3) {
  addClusterPlane(out, center, proxy, width, height, rng.range(-Math.PI, Math.PI), tile, variation, rng.signed(.08)); if (layers < 2) return; const { u, v } = frame(proxy);
  const n2 = proxy.clone().multiplyScalar(.80).addScaledVector(u, rng.next() < .5 ? .32 : -.32).normalize(); addClusterPlane(out, center.clone().addScaledVector(proxy, rng.signed(width * .025)), n2, width * rng.range(.94, 1.06), height * rng.range(.94, 1.07), rng.range(-Math.PI, Math.PI), (tile + 1 + rng.int(0, 2)) % 4, variation + rng.signed(.006), rng.signed(.10)); if (layers < 3) return;
  const n3 = proxy.clone().multiplyScalar(.82).addScaledVector(v, rng.next() < .5 ? .28 : -.28).normalize(); addClusterPlane(out, center.clone().addScaledVector(proxy, rng.signed(width * .018)), n3, width * rng.range(.78, .94), height * rng.range(.82, .98), rng.range(-Math.PI, Math.PI), (tile + 2 + rng.int(0, 1)) % 4, variation + rng.signed(.005), rng.signed(.09));
}

function parentFrame(parent, t) { const origin = parent.curve.getPoint(t), tangent = parent.curve.getTangent(Math.min(.995, Math.max(.005, t))).normalize(); let radial = new THREE.Vector3(origin.x, 0, origin.z); if (radial.lengthSq() < 1e-5) radial = new THREE.Vector3(tangent.x, 0, tangent.z); if (radial.lengthSq() < 1e-5) radial.copy(X); radial.normalize(); return { origin, tangent, radial, side: new THREE.Vector3().crossVectors(UP, radial).normalize() }; }
function growChild(parent, id, order, t, length, sign, rng, radiusScale, upBias, outBias) { const { origin, tangent, radial, side } = parentFrame(parent, t); const dir = tangent.clone().multiplyScalar(rng.range(.16, .32)).addScaledVector(side, sign * rng.range(.40, .72)).addScaledVector(radial, rng.range(outBias * .70, outBias * 1.08)).addScaledVector(UP, rng.range(upBias * .72, upBias * 1.12)).normalize(); const end = origin.clone().addScaledVector(dir, length), p1 = origin.clone().addScaledVector(tangent, length * .16).addScaledVector(UP, length * .04), p2 = origin.clone().lerp(end, .68).addScaledVector(side, sign * length * rng.range(.03, .07)).addScaledVector(UP, length * .04); return branch(id, order, origin, p1, p2, end, parent.radius0 * radiusScale * (1 - t * .22), parent.radius1 * radiusScale * .70, parent.id, parent.leader); }

function buildGraph(params, recipe) {
  const growth = resolveGrowth(recipe, params.maturity), spread = growth.spreadM * params.openness, branches = [], anchors = [], s = recipe.structure;
  for (let i = 0; i < s.leaderCount; i++) {
    const rng = new RNG(hashSeed(params.seed, `leader:${i}`)), a = s.leaderAzimuth[i] + rng.signed(.14), leaderHeight = THREE.MathUtils.lerp(growth.heightM * .58, s.leaderHeightMatureM[i], growth.maturity), p0 = new THREE.Vector3(Math.cos(a) * .04, 0, Math.sin(a) * .04), p3 = new THREE.Vector3(Math.cos(a) * spread * s.leaderReachFraction[i], leaderHeight, Math.sin(a) * spread * s.leaderReachFraction[i]);
    const stem = branch(`stem:${i}`, 0, p0, new THREE.Vector3(Math.cos(a) * spread * .03, leaderHeight * .34, Math.sin(a) * spread * .03), new THREE.Vector3(p3.x * .60 + rng.signed(.12), p3.y * .76, p3.z * .60 + rng.signed(.12)), p3, THREE.MathUtils.lerp(.065, .15, growth.maturity), THREE.MathUtils.lerp(.024, .058, growth.maturity), null, i); branches.push(stem);
    const scaffoldCount = growth.maturity > .62 ? s.scaffoldCountMature : Math.max(2, s.scaffoldCountMature - 2), [lm, lx] = s.scaffoldLengthFraction;
    for (let j = 0; j < scaffoldCount; j++) {
      const r = new RNG(hashSeed(params.seed, `scaffold:${i}:${j}`)), t = .30 + j * (.58 / Math.max(1, scaffoldCount - 1)) + r.signed(.018), length = spread * r.range(lm, lx), sign = (i + j) % 2 ? -1 : 1; const scaffold = growChild(stem, `scaffold:${i}:${j}`, 1, t, length, sign, r, .54, (i === 2 && j === scaffoldCount - 1) ? r.range(.56, .75) : r.range(.22, .42), .74); branches.push(scaffold);
      anchors.push({ branch: scaffold, t: .50, weight: .42, role: 'transition' }, { branch: scaffold, t: .66, weight: .58, role: 'transition' }); for (const at of [.78,.90,.985]) anchors.push({ branch: scaffold, t: at, weight: THREE.MathUtils.lerp(.72, .98, at), role: 'region' });
      const secondaryCount = growth.maturity > .64 ? 3 : 2;
      for (let k = 0; k < secondaryCount; k++) { const br = new RNG(hashSeed(params.seed, `secondary:${i}:${j}:${k}`)), bt = .35 + k * (.48 / Math.max(1, secondaryCount - 1)) + br.signed(.02); const child = growChild(scaffold, `secondary:${i}:${j}:${k}`, 2, bt, length * br.range(.30, .46), (j + k) % 2 ? -1 : 1, br, .46, br.range(.12, .30), .58); branches.push(child); anchors.push({ branch: child, t: .52, weight: .58, role: 'transition' }, { branch: child, t: .68, weight: .68, role: 'transition' }); for (const at of [.80,.94,.992]) anchors.push({ branch: child, t: at, weight: THREE.MathUtils.lerp(.76, 1.0, at), role: 'region' }); if (growth.maturity > .70) { const tr = new RNG(hashSeed(params.seed, `twig:${i}:${j}:${k}`)); const twig = growChild(child, `twig:${i}:${j}:${k}`, 3, tr.range(.52, .72), length * tr.range(.15, .24), tr.next() < .5 ? -1 : 1, tr, .40, tr.range(.06, .20), .48); branches.push(twig); anchors.push({ branch: twig, t: .68, weight: .72, role: 'transition' }, { branch: twig, t: .88, weight: .90, role: 'region' }, { branch: twig, t: .992, weight: 1.0, role: 'region' }); } }
    }
  }
  return { branches, anchors, height: growth.heightM, spread, growth };
}
function anchorFrame(anchor) { const center = anchor.branch.curve.getPoint(anchor.t), tangent = anchor.branch.curve.getTangent(Math.min(.995, anchor.t)).normalize(); const { u, v } = frame(tangent); let outward = new THREE.Vector3(center.x, 0, center.z); if (outward.lengthSq() < 1e-5) outward.copy(u); else outward.normalize(); return { center, tangent, u, v, outward, proxy: outward.clone().multiplyScalar(.48).addScaledVector(UP, .36).addScaledVector(tangent, .16).normalize() }; }
function regionVariation(anchor, f, graph) { const leaderBias = [-.004, 0, .004][anchor.branch.leader % 3], heightBias = THREE.MathUtils.lerp(-.005, .007, THREE.MathUtils.clamp(f.center.y / Math.max(graph.height, .001), 0, 1)); return .505 + leaderBias + heightBias; }

function addGlobalCanopyRegions(foliage, graph, params, recipe) {
  const r = new RNG(hashSeed(params.seed, 'global-canopy-regions')), s = graph.spread, h = graph.height;
  const layout = [
    [-.31,.57,-.04,1.00],[-.23,.70,.08,.92],[-.04,.78,-.06,.88],
    [.23,.70,.05,.94],[.32,.57,-.03,1.02],[-.05,.62,.18,.80],[.08,.64,-.18,.82]
  ];
  let count = 0;
  layout.forEach((q, regionIndex) => {
    const center = new THREE.Vector3(q[0]*s + r.signed(.10), q[1]*h + r.signed(.08), q[2]*s + r.signed(.10));
    const outward = new THREE.Vector3(center.x,0,center.z); if(outward.lengthSq()<1e-5)outward.copy(X); outward.normalize();
    const proxy = outward.clone().multiplyScalar(.42).addScaledVector(UP,.58).normalize();
    const regionTone = .502 + (q[1]-.62)*.030 + [-.004,0,.004,-.002,.003,0,-.003][regionIndex];
    const clusters = regionIndex===2 ? 4 : 5;
    for(let i=0;i<clusters;i++){
      const angle=i*GOLDEN_ANGLE+r.signed(.30), base= r.range(.58,.92)*q[3], width=base*(i===0?1:r.range(.66,.88)), height=width*r.range(.52,.72);
      const p=center.clone().add(new THREE.Vector3(Math.cos(angle)*width*r.range(.08,.25),r.signed(width*.16),Math.sin(angle)*width*r.range(.07,.22)));
      addVolumetricCluster(foliage,p,proxy,width,height,r,regionTone+r.signed(.004),r.int(0,3),3); count++;
    }
  });
  return count;
}

function buildFoliage(graph, params, recipe) {
  const foliage = target(), flowers = target(); let masses = addGlobalCanopyRegions(foliage,graph,params,recipe), accents = 0, bloom = 0, transitions = 0; const globalRegions = masses; const avoid = recipe.growth.mature.spreadM * recipe.canopy.avoidSolidCenterRadiusFraction;
  graph.anchors.forEach(anchor => {
    const rng = new RNG(hashSeed(params.seed, `atlas:${anchor.branch.id}:${anchor.t}`)), f = anchorFrame(anchor); if (f.center.y < graph.height * .29 && anchor.weight < .78) return; const yNorm = THREE.MathUtils.clamp(f.center.y / Math.max(graph.height, .001), 0, 1), upperT = THREE.MathUtils.clamp((yNorm - recipe.canopy.upperCrownStart) / Math.max(.001, 1 - recipe.canopy.upperCrownStart), 0, 1), upperScale = THREE.MathUtils.lerp(1, recipe.canopy.upperCrownScale, upperT), baseTone = regionVariation(anchor, f, graph);
    if (anchor.role === 'transition') {
      if (rng.next() < recipe.canopy.transitionCoverage) { const width = rng.range(.27,.44) * (.80 + anchor.weight * .25) * THREE.MathUtils.lerp(1,1.12,upperT), height = width * rng.range(.50,.68), p = f.center.clone().addScaledVector(f.u,rng.signed(width*.14)).addScaledVector(f.v,rng.signed(width*.09)).addScaledVector(UP,rng.signed(width*.08)); addVolumetricCluster(foliage,p,f.proxy,width,height,rng,baseTone-.007,rng.int(0,3),2); masses++; transitions++; }
    } else {
      let count = rng.int(1,3); if (upperT > .18) count += 1;
      for (let m = 0; m < count; m++) { const hierarchy = m===0?1:rng.range(.58,.78), width=rng.range(.30,.58)*(.82+anchor.weight*.24)*hierarchy*THREE.MathUtils.lerp(1,1.16,upperT), height=width*rng.range(.50,.70), angle=m*GOLDEN_ANGLE+rng.signed(.32), p=f.center.clone().addScaledVector(f.u,Math.cos(angle)*width*rng.range(.06,.22)).addScaledVector(f.v,Math.sin(angle)*width*rng.range(.05,.18)).addScaledVector(UP,rng.signed(width*.14)); if(anchor.t>.92)p.addScaledVector(f.tangent,width*.06); if(Math.hypot(p.x,p.z)<avoid&&p.y>graph.height*.31)p.addScaledVector(f.outward,avoid*rng.range(.15,.30)); addVolumetricCluster(foliage,p,f.proxy,width,height,rng,baseTone+rng.signed(.004),rng.int(0,3),3); masses++; }
    }
    const accentChance=anchor.role==='region'?recipe.canopy.fineAccentFraction*.50:recipe.canopy.fineAccentFraction*.18; if(rng.next()<accentChance){const width=rng.range(.13,.20)*params.sprayScale,height=width*rng.range(.30,.44),p=f.center.clone().addScaledVector(f.u,rng.signed(.07)).addScaledVector(UP,rng.signed(.04));addClusterPlane(foliage,p,f.proxy,width,height,rng.range(-Math.PI,Math.PI),rng.int(0,3),baseTone+rng.signed(.006),rng.signed(.08));accents++;if(rng.next()<recipe.modules.bloom.probabilityAtTerminal){addClusterPlane(flowers,p.clone().addScaledVector(UP,.018),f.proxy,width*.40,height*.48,rng.range(-Math.PI,Math.PI),rng.int(0,3),.52,rng.signed(.06));bloom++;}}
  });
  return {foliage:geom(foliage),flowers:geom(flowers),masses,accents,bloom,transitions,globalRegions};
}

export function buildDesertMuseum(params, recipe = DESERT_MUSEUM_PALO_VERDE) {
  validateSpeciesRecipe(recipe); const graph=buildGraph(params,recipe),wood=target(),outline=target(); for(const b of graph.branches){addTube(wood,b,1);if(b.order===0)addTube(outline,b,1.024);} const crown=buildFoliage(graph,params,recipe),woodG=geom(wood),outlineG=geom(outline),triangles=(woodG.index.count+outlineG.index.count+crown.foliage.index.count+crown.flowers.index.count)/3; if(triangles>recipe.lod0Budget.triangleHardCap)throw new Error(`LOD0 hard cap exceeded: ${triangles}`);
  return {wood:woodG,outline:outlineG,foliage:crown.foliage,flowers:crown.flowers,flowerCount:crown.bloom,report:{schema:'threejs-palo-verde/2',recipeSchema:recipe.schema,recipeId:recipe.id,styleProfile:recipe.styleProfile,seed:params.seed,maturity:params.maturity,targetHeightM:graph.height,targetSpreadM:graph.spread,branches:graph.branches.length,structuralBranches:graph.branches.length,microTwigs:0,foliageMasses:crown.masses,fineSprays:crown.accents,transitionMasses:crown.transitions,globalCanopyRegions:crown.globalRegions,foliageBrushes:crown.masses+crown.accents,flowerBrushes:crown.bloom,triangles,triangleTarget:recipe.lod0Budget.triangleTarget,triangleHardCap:recipe.lod0Budget.triangleHardCap,targetMet:triangles<=recipe.lod0Budget.triangleTarget,lod:0,calendarCalibrated:false,foliageRepresentation:'painted foliage atlas on fixed 3D quadmesh with bent proxy normals; illustrator-first global canopy regions plus branch-local detail'}};
}
