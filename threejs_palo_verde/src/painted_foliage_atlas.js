function lcg(seed){let s=seed>>>0||1;return()=>{s=Math.imul(1664525,s)+1013904223>>>0;return s/4294967296;};}

/**
 * Original procedural foliage paint atlas.
 * Each tile is one continuous irregular brush-cloud, not a literal leaf cluster.
 * Grayscale stores broad painted value; alpha stores the silhouette.
 */
export function createPaintedCloudAtlas(THREE,{seed=39041,tiles=4,tileSize=256}={}){
  const canvas=document.createElement('canvas');canvas.width=tileSize*tiles;canvas.height=tileSize;
  const ctx=canvas.getContext('2d');ctx.clearRect(0,0,canvas.width,canvas.height);
  for(let tile=0;tile<tiles;tile++){
    const r=lcg(seed+tile*6173),ox=tile*tileSize,cx=ox+tileSize*.5,cy=tileSize*.5;
    const phase=r()*Math.PI*2,phase2=r()*Math.PI*2,rx=tileSize*(.355+r()*.025),ry=tileSize*(.235+r()*.025);
    ctx.save();ctx.beginPath();ctx.rect(ox,0,tileSize,tileSize);ctx.clip();
    ctx.beginPath();
    const steps=52;
    for(let i=0;i<steps;i++){
      const a=i/steps*Math.PI*2;
      const wave=1+.075*Math.sin(a*3+phase)+.046*Math.sin(a*7+phase2)+.020*(r()-.5);
      const asym=1+.035*Math.cos(a-phase*.35);
      const x=cx+Math.cos(a)*rx*wave*asym+Math.sin(a*2+phase)*tileSize*.008;
      const y=cy+Math.sin(a)*ry*wave+Math.cos(a*3+phase2)*tileSize*.006;
      if(i===0)ctx.moveTo(x,y);else ctx.lineTo(x,y);
    }
    ctx.closePath();ctx.fillStyle='white';ctx.fill();

    // A broad diagonal painted value field. This is intentionally low-frequency.
    ctx.globalCompositeOperation='source-in';
    const grad=ctx.createLinearGradient(ox+tileSize*.22,tileSize*.82,ox+tileSize*.80,tileSize*.18);
    grad.addColorStop(0,'rgb(96,96,96)');grad.addColorStop(.48,'rgb(158,158,158)');grad.addColorStop(1,'rgb(224,224,224)');
    ctx.fillStyle=grad;ctx.fillRect(ox,0,tileSize,tileSize);

    // A few subtle, broad paint washes; never individual leaf marks.
    ctx.globalCompositeOperation='source-atop';
    for(let p=0;p<3;p++){
      const px=cx+(r()-.5)*rx*.65,py=cy+(r()-.5)*ry*.55,rad=tileSize*(.08+r()*.045);
      const wash=ctx.createRadialGradient(px,py,0,px,py,rad);
      const light=p===0;wash.addColorStop(0,light?'rgba(255,255,255,.14)':'rgba(45,45,45,.10)');wash.addColorStop(1,'rgba(128,128,128,0)');
      ctx.fillStyle=wash;ctx.fillRect(px-rad,py-rad,rad*2,rad*2);
    }

    // Tiny negative-space holes plus shallow edge bites prevent a sticker silhouette.
    ctx.globalCompositeOperation='destination-out';
    for(let h=0;h<2;h++){
      const a=r()*Math.PI*2,rr=.18+r()*.32;
      ctx.globalAlpha=.78;ctx.beginPath();ctx.ellipse(cx+Math.cos(a)*rx*rr,cy+Math.sin(a)*ry*rr,tileSize*(.020+r()*.018),tileSize*(.014+r()*.014),r()*Math.PI,0,Math.PI*2);ctx.fill();
    }
    for(let h=0;h<3;h++){
      const a=r()*Math.PI*2;
      ctx.globalAlpha=.72;ctx.beginPath();ctx.ellipse(cx+Math.cos(a)*rx*.98,cy+Math.sin(a)*ry*.98,tileSize*(.027+r()*.016),tileSize*(.018+r()*.014),a,0,Math.PI*2);ctx.fill();
    }
    ctx.restore();
  }
  const texture=new THREE.CanvasTexture(canvas);texture.colorSpace=THREE.NoColorSpace;texture.needsUpdate=true;return texture;
}
