shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap;
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float s=sin(p.x*119.0+sin(p.y*8.0+TIME*4.0)*0.45);
 float fine=sin(p.y*57.0+TIME*15.0+p.x*3.0)*0.5+0.5;
 float streak=smoothstep(0.5,0.97,s);
 ALBEDO=mix(vec3(0.16,0.53,0.68),vec3(0.86,0.97,1.0),streak*0.82+fine*0.1);
 ROUGHNESS=0.18; SPECULAR=0.7; EMISSION=vec3(0.15,0.24,0.26)*streak;
}

