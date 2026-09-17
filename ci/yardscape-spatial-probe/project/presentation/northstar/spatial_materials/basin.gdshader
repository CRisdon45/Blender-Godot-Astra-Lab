shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Opaque submerged geometry, not a painted top-down screenshot.
// The supplied water datum and actual fragment elevation control depth tone.
// Stationary caustic-like marks are illustration, not simulated light transport.
uniform float water_level = 0.0;
uniform float seed = 41.0;
uniform vec3 shallow_color : source_color = vec3(.50,.80,.80);
uniform vec3 deep_color : source_color = vec3(.09,.53,.65);
uniform vec3 wall_color : source_color = vec3(.77,.85,.82);
uniform vec3 light_color : source_color = vec3(.88,.97,.94);
varying vec3 world_point;
varying vec3 world_normal;
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
float hv(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7))+seed*.071)*43758.5453);}
float nv(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hv(i),hv(i+vec2(1,0)),f.x),mix(hv(i+vec2(0,1)),hv(i+vec2(1,1)),f.x),f.y);}
float wash(vec2 p){return .61*nv(p)+.27*nv(p*2.07+7.)+.12*nv(p*4.13+19.);}
vec2 site(vec2 p){return vec2(hv(p),hv(p+37.));}
float caustic_edge(vec2 p){
 vec2 cell=floor(p),f=fract(p);float first=100.,second=100.;
 for(int y=-1;y<=1;y++)for(int x=-1;x<=1;x++){
  vec2 g=vec2(float(x),float(y));vec2 jitter=.18+.64*site(cell+g);
  float d=length(g+jitter-f);
  if(d<first){second=first;first=d;}else{second=min(second,d);}
 }
 return second-first;
}
void fragment(){
 float depth=max(0.,water_level-world_point.y);
 vec2 plan=vec2(world_point.x,-world_point.z);
 vec2 p=plan;
 // Project onto walls too, without stretching a flat decal down their faces.
 if(abs(world_normal.y)<.5){p=abs(world_normal.x)>.5?vec2(plan.y,depth):vec2(plan.x,depth);}
 vec2 warp=vec2(wash(p*.48+5.),wash(p*.53+31.))-.5;
 float value=wash(p*vec2(.55,.36)+warp*.55);
 vec3 rgb=mix(shallow_color,deep_color,smoothstep(.25,1.65,depth));
 rgb*=.89+.20*smoothstep(.30,.70,value);
 float deposit=exp(-abs(value-.48)*80.)*.055;
 rgb*=exp(-deposit*vec3(.9,.40,.30));
 float edge=caustic_edge(p*2.8+warp*.64);
 float aa=max(fwidth(edge),.006);
 float net=1.-smoothstep(.018,.018+aa,edge);
 float density=.43+.20*wash(p*1.2+19.);
 rgb=mix(rgb,light_color,net*density);
 // Do not color the above-water wall as though it were submerged.
 rgb=mix(wall_color,rgb,smoothstep(-.005,.025,water_level-world_point.y));
 ALBEDO=rgb;ROUGHNESS=1.;
}
