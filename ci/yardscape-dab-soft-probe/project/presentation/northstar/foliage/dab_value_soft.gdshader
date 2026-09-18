shader_type spatial;
render_mode specular_disabled;
// Same geometry, hierarchy values and final-mesh normals as the retained value
// candidate. Only direct diffuse response is compressed; ATTENUATION still carries
// the scene's real light/shadow visibility.
uniform float family_value = 0.0;
uniform float role_value = 0.0;
varying vec3 local_point;
void vertex(){local_point=VERTEX;}
float grain(vec3 p){return .5+.25*sin(p.x*7.1+p.y*4.7)+.15*sin(p.z*9.3-p.y*3.1);}
void fragment(){
 float local_tone=mix(.5,COLOR.r,.14);
 float tone=clamp(local_tone+family_value+role_value,.20,.80);
 vec3 dark=vec3(.18,.29,.12);
 vec3 middle=vec3(.35,.49,.21);
 vec3 light_color_value=vec3(.60,.65,.34);
 vec3 color=mix(dark,middle,smoothstep(.34,.54,tone));
 color=mix(color,light_color_value,smoothstep(.49,.65,tone)*.43);
 color*=.97+.055*grain(local_point);
 ALBEDO=color;
 ROUGHNESS=1.;
}
void light(){
 float ndl=max(dot(NORMAL,LIGHT),0.0);
 float compressed=mix(.32,1.0,pow(ndl,.45));
 DIFFUSE_LIGHT += compressed * ATTENUATION * LIGHT_COLOR / PI;
}
