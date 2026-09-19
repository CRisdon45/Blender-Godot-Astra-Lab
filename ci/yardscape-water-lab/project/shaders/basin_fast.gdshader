shader_type spatial;
render_mode unshaded;

// Known-fast diagnostic baseline.
// Keeps only the visual cues we absolutely need to judge the water:
// real depth, broad illustrated variation, and cheap moving light bands.
uniform float visual_time = 0.0;
uniform float water_level = 0.0;
uniform bool caustics_enabled = true;
uniform vec3 shallow_color : source_color = vec3(0.53, 0.82, 0.82);
uniform vec3 deep_color : source_color = vec3(0.08, 0.48, 0.61);
uniform vec3 wall_shallow : source_color = vec3(0.67, 0.84, 0.82);
uniform vec3 wall_deep : source_color = vec3(0.16, 0.53, 0.62);
uniform vec3 light_tint : source_color = vec3(0.90, 0.98, 0.95);

varying vec3 world_position;
varying vec3 world_normal;

float tri(float x) {
	float f = abs(fract(x) - 0.5) * 2.0;
	return f * f * (3.0 - 2.0 * f);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	float depth = max(0.0, water_level - world_position.y);
	vec3 n = normalize(world_normal);
	bool horizontal = abs(n.y) > 0.55;

	float depth_mix = smoothstep(0.12, 1.58, depth);
	vec3 base = horizontal
		? mix(shallow_color, deep_color, depth_mix)
		: mix(wall_shallow, wall_deep, depth_mix);

	vec2 p = world_position.xz;
	float wash_a = tri(dot(p, vec2(0.17, 0.09)) + 0.18);
	float wash_b = tri(dot(p, vec2(-0.11, 0.21)) + 0.63);
	float wash = 0.62 * wash_a + 0.38 * wash_b;
	base *= 0.92 + 0.10 * wash;

	float light = 0.0;
	if (caustics_enabled && depth > 0.03) {
		// Two broad moving triangular bands. Intentionally cheap and soft.
		float b1 = tri(dot(p, vec2(0.66, 0.28)) + visual_time * 0.055);
		float b2 = tri(dot(p, vec2(-0.31, 0.74)) - visual_time * 0.043 + 0.31);
		float focus = smoothstep(0.69, 0.91, 0.58 * b1 + 0.42 * b2);
		light = focus * exp(-depth * 0.24) * 0.26;
	}
	base = mix(base, light_tint, light);
	ALBEDO = base;
}
