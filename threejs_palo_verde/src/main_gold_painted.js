document.documentElement.dataset.ready='starting';
window.addEventListener('error',e=>{document.documentElement.dataset.ready='error';document.documentElement.dataset.error=String(e.error||e.message||'unknown');});
window.addEventListener('unhandledrejection',e=>{document.documentElement.dataset.ready='error';document.documentElement.dataset.error=String(e.reason||'unhandled rejection');});

import * as THREE from 'three/webgpu';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
import {attribute,clamp,color,mix,normalWorld,positionWorld,smoothstep,uniform,texture,uv} from 'three/tsl';
import {buildDesertMuseum} from './tree_gold_dense.js';
import {DESERT_MUSEUM_PALO_VERDE,validateSpeciesRecipe} from './recipes.js';

const recipe=DESERT_MUSEUM_PALO_VERDE;validateSpeciesRecipe(recipe);
const canvas=document.querySelector('#viewport');
const renderer=new THREE.WebGPURenderer({canvas,antialias:true,alpha:false});
renderer.setPixelRatio(Math.min(window.devicePixelRatio||1,1.8));
renderer.setSize(window.innerWidth,window.innerHeight,false);
await renderer.init();

const scene=new THREE.Scene();
scene.background=new THREE.Color('#dfeae7');
scene.fog=new THREE.FogExp2('#dfeae7',.0052);
const camera=new THREE.PerspectiveCamera(42,window.innerWidth/window.innerHeight,.08,120);
const controls=new OrbitControls(camera,canvas);controls.enableDamping=true;controls.dampingFactor=.06;controls.minDistance=4;controls.maxDistance=28;controls.maxPolarAngle=Math.PI*.49;
const sunDirection=uniform(new THREE.Vector3(-.45,.78,.43).normalize());

function rng(seed){let s=seed>>>0||1;return()=>{s=Math.imul(1664525,s)+1013904223>>>0;return s/4294967296;};}
function ellipse(ctx,x,y,rx,ry,rot,gray,alpha=1){ctx.save();ctx.translate(x,y);ctx.rotate(rot);ctx.globalAlpha=alpha;ctx.fillStyle=`rgb(${gray},${gray},${gray})`;ctx.beginPath();ctx.ellipse(0,0,rx,ry,0,0,Math.PI*2);ctx.fill();ctx.restore();}
function makePaintedAtlas(){
  const c=document.createElement('canvas');c.width=1024;c.height=256;const ctx=c.getContext('2d');ctx.clearRect(0,0,c.width,c.height);
  for(let tile=0;tile<4;tile++){
    const r=rng(18113+tile*4099),ox=tile*256;
    ctx.save();ctx.beginPath();ctx.rect(ox,0,256,256);ctx.clip();
    // Shadow body: broad, coherent lower-left mass.
    for(let i=0;i<7;i++){
      const a=r()*Math.PI*2,rr=Math.pow(r(),.82)*45;
      ellipse(ctx,ox+122+Math.cos(a)*rr,136+Math.sin(a)*rr*.52,38+r()*28,24+r()*22,(r()-.5)*1.3,98+Math.round(r()*28),.96);
    }
    // Midtone paint: sits over the main body, slightly lifted/rightward.
    for(let i=0;i<7;i++){
      const a=r()*Math.PI*2,rr=Math.pow(r(),.82)*43;
      ellipse(ctx,ox+132+Math.cos(a)*rr,122+Math.sin(a)*rr*.50,34+r()*25,20+r()*20,(r()-.5)*1.25,156+Math.round(r()*28),.96);
    }
    // Small sunlit patches: never coat the full cluster.
    for(let i=0;i<3;i++){
      const a=-.35+r()*.95,rr=24+r()*36;
      ellipse(ctx,ox+132+Math.cos(a)*rr,104+Math.sin(a)*rr*.42,22+r()*22,12+r()*15,(r()-.5)*.9,214+Math.round(r()*25),.92);
    }
    // Sparse peripheral strokes soften the silhouette without creating micro-noise.
    for(let i=0;i<8;i++){
      const a=r()*Math.PI*2,rr=74+r()*22;
      ellipse(ctx,ox+128+Math.cos(a)*rr,128+Math.sin(a)*rr*.54,16+r()*17,7+r()*9,a+(r()-.5)*.72,138+Math.round(r()*45),.88);
    }
    // Intentional holes create air and hand-painted negative space.
    ctx.globalCompositeOperation='destination-out';
    for(let h=0;h<3;h++){
      const a=r()*Math.PI*2,rr=20+r()*46;
      ctx.globalAlpha=.72;ctx.beginPath();ctx.ellipse(ox+128+Math.cos(a)*rr,128+Math.sin(a)*rr*.47,7+r()*10,5+r()*8,r()*Math.PI,0,Math.PI*2);ctx.fill();
    }
    ctx.globalCompositeOperation='source-over';ctx.restore();
  }
  const tex=new THREE.CanvasTexture(c);tex.colorSpace=THREE.NoColorSpace;tex.needsUpdate=true;return tex;
}
const atlas=makePaintedAtlas();

function woodMaterial(){
  const m=new THREE.MeshBasicNodeMaterial({side:THREE.DoubleSide});
  const shadow=color('#6f8e79'),mid=color('#8ca68e'),light=color('#b1c2ac');
  const variation=attribute('variation','float').sub(.5).mul(.012);
  const value=normalWorld.dot(sunDirection).mul(.18).add(.58).add(variation).add(clamp(positionWorld.y.div(8),0,1).mul(.012));
  m.colorNode=mix(mix(shadow,mid,smoothstep(.45,.55,value)),light,smoothstep(.76,.88,value));m.roughness=1;return m;
}
function foliageMaterial(palette){
  const m=new THREE.MeshBasicNodeMaterial({side:THREE.DoubleSide});
  const shadow=color(palette[0]),mid=color(palette[1]),light=color(palette[2]);
  const sample=texture(atlas,uv());
  const variation=attribute('variation','float').sub(.5).mul(.010);
  // The painted atlas carries most of the tonal design; real 3D light only nudges it.
  const painted=sample.r.sub(.50).mul(.42);
  const form=normalWorld.dot(sunDirection).mul(.10).add(.54);
  const height=clamp(positionWorld.y.div(8),0,1).mul(.010);
  const value=form.add(painted).add(height).add(variation);
  m.opacityNode=sample.a;m.alphaTest=.22;
  m.colorNode=mix(mix(shadow,mid,smoothstep(.45,.53,value)),light,smoothstep(.72,.80,value));m.roughness=1;return m;
}
const materials={
  wood:woodMaterial(),
  foliage:foliageMaterial(['#546b4d','#7f935f','#a6b777']),
  flowers:foliageMaterial(['#9a7d35','#c0a447','#dcc564']),
  outline:new THREE.MeshBasicNodeMaterial({color:new THREE.Color('#768b80'),side:THREE.BackSide})
};

const ground=new THREE.Mesh(new THREE.PlaneGeometry(60,60),new THREE.MeshBasicNodeMaterial({color:new THREE.Color('#e1d7c5')}));ground.rotation.x=-Math.PI/2;ground.position.y=-.025;scene.add(ground);
function makeContactShadow(){const c=document.createElement('canvas');c.width=c.height=256;const x=c.getContext('2d'),g=x.createRadialGradient(128,128,5,128,128,126);g.addColorStop(0,'rgba(71,77,66,.26)');g.addColorStop(.58,'rgba(71,77,66,.085)');g.addColorStop(1,'rgba(71,77,66,0)');x.fillStyle=g;x.fillRect(0,0,256,256);return new THREE.CanvasTexture(c);}
const shadowMat=new THREE.MeshBasicMaterial({map:makeContactShadow(),transparent:true,depthWrite:false,opacity:.36,color:new THREE.Color('#777b71')});
const contactShadow=new THREE.Mesh(new THREE.PlaneGeometry(1,1),shadowMat);contactShadow.rotation.x=-Math.PI/2;contactShadow.rotation.z=-.15;contactShadow.position.set(.25,.004,.04);scene.add(contactShadow);

const state={seed:41,maturity:1,openness:1,density:1,sprayScale:1,bloom:.08,azimuth:-35,elevation:52,shadow:4.6};
let treeGroup=null,flowerMesh=null,flowerIndexCount=0,currentReport=null,timer=null;
function backendLabel(){const n=renderer.backend?.constructor?.name||'Renderer';return/webgpu/i.test(n)?'WebGPU':/webgl/i.test(n)?'WebGL2 fallback':n;}
function disposeTree(){if(!treeGroup)return;treeGroup.traverse(o=>{if(o.isMesh&&o.geometry)o.geometry.dispose();});scene.remove(treeGroup);}
function rebuildTree(){disposeTree();const built=buildDesertMuseum({seed:state.seed,maturity:state.maturity,openness:state.openness,density:state.density,sprayScale:state.sprayScale},recipe);treeGroup=new THREE.Group();treeGroup.add(new THREE.Mesh(built.outline,materials.outline),new THREE.Mesh(built.wood,materials.wood),new THREE.Mesh(built.foliage,materials.foliage));flowerMesh=new THREE.Mesh(built.flowers,materials.flowers);flowerIndexCount=built.flowers.index?.count??0;treeGroup.add(flowerMesh);scene.add(treeGroup);currentReport=built.report;setBloom(state.bloom);updateMetrics();updateShadow();window.__PALO_VERDE_REPORT__={...currentReport,backend:backendLabel(),errors:[],artApproved:false,recipeDriven:true,paintedContactShadow:true,foliageAtlasTiles:4,paintedToneAtlas:true,target:'anime-background Desert Museum palo verde LOD0',goldComposition:true};document.documentElement.dataset.report=JSON.stringify(window.__PALO_VERDE_REPORT__);}
function setBloom(v){state.bloom=Number(v);if(flowerMesh?.geometry?.index&&currentReport?.flowerBrushes){const per=flowerIndexCount/currentReport.flowerBrushes,visible=Math.floor(currentReport.flowerBrushes*state.bloom);flowerMesh.geometry.setDrawRange(0,Math.floor(visible*per));flowerMesh.visible=visible>0;}else if(flowerMesh)flowerMesh.visible=false;const o=document.querySelector('#bloomOut');if(o)o.value=`${Math.round(state.bloom*100)}%`;}
function updateSun(){const az=THREE.MathUtils.degToRad(state.azimuth),el=THREE.MathUtils.degToRad(state.elevation);sunDirection.value.set(Math.cos(el)*Math.cos(az),Math.sin(el),Math.cos(el)*Math.sin(az)).normalize();}
function updateShadow(){const soft=THREE.MathUtils.clamp(state.shadow,.5,5),spread=currentReport?.targetSpreadM||recipe.growth.mature.spreadM;contactShadow.scale.set(spread*(.68+soft*.035),spread*(.37+soft*.022),1);shadowMat.opacity=THREE.MathUtils.lerp(.40,.21,(soft-.5)/4.5);}
function updateMetrics(){document.querySelector('#backend').textContent=backendLabel();document.querySelector('#triangles').textContent=currentReport?Math.round(currentReport.triangles).toLocaleString():'—';document.querySelector('#brushes').textContent=currentReport?currentReport.foliageBrushes.toLocaleString():'—';}
function schedule(){clearTimeout(timer);timer=setTimeout(rebuildTree,40);}
const bindings={seed:{out:v=>String(Math.round(v)),rebuild:true},maturity:{out:v=>`${Math.round(v*100)}%`,rebuild:true},openness:{out:v=>v.toFixed(2),rebuild:true},density:{out:v=>v.toFixed(2),rebuild:true},spray:{key:'sprayScale',out:v=>v.toFixed(2),rebuild:true},bloom:{out:v=>`${Math.round(v*100)}%`,change:setBloom},azimuth:{out:v=>`${Math.round(v)}°`,change:updateSun},elevation:{out:v=>`${Math.round(v)}°`,change:updateSun},shadow:{out:v=>v.toFixed(1),change:updateShadow}};
for(const[id,b]of Object.entries(bindings)){const input=document.querySelector(`#${id}`),o=document.querySelector(`#${id}Out`);if(!input)continue;const key=b.key||id;if(state[key]!==undefined)input.value=String(state[key]);if(o)o.value=b.out(state[key]);input.addEventListener('input',()=>{state[key]=Number(input.value);if(o)o.value=b.out(state[key]);if(b.change)b.change(state[key]);if(b.rebuild)schedule();});}
const views={hero:{position:[6.8,4.9,7.35],target:[0,3.25,0]},side:{position:[-7.7,4.55,.7],target:[0,3.15,0]},low:{position:[5.4,2.35,6.65],target:[0,3.35,0]},elevated:{position:[5.9,7.9,6.1],target:[0,3.2,0]},reverse:{position:[-6.7,4.9,-7.55],target:[0,3.25,0]}};
function setView(name){const v=views[name];if(!v)return;camera.position.fromArray(v.position);controls.target.fromArray(v.target);controls.update();}
for(const b of document.querySelectorAll('[data-view]'))b.addEventListener('click',()=>setView(b.dataset.view));document.querySelector('#randomize').addEventListener('click',()=>{state.seed=1+Math.floor(Math.random()*998);document.querySelector('#seed').value=String(state.seed);document.querySelector('#seedOut').value=String(state.seed);rebuildTree();});
updateSun();rebuildTree();setView('hero');document.documentElement.dataset.ready='true';
let frames=0,start=performance.now(),smooth=60;function animate(now){controls.update();renderer.render(scene,camera);frames++;if(now-start>600){const fps=frames*1000/(now-start);smooth=smooth*.4+fps*.6;document.querySelector('#fps').textContent=smooth.toFixed(0);frames=0;start=now;}}renderer.setAnimationLoop(animate);
window.addEventListener('resize',()=>{camera.aspect=window.innerWidth/window.innerHeight;camera.updateProjectionMatrix();renderer.setSize(window.innerWidth,window.innerHeight,false);});
const q=new URLSearchParams(location.search);if(q.has('capture')){document.querySelector('#panel').style.display='none';document.querySelector('#badge').style.display='none';setView(q.get('view')||'hero');}
