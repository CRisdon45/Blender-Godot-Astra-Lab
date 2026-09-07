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

function curveBranch({ id, parent = null, order, p0, p1, p2, p3, radius0, radius1, foliageWeight = 1 }) {
  return { id, parent, order, curve: new THREE.CubicBezierCurve3(p0, p1, p2, p3), radius0, radius1, foliageWeight };
}

function tangentBasis(tangent) {
  const n = tangent.clone().normalize();
  const ref = Math.abs(n.dot(UP)) > 0.93 ? X : UP;
  const u = new THREE.Vector3().crossVectors(n, ref).normalize();
  const v = new THREE.Vector3().crossVectors(n, u).normalize();
  return { u, v, n };
}

function makeTarget() { return { positions: [], normals: [], variation: [], indices: [] }; }

function addBranchTube(target, branch, radiusScale = 1) {
  const samples = branch.order === 0 ? 15 : branch.order === 1 ? 10 : branch.order === 2 ? 7 : 5;
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
    const taper = Math.pow(1 - t, 0.68);
    const radius = THREE.MathUtils.lerp(branch.radius1, branch.radius0, taper) * radiusScale;
    for (let s = 0; s < sides; s++) {
      const a = s / sides * Math.PI * 2;
      const radial = u.clone().multiplyScalar(Math.cos(a)).addScaledVector(v, Math.sin(a));
      const wobble = 1 + 0.025 * Math.sin(a * 3.2 + t * 7.3 + branch.order);
      const q = p.clone().addScaledVector(radial, radius * wobble);
      target.positions.push(q.x, q.y, q.z);
      target.normals.push(radial.x, radial.y, radial.z);
      target.variation.push(0.42 + branch.order * 0.055 + t * 0.035);
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
  const verts = [[-0.54,-0.06],[-0.28,-0.46],[0.20,-0.39],[0.56,-0.04],[0.30,0.43],[-0.18,0.48]];
  const base = target.positions.length / 3;
  for (let i = 0; i < verts.length; i++) {
    const [x0, y0] = verts[i];
    const angle = Math.atan2(y0, x0);
    const irregular = 1 + 0.08 * Math.sin(angle * 3.1 + variation * 9.7);
    const x = x0 * width * irregular;
    const y = y0 * height * irregular;
    const depth = Math.sin(angle * 2 + spin) * Math.min(width, height) * bow;
    const p = center.clone().addScaledVector(t, x).addScaledVector(b, y).addScaledVector(n, depth);
    target.positions.push(p.x, p.y, p.z);
    target.normals.push(n.x, n.y, n.z);
    target.variation.push(variation);
  }
  target.indices.push(base,base+1,base+2, base,base+2,base+3, base,base+3,base+4, base,base+4,base+5);
}

function addQuad(target, p0, p1, p2, p3, normal, variation) {
  const base = target.positions.length / 3;
  for (const p of [p0,p1,p2,p3]) {
    target.positions.push(p.x,p.y,p.z);
    target.normals.push(normal.x,normal.y,normal.z);
    target.variation.push(variation);
  }
  target.indices.push(base,base+1,base+2, base,base+2,base+3);
}

function addLeafDiamond(target, center, axis, side, length, width, normal, variation, lean = 0) {
  const a = axis.clone().normalize();
  const s = side.clone().normalize();
  const n = normal.clone().normalize();
  const base = center.clone().addScaledVector(a, -length * 0.43).addScaledVector(n, -lean);
  const tip = center.clone().addScaledVector(a, length * 0.57).addScaledVector(n, lean);
  const left = center.clone().addScaledVector(s, width * 0.52);
  const right = center.clone().addScaledVector(s, -width * 0.52);
  addQuad(target, base, left, tip, right, n, variation);
}

function addCompoundSpray(target, center, direction, proxyNormal, length, rng, variation) {
  const axis = direction.clone().normalize();
  let side = new THREE.Vector3().crossVectors(proxyNormal, axis);
  if (side.lengthSq() < 1e-7) side.crossVectors(UP, axis);
  if (side.lengthSq() < 1e-7) side.copy(X);
  side.normalize();
  const n = new THREE.Vector3().crossVectors(axis, side).normalize();
  if (n.dot(proxyNormal) < 0) n.multiplyScalar(-1);

  const start = center.clone().addScaledVector(axis, -length * 0.47);
  const end = center.clone().addScaledVector(axis, length * 0.53);
  const rachisWidth = Math.max(0.005, length * 0.012);
  addQuad(target,
    start.clone().addScaledVector(side, rachisWidth),
    end.clone().addScaledVector(side, rachisWidth * 0.56),
    end.clone().addScaledVector(side, -rachisWidth * 0.56),
    start.clone().addScaledVector(side, -rachisWidth), n, variation * 0.7 + 0.15);

  const pairCount = rng.next() < 0.38 ? 7 : 6;
  for (let i = 0; i < pairCount; i++) {
    const t = (i + 0.55) / pairCount;
    const bend = Math.sin(t * Math.PI) * rng.signed(length * 0.035);
    const anchor = start.clone().lerp(end, t).addScaledVector(side, bend);
    const leafletLength = length * rng.range(0.145, 0.205) * (0.84 + Math.sin(t * Math.PI) * 0.18);
    const leafletWidth = leafletLength * rng.range(0.25, 0.34);
    const forward = axis.clone().multiplyScalar(rng.range(0.26, 0.44));
    for (const sign of [-1, 1]) {
      const leafAxis = forward.clone().addScaledVector(side, sign * rng.range(0.82, 1.0)).addScaledVector(UP, rng.range(-0.08, 0.12)).normalize();
      const leafSide = new THREE.Vector3().crossVectors(n, leafAxis).normalize();
      const leafCenter = anchor.clone().addScaledVector(side, sign * leafletLength * 0.12).addScaledVector(n, rng.signed(length * 0.015));
      addLeafDiamond(target, leafCenter, leafAxis, leafSide, leafletLength, leafletWidth, proxyNormal, variation + sign * 0.015, length * 0.006);
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
  const tangent = parent.curve.getTangent(Math.min(0.995, Math.max(0.005, t))).normalize();
  let radial = new THREE.Vector3(origin.x, 0, origin.z);
  if (radial.lengthSq() < 1e-5) radial = new THREE.Vector3(tangent.x, 0, tangent.z);
  if (radial.lengthSq() < 1e-5) radial.copy(X);
  radial.normalize();
  const side = new THREE.Vector3().crossVectors(UP, radial).normalize();
  return { origin, tangent, radial, side };
}

function growChild(parent, id, order, t, length, sideSign, rng, radiusScale, upwardBias = 0.32) {
  const { origin, tangent, radial, side } = parentFrame(parent, t);
  const lateral = side.clone().multiplyScalar(sideSign * rng.range(0.50, 0.92));
  const outward = radial.clone().multiplyScalar(rng.range(0.28, 0.72));
  const up = UP.clone().multiplyScalar(rng.range(upwardBias * 0.65, upwardBias * 1.28));
  const dir = tangent.clone().multiplyScalar(rng.range(0.12, 0.34)).add(lateral).add(outward).add(up).normalize();
  const end = origin.clone().addScaledVector(dir, length);
  const p1 = origin.clone().addScaledVector(tangent, length * 0.13).addScaledVector(UP, length * 0.035);
  const p2 = origin.clone().lerp(end, 0.68).addScaledVector(side, sideSign * length * rng.range(0.035, 0.095)).addScaledVector(UP, length * rng.range(0.015, 0.065));
  return curveBranch({
    id, parent: parent.id, order, p0: origin, p1, p2, p3: end,
    radius0: parent.radius0 * radiusScale * (1 - t * 0.27),
    radius1: parent.radius1 * radiusScale * 0.72,
    foliageWeight: rng.range(0.84, 1.17)
  });
}

function buildBranchGraph(params) {
  const { seed, maturity, openness } = params;
  const height = THREE.MathUtils.lerp(3.0, 7.55, maturity);
  const spread = THREE.MathUtils.lerp(2.2, 7.55, Math.pow(maturity, 1.06)) * openness;
  const branches = [];
  const foliageSites = [];
  const leaders = [];

  const azimuths = [0.18, 2.18, 4.35];
  const leaderReach = [0.39, 0.48, 0.42];
  const leaderHeight = [0.88, 0.78, 0.94];

  for (let i = 0; i < 3; i++) {
    const rng = new RNG(hashSeed(seed, `leader:${i}`));
    const a = azimuths[i] + rng.signed(0.17);
    const p0 = new THREE.Vector3(Math.cos(a) * 0.055, 0, Math.sin(a) * 0.055);
    const tip = new THREE.Vector3(Math.cos(a) * spread * leaderReach[i], height * (leaderHeight[i] + rng.signed(0.025)), Math.sin(a) * spread * leaderReach[i]);
    const p1 = new THREE.Vector3(Math.cos(a) * spread * 0.045, height * 0.18, Math.sin(a) * spread * 0.045);
    const p2 = new THREE.Vector3(tip.x * 0.60 + rng.signed(spread * 0.055), tip.y * 0.67, tip.z * 0.60 + rng.signed(spread * 0.055));
    const leader = curveBranch({
      id:`leader:${i}`, order:0, p0,p1,p2,p3:tip,
      radius0: THREE.MathUtils.lerp(0.055, 0.125, maturity),
      radius1: THREE.MathUtils.lerp(0.018, 0.041, maturity)
    });
    branches.push(leader); leaders.push(leader);

    const secondaryCount = maturity < 0.62 ? 4 : 6;
    for (let j = 0; j < secondaryCount; j++) {
      const srng = new RNG(hashSeed(seed, `secondary:${i}:${j}`));
      const attachT = 0.24 + j * (0.64 / Math.max(1, secondaryCount - 1)) + srng.signed(0.022);
      const length = spread * srng.range(0.18, 0.31) * (0.90 + attachT * 0.16);
      const sec = growChild(leader, `secondary:${i}:${j}`, 1, attachT, length, j % 2 ? -1 : 1, srng, 0.50, srng.range(0.22,0.46));
      branches.push(sec);
      foliageSites.push({ branch:sec, t:0.58, weight:0.48 }, { branch:sec, t:0.80, weight:0.66 }, { branch:sec, t:0.98, weight:0.84 });

      const tertiaryCount = maturity < 0.58 ? 1 : 2;
      for (let k = 0; k < tertiaryCount; k++) {
        const trng = new RNG(hashSeed(seed, `tertiary:${i}:${j}:${k}`));
        const tt = 0.50 + k * 0.27 + trng.signed(0.025);
        const tertiary = growChild(sec, `tertiary:${i}:${j}:${k}`, 2, tt, length * trng.range(0.35,0.54), (j+k)%2 ? -1:1, trng, 0.47, trng.range(0.13,0.34));
        branches.push(tertiary);
        foliageSites.push({ branch:tertiary, t:0.70, weight:0.58 }, { branch:tertiary, t:0.98, weight:0.76 });

        if (maturity > 0.72 && (j + k) % 2 === 0) {
          const qrng = new RNG(hashSeed(seed, `twig:${i}:${j}:${k}`));
          const qt = qrng.range(0.57,0.79);
          const twig = growChild(tertiary, `twig:${i}:${j}:${k}`, 3, qt, length * qrng.range(0.16,0.28), qrng.next()<0.5?-1:1, qrng, 0.42, qrng.range(0.08,0.22));
          branches.push(twig);
          foliageSites.push({ branch:twig, t:0.96, weight:0.60 });
        }
      }
    }
  }

  // Sparse bridge sites make the crown continuous without erasing the open center.
  for (const leader of leaders) foliageSites.push({ branch:leader, t:0.90, weight:0.40 });
  return { branches, foliageSites, height, spread };
}

function buildFoliage(foliageSites, params) {
  const foliage = makeTarget();
  const flowers = makeTarget();
  const { seed, density, sprayScale, maturity } = params;
  let sprayCount = 0;
  let flowerCount = 0;

  for (const site of foliageSites) {
    const rng = new RNG(hashSeed(seed, `foliage:${site.branch.id}:${site.t}`));
    const center = site.branch.curve.getPoint(Math.min(0.997,site.t));
    const tangent = site.branch.curve.getTangent(Math.min(0.995,Math.max(0.05,site.t))).normalize();
    const { u, v } = tangentBasis(tangent);
    const cloudRadius = THREE.MathUtils.lerp(0.24,0.54,maturity) * site.weight;
    const sprays = Math.max(1, Math.round(rng.range(1.6,3.2) * density * (0.72 + site.weight)));

    for (let s = 0; s < sprays; s++) {
      const theta = (s + rng.next()) * GOLDEN_ANGLE;
      const vertical = rng.range(-0.52,0.62);
      const radial = Math.sqrt(Math.max(0,1-vertical*vertical));
      const shell = rng.range(0.18,1.0);
      const offset = u.clone().multiplyScalar(Math.cos(theta)*radial*cloudRadius*shell)
        .addScaledVector(UP, vertical*cloudRadius*0.72*shell)
        .addScaledVector(v, Math.sin(theta)*radial*cloudRadius*0.72*shell);
      const p = center.clone().add(offset);
      const proxy = offset.lengthSq()>1e-6 ? offset.clone().normalize() : tangent.clone();
      proxy.multiplyScalar(0.46).addScaledVector(UP,0.22).addScaledVector(tangent,0.32).normalize();
      let direction = tangent.clone().multiplyScalar(rng.range(0.52,0.82))
        .addScaledVector(u,rng.signed(0.54)).addScaledVector(v,rng.signed(0.42)).addScaledVector(UP,rng.range(-0.10,0.26)).normalize();
      const length = THREE.MathUtils.lerp(0.28,0.50,maturity) * sprayScale * rng.range(0.72,1.20) * (0.82+site.weight*0.23);
      const variation = rng.next();
      addCompoundSpray(foliage,p,direction,proxy,length,rng,variation);
      sprayCount++;

      if (rng.next() < 0.48) {
        const flowerN = 1 + (rng.next()<0.34 ? 1:0);
        for (let f=0; f<flowerN; f++) {
          const fp = p.clone().addScaledVector(direction,length*rng.range(0.10,0.42)).addScaledVector(proxy,rng.range(0.015,0.045));
          addBrush(flowers,fp,proxy,length*rng.range(0.13,0.19),length*rng.range(0.09,0.13),rng.range(-Math.PI,Math.PI),rng.next(),0.03);
          flowerCount++;
        }
      }
    }
  }
  return { foliage:createGeometry(foliage), flowers:createGeometry(flowers), sprayCount, flowerCount };
}

export function buildDesertMuseum(params) {
  const graph = buildBranchGraph(params);
  const wood = makeTarget();
  const outline = makeTarget();
  for (const branch of graph.branches) {
    addBranchTube(wood,branch,1.0);
    // Outline the structural skeleton, not every fine twig.
    if (branch.order <= 1) addBranchTube(outline,branch,1.065);
  }
  const crown = buildFoliage(graph.foliageSites,params);
  const woodGeom = createGeometry(wood);
  const outlineGeom = createGeometry(outline);
  const report = {
    schema:'threejs-palo-verde/1', seed:params.seed, maturity:params.maturity,
    targetHeightM:graph.height, targetSpreadM:graph.spread,
    branches:graph.branches.length, foliageBrushes:crown.sprayCount,
    flowerBrushes:crown.flowerCount,
    triangles:(woodGeom.index.count+outlineGeom.index.count+crown.foliage.index.count+crown.flowers.index.count)/3,
    lod:0, calendarCalibrated:false,
    foliageRepresentation:'opaque compound pinna sprays'
  };
  return { wood:woodGeom, outline:outlineGeom, foliage:crown.foliage, flowers:crown.flowers, flowerCount:crown.flowerCount, report };
}
