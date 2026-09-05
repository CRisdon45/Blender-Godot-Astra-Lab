shader_type spatial;
render_mode unshaded,cull_disabled;
varying float h;
void vertex(){
 vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; h=clamp((p.y-1.79)/0.65,0.0,1.0);
 VERTEX.x+=sin(TIME*5.0+p.x*13.0+p.y*5.0)*h*0.024;
}
void fragment(){ALBEDO=mix(vec3(1.0,0.92,0.35),vec3(1.0,0.30,0.012),h); EMISSION=ALBEDO*0.4;}
