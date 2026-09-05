shader_type spatial;
render_mode cull_disabled;
uniform vec4 shallow_color : source_color=vec4(0.23,0.68,0.79,1.0);
uniform vec4 deep_color : source_color=vec4(0.025,0.43,0.62,1.0);
varying vec3 p;
vec2 hash2(vec2 v){return fract(sin(vec2(dot(v,vec2(127.1,311.7)),dot(v,vec2(269.5,183.3))))*43758.5453);}
float cells(vec2 uv){
 vec2 i=floor(uv); vec2 f=fract(uv); float a=8.0; float b=8.0;
 for(int y=-1;y<=1;y++)for(int x=-1;x<=1;x++){
  vec2 n=vec2(float(x),float(y)); vec2 point=hash2(i+n); point=0.5+0.36*sin(TIME*0.6+6.2831*point); float d=length(n+point-f);
  if(d<a){b=a;a=d;}else if(d<b)b=d;
 }
 return 1.0-smoothstep(0.015,0.07,b-a);
}
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; VERTEX.y+=sin(p.x*6.0+p.z*7.0+TIME)*0.007;}
void fragment(){
 vec2 uv=p.xz;
 float caustic=cells(uv*3.3+vec2(sin(uv.y*4.0+TIME)*0.1,cos(uv.x*3.0+TIME)*0.1));
 float fine=pow(max(0.0,sin(uv.y*43.0+sin(uv.x*5.0+uv.y*3.0)*4.0+sin(uv.x*18.0+TIME)*1.4+TIME*1.2)),12.0);
 float shallow=smoothstep(-0.2,1.2,p.z);
 vec3 col=mix(deep_color.rgb,shallow_color.rgb,0.35+shallow*0.6);
 col=mix(col,vec3(0.61,0.87,0.91),caustic*0.20+fine*0.045);
 ALBEDO=col; ROUGHNESS=0.22; SPECULAR=0.65; METALLIC=0.08;
 NORMAL=normalize(NORMAL+vec3(sin(uv.x*14.0+uv.y*8.0+TIME)*0.08,0.0,cos(uv.y*19.0+TIME)*0.08));
}
