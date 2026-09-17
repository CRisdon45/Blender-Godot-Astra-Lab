shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Same opaque geometry and final-mesh normals. Family value is assigned per
// branch family by the scene; local dab-tone variation is intentionally compressed.
uniform float family_value = 0.0;
uniform float role_value = 0.0;
varying vec3 local_point;
void vertex(){local_point=VERTEX;}
float grain(vec3 p){return .5+.25*sin(p.x*7.1+p.y*4.7)+.15*sin(p.z*9.3-p.y*3.1);}
void fragment(){
 float local_tone=mix(.5,COLOR.r,.28);
 float tone=clamp(local_tone+family_value+role_value,.20,.80);
 vec3 dark=vec3(.19,.30,.13);
 vec3 middle=vec3(.35,.49,.21);
 vec3 light=vec3(.57,.63,.33);
 vec3 color=mix(dark,middle,smoothstep(.34,.54,tone));
 color=mix(color,light,smoothstep(.49,.65,tone)*.43);
 color*=.97+.055*grain(local_point);
 ALBEDO=color;
 ROUGHNESS=1.;
}
