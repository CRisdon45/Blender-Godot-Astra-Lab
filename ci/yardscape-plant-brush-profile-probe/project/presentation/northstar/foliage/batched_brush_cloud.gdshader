shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
// COLOR.r is restrained local tone, COLOR.g is interior occlusion, and
// COLOR.a is hierarchy role. UV/UV2 preserve group-local position and family.
uniform vec2 sun_direction = vec2(0.0,-1.0);
uniform float leader_family_value = 0.0;
varying vec3 group_local;
varying float family_angle;
varying float role_code;
varying float interior_occlusion;
void vertex(){
 group_local=vec3(UV.x,UV2.x,UV.y);
 family_angle=UV2.y;
 role_code=COLOR.a;
 interior_occlusion=COLOR.g;
}
float grain(vec3 p){return .5+.23*sin(p.x*4.7+p.y*3.3)+.12*sin(p.z*6.1-p.y*2.4);}
void fragment(){
 float family_value=0.0;
 float role_value=-.004;
 if(role_code>.90){
  family_value=leader_family_value;
  role_value=.006;
 }else{
  vec2 family_dir=vec2(cos(family_angle),sin(family_angle));
  float alignment=dot(family_dir,sun_direction);
  if(alignment>.28) family_value=.095;
  else if(alignment<-.28) family_value=-.095;
  if(role_code>.50) role_value=.008;
 }
 float local_tone=mix(.5,COLOR.r,.24)-interior_occlusion*.045;
 float tone=clamp(local_tone+family_value+role_value,.18,.80);
 vec3 dark=vec3(.16,.27,.105);
 vec3 middle=vec3(.34,.49,.205);
 vec3 light_value=vec3(.61,.67,.355);
 vec3 color=mix(dark,middle,smoothstep(.33,.52,tone));
 color=mix(color,light_value,smoothstep(.50,.66,tone)*.46);
 color*=.985+.030*grain(group_local);
 ALBEDO=color;
 ROUGHNESS=1.0;
}
