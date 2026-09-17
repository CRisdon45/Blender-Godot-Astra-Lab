shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Final-mesh normals only. Low-frequency pigment follows local 3D position.
varying vec3 local_point;
void vertex(){local_point=VERTEX;}
float grain(vec3 p){return .5+.25*sin(p.x*7.1+p.y*4.7)+.15*sin(p.z*9.3-p.y*3.1);}
void fragment(){
 float tone=COLOR.r;
 vec3 dark=vec3(.20,.32,.14);
 vec3 middle=vec3(.36,.50,.21);
 vec3 light=vec3(.58,.64,.33);
 vec3 color=mix(dark,middle,smoothstep(.34,.54,tone));
 color=mix(color,light,smoothstep(.48,.62,tone)*.45);
 color*=.96+.07*grain(local_point);
 ALBEDO=color;
 ROUGHNESS=1.;
}
