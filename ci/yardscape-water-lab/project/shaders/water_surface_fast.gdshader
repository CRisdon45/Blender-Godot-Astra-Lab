shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

// Restrained two-wave surface. It should make the pool read as moving water
// without covering the depth story underneath.
uniform float visual_time = 0.0;
uniform vec3 surface_tint : source_color = vec3(0.24, 0.65, 0.72);
uniform vec3 highlight_tint : source_color = vec3(0.91, 0.98, 0.96);

varying vec3 world_position;
varying vec3 world_normal;
varying float phase_crest;

float tri(float x) {
	float f = abs(fract(x) - 0.5) * 2.0;
	return f * f * (3.0 - 2.0 * f);
}

void vertex() {
	vec2 p = VERTEX.xz;
	float p0 = dot(p, vec2(0.972, 0.233)) * 2.55 + visual_time * 0.68;
	float p1 = dot(p, vec2(-0.339, 0.941)) * 3.75 - visual_time * 0.46;
	float h = 0.017 * sin(p0) + 0.008 * sin(p1);
	vec2 g = vec2(
		0.017 * 2.55 * 0.972 * cos(p0) - 0.008 * 3.75 * 0.339 * cos(p1),
		0.017 * 2.55 * 0.233 * cos(p0) + 0.008 * 3.75 * 0.941 * cos(p1)
	);
	VERTEX.y += h;
	NORMAL = normalize(vec3(-g.x, 1.0, -g.y));
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	phase_crest = h;
}

void fragment() {
	vec3 n = normalize(world_normal);
	float slope = 1.0 - clamp(abs(n.y), 0.0, 1.0);
	float wash = 0.62 * tri(dot(world_position.xz, vec2(0.12, 0.06)) + 0.19)
		+ 0.38 * tri(dot(world_position.xz, vec2(-0.07, 0.17)) + 0.54);
	float crest = smoothstep(0.012, 0.024, phase_crest);

	vec3 color = surface_tint * (0.95 + 0.07 * wash);
	color = mix(color, highlight_tint, crest * 0.09);

	float alpha = 0.065 + 0.09 * slope + 0.018 * crest;
	ALBEDO = color;
	ALPHA = clamp(alpha, 0.045, 0.20);
}
