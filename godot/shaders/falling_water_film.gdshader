shader_type spatial;
render_mode cull_disabled, depth_draw_never;
#include "res://shaders/water_detail_common.gdshaderinc"
uniform float water_time = 0.0;
uniform float water_level = 0.3225;
uniform float flow_strength = 1.0;
uniform float sheet_top = 1.43;
varying vec3 p;
void vertex() {
	p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	// Subtle film flutter, pinned at both the lip and the measured impact plane.
	// CPU source geometry stays authoritative for contacts; visual offset <= 6 mm.
	float fall=clamp((sheet_top-p.y)/max(sheet_top-water_level,0.05),0.0,1.0);
	float envelope=sin(fall*PI);
	vec3 world=p;
	world.z+=sin(p.x*16.7+p.y*8.1+water_time*5.3)*0.006*envelope*flow_strength;
	VERTEX=(inverse(MODEL_MATRIX)*vec4(world,1.0)).xyz;
	p=world;
}
void fragment() {
	if (flow_strength<=0.0) { discard; }
	float drop=max(0.0,sheet_top-p.y);
	// Increasing velocity down the film: equal phase traverses greater distances.
	float falling=sqrt(drop+0.025)*5.5-water_time*4.0;
	float strands=detail_noise(vec2(p.x*42.0+sin(p.y*3.0)*0.6,falling));
	float veil=detail_noise(vec2(p.x*10.7-water_time*0.15,falling*1.6));
	float aeration=(1.0-smoothstep(water_level+0.03,water_level+0.28,p.y));
	float sparkle=smoothstep(0.66,0.86,strands)*(.4+.6*veil);
	ALBEDO=mix(vec3(0.16,0.48,0.53),vec3(0.80,0.90,0.91),sparkle*0.55+aeration*0.35);
	ROUGHNESS=mix(0.08,0.27,aeration);
	SPECULAR=0.28;
	ALPHA=clamp(0.20+veil*0.09+sparkle*0.27+aeration*(0.17+strands*0.12),0.0,0.72);
}
