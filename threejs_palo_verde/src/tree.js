import * as THREE from 'three/webgpu';

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
}

function hashSeed(seed, text) {
  let h = seed >>> 0;
  for (let i = 0; i < text.length; i++) h = Math.imul(h ^ text.charCodeAt(i), 16777619) >>> 0;
  return h || 1;
}

function curveBranch({ id, parent = null, order, p0, p1, p2, p3, radius0, radius1, leafWeight = 1 }) {
  const curve = new THREE.CubicBezierCurve3(p0, p1, p2, p3);
  return { id, parent, order, curve, radius0, radius1, leafWeight };
}

function tangentBasis(tangent) {
  const n = tangent.clone().normalize();
  const ref = Math.abs(n.dot(UP)) > 0.93 ? X : UP;
  const u = new THREE.Vector3().crossVectors(n, ref).normalize();
  const v = new THREE.Vector3().crossVectors(n, u).normalize();
  return { u, v, n };
}

function addBranchTube(target, branch, radiusScale = 1) {
  const samples = branch.order === 0 ? 13 : branch.order === 1 ? 9 : 6;
  const sides = branch.order === 0 ? 8 : branch.order === 1 ? 6 : 5;
  const base = target.positions.length / 3;
  let previousU = null;

  for (let i = 0; i <= samples; i++) {
    const t = i / samples;
    const p = branch.curve.getPoint(t);
    const tangent = branch.curve.getTangent(Math.min(0.999, Math.max(0.001, t)));
    let { u, v } = tangentBasis(tangent);
    if (previousU && u.dot(previousU) < 0) { u.multiplyScalar(-1); v.multiplyScalar(-1); }
    previousU = u.clone();
    const taper = Math.pow(1 - t, 0.74);
    const radius = THREE.MathUtils.lerp(branch.radius1, branch.radius0, taper) * radiusScale;

    for (let s = 0; s < sides; s++) {
      const a = s / sides * Math.PI * 2;
      const radial = u.clone().multiplyScalar(Math.cos(a)).addScaledVector(v, Math.sin(a));
      const wobble = 1 + 0.035 * Math.sin(a * 3 + branch.order * 1.7 + t * 8);
      const q = p.clone().addScaledVector(radial, radius * wobble);
      target.positions.push(q.x, q.y, q.z);
      target.normals.push(radial.x, radial.y, radial.z);
      target.variation.push(branch.order * 0.17 + t * 0.08);
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

function addBrush(target, center, normal, width, height, spin, variation, bow = 0.08) {
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
    [-0.54, -0.06], [-0.28, -0.46], [0.20, -0.39],
    [0.56, -0.04], [0.30, 0.43], [-0.18, 0.48]
  ];
  const base = target.positions.length / 3;
  for (let i = 0; i < verts.length; i++) {
    const [x0, y0] = verts[i];
    const angle = Math.atan2(y0, x0);
    const irregular = 1 + 0.09 * Math.sin(angle * 3.1 + variation * 9.7);
    const x = x0 * width * irregular;
    const y = y0 * height * irregular;
    const depth = Math.sin(angle * 2 + spin) * Math.min(width, height) * bow;
    const p = center.clone().addScaledVector(t, x).addScaledVector(b, y).addScaledVector(n, depth);
    target.positions.push(p.x, p.y, p.z);
    target.normals.push(n.x, n.y, n.z);
    target.variation.push(variation);
  }
  target.indices.push(base, base + 1, base + 2, base, base + 2, base + 3, base, base + 3, base + 4, base, base + 4, base + 5);
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

function buildBranchGraph(params) {
  const { seed, maturity, openness } = params;
  const rng = new RNG(seed);
  const height = THREE.MathUtils.lerp(3.0, 7.55, maturity);
  const spread = THREE.MathUtils.lerp(2.1, 7.55, Math.pow(maturity, 1.08)) * openness;
  const branches = [];
  const leafSites = [];
  const leaders = [];

  const azimuths = [0.10, 2.12, 4.31];
  const leaderReach = [0.34, 0.47, 0.38];
  const leaderHeight = [0.92, 0.76, 0.97];

  for (let i = 0; i < 3; i++) {
    const local = new RNG(hashSeed(seed, `leader:${i}`));
    const a = azimuths[i] + local.signed(0.14);
    const baseOffset = new THREE.Vector3(Math.cos(a) * 0.08, 0, Math.sin(a) * 0.08);
    const tip = new THREE.Vector3(Math.cos(a) * spread * leaderReach[i], height * (leaderHeight[i] + local.signed(0.025)), Math.sin(a) * spread * leaderReach[i]);
    const p1 = baseOffset.clone().add(new THREE.Vector3(Math.cos(a) * spread * 0.05, height * 0.26, Math.sin(a) * spread * 0.05));
    const p2 = new THREE.Vector3(Math.cos(a + local.signed(0.08)) * tip.length() * 0.72, tip.y * 0.73, Math.sin(a + local.signed(0.08)) * tip.length() * 0.72);
    p2.x = tip.x * 0.68 + local.signed(spread * 0.05);
    p2.z = tip.z * 0.68 + local.signed(spread * 0.05);
    const leader = curveBranch({
      id: `leader:${i}`, order: 0,
      p0: baseOffset, p1, p2, p3: tip,
      radius0: THREE.MathUtils.lerp(0.065, 0.145, maturity),
      radius1: THREE.MathUtils.lerp(0.025, 0.052, maturity)
    });
    branches.push(leader); leaders.push(leader);

    const secondaryCount = maturity < 0.62 ? 3 : 5;
    for (let j = 0; j < secondaryCount; j++) {
      const srng = new RNG(hashSeed(seed, `secondary:${i}:${j}`));
      const attachT = 0.31 + j * (0.56 / Math.max(1, secondaryCount - 1)) + srng.signed(0.025);
      const origin = leader.curve.getPoint(attachT);
      const pt = leader.curve.getTangent(attachT).normalize();
      const radial = new THREE.Vector3(origin.x, 0, origin.z).normalize();
      const side = new THREE.Vector3().crossVectors(UP, radial.lengthSq() > 0.01 ? radial : pt).normalize();
      const sign = j % 2 ? -1 : 1;
      const length = spread * srng.range(0.20, 0.34) * (0.88 + attachT * 0.18);
      const horizontal = radial.multiplyScalar(srng.range(0.48, 0.78)).addScaledVector(side, sign * srng.range(0.42, 0.82)).normalize();
      const rise = srng.range(0.30, 0.66);
      const dir = horizontal.multiplyScalar(Math.sqrt(1 - rise * rise)).addScaledVector(UP, rise).normalize();
      const end = origin.clone().addScaledVector(dir, length);
      end.y = Math.min(height * 0.98, end.y);
      const p1s = origin.clone().addScaledVector(pt, length * 0.14).addScaledVector(UP, length * 0.10);
      const p2s = THREE.Vector3.prototype.lerp.call(origin.clone(), end, 0.68).addScaledVector(side, sign * length * 0.09).addScaledVector(UP, length * 0.08);
      const secondary = curveBranch({
        id: `secondary:${i}:${j}`, parent: leader.id, order: 1,
        p0: origin, p1: p1s, p2: p2s, p3: end,
        radius0: leader.radius0 * (0.52 - attachT * 0.18),
        radius1: leader.radius1 * 0.52,
        leafWeight: srng.range(0.9, 1.15)
      });
      branches.push(secondary);
      leafSites.push({ branch: secondary, t: 0.76, weight: 0.72 }, { branch: secondary, t: 1.0, weight: 1.0 });

      if (maturity > 0.56) {
        const tertiaryCount = j === secondaryCount - 1 ? 2 : 1;
        for (let k = 0; k < tertiaryCount; k++) {
          const trng = new RNG(hashSeed(seed, `tertiary:${i}:${j}:${k}`));
          const tt = 0.58 + k * 0.20 + trng.signed(0.03);
          const o = secondary.curve.getPoint(tt);
          const tangent = secondary.curve.getTangent(tt).normalize();
          const tside = new THREE.Vector3().crossVectors(UP, tangent).normalize();
          const tlen = length * trng.range(0.34, 0.52);
          const tdir = tangent.clone().multiplyScalar(0.42).addScaledVector(tside, (k ? -1 : 1) * trng.range(0.55, 0.84)).addScaledVector(UP, trng.range(0.18, 0.42)).normalize();
          const e = o.clone().addScaledVector(tdir, tlen);
          const tertiary = curveBranch({
            id: `tertiary:${i}:${j}:${k}`, parent: secondary.id, order: 2,
            p0: o,
            p1: o.clone().addScaledVector(tangent, tlen * 0.16),
            p2: THREE.Vector3.prototype.lerp.call(o.clone(), e, 0.72).addScaledVector(UP, tlen * 0.06),
            p3: e,
            radius0: secondary.radius0 * 0.52,
            radius1: secondary.radius1 * 0.46,
            leafWeight: trng.range(0.95, 1.2)
          });
          branches.push(tertiary);
          leafSites.push({ branch: tertiary, t: 1.0, weight: 0.78 });
        }
      }
    }
  }

  // A few deliberate bridge sites make the crown feel continuous without filling its characteristic voids.
  for (const leader of leaders) leafSites.push({ branch: leader, t: 0.92, weight: 0.70 });
  return { branches, leafSites, height, spread };
}

function buildFoliage(leafSites, params) {
  const target = { positions: [], normals: [], variation: [], indices: [] };
  const flowers = { positions: [], normals: [], variation: [], indices: [] };
  const { seed, density, sprayScale, openness, maturity } = params;
  let brushCount = 0;
  let flowerCount = 0;

  leafSites.forEach((site, siteIndex) => {
    const rng = new RNG(hashSeed(seed, `lobe:${site.branch.id}:${site.t}`));
    const center = site.branch.curve.getPoint(Math.min(0.999, site.t));
    const tangent = site.branch.curve.getTangent(Math.min(0.995, Math.max(0.05, site.t))).normalize();
    const basis = tangentBasis(tangent);
    const baseWidth = THREE.MathUtils.lerp(0.34, 0.68, maturity) * site.weight * openness;
    const radii = new THREE.Vector3(baseWidth * rng.range(0.88, 1.18), baseWidth * rng.range(0.46, 0.68), baseWidth * rng.range(0.40, 0.62));
    const count = Math.max(10, Math.round(rng.range(24, 38) * density * site.weight));

    for (let i = 0; i < count; i++) {
      const z = 1 - 2 * ((i + 0.5) / count);
      const rr = Math.sqrt(Math.max(0, 1 - z * z));
      const theta = i * GOLDEN_ANGLE + rng.signed(0.18);
      const localDir = new THREE.Vector3(rr * Math.cos(theta), z, rr * Math.sin(theta));
      const shell = rng.range(0.42, 1.06);
      const offset = basis.u.clone().multiplyScalar(localDir.x * radii.x * shell)
        .addScaledVector(UP, localDir.y * radii.y * shell)
        .addScaledVector(basis.v, localDir.z * radii.z * shell);
      const p = center.clone().add(offset);
      const proxy = offset.clone().normalize().multiplyScalar(0.58)
        .addScaledVector(UP, 0.24)
        .addScaledVector(tangent, 0.18).normalize();
      const variation = rng.next();
      const width = THREE.MathUtils.lerp(0.19, 0.34, maturity) * sprayScale * rng.range(0.72, 1.28);
      const height = width * rng.range(0.28, 0.46);
      addBrush(target, p, proxy, width, height, rng.range(-Math.PI, Math.PI), variation, 0.12);
      brushCount++;

      if (localDir.y > -0.15 && i % 6 === 0 && rng.next() < 0.72) {
        const fp = p.clone().addScaledVector(proxy, width * 0.08);
        addBrush(flowers, fp, proxy, width * 0.50, height * 0.78, rng.range(-Math.PI, Math.PI), rng.next(), 0.05);
        flowerCount++;
      }
    }
  });

  return { foliage: createGeometry(target), flowers: createGeometry(flowers), brushCount, flowerCount };
}

export function buildDesertMuseum(params) {
  const graph = buildBranchGraph(params);
  const wood = { positions: [], normals: [], variation: [], indices: [] };
  const outline = { positions: [], normals: [], variation: [], indices: [] };
  graph.branches.forEach(branch => { addBranchTube(wood, branch, 1.0); addBranchTube(outline, branch, 1.10); });
  const foliage = buildFoliage(graph.leafSites, params);
  const report = {
    schema: 'threejs-palo-verde/1',
    seed: params.seed,
    maturity: params.maturity,
    targetHeightM: graph.height,
    targetSpreadM: graph.spread,
    branches: graph.branches.length,
    foliageBrushes: foliage.brushCount,
    flowerBrushes: foliage.flowerCount,
    triangles: (wood.indices.length + outline.indices.length + foliage.foliage.index.count + foliage.flowers.index.count) / 3,
    lod: 0,
    calendarCalibrated: false
  };
  return {
    wood: createGeometry(wood),
    outline: createGeometry(outline),
    foliage: foliage.foliage,
    flowers: foliage.flowers,
    flowerCount: foliage.flowerCount,
    report
  };
}
