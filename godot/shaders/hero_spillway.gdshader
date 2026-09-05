shader_type spatial;
render_mode cull_disabled, depth_draw_never;
uniform float water_time = 0.0;
uniform float water_level = 0.3225;
uniform float flow_strength = 1.0;
varying vec3 p;
void vertex() { p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	if (flow_strength<=0.0) { discard; }
	float phase=p.x*36.0+sin(p.x*9.3+p.y*3.2-water_time*1.5)*1.7;
	float fine=pow(0.5+0.5*sin(phase),8.0);
	float falling=0.5+0.5*sin(p.y*18.0+water_time*7.0+p.x*4.5);
	float aeration=1.0-smoothstep(water_level+0.03,water_level+0.36,p.y);
	ALBEDO=mix(vec3(0.12,0.47,0.55),vec3(0.78,0.88,0.87),fine*0.34+aeration*0.4);
	ROUGHNESS=mix(0.09,0.23,aeration);
	SPECULAR=0.30;
	ALPHA=clamp(0.35+fine*0.16+falling*0.07+aeration*0.22,0.0,0.85);
}
