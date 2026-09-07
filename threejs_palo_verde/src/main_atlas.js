document.documentElement.dataset.ready = 'starting';
window.addEventListener('error', e => { document.documentElement.dataset.ready='error'; document.documentElement.dataset.error=String(e.error||e.message||'unknown'); });
window.addEventListener('unhandledrejection', e => { document.documentElement.dataset.ready='error'; document.documentElement.dataset.error=String(e.reason||'unhandled rejection'); });

import * as THREE from 'three/webgpu';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { attribute, clamp, color, mix, normalWorld, positionWorld, smoothstep, uniform, texture, uv } from 'three/tsl';
import { buildDesertMuseum } from './tree_atlas.js';
import { DESERT_MUSEUM_PALO_VERDE, NORTHSTAR_ANIME_01, validateSpeciesRecipe } from './recipes.js';

const recipe=DESERT_MUSEUM_PALO_VERDE, style=NORTHSTAR_ANIME_01; validateSpeciesRecipe(recipe);
const canvas=document.querySelector('#viewport');
const renderer=new THREE.WebGPURenderer({canvas,antialias:true,alpha:false}); renderer.setPixelRatio(Math.min(window.devicePixelRatio||1,1.8)); renderer.setSize(window.innerWidth,window.innerHeight,false); await renderer.init();
const scene=new THREE.Scene(); scene.background=new THREE.Color(recipe.material.sky); scene.fog=new THREE.FogExp2(recipe.material.sky,.0075);
const camera=new THREE.PerspectiveCamera(43,window.innerWidth/window.innerHeight,.08,120); const controls=new OrbitControls(camera,canvas); controls.enableDamping=true; controls.dampingFactor=.065; controls.minDistance=4.2; controls.maxDistance=28; controls.maxPolarAngle=Math.PI*.49;
const sunDirection=uniform(new THREE.Vector3(-.45,.78,.43).normalize());

function rand(seed){ let s=seed>>>0||1; return ()=>{s=Math.imul(1664525,s)+1013904223>>>0; return s/4294967296;}; }
function makeFoliageAtlas(){
  const c=document.createElement('canvas'); c.width=1024; c.height=256; const ctx=c.getContext('2d'); ctx.clearRect(0,0,c.width,c.height);
  for(let tile=0;tile<4;tile++){
    const r=rand(7109+tile*1943), ox=tile*256;
    ctx.save(); ctx.beginPath(); ctx.rect(ox,0,256,256); ctx.clip();
    for(let i=0;i<28;i++){
      const angle=r()*Math.PI*2, radius=Math.pow(r(),.72)*92, cx=ox+128+Math.cos(angle)*radius, cy=128+Math.sin(angle)*radius*.62;
      const len=18+r()*38, wid=6+r()*12, rot=(r()-.5)*2.2;
      ctx.save(); ctx.translate(cx,cy); ctx.rotate(rot); ctx.globalAlpha=.78+r()*.22; ctx.fillStyle='#ffffff';
      ctx.beginPath(); ctx.ellipse(0,0,len*.5,wid*.5,0,0,Math.PI*2); ctx.fill();
      if(i%4===0){ ctx.beginPath(); ctx.ellipse(len*.18,(r()-.5)*wid*.6,len*.30,wid*.34,0,0,Math.PI*2); ctx.fill(); }
      ctx.restore();
    }
    // Break a few tiny holes into the painted cluster so it never reads as a solid sticker.
    ctx.globalCompositeOperation='destination-out';
    for(let h=0;h<6;h++){ const a=r()*Math.PI*2, rr=20+r()*58; ctx.globalAlpha=.70; ctx.beginPath(); ctx.ellipse(ox+128+Math.cos(a)*rr,128+Math.sin(a)*rr*.55,4+r()*8,3+r()*6,r()*Math.PI,0,Math.PI*2); ctx.fill(); }
    ctx.globalCompositeOperation='source-over'; ctx.restore();
  }
  const tex=new THREE.CanvasTexture(c); tex.colorSpace=THREE.NoColorSpace; tex.needsUpdate=true; return tex;
}
const foliageAtlas=makeFoliageAtlas();

function illustratedMaterial(palette,role,masked=false){
  const m=new THREE.MeshBasicNodeMaterial({side:THREE.DoubleSide}); const sh=style.shading, shadow=color(palette[0]), middle=color(palette[1]), light=color(palette[2]);
  const variation=attribute('variation','float').sub(.5).mul(role==='foliage'?sh.variationAmount:sh.variationAmount*.5); const height=clamp(positionWorld.y.div(recipe.growth.mature.heightM+.4),0,1); const facing=normalWorld.dot(sunDirection).mul(.5).add(.5);
  const value=facing.add(normalWorld.y.mul(sh.normalUpBias)).add(height.mul(role==='foliage'?sh.heightLightBias:sh.heightLightBias*.35)).add(variation); const mid=smoothstep(sh.midBand[0],sh.midBand[1],value), hi=smoothstep(sh.highBand[0],sh.highBand[1],value);
  m.colorNode=mix(mix(shadow,middle,mid),light,hi); m.roughness=1;
  if(masked){ const sample=texture(foliageAtlas,uv()); m.opacityNode=sample.a; m.alphaTest=.32; m.depthWrite=true; }
  return m;
}
const materials={
  wood:illustratedMaterial(recipe.material.wood,'wood',false),
  foliage:illustratedMaterial(recipe.material.foliage,'foliage',true),
  flowers:illustratedMaterial(recipe.material.bloom,'bloom',true),
  outline:new THREE.MeshBasicNodeMaterial({color:new THREE.Color(recipe.material.outline),side:THREE.BackSide})
};
const ground=new THREE.Mesh(new THREE.PlaneGeometry(60,60),new THREE.MeshBasicNodeMaterial({color:new THREE.Color(recipe.material.ground)})); ground.rotation.x=-Math.PI/2; ground.position.y=-.025; scene.add(ground);

function makeShadowTexture(){ const c=document.createElement('canvas'); c.width=c.height=256; const x=c.getContext('2d'),g=x.createRadialGradient(128,128,8,128,128,126); g.addColorStop(0,'rgba(60,65,56,.38)'); g.addColorStop(.52,'rgba(60,65,56,.15)'); g.addColorStop(1,'rgba(60,65,56,0)'); x.fillStyle=g; x.fillRect(0,0,256,256); return new THREE.CanvasTexture(c); }
const shadowMaterial=new THREE.MeshBasicMaterial({map:makeShadowTexture(),transparent:true,depthWrite:false,opacity:.46,color:new THREE.Color(recipe.material.contactShadow)}); const contactShadow=new THREE.Mesh(new THREE.PlaneGeometry(1,1),shadowMaterial); contactShadow.rotation.x=-Math.PI/2; contactShadow.rotation.z=-.18; contactShadow.position.set(.4,.004,.1); scene.add(contactShadow);
const ringMaterial=new THREE.MeshBasicNodeMaterial({color:new THREE.Color('#9aa9a0'),transparent:true,opacity:.055}); for(const radius of [2,4,6]){const curve=new THREE.EllipseCurve(0,0,radius,radius,0,Math.PI*2,false,0),pts=curve.getPoints(128).map(p=>new THREE.Vector3(p.x,.006,p.y)); scene.add(new THREE.LineLoop(new THREE.BufferGeometry().setFromPoints(pts),ringMaterial));}

const state={seed:41,maturity:1,openness:1,density:.94,sprayScale:.94,bloom:.14,azimuth:-35,elevation:52,shadow:4.3}; let treeGroup=null,flowerMesh=null,flowerIndexCount=0,currentReport=null,timer=null;
function backendLabel(){const n=renderer.backend?.constructor?.name||'Renderer'; return /webgpu/i.test(n)?'WebGPU':/webgl/i.test(n)?'WebGL2 fallback':n;}
function disposeTree(){if(!treeGroup)return;treeGroup.traverse(o=>{if(o.isMesh&&o.geometry)o.geometry.dispose();});scene.remove(treeGroup);}
function rebuildTree(){
  disposeTree(); const built=buildDesertMuseum({seed:state.seed,maturity:state.maturity,openness:state.openness,density:state.density,sprayScale:state.sprayScale},recipe); treeGroup=new THREE.Group();
  const outline=new THREE.Mesh(built.outline,materials.outline); treeGroup.add(outline); const wood=new THREE.Mesh(built.wood,materials.wood); treeGroup.add(wood); const foliage=new THREE.Mesh(built.foliage,materials.foliage); treeGroup.add(foliage); flowerMesh=new THREE.Mesh(built.flowers,materials.flowers); flowerIndexCount=built.flowers.index?.count??0; treeGroup.add(flowerMesh); scene.add(treeGroup);
  currentReport=built.report; setBloom(state.bloom); updateMetrics(); updateShadow(); window.__PALO_VERDE_REPORT__={...currentReport,backend:backendLabel(),errors:[],artApproved:false,recipeDriven:true,paintedContactShadow:true,foliageAtlasTiles:4,target:'anime-background Desert Museum palo verde LOD0'}; document.documentElement.dataset.report=JSON.stringify(window.__PALO_VERDE_REPORT__);
}
function setBloom(v){state.bloom=Number(v);if(flowerMesh?.geometry?.index&&currentReport?.flowerBrushes){const per=flowerIndexCount/currentReport.flowerBrushes,visible=Math.floor(currentReport.flowerBrushes*state.bloom);flowerMesh.geometry.setDrawRange(0,Math.floor(visible*per));flowerMesh.visible=visible>0;}else if(flowerMesh)flowerMesh.visible=false;const o=document.querySelector('#bloomOut');if(o)o.value=`${Math.round(state.bloom*100)}%`;}
function updateSun(){const az=THREE.MathUtils.degToRad(state.azimuth),el=THREE.MathUtils.degToRad(state.elevation);sunDirection.value.set(Math.cos(el)*Math.cos(az),Math.sin(el),Math.cos(el)*Math.sin(az)).normalize();}
function updateShadow(){const softness=THREE.MathUtils.clamp(state.shadow,.5,5),spread=currentReport?.targetSpreadM||recipe.growth.mature.spreadM;contactShadow.scale.set(spread*(.72+softness*.035),spread*(.40+softness*.025),1);shadowMaterial.opacity=THREE.MathUtils.lerp(.56,.30,(softness-.5)/4.5);}
function updateMetrics(){document.querySelector('#backend').textContent=backendLabel();document.querySelector('#triangles').textContent=currentReport?Math.round(currentReport.triangles).toLocaleString():'—';document.querySelector('#brushes').textContent=currentReport?currentReport.foliageBrushes.toLocaleString():'—';}
function schedule(){clearTimeout(timer);timer=setTimeout(rebuildTree,40);}
const bindings={seed:{out:v=>String(Math.round(v)),rebuild:true},maturity:{out:v=>`${Math.round(v*100)}%`,rebuild:true},openness:{out:v=>v.toFixed(2),rebuild:true},density:{out:v=>v.toFixed(2),rebuild:true},spray:{key:'sprayScale',out:v=>v.toFixed(2),rebuild:true},bloom:{out:v=>`${Math.round(v*100)}%`,change:setBloom},azimuth:{out:v=>`${Math.round(v)}°`,change:updateSun},elevation:{out:v=>`${Math.round(v)}°`,change:updateSun},shadow:{out:v=>v.toFixed(1),change:updateShadow}};
for(const[id,b]of Object.entries(bindings)){const input=document.querySelector(`#${id}`),o=document.querySelector(`#${id}Out`);if(!input)continue;const key=b.key||id;if(state[key]!==undefined)input.value=String(state[key]);if(o)o.value=b.out(state[key]);input.addEventListener('input',()=>{state[key]=Number(input.value);if(o)o.value=b.out(state[key]);if(b.change)b.change(state[key]);if(b.rebuild)schedule();});}
const views={hero:{position:[8.7,5.9,9.4],target:[0,3.3,0]},side:{position:[-9.8,5.2,1],target:[0,3.2,0]},low:{position:[6.7,2.6,8.4],target:[0,3.45,0]},elevated:{position:[7.4,9.5,7.8],target:[0,3.2,0]},reverse:{position:[-8,5.7,-9.8],target:[0,3.3,0]}};
function setView(name){const v=views[name];if(!v)return;camera.position.fromArray(v.position);controls.target.fromArray(v.target);controls.update();}
for(const button of document.querySelectorAll('[data-view]'))button.addEventListener('click',()=>setView(button.dataset.view));document.querySelector('#randomize').addEventListener('click',()=>{state.seed=1+Math.floor(Math.random()*998);document.querySelector('#seed').value=String(state.seed);document.querySelector('#seedOut').value=String(state.seed);rebuildTree();});
updateSun();rebuildTree();setView('hero');document.documentElement.dataset.ready='true';let frames=0,start=performance.now(),smooth=60;function animate(now){controls.update();renderer.render(scene,camera);frames++;if(now-start>600){const fps=frames*1000/(now-start);smooth=smooth*.4+fps*.6;document.querySelector('#fps').textContent=smooth.toFixed(0);frames=0;start=now;}}renderer.setAnimationLoop(animate);
window.addEventListener('resize',()=>{camera.aspect=window.innerWidth/window.innerHeight;camera.updateProjectionMatrix();renderer.setSize(window.innerWidth,window.innerHeight,false);});const q=new URLSearchParams(location.search);if(q.has('capture')){document.querySelector('#panel').style.display='none';document.querySelector('#badge').style.display='none';setView(q.get('view')||'hero');}
