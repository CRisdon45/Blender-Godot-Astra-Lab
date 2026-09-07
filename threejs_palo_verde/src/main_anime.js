document.documentElement.dataset.ready = 'starting';
window.addEventListener('error', event => { document.documentElement.dataset.ready = 'error'; document.documentElement.dataset.error = String(event.error || event.message || 'unknown'); });
window.addEventListener('unhandledrejection', event => { document.documentElement.dataset.ready = 'error'; document.documentElement.dataset.error = String(event.reason || 'unhandled rejection'); });

import * as THREE from 'three/webgpu';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { attribute, clamp, color, mix, normalWorld, positionWorld, smoothstep, uniform } from 'three/tsl';
import { buildDesertMuseum } from './tree_anime.js';
import { DESERT_MUSEUM_PALO_VERDE, NORTHSTAR_ANIME_01, validateSpeciesRecipe } from './recipes.js';

const recipe = DESERT_MUSEUM_PALO_VERDE;
const style = NORTHSTAR_ANIME_01;
validateSpeciesRecipe(recipe);

const canvas = document.querySelector('#viewport');
const renderer = new THREE.WebGPURenderer({ canvas, antialias: true, alpha: false });
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.8));
renderer.setSize(window.innerWidth, window.innerHeight, false);
await renderer.init();

const scene = new THREE.Scene();
scene.background = new THREE.Color(recipe.material.sky);
scene.fog = new THREE.FogExp2(recipe.material.sky, 0.0075);

const camera = new THREE.PerspectiveCamera(43, window.innerWidth / window.innerHeight, 0.08, 120);
const controls = new OrbitControls(camera, canvas);
controls.enableDamping = true;
controls.dampingFactor = 0.065;
controls.minDistance = 4.2;
controls.maxDistance = 28;
controls.maxPolarAngle = Math.PI * .49;

const sunDirection = uniform(new THREE.Vector3(-.45, .78, .43).normalize());

function illustratedMaterial(palette, role, side = THREE.DoubleSide) {
  const m = new THREE.MeshBasicNodeMaterial({ side });
  const sh = style.shading;
  const shadow = color(palette[0]);
  const middle = color(palette[1]);
  const light = color(palette[2]);
  const variationScale = role === 'foliage' ? sh.variationAmount : role === 'wood' ? sh.variationAmount * .48 : sh.variationAmount * .60;
  const variation = attribute('variation', 'float').sub(.5).mul(variationScale);
  const height = clamp(positionWorld.y.div(recipe.growth.mature.heightM + .4), 0, 1);
  const facing = normalWorld.dot(sunDirection).mul(.5).add(.5);
  const value = facing.add(normalWorld.y.mul(sh.normalUpBias)).add(height.mul(role === 'foliage' ? sh.heightLightBias : sh.heightLightBias * .35)).add(variation);
  const mid = smoothstep(sh.midBand[0], sh.midBand[1], value);
  const high = smoothstep(sh.highBand[0], sh.highBand[1], value);
  m.colorNode = mix(mix(shadow, middle, mid), light, high);
  m.roughness = 1;
  return m;
}

const materials = {
  wood: illustratedMaterial(recipe.material.wood, 'wood', THREE.FrontSide),
  foliage: illustratedMaterial(recipe.material.foliage, 'foliage', THREE.DoubleSide),
  flowers: illustratedMaterial(recipe.material.bloom, 'bloom', THREE.DoubleSide),
  outline: new THREE.MeshBasicNodeMaterial({ color: new THREE.Color(recipe.material.outline), side: THREE.BackSide })
};

const ground = new THREE.Mesh(
  new THREE.PlaneGeometry(60, 60),
  new THREE.MeshBasicNodeMaterial({ color: new THREE.Color(recipe.material.ground) })
);
ground.rotation.x = -Math.PI / 2;
ground.position.y = -.025;
scene.add(ground);

function makeShadowTexture() {
  const c = document.createElement('canvas');
  c.width = c.height = 256;
  const ctx = c.getContext('2d');
  const g = ctx.createRadialGradient(128, 128, 8, 128, 128, 126);
  g.addColorStop(0, 'rgba(60,65,56,.48)');
  g.addColorStop(.48, 'rgba(60,65,56,.20)');
  g.addColorStop(1, 'rgba(60,65,56,0)');
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, 256, 256);
  const texture = new THREE.CanvasTexture(c);
  texture.needsUpdate = true;
  return texture;
}

const shadowTexture = makeShadowTexture();
const shadowMaterial = new THREE.MeshBasicMaterial({ map: shadowTexture, transparent: true, depthWrite: false, opacity: .52, color: new THREE.Color(recipe.material.contactShadow) });
const contactShadow = new THREE.Mesh(new THREE.PlaneGeometry(1, 1), shadowMaterial);
contactShadow.rotation.x = -Math.PI / 2;
contactShadow.rotation.z = -.18;
contactShadow.position.set(.45, .004, .15);
contactShadow.renderOrder = 1;
scene.add(contactShadow);

const ringMaterial = new THREE.MeshBasicNodeMaterial({ color: new THREE.Color('#9aa9a0'), transparent: true, opacity: .07 });
for (const radius of [2, 4, 6]) {
  const curve = new THREE.EllipseCurve(0, 0, radius, radius, 0, Math.PI * 2, false, 0);
  const pts = curve.getPoints(128).map(p => new THREE.Vector3(p.x, .006, p.y));
  scene.add(new THREE.LineLoop(new THREE.BufferGeometry().setFromPoints(pts), ringMaterial));
}

const state = {
  seed: 41,
  maturity: 1,
  openness: recipe.canopy.openness,
  density: .94,
  sprayScale: .94,
  bloom: .18,
  azimuth: -35,
  elevation: 52,
  shadow: 4.2
};

let treeGroup = null;
let flowerMesh = null;
let flowerIndexCount = 0;
let currentReport = null;
let rebuildTimer = null;

function disposeTree() {
  if (!treeGroup) return;
  treeGroup.traverse(o => { if (o.isMesh && o.geometry) o.geometry.dispose(); });
  scene.remove(treeGroup);
}

function rebuildTree() {
  disposeTree();
  const built = buildDesertMuseum({ seed: state.seed, maturity: state.maturity, openness: state.openness, density: state.density, sprayScale: state.sprayScale }, recipe);
  treeGroup = new THREE.Group();
  treeGroup.name = recipe.commonName;

  const outline = new THREE.Mesh(built.outline, materials.outline);
  outline.renderOrder = 1;
  treeGroup.add(outline);
  const wood = new THREE.Mesh(built.wood, materials.wood);
  wood.renderOrder = 2;
  treeGroup.add(wood);
  const foliage = new THREE.Mesh(built.foliage, materials.foliage);
  foliage.renderOrder = 3;
  treeGroup.add(foliage);
  flowerMesh = new THREE.Mesh(built.flowers, materials.flowers);
  flowerMesh.renderOrder = 4;
  flowerIndexCount = built.flowers.index?.count ?? 0;
  treeGroup.add(flowerMesh);
  scene.add(treeGroup);

  currentReport = built.report;
  setBloom(state.bloom);
  updateMetrics();
  updatePaintedShadow();
  window.__PALO_VERDE_REPORT__ = {
    ...currentReport,
    backend: backendLabel(),
    errors: [],
    artApproved: false,
    recipeDriven: true,
    paintedContactShadow: true,
    target: 'anime-background Desert Museum palo verde LOD0'
  };
  document.documentElement.dataset.report = JSON.stringify(window.__PALO_VERDE_REPORT__);
}

function setBloom(value) {
  state.bloom = Number(value);
  if (flowerMesh?.geometry?.index && currentReport?.flowerBrushes) {
    const per = flowerIndexCount / currentReport.flowerBrushes;
    const visible = Math.floor(currentReport.flowerBrushes * state.bloom);
    flowerMesh.geometry.setDrawRange(0, Math.floor(visible * per));
    flowerMesh.visible = visible > 0;
  } else if (flowerMesh) flowerMesh.visible = false;
  const out = document.querySelector('#bloomOut');
  if (out) out.value = `${Math.round(state.bloom * 100)}%`;
}

function backendLabel() {
  const name = renderer.backend?.constructor?.name || 'Renderer';
  return /webgpu/i.test(name) ? 'WebGPU' : /webgl/i.test(name) ? 'WebGL2 fallback' : name;
}

function updateSun() {
  const az = THREE.MathUtils.degToRad(state.azimuth);
  const el = THREE.MathUtils.degToRad(state.elevation);
  sunDirection.value.set(Math.cos(el) * Math.cos(az), Math.sin(el), Math.cos(el) * Math.sin(az)).normalize();
}

function updatePaintedShadow() {
  const softness = THREE.MathUtils.clamp(state.shadow, .5, 5);
  const spread = currentReport?.targetSpreadM || recipe.growth.mature.spreadM;
  contactShadow.scale.set(spread * (.74 + softness * .035), spread * (.43 + softness * .024), 1);
  shadowMaterial.opacity = THREE.MathUtils.lerp(.62, .34, (softness - .5) / 4.5);
}

function updateMetrics() {
  document.querySelector('#backend').textContent = backendLabel();
  document.querySelector('#triangles').textContent = currentReport ? Math.round(currentReport.triangles).toLocaleString() : '—';
  document.querySelector('#brushes').textContent = currentReport ? currentReport.foliageBrushes.toLocaleString() : '—';
}

function scheduleRebuild() {
  clearTimeout(rebuildTimer);
  rebuildTimer = setTimeout(rebuildTree, 40);
}

const bindings = {
  seed: { output: v => String(Math.round(v)), rebuild: true },
  maturity: { output: v => `${Math.round(v * 100)}%`, rebuild: true },
  openness: { output: v => v.toFixed(2), rebuild: true },
  density: { output: v => v.toFixed(2), rebuild: true },
  spray: { key: 'sprayScale', output: v => v.toFixed(2), rebuild: true },
  bloom: { output: v => `${Math.round(v * 100)}%`, change: setBloom },
  azimuth: { output: v => `${Math.round(v)}°`, change: updateSun },
  elevation: { output: v => `${Math.round(v)}°`, change: updateSun },
  shadow: { output: v => v.toFixed(1), change: updatePaintedShadow }
};

for (const [id, binding] of Object.entries(bindings)) {
  const input = document.querySelector(`#${id}`);
  const out = document.querySelector(`#${id}Out`);
  if (!input) continue;
  const key = binding.key || id;
  if (state[key] !== undefined) input.value = String(state[key]);
  if (out) out.value = binding.output(state[key]);
  input.addEventListener('input', () => {
    state[key] = Number(input.value);
    if (out) out.value = binding.output(state[key]);
    if (binding.change) binding.change(state[key]);
    if (binding.rebuild) scheduleRebuild();
  });
}

const views = {
  hero: { position: [8.7, 5.9, 9.4], target: [0, 3.20, 0] },
  side: { position: [-9.8, 5.2, 1.0], target: [0, 3.05, 0] },
  low: { position: [6.7, 2.6, 8.4], target: [0, 3.35, 0] },
  elevated: { position: [7.4, 9.5, 7.8], target: [0, 3.05, 0] },
  reverse: { position: [-8.0, 5.7, -9.8], target: [0, 3.18, 0] }
};

function setView(name) {
  const v = views[name];
  if (!v) return;
  camera.position.fromArray(v.position);
  controls.target.fromArray(v.target);
  controls.update();
}
for (const button of document.querySelectorAll('[data-view]')) button.addEventListener('click', () => setView(button.dataset.view));
document.querySelector('#randomize').addEventListener('click', () => {
  state.seed = 1 + Math.floor(Math.random() * 998);
  document.querySelector('#seed').value = String(state.seed);
  document.querySelector('#seedOut').value = String(state.seed);
  rebuildTree();
});

updateSun();
rebuildTree();
setView('hero');
document.documentElement.dataset.ready = 'true';

let frames = 0, sampleStart = performance.now(), smoothFPS = 60;
function animate(now) {
  controls.update();
  renderer.render(scene, camera);
  frames++;
  if (now - sampleStart > 600) {
    const fps = frames * 1000 / (now - sampleStart);
    smoothFPS = smoothFPS * .4 + fps * .6;
    document.querySelector('#fps').textContent = smoothFPS.toFixed(0);
    frames = 0; sampleStart = now;
  }
}
renderer.setAnimationLoop(animate);

window.addEventListener('resize', () => {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight, false);
});

const params = new URLSearchParams(location.search);
if (params.has('capture')) {
  document.querySelector('#panel').style.display = 'none';
  document.querySelector('#badge').style.display = 'none';
  setView(params.get('view') || 'hero');
}
