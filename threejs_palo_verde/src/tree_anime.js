import * as THREE from 'three/webgpu';
import { DESERT_MUSEUM_PALO_VERDE, resolveGrowth, validateSpeciesRecipe } from './recipes.js';

const UP = new THREE.Vector3(0, 1, 0);
const X = new THREE.Vector3(1, 0, 0);
const GOLDEN_ANGLE = Math.PI * (3 - Math.sqrt(5));

class RNG {
  constructor(seed = 41) { this.state = (seed >>> 0) || 1; }
  next() {
    let t = this.state += 0x6D2B79F5;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }
  range(a, b) { return a + (b - a) * this.next(); }
  signed(v = 1) { return this.range(-v, v); }
  int(a, b) { return Math.floor(this.range(a, b + 1)); }
}

function hashSeed(seed, label) {
  let h = seed >>> 0;
  for (let i = 0; i < label.length; i++) h = Math.imul(h ^ label.charCodeAt(i), 16777619) >>> 0;
  return h || 1;
}

function target() { return { positions: [], normals: [], variation: [], indices: [] }; }

function geometry(data) {
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(data.positions, 3));
  g.setAttribute('normal', new THREE.Float32BufferAttribute(data.normals, 3));
  g.setAttribute('variation', new THREE.Float32BufferAttribute(data.variation, 1));
  g.setIndex(data.indices);
  g.computeBoundingBox();
  g.computeBoundingSphere();
  return g;
}

function frameFrom(direction) {
  const n = direction.clone().normalize();
  const ref = Math.abs(n.dot(UP)) > .93 ? X : UP;
  const u = new THREE.Vector3().crossVectors(n, ref).normalize();
  const v = new THREE.Vector3().crossVectors(n, u).normalize();
  return { n, u, v };
}

function branch(id, order, p0, p1, p2, p3, radius0, radius1, parent = null) {
  return { id, order, parent, curve: new THREE.CubicBezierCurve3(p0, p1, p2, p3), radius0, radius1 };
}

function addTube(out, b, scale = 1) {
  const samples = b.order === 0 ? 15 : b.order === 1 ? 10 : b.order === 2 ? 7 : 5;
  const sides = b.order === 0 ? 8 : b.order === 1 ? 6 : 5;
  const base = out.positions.length / 3;
  let previous = null;
  for (let j = 0; j <= samples; j++) {
    const t = j / samples;
    const p = b.curve.getPoint(t);
    const tangent = b.curve.getTangent(Math.min(.999, Math.max(.001, t)));
    let { u, v } = frameFrom(tangent);
    if (previous && u.dot(previous) < 0) { u.multiplyScalar(-1); v.multiplyScalar(-1); }
    previous = u.clone();
    const radius = THREE.MathUtils.lerp(b.radius1, b.radius0, Math.pow(1 - t, .72)) * scale;
    for (let s = 0; s < sides; s++) {
      const a = s / sides * Math.PI * 2;
      const radial = u.clone().multiplyScalar(Math.cos(a)).addScaledVector(v, Math.sin(a));
      const q = p.clone().addScaledVector(radial, radius * (1 + .025 * Math.sin(a * 3 + t * 7 + b.order)));
      out.positions.push(q.x, q.y, q.z);
      out.normals.push(radial.x, radial.y, radial.z);
      out.variation.push(.54 + b.order * .045 + t * .035);
    }
  }
  for (let j = 0; j < samples; j++) {
    for (let s = 0; s < sides; s++) {
      const a = base + j * sides + s;
      const bb = base + j * sides + (s + 1) % sides;
      const c = base + (j + 1) * sides + s;
      const d = base + (j + 1) * sides + (s + 1) % sides;
      out.indices.push(a, c, bb, bb, c, d);
    }
  }
}

function addQuad(out, points, normal, variation) {
  const base = out.positions.length / 3;
  for (const p of points) {
    out.positions.push(p.x, p.y, p.z);
    out.normals.push(normal.x, normal.y, normal.z);
    out.variation.push(variation);
  }
  out.indices.push(base, base + 1, base + 2, base, base + 2, base + 3);
}

function addPaintedPuff(out, center, proxy, width, height, depth, spin, variation, rng) {
  const n = proxy.clone().normalize();
  let t = new THREE.Vector3().crossVectors(UP, n);
  if (t.lengthSq() < 1e-7) t.copy(X);
  t.normalize();
  let b = new THREE.Vector3().crossVectors(n, t).normalize();
  const c = Math.cos(spin), s = Math.sin(spin);
  const rt = t.clone().multiplyScalar(c).addScaledVector(b, s).normalize();
  const rb = b.clone().multiplyScalar(c).addScaledVector(t, -s).normalize();
  t = rt; b = rb;

  const sides = 9;
  const rings = [-.62, 0, .62];
  const base = out.positions.length / 3;
  const phase = rng.range(-Math.PI, Math.PI);
  for (let r = 0; r < rings.length; r++) {
    const lat = rings[r];
    const ringScale = Math.cos(lat * Math.PI * .5);
    const z = Math.sin(lat * Math.PI * .5);
    for (let i = 0; i < sides; i++) {
      const a = i / sides * Math.PI * 2;
      const edge = 1 + .12 * Math.sin(a * 3 + phase) + .045 * Math.cos(a * 5 - phase * .7);
      const lx = Math.cos(a) * width * .5 * ringScale * edge;
      const ly = Math.sin(a) * height * .5 * ringScale * edge;
      const lz = z * depth * .5 * (1 + .06 * Math.sin(a * 2 + phase));
      const p = center.clone().addScaledVector(t, lx).addScaledVector(b, ly).addScaledVector(n, lz);
      const local = t.clone().multiplyScalar(lx / Math.max(width * width, 1e-6))
        .addScaledVector(b, ly / Math.max(height * height, 1e-6))
        .addScaledVector(n, lz / Math.max(depth * depth, 1e-6)).normalize();
      const grouped = proxy.clone().multiplyScalar(.80).addScaledVector(local, .20).normalize();
      out.positions.push(p.x, p.y, p.z);
      out.normals.push(grouped.x, grouped.y, grouped.z);
      out.variation.push(variation + (r - 1) * .004);
    }
  }
  const top = out.positions.length / 3;
  const tp = center.clone().addScaledVector(n, depth * .54);
  out.positions.push(tp.x, tp.y, tp.z); out.normals.push(n.x, n.y, n.z); out.variation.push(variation + .006);
  const bottom = out.positions.length / 3;
  const bp = center.clone().addScaledVector(n, -depth * .54);
  out.positions.push(bp.x, bp.y, bp.z); out.normals.push(n.x, n.y, n.z); out.variation.push(variation - .006);

  for (let r = 0; r < rings.length - 1; r++) {
    for (let i = 0; i < sides; i++) {
      const a = base + r * sides + i;
      const bb = base + r * sides + (i + 1) % sides;
      const cc = base + (r + 1) * sides + i;
      const d = base + (r + 1) * sides + (i + 1) % sides;
      out.indices.push(a, cc, bb, bb, cc, d);
    }
  }
  for (let i = 0; i < sides; i++) {
    out.indices.push(top, base + 2 * sides + (i + 1) % sides, base + 2 * sides + i);
    out.indices.push(bottom, base + i, base + (i + 1) % sides);
  }
}

function addCompoundAccent(out, center, direction, proxy, length, rng, variation, recipe) {
  const axis = direction.clone().normalize();
  let side = new THREE.Vector3().crossVectors(proxy, axis);
  if (side.lengthSq() < 1e-7) side = frameFrom(axis).u;
  side.normalize();
  const normal = new THREE.Vector3().crossVectors(axis, side).normalize();
  if (normal.dot(proxy) < 0) normal.multiplyScalar(-1);
  const start = center.clone().addScaledVector(axis, -length * .46);
  const end = center.clone().addScaledVector(axis, length * .54);
  const rw = Math.max(.0035, length * .008);
  addQuad(out, [
    start.clone().addScaledVector(side, rw), end.clone().addScaledVector(side, rw * .55),
    end.clone().addScaledVector(side, -rw * .55), start.clone().addScaledVector(side, -rw)
  ], proxy, variation);

  const pairs = rng.int(recipe.modules.fineSprig.leafletPairs[0], recipe.modules.fineSprig.leafletPairs[1]);
  for (let i = 0; i < pairs; i++) {
    const t = (i + .55) / pairs;
    const anchor = start.clone().lerp(end, t);
    const ll = length * rng.range(recipe.modules.fineSprig.leafletLengthFraction[0], recipe.modules.fineSprig.leafletLengthFraction[1]);
    const lw = ll * rng.range(.24, .34);
    for (const sign of [-1, 1]) {
      const la = axis.clone().multiplyScalar(.30).addScaledVector(side, sign).normalize();
      const ls = new THREE.Vector3().crossVectors(normal, la).normalize();
      const c = anchor.clone().addScaledVector(side, sign * ll * .08);
      addQuad(out, [
        c.clone().addScaledVector(la, -ll * .42),
        c.clone().addScaledVector(ls, lw * .5),
        c.clone().addScaledVector(la, ll * .58),
        c.clone().addScaledVector(ls, -lw * .5)
      ], proxy, variation + sign * .008);
    }
  }
}

function parentFrame(parent, t) {
  const origin = parent.curve.getPoint(t);
  const tangent = parent.curve.getTangent(Math.min(.995, Math.max(.005, t))).normalize();
  let radial = new THREE.Vector3(origin.x, 0, origin.z);
  if (radial.lengthSq() < 1e-5) radial = new THREE.Vector3(tangent.x, 0, tangent.z);
  if (radial.lengthSq() < 1e-5) radial.copy(X);
  radial.normalize();
  const side = new THREE.Vector3().crossVectors(UP, radial).normalize();
  return { origin, tangent, radial, side };
}

function growChild(parent, id, order, t, length, sign, rng, radiusScale, upBias, outBias) {
  const { origin, tangent, radial, side } = parentFrame(parent, t);
  const dir = tangent.clone().multiplyScalar(rng.range(.16, .32))
    .addScaledVector(side, sign * rng.range(.40, .72))
    .addScaledVector(radial, rng.range(outBias * .70, outBias * 1.08))
    .addScaledVector(UP, rng.range(upBias * .72, upBias * 1.12)).normalize();
  const end = origin.clone().addScaledVector(dir, length);
  const p1 = origin.clone().addScaledVector(tangent, length * .16).addScaledVector(UP, length * .04);
  const p2 = origin.clone().lerp(end, .68).addScaledVector(side, sign * length * rng.range(.03, .07)).addScaledVector(UP, length * .04);
  return branch(id, order, origin, p1, p2, end,
    parent.radius0 * radiusScale * (1 - t * .22), parent.radius1 * radiusScale * .70, parent.id);
}

function buildGraph(params, recipe) {
  const growth = resolveGrowth(recipe, params.maturity);
  const spread = growth.spreadM * params.openness;
  const height = growth.heightM;
  const branches = [], anchors = [];
  const s = recipe.structure;

  for (let i = 0; i < s.leaderCount; i++) {
    const rng = new RNG(hashSeed(params.seed, `leader:${i}`));
    const a = s.leaderAzimuth[i] + rng.signed(.14);
    const leaderHeight = THREE.MathUtils.lerp(growth.heightM * .58, s.leaderHeightMatureM[i], growth.maturity);
    const p0 = new THREE.Vector3(Math.cos(a) * .04, 0, Math.sin(a) * .04);
    const p3 = new THREE.Vector3(Math.cos(a) * spread * s.leaderReachFraction[i], leaderHeight, Math.sin(a) * spread * s.leaderReachFraction[i]);
    const p1 = new THREE.Vector3(Math.cos(a) * spread * .03, leaderHeight * .34, Math.sin(a) * spread * .03);
    const p2 = new THREE.Vector3(p3.x * .60 + rng.signed(.12), p3.y * .76, p3.z * .60 + rng.signed(.12));
    const stem = branch(`stem:${i}`, 0, p0, p1, p2, p3,
      THREE.MathUtils.lerp(.065, .15, growth.maturity), THREE.MathUtils.lerp(.024, .058, growth.maturity));
    branches.push(stem);

    const scaffoldCount = growth.maturity > .62 ? s.scaffoldCountMature : Math.max(2, s.scaffoldCountMature - 2);
    const [lenMin, lenMax] = s.scaffoldLengthFraction || [.27, .39];
    for (let j = 0; j < scaffoldCount; j++) {
      const r = new RNG(hashSeed(params.seed, `scaffold:${i}:${j}`));
      const t = .30 + j * (.58 / Math.max(1, scaffoldCount - 1)) + r.signed(.018);
      const length = spread * r.range(lenMin, lenMax);
      const sign = (i + j) % 2 ? -1 : 1;
      const up = (i === 2 && j === scaffoldCount - 1) ? r.range(.56, .75) : r.range(.22, .42);
      const scaffold = growChild(stem, `scaffold:${i}:${j}`, 1, t, length, sign, r, .54, up, .74);
      branches.push(scaffold);
      for (const at of [.42, .58, .73, .86, .97]) anchors.push({ branch: scaffold, t: at, weight: THREE.MathUtils.lerp(.36, .84, at) });

      const secondaryCount = growth.maturity > .64 ? 3 : 2;
      for (let k = 0; k < secondaryCount; k++) {
        const br = new RNG(hashSeed(params.seed, `secondary:${i}:${j}:${k}`));
        const bt = .35 + k * (.48 / Math.max(1, secondaryCount - 1)) + br.signed(.02);
        const child = growChild(scaffold, `secondary:${i}:${j}:${k}`, 2, bt, length * br.range(.30, .46), (j + k) % 2 ? -1 : 1, br, .46, br.range(.12, .30), .58);
        branches.push(child);
        for (const at of [.46, .66, .84, .98]) anchors.push({ branch: child, t: at, weight: THREE.MathUtils.lerp(.45, .88, at) });

        if (growth.maturity > .70) {
          const tr = new RNG(hashSeed(params.seed, `twig:${i}:${j}:${k}`));
          const twig = growChild(child, `twig:${i}:${j}:${k}`, 3, tr.range(.52, .72), length * tr.range(.15, .24), tr.next() < .5 ? -1 : 1, tr, .40, tr.range(.06, .20), .48);
          branches.push(twig);
          anchors.push({ branch: twig, t: .55, weight: .58 }, { branch: twig, t: .82, weight: .74 }, { branch: twig, t: .98, weight: .88 });
        }
      }
    }
  }
  return { branches, anchors, height, spread, growth };
}

function anchorFrame(anchor) {
  const center = anchor.branch.curve.getPoint(anchor.t);
  const tangent = anchor.branch.curve.getTangent(Math.min(.995, anchor.t)).normalize();
  const { u, v } = frameFrom(tangent);
  let outward = new THREE.Vector3(center.x, 0, center.z);
  if (outward.lengthSq() < 1e-5) outward.copy(u); else outward.normalize();
  const proxy = outward.clone().multiplyScalar(.46).addScaledVector(UP, .38).addScaledVector(tangent, .16).normalize();
  return { center, tangent, u, v, outward, proxy };
}

function buildCrown(graph, params, recipe, wood) {
  const foliage = target(), flowers = target();
  let massCount = 0, fineSprays = 0, microTwigs = 0, flowerCount = 0;
  const centerAvoid = recipe.growth.mature.spreadM * recipe.canopy.avoidSolidCenterRadiusFraction;

  graph.anchors.forEach((anchor, index) => {
    const rng = new RNG(hashSeed(params.seed, `crown:${anchor.branch.id}:${anchor.t}`));
    const { center, tangent, u, v, outward, proxy } = anchorFrame(anchor);
    if (center.y < graph.height * .27 && anchor.weight < .70) return;

    const clusterCount = rng.int(recipe.canopy.massBrushesPerAnchor[0], recipe.canopy.massBrushesPerAnchor[1]);
    for (let m = 0; m < clusterCount; m++) {
      const hierarchy = m === 0 ? 1 : m < 3 ? rng.range(.62, .82) : rng.range(.42, .60);
      const width = THREE.MathUtils.lerp(recipe.canopy.massWidthM[0], recipe.canopy.massWidthM[1], rng.next()) * (.78 + anchor.weight * .38) * hierarchy;
      const aspect = rng.range(recipe.canopy.massAspect[0], recipe.canopy.massAspect[1]);
      const height = width / aspect;
      const depth = width * rng.range(recipe.canopy.massDepthFraction[0], recipe.canopy.massDepthFraction[1]);
      const angle = m * GOLDEN_ANGLE + rng.signed(.42);
      const scatter = rng.range(recipe.canopy.massDepthScatter[0], recipe.canopy.massDepthScatter[1]);
      const p = center.clone()
        .addScaledVector(u, Math.cos(angle) * width * scatter)
        .addScaledVector(v, Math.sin(angle) * width * scatter * rng.range(.42, .76))
        .addScaledVector(UP, rng.signed(width * .28))
        .addScaledVector(tangent, rng.signed(width * .18));
      if (Math.hypot(p.x, p.z) < centerAvoid && p.y > graph.height * .28) p.addScaledVector(outward, centerAvoid * rng.range(.22, .48));
      const pn = proxy.clone().multiplyScalar(.82).addScaledVector(UP, .10).addScaledVector(outward, .08).normalize();
      addPaintedPuff(foliage, p, pn, width, height, depth, rng.range(-Math.PI, Math.PI), rng.range(.48, .54), rng);
      massCount++;
    }

    const accentChance = recipe.canopy.fineAccentFraction * (.55 + anchor.weight * .55);
    if (rng.next() < accentChance) {
      const count = anchor.weight > .75 ? 2 : 1;
      for (let a = 0; a < count; a++) {
        const length = rng.range(recipe.modules.fineSprig.lengthM[0], recipe.modules.fineSprig.lengthM[1]) * params.sprayScale;
        const direction = tangent.clone().multiplyScalar(.55).addScaledVector(u, rng.signed(.48)).addScaledVector(v, rng.signed(.30)).addScaledVector(UP, rng.range(-.04, .18)).normalize();
        const p = center.clone().addScaledVector(u, rng.signed(widthOr(anchor.weight, .06, .18))).addScaledVector(v, rng.signed(.08));
        addCompoundAccent(foliage, p, direction, proxy, length, rng, rng.range(.49, .56), recipe);
        fineSprays++;
        if (rng.next() < recipe.modules.bloom.probabilityAtTerminal) {
          const fp = p.clone().addScaledVector(direction, length * .35);
          const s = length * rng.range(.07, .105);
          const right = frameFrom(proxy).u;
          addQuad(flowers, [
            fp.clone().addScaledVector(right, -s), fp.clone().addScaledVector(UP, s * .6),
            fp.clone().addScaledVector(right, s), fp.clone().addScaledVector(UP, -s * .45)
          ], proxy, .52);
          flowerCount++;
        }
      }
    }
  });

  return { foliage: geometry(foliage), flowers: geometry(flowers), massCount, fineSprays, microTwigs, flowerCount };
}

function widthOr(weight, min, max) { return THREE.MathUtils.lerp(min, max, weight); }

export function buildDesertMuseum(params, recipe = DESERT_MUSEUM_PALO_VERDE) {
  validateSpeciesRecipe(recipe);
  const graph = buildGraph(params, recipe);
  const wood = target(), outline = target();
  for (const b of graph.branches) {
    addTube(wood, b, 1);
    if (b.order <= 1) addTube(outline, b, 1.045);
  }
  const crown = buildCrown(graph, params, recipe, wood);
  const woodGeom = geometry(wood), outlineGeom = geometry(outline);
  const triangles = (woodGeom.index.count + outlineGeom.index.count + crown.foliage.index.count + crown.flowers.index.count) / 3;
  if (triangles > recipe.lod0Budget.triangleHardCap) throw new Error(`LOD0 hard cap exceeded: ${triangles}`);
  return {
    wood: woodGeom,
    outline: outlineGeom,
    foliage: crown.foliage,
    flowers: crown.flowers,
    flowerCount: crown.flowerCount,
    report: {
      schema: 'threejs-palo-verde/2',
      recipeSchema: recipe.schema,
      recipeId: recipe.id,
      styleProfile: recipe.styleProfile,
      seed: params.seed,
      maturity: params.maturity,
      targetHeightM: graph.height,
      targetSpreadM: graph.spread,
      branches: graph.branches.length,
      structuralBranches: graph.branches.length,
      microTwigs: crown.microTwigs,
      foliageMasses: crown.massCount,
      fineSprays: crown.fineSprays,
      foliageBrushes: crown.massCount + crown.fineSprays,
      flowerBrushes: crown.flowerCount,
      triangles,
      triangleTarget: recipe.lod0Budget.triangleTarget,
      triangleHardCap: recipe.lod0Budget.triangleHardCap,
      targetMet: triangles <= recipe.lod0Budget.triangleTarget,
      lod: 0,
      calendarCalibrated: false,
      foliageRepresentation: 'shallow volumetric painted puffs with grouped normals plus sparse pinnate accents'
    }
  };
}
