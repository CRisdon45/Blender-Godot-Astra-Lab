shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap;

uniform vec4 tint : source_color = vec4(0.8,0.75,0.64,1.0);
uniform sampler2D grain_tex : repeat_enable, filter_linear_mipmap;
uniform int kind = 0;
uniform float detail = 0.13;
varying vec3 world_pos;
varying vec3 world_normal;

void vertex(){
 world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
 world_normal = normalize(mat3(MODEL_MATRIX)*NORMAL);
 if(kind==2){
  VERTEX.x += sin(TIME*0.65+world_pos.x*1.4+world_pos.z)*0.012;
 }
}
void fragment(){
 vec3 weights=pow(abs(world_normal),vec3(6.0));
 weights/=max(dot(weights,vec3(1.0)),0.001);
 float g=texture(grain_tex,world_pos.zy*2.0).r*weights.x+texture(grain_tex,world_pos.xz*2.0).r*weights.y+texture(grain_tex,world_pos.xy*2.0).r*weights.z;
 if(kind==1)g=texture(grain_tex,vec2((world_pos.z+world_pos.y)*0.9,world_pos.x*0.13)).r;
 vec3 col=tint.rgb*(1.0+(g-0.5)*detail);
 if(kind==2){
  float variation=sin(world_pos.x*9.0+world_pos.y*7.0+world_pos.z*12.0)*0.04;
  col*=1.0+variation;
  BACKLIGHT=col*0.18;
 }
 ALBEDO=col;
 ROUGHNESS=kind==4 ? 0.52 : 0.88;
 SPECULAR=kind==4 ? 0.35 : 0.17;
}

