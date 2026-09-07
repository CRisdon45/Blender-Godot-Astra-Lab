function lcg(seed){let s=seed>>>0||1;return()=>{s=Math.imul(1664525,s)+1013904223>>>0;return s/4294967296;};}
function ellipse(ctx,x,y,rx,ry,rot,gray,alpha){ctx.save();ctx.translate(x,y);ctx.rotate(rot);ctx.globalAlpha=alpha;ctx.fillStyle=`rgb(${gray},${gray},${gray})`;ctx.beginPath();ctx.ellipse(0,0,rx,ry,0,0,Math.PI*2);ctx.fill();ctx.restore();}

/**
 * Original Palo Verde medium-cluster atlas.
 * One tile represents an entire airy foliage spray: several fine rachises plus many
 * overlapping narrow brush leaflets. Internal transparency is intentional.
 */
export function createPaloVerdeClusterAtlas(THREE,{seed=94117,tiles=4,tileSize=256}={}){
  const canvas=document.createElement('canvas');canvas.width=tileSize*tiles;canvas.height=tileSize;const ctx=canvas.getContext('2d');ctx.clearRect(0,0,canvas.width,canvas.height);
  for(let tile=0;tile<tiles;tile++){
    const r=lcg(seed+tile*7919),ox=tile*tileSize,cx=ox+tileSize*.5,cy=tileSize*.5;
    ctx.save();ctx.beginPath();ctx.rect(ox,0,tileSize,tileSize);ctx.clip();
    const stemCount=4+Math.floor(r()*2);
    for(let s=0;s<stemCount;s++){
      const baseX=cx-72+r()*28,baseY=cy-25+s*(48/Math.max(1,stemCount-1))+r()*10,endX=cx+68+r()*18,endY=baseY+(r()-.5)*34;
      ctx.strokeStyle=`rgb(${135+Math.floor(r()*35)},${135+Math.floor(r()*35)},${135+Math.floor(r()*35)})`;ctx.globalAlpha=.65;ctx.lineWidth=2.2+r()*1.8;ctx.lineCap='round';ctx.beginPath();ctx.moveTo(baseX,baseY);ctx.bezierCurveTo(cx-34,baseY+(r()-.5)*18,cx+25,endY+(r()-.5)*15,endX,endY);ctx.stroke();
      const pairs=5+Math.floor(r()*3),stemAngle=Math.atan2(endY-baseY,endX-baseX);
      for(let p=0;p<pairs;p++){
        const t=(p+.55)/(pairs+.2),x=baseX+(endX-baseX)*t,y=baseY+(endY-baseY)*t+Math.sin(t*Math.PI)*((r()-.5)*8),leafLen=10+r()*10,leafWid=3.3+r()*3.4,brightness=118+Math.floor((.28+.72*t)*78+r()*22);
        for(const sign of[-1,1]){
          const rot=stemAngle+sign*(.53+r()*.33)+(r()-.5)*.16;
          ellipse(ctx,x+Math.cos(rot)*leafLen*.36,y+Math.sin(rot)*leafLen*.36,leafLen*.64,leafWid,rot,brightness,.78+r()*.19);
        }
      }
      ellipse(ctx,endX,endY,13+r()*6,4+r()*2.6,stemAngle+(r()-.5)*.18,178+Math.floor(r()*45),.90);
    }
    // A handful of isolated edge brushes soften the cluster silhouette without filling its holes.
    for(let i=0;i<7;i++){const a=r()*Math.PI*2,rr=55+r()*42,x=cx+Math.cos(a)*rr,y=cy+Math.sin(a)*rr*.52,rot=a+(r()-.5)*.9;ellipse(ctx,x,y,8+r()*8,2.8+r()*3.0,rot,145+Math.floor(r()*65),.68+r()*.24);}
    ctx.restore();
  }
  const texture=new THREE.CanvasTexture(canvas);texture.colorSpace=THREE.NoColorSpace;texture.needsUpdate=true;return texture;
}
