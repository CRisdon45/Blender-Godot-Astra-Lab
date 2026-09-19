shader_type spatial;
render_mode unshaded, cull_front;

// Interior-only pool wall witness. cull_front hides the camera-facing exterior
// shell while keeping far/inside wall faces visible through the water.
uniform float water_level = 0.0;
uniform vec3 wall_shallow : source_color = vec3(0.62, 0.82, 0.81);
uniform vec3 wall_deep : source_color = vec3(0.14, 0.49, 0.60);

varying vec3 world_position;

float tri(float x) {
	float f = abs(fract(x) - 0.5) * 2.0;
	return f * f * (3.0 - 2.0 * f);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float depth = max(0.0, water_level - world_position.y);
	float depth_mix = smoothstep(0.10, 1.55, depth);
	vec3 color = mix(wall_shallow, wall_deep, depth_mix);
	float wash = 0.62 * tri(world_position.x * 0.13 + world_position.z * 0.07 + 0.2)
		+ 0.38 * tri(-world_position.x * 0.08 + world_position.z * 0.17 + 0.6);
	color *= 0.93 + 0.09 * wash;
	ALBEDO = color;
}
