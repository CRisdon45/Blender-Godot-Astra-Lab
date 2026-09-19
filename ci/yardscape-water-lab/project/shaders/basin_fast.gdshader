shader_type spatial;
render_mode unshaded;

// Lightweight illustrated basin: real geometry controls depth; caustics are
// sparse curved ribbons rather than a cellular net or repeated dot pattern.
uniform float visual_time = 0.0;
uniform float water_level = 0.0;
uniform bool caustics_enabled = true;
uniform vec3 shallow_color : source_color = vec3(0.51, 0.82, 0.82);
uniform vec3 deep_color : source_color = vec3(0.07, 0.44, 0.58);
uniform vec3 light_tint : source_color = vec3(0.90, 0.98, 0.95);

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
	float depth_mix = smoothstep(0.10, 1.58, depth);
	vec3 color = mix(shallow_color, deep_color, depth_mix);

	vec2 p = world_position.xz;
	float wash_a = tri(dot(p, vec2(0.16, 0.08)) + 0.17);
	float wash_b = tri(dot(p, vec2(-0.09, 0.20)) + 0.61);
	float wash = 0.64 * wash_a + 0.36 * wash_b;
	color *= 0.91 + 0.12 * wash;

	if (caustics_enabled && depth > 0.03) {
		float phase_a = dot(p, vec2(2.50, 0.88)) + visual_time * 0.68 + sin(p.y * 1.10) * 0.48;
		float phase_b = dot(p, vec2(-1.10, 3.15)) - visual_time * 0.51 + sin(p.x * 0.92) * 0.55;
		float ribbon_a = 1.0 - smoothstep(0.035, 0.16, abs(sin(phase_a)));
		float ribbon_b = 1.0 - smoothstep(0.030, 0.14, abs(sin(phase_b)));
		float breakup = 0.56 + 0.44 * tri(dot(p, vec2(0.23, -0.17)) + 0.39);
		float reserve = smoothstep(0.70, 0.88, tri(dot(p, vec2(-0.31, 0.13)) + 0.72));
		float light = max(ribbon_a * 0.17, ribbon_b * 0.13);
		light *= breakup * (1.0 - reserve * 0.62) * exp(-depth * 0.19);
		color = mix(color, light_tint, clamp(light, 0.0, 0.22));
	}

	ALBEDO = color;
}
