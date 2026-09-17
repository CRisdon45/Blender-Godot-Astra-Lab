shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Branch-group pigment organization only. Real scene light/shadows stay active.
uniform float group_value=.5;
uniform float group_mix=.72;
uniform float group_phase=0.;
varying vec3 local_point;
void vertex(){local_point=VERTEX;}
float broad(vec3 p){return .5+.23*sin(p.x*4.3+group_phase)*sin(p.y*3.1-p.z*.8)+.12*sin(p.z*5.1+p.x*1.7-group_phase);}
void fragment(){
 float local_value=COLOR.r;
 float tone=mix(local_value,group_value,group_mix)+(broad(local_point*2.1)-.5)*.05;
 tone=clamp(tone,.30,.72);
 vec3 dark=vec3(.20,.31,.14);
 vec3 middle=vec3(.36,.49,.21);
 vec3 light=vec3(.58,.63,.33);
 vec3 color=mix(dark,middle,smoothstep(.34,.54,tone));
 color=mix(color,light,smoothstep(.49,.66,tone)*.46);
 ALBEDO=color;
 ROUGHNESS=1.;
}
