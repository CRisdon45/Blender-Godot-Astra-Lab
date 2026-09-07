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
  int(a, bInclusive) { return Math.floor(this.range(a, bInclusive + 1)); }
}

function hashSeed(seed, text) {
  let h = seed >>> 0;
  for (let i = 0; i < text.length; i++) h = Math.imul(h ^ text.charCodeAt(i), 16777619) >>> 0;
  return h || 1;
}

function curveBranch({ id, parent = null, order, p0, p1, p2, p3, radius0, radius1, foliageWeight = 1 }) {
  return { id, parent, order, curve: new THREE.CubicBezierCurve3(p0, p1, p2, p3), radius0, radius1, foliageWeight };
}

function makeTarget() { return { positions: [], normals: [], variation: [], indices: [] }; }

function tangentBasis(tangent) {
  const n = tangent.clone().normalize();
  const ref = Math.abs(n.dot(UP)) > 0.93 ? X : UP;
  const u = new THREE.Vector3().crossVectors(n, ref).normalize();
  const v = new THREE.Vector3().crossVectors(n, u).normalize();
  return { u, v, n };
}

function addBranchTube(target, branch, radiusScale = 1) {
  const samples = branch.order === 0 ? 15 : branch.order === 1 ? 10 : branch.order === 2 ? 7 : branch.order === 3 ? 5 : 3;
  const sides = branch.order === 0 ? 8 : branch.order === 1 ? 6 : branch.order === 2 ? 5 : 4;
  const base = target.positions.length / 3;
  let previousU = null;
  for (let i = 0; i <= samples; i++) {
    const t = i / samples;
    const p = branch.curve.getPoint(t);
    const tangent = branch.curve.getTangent(Math.min(0.999, Math.max(0.001, t)));
    let { u, v } = tangentBasis(tangent);
    if (previousU && u.dot(previousU) < 0) { u.multiplyScalar(-1); v.multiplyScalar(-1); }
    previousU = u.clone();
    const taper = Math.pow(1 - t, 0.66);
    const radius = THREE.MathUtils.lerp(branch.radius1, branch.radius0, taper) * radiusScale;
    for (let s = 0; s < sides; s++) {
      const a = s / sides * Math.PI * 2;
      const radial = u.clone().multiplyScalar(Math.cos(a)).addScaledVector(v, Math.sin(a));
      const wobble = 1 + 0.022 * Math.sin(a * 3.3 + t * 8.2 + branch.order * 0.9);
      const q = p.clone().addScaledVector(radial, radius * wobble);
      target.positions.push(q.x, q.y, q.z);
      target.normals.push(radial.x, radial.y, radial.z);
      target.variation.push(Math.min(0.96, 0.58 + branch.order * 0.055 + t * 0.05));
    }
  }
  for (let i = 0; i < samples; i++) {
    for (let s = 0; s < sides; s++) {
      const a = base + i * sides + s;
      const b = base + i * sides + (s + 1) % sides;
      const c = base + (i + 1) * sides + s;
      const d = base + (i + 1) * sides + (s + 1) % sides;
      target.indices.push(a, c, b, b, c, d);
    }
  }
}

function addQuad(target, p0, p1, p2, p3, normal, variation) {
  const base = target.positions.length / 3;
  for (const p of [p0, p1, p2, p3]) {
    target.positions.push(p.x, p.y, p.z);
    target.normals.push(normal.x, normal.y, normal.z);
    target.variation.push(variation);
  }
  target.indices.push(base, base + 1, base + 2, base, base + 2, base + 3);
}

function addBrush(target, center, normal, width, height, spin, variation, bow = 0.05, shapeBias = 0) {
  const n = normal.clone().normalize();
  let t = new THREE.Vector3().crossVectors(UP, n);
  if (t.lengthSq() < 1e-6) t.copy(X);
  t.normalize();
  let b = new THREE.Vector3().crossVectors(n, t).normalize();
  const c = Math.cos(spin), s = Math.sin(spin);
  const rt = t.clone().multiplyScalar(c).addScaledVector(b, s).normalize();
  const rb = b.clone().multiplyScalar(c).addScaledVector(t, -s).normalize();
  t = rt; b = rb;
  const verts = [
    [-0.58, -0.05], [-0.36, -0.45], [0.08, -0.52],
    [0.55, -0.24], [0.61, 0.08], [0.27, 0.48], [-0.18, 0.51], [-0.53, 0.25]
  ];
  const base = target.positions.length / 3;
  for (let i = 0; i < verts.length; i++) {
    const [x0, y0] = verts[i];
    const angle = Math.atan2(y0, x0);
    const irregular = 1 + 0.09 * Math.sin(angle * 3.2 + variation * 8.9) + shapeBias * 0.035 * Math.cos(angle * 2.0);
    const x = x0 * width * irregular;
    const y = y0 * height * irregular;
    const depth = Math.sin(angle * 2 + spin) * Math.min(width, height) * bow;
    const p = center.clone().addScaledVector(t, x).addScaledVector(b, y).addScaledVector(n, depth);
    target.positions.push(p.x, p.y, p.z);
    target.normals.push(n.x, n.y, n.z);
    target.variation.push(variation);
  }
  for (let i = 1; i < verts.length - 1; i++) target.indices.push(base, base + i, base + i + 1);
}

function addLeafDiamond(target, center, axis, side, length, width, normal, variation, lean = 0) {
  const a = axis.clone().normalize(), s = side.clone().normalize(), n = normal.clone().normalize();
  const root = center.clone().addScaledVector(a, -length * .43).addScaledVector(n, -lean);
  const tip = center.clone().addScaledVector(a, length * .57).addScaledVector(n, lean);
  const left = center.clone().addScaledVector(s, width * .52);
  const right = center.clone().addScaledVector(s, -width * .52);
  addQuad(target, root, left, tip, right, n, variation);
}

function addCompoundSpray(target, center, direction, proxyNormal, length, rng, variation, recipe) {
  const axis = direction.clone().normalize();
  let side = new THREE.Vector3().crossVectors(proxyNormal, axis);
  if (side.lengthSq() < 1e-7) side.crossVectors(UP, axis);
  if (side.lengthSq() < 1e-7) side.copy(X);
  side.normalize();
  const n = new THREE.Vector3().crossVectors(axis, side).normalize();
  if (n.dot(proxyNormal) < 0) n.multiplyScalar(-1);

  const start = center.clone().addScaledVector(axis, -length * .47);
  const end = center.clone().addScaledVector(axis, length * .53);
  const rachisWidth = Math.max(.004, length * .009);
  addQuad(target,
    start.clone().addScaledVector(side, rachisWidth),
    end.clone().addScaledVector(side, rachisWidth * .55),
    end.clone().addScaledVector(side, -rachisWidth * .55),
    start.clone().addScaledVector(side, -rachisWidth),
    n, variation * .68 + .17);

  const [pairMin, pairMax] = recipe.modules.fineSprig.leafletPairs;
  const pairs = rng.int(pairMin, pairMax);
  const [lenMin, lenMax] = recipe.modules.fineSprig.leafletLengthFraction;
  for (let i = 0; i < pairs; i++) {
    const t = (i + .52) / pairs;
    const anchor = start.clone().lerp(end, t).addScaledVector(side, Math.sin(t * Math.PI) * rng.signed(length * .018));
    const leafletLength = length * rng.range(lenMin, lenMax) * (.83 + Math.sin(t * Math.PI) * .20);
    const leafletWidth = leafletLength * rng.range(.28, .37);
    const forward = axis.clone().multiplyScalar(rng.range(.24, .42));
    for (const sign of [-1, 1]) {
      const leafAxis = forward.clone().addScaledVector(side, sign * rng.range(.86, 1.0)).addScaledVector(UP, rng.range(-.05, .08)).normalize();
      const leafSide = new THREE.Vector3().crossVectors(n, leafAxis).normalize();
      const leafCenter = anchor.clone().addScaledVector(side, sign * leafletLength * .10).addScaledVector(n, rng.signed(length * .009));
      addLeafDiamond(target, leafCenter, leafAxis, leafSide, leafletLength, leafletWidth, proxyNormal, variation + sign * .012, length * .004);
    }
  }
}

function createGeometry(target) {
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.Float32BufferAttribute(target.positions, 3));
  geometry.setAttribute('normal', new THREE.Float32BufferAttribute(target.normals, 3));
  geometry.setAttribute('variation', new THREE.Float32BufferAttribute(target.variation, 1));
  geometry.setIndex(target.indices);
  geometry.computeBoundingBox();
  geometry.computeBoundingSphere();
  return geometry;
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

function growChild(parent, id, order, t, length, sideSign, rng, radiusScale, upwardBias = .25, outwardBias = .62) {
  const { origin, tangent, radial, side } = parentFrame(parent, t);
  const lateral = side.clone().multiplyScalar(sideSign * rng.range(.54, .92));
  const outward = radial.clone().multiplyScalar(rng.range(outwardBias * .72, outwardBias * 1.16));
  const up = UP.clone().multiplyScalar(rng.range(upwardBias * .55, upwardBias * 1.16));
  const dir = tangent.clone().multiplyScalar(rng.range(.10, .29)).add(lateral).add(outward).add(up).normalize();
  const end = origin.clone().addScaledVector(dir, length);
  const p1 = origin.clone().addScaledVector(tangent, length * .11).addScaledVector(UP, length * .025);
  const p2 = origin.clone().lerp(end, .68).addScaledVector(side, sideSign * length * rng.range(.025, .082)).addScaledVector(UP, length * rng.range(.005, .045));
  return curveBranch({
    id, parent: parent.id, order, p0: origin, p1, p2, p3: end,
    radius0: parent.radius0 * radiusScale * (1 - t * .25), radius1: parent.radius1 * radiusScale * .68,
    foliageWeight: rng.range(.86, 1.18)
  });
}

function buildBranchGraph(params, recipe) {
  const { seed, maturity, openness } = params;
  const growth = resolveGrowth(recipe, maturity);
  const height = growth.heightM;
  const spread = growth.spreadM * openness;
  const branches = [], foliageSites = [], stems = [];
  const structure = recipe.structure;

  for (let i = 0; i < structure.leaderCount; i++) {
    const rng = new RNG(hashSeed(seed, `stem:${i}`));
    const a = structure.leaderAzimuth[i] + rng.signed(.16);
    const p0 = new THREE.Vector3(Math.cos(a) * .045, 0, Math.sin(a) * .045);
    const stemHeight = THREE.MathUtils.lerp(recipe.growth.installed.heightM * .58, structure.leaderHeightMatureM[i], growth.maturity);
    const p3 = new THREE.Vector3(Math.cos(a) * spread * structure.leaderReachFraction[i], stemHeight, Math.sin(a) * spread * structure.leaderReachFraction[i]);
    const p1 = new THREE.Vector3(Math.cos(a) * spread * .035, stemHeight * .34, Math.sin(a) * spread * .035);
    const p2 = new THREE.Vector3(p3.x * .58 + rng.signed(.13), p3.y * .74, p3.z * .58 + rng.signed(.13));
    const stem = curveBranch({
      id: `stem:${i}`, order: 0, p0, p1, p2, p3,
      radius0: THREE.MathUtils.lerp(.065, .15, growth.maturity), radius1: THREE.MathUtils.lerp(.025, .060, growth.maturity)
    });
    branches.push(stem); stems.push(stem);

    const scaffoldCount = growth.maturity < .58 ? Math.max(2, structure.scaffoldCountMature - 2) : structure.scaffoldCountMature;
    for (let j = 0; j < scaffoldCount; j++) {
      const srng = new RNG(hashSeed(seed, `scaffold:${i}:${j}`));
      const t = .29 + j * (.59 / Math.max(1, scaffoldCount - 1)) + srng.signed(.022);
      const len = spread * srng.range(.32, .49) * (j === scaffoldCount - 1 ? 1.02 : .94);
      const sideSign = (j + i) % 2 ? -1 : 1;
      const upward = (i === 2 && j === scaffoldCount - 1) ? srng.range(.62, .86) : srng.range(.18, .46);
      const scaffold = growChild(stem, `scaffold:${i}:${j}`, 1, t, len, sideSign, srng, .53, upward, .92);
      branches.push(scaffold);
      foliageSites.push({ branch: scaffold, t: .42, weight: .30 }, { branch: scaffold, t: .60, weight: .43 }, { branch: scaffold, t: .78, weight: .58 }, { branch: scaffold, t: .94, weight: .72 }, { branch: scaffold, t: .995, weight: .78 });

      const secondaryCount = growth.maturity < .60 ? Math.max(2, structure.secondaryCountMature - 2) : structure.secondaryCountMature;
      for (let k = 0; k < secondaryCount; k++) {
        const brng = new RNG(hashSeed(seed, `branch:${i}:${j}:${k}`));
        const bt = .28 + k * (.58 / Math.max(1, secondaryCount - 1)) + brng.signed(.022);
        const childLen = len * brng.range(.33, .54);
        const branch = growChild(scaffold, `branch:${i}:${j}:${k}`, 2, bt, childLen, (j + k) % 2 ? -1 : 1, brng, .46, brng.range(.08, .28), .74);
        branches.push(branch);
        foliageSites.push({ branch, t: .40, weight: .36 }, { branch, t: .58, weight: .48 }, { branch, t: .76, weight: .60 }, { branch, t: .91, weight: .72 }, { branch, t: .992, weight: .80 });

        const twigCount = growth.maturity < .66 ? 1 : structure.twigCountMature;
        for (let q = 0; q < twigCount; q++) {
          const trng = new RNG(hashSeed(seed, `twig:${i}:${j}:${k}:${q}`));
          const qt = .46 + q * .34 + trng.signed(.025);
          const twig = growChild(branch, `twig:${i}:${j}:${k}:${q}`, 3, qt, childLen * trng.range(.38, .58), (i + j + k + q) % 2 ? -1 : 1, trng, .40, trng.range(.02, .18), .68);
          branches.push(twig);
          foliageSites.push({ branch: twig, t: .34, weight: .34 }, { branch: twig, t: .54, weight: .46 }, { branch: twig, t: .72, weight: .58 }, { branch: twig, t: .88, weight: .68 }, { branch: twig, t: .985, weight: .76 });

          if (growth.maturity > .76 && (k + q) % 2 === 0) {
            const qrng = new RNG(hashSeed(seed, `tip:${i}:${j}:${k}:${q}`));
            const tip = growChild(twig, `tip:${i}:${j}:${k}:${q}`, 4, qrng.range(.52, .75), childLen * qrng.range(.16, .27), qrng.next() < .5 ? -1 : 1, qrng, .36, qrng.range(0, .11), .62);
            branches.push(tip);
            foliageSites.push({ branch: tip, t: .45, weight: .40 }, { branch: tip, t: .68, weight: .54 }, { branch: tip, t: .93, weight: .68 });
          }
        }
      }
    }
  }

  for (const stem of stems) foliageSites.push({ branch: stem, t: .72, weight: .18 }, { branch: stem, t: .91, weight: .24 });
  return { branches, foliageSites, height, spread, growth };
}

function siteProxy(site) {
  const center = site.branch.curve.getPoint(Math.min(.997, site.t));
  const tangent = site.branch.curve.getTangent(Math.min(.995, Math.max(.05, site.t))).normalize();
  const { u, v } = tangentBasis(tangent);
  let outward = new THREE.Vector3(center.x, 0, center.z);
  if (outward.lengthSq() < 1e-5) outward = u.clone(); else outward.normalize();
  const proxy = outward.clone().multiplyScalar(.48).addScaledVector(UP, .34).addScaledVector(tangent, .18).normalize();
  return { center, tangent, u, v, outward, proxy };
}

function addAnimeMassCluster(foliage, site, siteIndex, params, recipe, counters) {
  const canopy = recipe.canopy;
  if (siteIndex % canopy.massStride !== 0 && site.weight < .74) return;
  if (site.branch.order === 0) return;
  const rng = new RNG(hashSeed(params.seed, `paint-mass:${site.branch.id}:${site.t}`));
  const { center, tangent, u, v, outward, proxy } = siteProxy(site);
  if (center.y < recipe.growth.mature.heightM * .27 && site.weight < .70) return;
  const count = rng.int(canopy.massBrushesPerAnchor[0], canopy.massBrushesPerAnchor[1]);
  const [depthMin, depthMax] = canopy.massDepthScatter;
  const avoidRadius = recipe.growth.mature.spreadM * canopy.avoidSolidCenterRadiusFraction;

  for (let i = 0; i < count; i++) {
    const angle = i * GOLDEN_ANGLE + rng.signed(.46);
    const depth = rng.range(depthMin, depthMax);
    const baseWidth = THREE.MathUtils.lerp(canopy.massWidthM[0], canopy.massWidthM[1], rng.next()) * (.70 + site.weight * .52);
    const hierarchy = i === 0 ? 1.0 : i < 3 ? rng.range(.58, .78) : rng.range(.36, .56);
    const radial = baseWidth * hierarchy;
    const offset = u.clone().multiplyScalar(Math.cos(angle) * baseWidth * depth)
      .addScaledVector(v, Math.sin(angle) * baseWidth * depth * rng.range(.42, .78))
      .addScaledVector(UP, rng.signed(baseWidth * .32))
      .addScaledVector(tangent, rng.signed(baseWidth * .24));
    const p = center.clone().add(offset);
    if (avoidRadius > 0 && Math.hypot(p.x, p.z) < avoidRadius && p.y > recipe.growth.mature.heightM * .28) {
      p.addScaledVector(outward, avoidRadius * rng.range(.25, .55));
    }
    const width = radial * rng.range(.94, 1.16);
    const aspect = rng.range(canopy.massAspect[0], canopy.massAspect[1]);
    const height = width / aspect;
    const normal = proxy.clone().multiplyScalar(.72).addScaledVector(UP, .18).addScaledVector(outward, .10).normalize();
    addBrush(foliage, p, normal, width, height, rng.range(-Math.PI, Math.PI), rng.range(.47, .57), .15, i % 3 - 1);
    counters.massCount++;

    if (rng.next() < canopy.bridgeMassProbability && i === 0) {
      const bp = p.clone().addScaledVector(tangent, width * rng.range(.32, .58)).addScaledVector(outward, width * rng.range(-.12, .20));
      addBrush(foliage, bp, normal, width * rng.range(.54, .72), height * rng.range(.62, .86), rng.range(-Math.PI, Math.PI), rng.range(.48, .57), .13, 1);
      counters.massCount++;
    }
  }
}

function addMicroSprig(wood, foliage, flowers, site, siteIndex, sprigIndex, params, recipe, counters) {
  const { seed, density, sprayScale, maturity } = params;
  const rng = new RNG(hashSeed(seed, `micro:${site.branch.id}:${site.t}:${sprigIndex}`));
  const origin = site.branch.curve.getPoint(Math.min(.997, site.t));
  const parentTangent = site.branch.curve.getTangent(Math.min(.995, Math.max(.05, site.t))).normalize();
  const { u, v } = tangentBasis(parentTangent);
  let outward = new THREE.Vector3(origin.x, 0, origin.z);
  if (outward.lengthSq() < 1e-5) outward = u.clone(); else outward.normalize();
  const direction = parentTangent.clone().multiplyScalar(rng.range(.28, .55))
    .addScaledVector(outward, rng.range(.28, .58))
    .addScaledVector(u, rng.signed(.48))
    .addScaledVector(v, rng.signed(.34))
    .addScaledVector(UP, rng.range(-.05, .22)).normalize();
  const length = THREE.MathUtils.lerp(.28, .64, maturity) * (.72 + site.weight * .46) * rng.range(.76, 1.18);
  const end = origin.clone().addScaledVector(direction, length);
  const p1 = origin.clone().addScaledVector(parentTangent, length * .14);
  const p2 = origin.clone().lerp(end, .64).addScaledVector(u, rng.signed(length * .055)).addScaledVector(UP, rng.signed(length * .035));
  const micro = curveBranch({
    id: `micro:${siteIndex}:${sprigIndex}`, parent: site.branch.id, order: 4, p0: origin, p1, p2, p3: end,
    radius0: THREE.MathUtils.lerp(.0045, .0095, maturity) * rng.range(.82, 1.15), radius1: .0018 + rng.next() * .0017
  });
  addBranchTube(wood, micro, 1);
  counters.microTwigs++;

  const accentScale = recipe.modules.fineSprig.densityScale;
  const sprayCount = Math.max(1, Math.round((2.1 + site.weight * 2.0) * density * accentScale * rng.range(.82, 1.18)));
  for (let i = 0; i < sprayCount; i++) {
    const t = .24 + (i + .55) / sprayCount * .73;
    const p = micro.curve.getPoint(Math.min(.995, t));
    const tangent = micro.curve.getTangent(Math.min(.99, t)).normalize();
    const { u: mu, v: mv } = tangentBasis(tangent);
    const localAngle = i * GOLDEN_ANGLE + rng.signed(.32);
    p.add(mu.clone().multiplyScalar(Math.cos(localAngle) * length * rng.range(.035, .10))
      .addScaledVector(mv, Math.sin(localAngle) * length * rng.range(.025, .075))
      .addScaledVector(UP, rng.signed(length * .022)));
    const radialProxy = outward.clone().multiplyScalar(.40).addScaledVector(UP, .27).addScaledVector(tangent, .33).normalize();
    const sprayDir = tangent.clone().multiplyScalar(rng.range(.56, .84)).addScaledVector(mu, rng.signed(.50)).addScaledVector(mv, rng.signed(.34)).addScaledVector(UP, rng.range(-.08, .17)).normalize();
    const [sprayMin, sprayMax] = recipe.modules.fineSprig.lengthM;
    const sprayLength = THREE.MathUtils.lerp(sprayMin, sprayMax, maturity) * sprayScale * rng.range(.78, 1.18);
    const variation = .45 + rng.next() * .24;
    addCompoundSpray(foliage, p, sprayDir, radialProxy, sprayLength, rng, variation, recipe);
    counters.sprayCount++;
    if (rng.next() < recipe.modules.bloom.probabilityAtTerminal && i >= sprayCount - 1) {
      const fp = p.clone().addScaledVector(sprayDir, sprayLength * rng.range(.16, .42)).addScaledVector(radialProxy, rng.range(.008, .024));
      const [bloomMin, bloomMax] = recipe.modules.bloom.sizeFractionOfSprig;
      addBrush(flowers, fp, radialProxy, sprayLength * rng.range(bloomMin, bloomMax), sprayLength * rng.range(bloomMin * .72, bloomMax * .82), rng.range(-Math.PI, Math.PI), rng.range(.46, .62), .025);
      counters.flowerCount++;
    }
  }
}

function buildCrown(graph, wood, params, recipe) {
  const foliage = makeTarget(), flowers = makeTarget();
  const counters = { massCount: 0, sprayCount: 0, flowerCount: 0, microTwigs: 0 };
  graph.foliageSites.forEach((site, siteIndex) => {
    addAnimeMassCluster(foliage, site, siteIndex, params, recipe, counters);
    const rng = new RNG(hashSeed(params.seed, `site:${site.branch.id}:${site.t}`));
    if (rng.next() > recipe.canopy.fineAccentFraction && site.weight < .70) return;
    const sprigCount = Math.max(1, Math.round((.72 + site.weight * 1.02) * params.density * recipe.modules.fineSprig.densityScale * rng.range(.82, 1.15)));
    for (let s = 0; s < sprigCount; s++) addMicroSprig(wood, foliage, flowers, site, siteIndex, s, params, recipe, counters);
  });
  return { foliage: createGeometry(foliage), flowers: createGeometry(flowers), ...counters };
}

export function buildDesertMuseum(params, recipe = DESERT_MUSEUM_PALO_VERDE) {
  validateSpeciesRecipe(recipe);
  if (recipe.generator !== 'airy_vase_tree') throw new Error(`Recipe ${recipe.id} is not an airy_vase_tree`);
  const graph = buildBranchGraph(params, recipe);
  const wood = makeTarget(), outline = makeTarget();
  for (const branch of graph.branches) {
    addBranchTube(wood, branch, 1);
    if (branch.order <= 1) addBranchTube(outline, branch, 1.050);
  }
  const crown = buildCrown(graph, wood, params, recipe);
  const woodGeom = createGeometry(wood), outlineGeom = createGeometry(outline);
  const triangles = (woodGeom.index.count + outlineGeom.index.count + crown.foliage.index.count + crown.flowers.index.count) / 3;
  if (triangles > recipe.lod0Budget.triangleHardCap) throw new Error(`LOD0 hard cap exceeded: ${triangles} > ${recipe.lod0Budget.triangleHardCap}`);
  const report = {
    schema: 'threejs-palo-verde/2',
    recipeSchema: recipe.schema,
    recipeId: recipe.id,
    styleProfile: recipe.styleProfile,
    seed: params.seed,
    maturity: params.maturity,
    targetHeightM: graph.height,
    targetSpreadM: graph.spread,
    branches: graph.branches.length + crown.microTwigs,
    structuralBranches: graph.branches.length,
    microTwigs: crown.microTwigs,
    foliageMasses: crown.massCount,
    fineSprays: crown.sprayCount,
    foliageBrushes: crown.massCount + crown.sprayCount,
    flowerBrushes: crown.flowerCount,
    triangles,
    triangleTarget: recipe.lod0Budget.triangleTarget,
    triangleHardCap: recipe.lod0Budget.triangleHardCap,
    targetMet: triangles <= recipe.lod0Budget.triangleTarget,
    lod: 0,
    calendarCalibrated: false,
    foliageRepresentation: 'anime hierarchy: opaque painted masses plus compound pinna accents'
  };
  return { wood: woodGeom, outline: outlineGeom, foliage: crown.foliage, flowers: crown.flowers, flowerCount: crown.flowerCount, report };
}
