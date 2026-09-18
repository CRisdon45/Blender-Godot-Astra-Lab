shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// COLOR.r retains each dab's local tone. COLOR.a encodes branch role.
// UV stores original group-local x/z; UV2.x stores original local y and UV2.y
// stores the branch-family angle. This preserves the retained local pigment field
// while allowing all foliage groups to share one material.
uniform vec2 sun_direction = vec2(0.0,-1.0);
uniform float leader_family_value = 0.0;
varying vec3 group_local;
varying float family_angle;
varying float role_code;
void vertex(){
 group_local=vec3(UV.x,UV2.x,UV.y);
 family_angle=UV2.y;
 role_code=COLOR.a;
}
float grain(vec3 p){return .5+.25*sin(p.x*7.1+p.y*4.7)+.15*sin(p.z*9.3-p.y*3.1);}
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
 float local_tone=mix(.5,COLOR.r,.14);
 float tone=clamp(local_tone+family_value+role_value,.20,.80);
 vec3 dark=vec3(.18,.29,.12);
 vec3 middle=vec3(.35,.49,.21);
 vec3 light_value=vec3(.60,.65,.34);
 vec3 color=mix(dark,middle,smoothstep(.34,.54,tone));
 color=mix(color,light_value,smoothstep(.49,.65,tone)*.43);
 color*=.97+.055*grain(group_local);
 ALBEDO=color;
 ROUGHNESS=1.;
}
