shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/hero_water_common.gdshaderinc"
uniform float caustic_strength = 1.8;
uniform float caustic_daylight = 1.0;
uniform float water_time = 0.0;
uniform float water_level = 0.3225;
uniform vec4 plaster : source_color = vec4(0.62,0.78,0.80,1.0);
varying vec3 world_position;
varying float focus;
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	float depth = max(0.0,water_level-world_position.y);
	vec2 source_point = world_position.xz+vec2(0.19,-0.24)*depth;
	vec3 h = pool_hessian(source_point,water_time);
	float travel = depth*(1.0-1.0/1.333)*1.6;
	float jacobian = (1.0+travel*h.x)*(1.0+travel*h.z)-travel*travel*h.y*h.y;
	float width = max(fwidth(jacobian)*1.4,0.06);
	focus = (1.0-smoothstep(0.10,0.34+width,abs(jacobian))) * exp(-depth*0.38);
	focus *= smoothstep(0.02,0.12,depth)*caustic_daylight;
	ALBEDO=plaster.rgb;
	ROUGHNESS=0.82;
	SPECULAR=0.18;
}
void light() {
	float diffuse=max(dot(NORMAL,LIGHT),0.0);
	// Receiver light, not luminous white paint: shadows and lights control it.
	DIFFUSE_LIGHT += ALBEDO*LIGHT_COLOR*ATTENUATION*diffuse*(1.0+focus*caustic_strength)/PI;
}
