function lcg(seed){let s=seed>>>0||1;return()=>{s=Math.imul(1664525,s)+1013904223>>>0;return s/4294967296;};}

/** Original lightweight Palo Verde silhouette accents: one soft rachis with paired brush leaflets. */
export function createPaloVerdeSprigAtlas(THREE,{seed=73121,tiles=4,tileSize=256}={}){
  const canvas=document.createElement('canvas');canvas.width=tileSize*tiles;canvas.height=tileSize;const ctx=canvas.getContext('2d');ctx.clearRect(0,0,canvas.width,canvas.height);
  for(let tile=0;tile<tiles;tile++){
    const r=lcg(seed+tile*4099),ox=tile*tileSize,cx=ox+tileSize*.5,cy=tileSize*.5,angle=(r()-.5)*.34;
    ctx.save();ctx.beginPath();ctx.rect(ox,0,tileSize,tileSize);ctx.clip();ctx.translate(cx,cy);ctx.rotate(angle);
    ctx.lineCap='round';ctx.strokeStyle='rgb(160,160,160)';ctx.globalAlpha=.86;ctx.lineWidth=5.5;ctx.beginPath();ctx.moveTo(-88,10);ctx.bezierCurveTo(-36,-7,34,7,88,-8);ctx.stroke();
    const pairs=5+Math.floor(r()*3);
    for(let i=0;i<pairs;i++){
      const x=-67+i*(134/Math.max(1,pairs-1)),baseY=4*Math.sin((i/(pairs-1))*Math.PI*1.4+tile*.4),len=19+r()*15,wid=5+r()*4,tilt=.32+r()*.24;
      for(const sign of[-1,1]){
        ctx.save();ctx.translate(x,baseY+sign*5);ctx.rotate(sign*tilt+(r()-.5)*.18);ctx.fillStyle=`rgb(${150+Math.floor(r()*55)},${150+Math.floor(r()*55)},${150+Math.floor(r()*55)})`;ctx.globalAlpha=.88+r()*.10;ctx.beginPath();ctx.ellipse(sign*len*.34,sign*len*.42,len*.55,wid,0,0,Math.PI*2);ctx.fill();ctx.restore();
      }
    }
    // Slightly larger terminal brush keeps the end soft rather than needle-like.
    ctx.save();ctx.translate(83,-7);ctx.rotate(-.18+(r()-.5)*.18);ctx.fillStyle='rgb(190,190,190)';ctx.globalAlpha=.93;ctx.beginPath();ctx.ellipse(7,0,18,6,0,0,Math.PI*2);ctx.fill();ctx.restore();
    ctx.restore();
  }
  const texture=new THREE.CanvasTexture(canvas);texture.colorSpace=THREE.NoColorSpace;texture.needsUpdate=true;return texture;
}
