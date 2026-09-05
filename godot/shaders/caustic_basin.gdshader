shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/water_detail_common.gdshaderinc"
uniform float caustic_strength = 2.1;
uniform float caustic_daylight = 1.0;
uniform float water_time = 0.0;
uniform float water_level = 0.3225;
uniform vec3 sun_to_surface = vec3(-0.314,0.743,0.589);
uniform vec4 plaster : source_color = vec4(0.69,0.81,0.81,1.0);
varying vec3 world_position;
varying float focus;
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	float depth=max(0.0,water_level-world_position.y);
	vec3 light_dir=normalize(sun_to_surface);
	vec3 bent=refract(-light_dir,vec3(0.0,1.0,0.0),1.0/1.333);
	vec2 source=world_position.xz-bent.xz*depth/max(-bent.y,0.1);
	// One inverse-ray correction moves the receiver sample with the same ripples.
	float travel=depth*(1.0-1.0/1.333)*1.65;
	source+=detail_field(source,water_time).xy*travel;
	vec3 h=detail_hessian(source,water_time);
	float jacobian=(1.0+travel*h.x)*(1.0+travel*h.z)-travel*travel*h.y*h.y;
	float width=max(fwidth(jacobian)*1.6,0.09);
	// Soft shoulders, narrow cores, bounded energy. Still a thin-lens study,
	// not a forward photon caustic solver or occlusion-complete refracted light.
	float density=clamp(1.0/max(abs(jacobian),width)-1.0,0.0,5.0);
	focus=pow(density/5.0,0.72)*exp(-depth*0.28);
	focus*=smoothstep(0.008,0.06,depth)*caustic_daylight;
	ALBEDO=plaster.rgb;
	ROUGHNESS=0.80;
	SPECULAR=0.15;
}
void light() {
	float diffuse=max(dot(NORMAL,LIGHT),0.0);
	// No white emission: visible light and its shadow attenuation gate the pattern.
	DIFFUSE_LIGHT+=ALBEDO*LIGHT_COLOR*ATTENUATION*diffuse*(1.0+focus*caustic_strength)/PI;
}
