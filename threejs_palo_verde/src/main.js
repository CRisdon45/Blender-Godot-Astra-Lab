document.documentElement.dataset.ready = 'starting';
window.addEventListener('error', event => { document.documentElement.dataset.ready = 'error'; document.documentElement.dataset.error = String(event.error || event.message || 'unknown'); });
window.addEventListener('unhandledrejection', event => { document.documentElement.dataset.ready = 'error'; document.documentElement.dataset.error = String(event.reason || 'unhandled rejection'); });
import * as THREE from 'three/webgpu';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { attribute, clamp, color, mix, normalWorld, positionWorld, smoothstep, uniform } from 'three/tsl';
import { buildDesertMuseum } from './tree.js';

const canvas = document.querySelector('#viewport');
const renderer = new THREE.WebGPURenderer({ canvas, antialias: true, alpha: false });
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.8));
renderer.setSize(window.innerWidth, window.innerHeight, false);
renderer.shadowMap.enabled = true;
await renderer.init();

const scene = new THREE.Scene();
scene.background = new THREE.Color('#dce9e7');
scene.fog = new THREE.FogExp2('#dce9e7', 0.012);

const camera = new THREE.PerspectiveCamera(42, window.innerWidth / window.innerHeight, 0.08, 120);
camera.position.set(10.6, 6.5, 11.6);
const controls = new OrbitControls(camera, canvas);
controls.target.set(0, 3.35, 0);
controls.enableDamping = true;
controls.dampingFactor = 0.065;
controls.minDistance = 4.2;
controls.maxDistance = 28;
controls.maxPolarAngle = Math.PI * 0.49;

const sunDirection = uniform(new THREE.Vector3(-0.45, 0.78, 0.43).normalize());

function illustratedMaterial(palette, variationAmount = 0.10, heightBoost = 0.06, side = THREE.DoubleSide) {
  const material = new THREE.MeshBasicNodeMaterial({ side });
  const shadow = color(palette[0]);
  const middle = color(palette[1]);
  const light = color(palette[2]);
  const variation = attribute('variation', 'float').sub(0.5).mul(variationAmount);
  const height = clamp(positionWorld.y.div(8.0), 0.0, 1.0);
  const facing = normalWorld.dot(sunDirection).mul(0.5).add(0.5);
  const value = facing.add(normalWorld.y.mul(0.045)).add(height.mul(heightBoost)).add(variation);
  const midBand = smoothstep(0.31, 0.50, value);
  const highBand = smoothstep(0.69, 0.86, value);
  material.colorNode = mix(mix(shadow, middle, midBand), light, highBand);
  material.roughness = 1;
  return material;
}

const materials = {
  wood: illustratedMaterial(['#2b5f4d', '#5e9270', '#8db596'], 0.055, 0.025, THREE.FrontSide),
  foliage: illustratedMaterial(['#315c37', '#6f9947', '#adc969'], 0.145, 0.085, THREE.DoubleSide),
  flowers: illustratedMaterial(['#96721b', '#dfb823', '#f6df58'], 0.09, 0.045, THREE.DoubleSide),
  outline: new THREE.MeshBasicNodeMaterial({ color: new THREE.Color('#29473e'), side: THREE.BackSide })
};

const hemi = new THREE.HemisphereLight('#dbe9e5', '#b39d79', 1.0);
scene.add(hemi);
const sun = new THREE.DirectionalLight('#fff6db', 2.0);
sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048);
sun.shadow.camera.left = -11;
sun.shadow.camera.right = 11;
sun.shadow.camera.top = 12;
sun.shadow.camera.bottom = -5;
sun.shadow.camera.near = 0.1;
sun.shadow.camera.far = 36;
sun.shadow.bias = -0.00035;
sun.shadow.normalBias = 0.018;
scene.add(sun);
scene.add(sun.target);

const groundMat = new THREE.MeshStandardNodeMaterial({ color: new THREE.Color('#d3c4aa'), roughness: 1.0, metalness: 0.0 });
const ground = new THREE.Mesh(new THREE.PlaneGeometry(60, 60), groundMat);
ground.rotation.x = -Math.PI / 2;
ground.position.y = -0.025;
ground.receiveShadow = true;
scene.add(ground);

// Very restrained illustrated datum rings help judge scale without turning the study into a game grid.
const ringMaterial = new THREE.MeshBasicNodeMaterial({ color: new THREE.Color('#94a59a'), transparent: true, opacity: 0.22 });
for (const radius of [2, 4, 6]) {
  const curve = new THREE.EllipseCurve(0, 0, radius, radius, 0, Math.PI * 2, false, 0);
  const pts = curve.getPoints(128).map(p => new THREE.Vector3(p.x, 0.005, p.y));
  const geometry = new THREE.BufferGeometry().setFromPoints(pts);
  scene.add(new THREE.LineLoop(geometry, ringMaterial));
}

const state = {
  seed: 41,
  maturity: 1.0,
  openness: 1.0,
  density: 1.0,
  sprayScale: 1.0,
  bloom: 0.62,
  azimuth: -35,
  elevation: 52,
  shadow: 2.0
};

let treeGroup = null;
let flowerMesh = null;
let flowerIndexCount = 0;
let currentReport = null;
let rebuildTimer = null;

function disposeGroup(group) {
  if (!group) return;
  group.traverse(obj => {
    if (obj.isMesh && obj.geometry) obj.geometry.dispose();
  });
  scene.remove(group);
}

function rebuildTree() {
  disposeGroup(treeGroup);
  const built = buildDesertMuseum({
    seed: state.seed,
    maturity: state.maturity,
    openness: state.openness,
    density: state.density,
    sprayScale: state.sprayScale
  });

  treeGroup = new THREE.Group();
  treeGroup.name = 'Desert Museum Palo Verde';

  const outline = new THREE.Mesh(built.outline, materials.outline);
  outline.castShadow = false;
  outline.renderOrder = 0;
  treeGroup.add(outline);

  const wood = new THREE.Mesh(built.wood, materials.wood);
  wood.castShadow = true;
  wood.receiveShadow = false;
  wood.renderOrder = 1;
  treeGroup.add(wood);

  const leaves = new THREE.Mesh(built.foliage, materials.foliage);
  leaves.castShadow = true;
  leaves.receiveShadow = false;
  leaves.renderOrder = 2;
  treeGroup.add(leaves);

  flowerMesh = new THREE.Mesh(built.flowers, materials.flowers);
  flowerMesh.castShadow = false;
  flowerMesh.renderOrder = 3;
  flowerIndexCount = built.flowers.index?.count ?? 0;
  treeGroup.add(flowerMesh);

  scene.add(treeGroup);
  currentReport = built.report;
  setBloom(state.bloom);
  updateMetrics();
  window.__PALO_VERDE_REPORT__ = {
    ...currentReport,
    backend: backendLabel(),
    errors: [],
    artApproved: false,
    target: 'Desert Museum palo verde architectural illustration LOD0'
  };
  document.documentElement.dataset.report = JSON.stringify(window.__PALO_VERDE_REPORT__);
}

function scheduleRebuild() {
  clearTimeout(rebuildTimer);
  rebuildTimer = setTimeout(rebuildTree, 45);
}

function setBloom(value) {
  state.bloom = Number(value);
  if (flowerMesh?.geometry?.index) {
    const brushes = Math.floor((flowerIndexCount / 12) * state.bloom);
    flowerMesh.geometry.setDrawRange(0, brushes * 12);
    flowerMesh.visible = brushes > 0;
  }
  document.querySelector('#bloomOut').value = `${Math.round(state.bloom * 100)}%`;
}

function backendLabel() {
  const name = renderer.backend?.constructor?.name || 'Renderer';
  return /webgpu/i.test(name) ? 'WebGPU' : /webgl/i.test(name) ? 'WebGL2 fallback' : name;
}

function updateSun() {
  const az = THREE.MathUtils.degToRad(state.azimuth);
  const el = THREE.MathUtils.degToRad(state.elevation);
  const dir = new THREE.Vector3(Math.cos(el) * Math.cos(az), Math.sin(el), Math.cos(el) * Math.sin(az)).normalize();
  sunDirection.value.copy(dir);
  sun.position.copy(dir).multiplyScalar(14);
  sun.target.position.set(0, 2.6, 0);
  sun.shadow.radius = state.shadow;
}

function updateMetrics() {
  document.querySelector('#backend').textContent = backendLabel();
  document.querySelector('#triangles').textContent = currentReport ? Math.round(currentReport.triangles).toLocaleString() : '—';
  document.querySelector('#brushes').textContent = currentReport ? currentReport.foliageBrushes.toLocaleString() : '—';
}

const sliderBindings = {
  seed: { parse: Number, output: v => String(Math.round(v)), rebuild: true },
  maturity: { parse: Number, output: v => `${Math.round(v * 100)}%`, rebuild: true },
  openness: { parse: Number, output: v => v.toFixed(2), rebuild: true },
  density: { parse: Number, output: v => v.toFixed(2), rebuild: true },
  spray: { key: 'sprayScale', parse: Number, output: v => v.toFixed(2), rebuild: true },
  bloom: { parse: Number, output: v => `${Math.round(v * 100)}%`, onChange: setBloom },
  azimuth: { parse: Number, output: v => `${Math.round(v)}°`, onChange: updateSun },
  elevation: { parse: Number, output: v => `${Math.round(v)}°`, onChange: updateSun },
  shadow: { parse: Number, output: v => v.toFixed(1), onChange: updateSun }
};

for (const [id, binding] of Object.entries(sliderBindings)) {
  const input = document.querySelector(`#${id}`);
  const out = document.querySelector(`#${id}Out`);
  input.addEventListener('input', () => {
    const key = binding.key || id;
    const value = binding.parse(input.value);
    state[key] = value;
    if (out) out.value = binding.output(value);
    if (binding.onChange) binding.onChange(value);
    if (binding.rebuild) scheduleRebuild();
  });
}

const views = {
  hero: { position: [10.6, 6.5, 11.6], target: [0, 3.35, 0] },
  side: { position: [-12.6, 5.7, 1.5], target: [0, 3.15, 0] },
  low: { position: [7.8, 2.35, 10.0], target: [0, 3.45, 0] }
};
function setView(name) {
  const view = views[name];
  if (!view) return;
  camera.position.fromArray(view.position);
  controls.target.fromArray(view.target);
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
document.documentElement.dataset.ready = 'true';

let frames = 0;
let fpsTime = performance.now();
let smoothFPS = 60;
function animate(now) {
  controls.update();
  renderer.render(scene, camera);
  frames++;
  if (now - fpsTime > 600) {
    const fps = frames * 1000 / (now - fpsTime);
    smoothFPS = smoothFPS * 0.4 + fps * 0.6;
    document.querySelector('#fps').textContent = smoothFPS.toFixed(0);
    frames = 0; fpsTime = now;
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
