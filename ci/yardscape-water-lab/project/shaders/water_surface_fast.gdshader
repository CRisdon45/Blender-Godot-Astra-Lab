shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

// Known-fast surface baseline.
// Two vertex waves + cheap Fresnel-like opacity + broad illustrated variation.
uniform float visual_time = 0.0;
uniform vec3 surface_tint : source_color = vec3(0.25, 0.68, 0.75);
uniform vec3 highlight_tint : source_color = vec3(0.91, 0.98, 0.96);
uniform float surface_strength = 1.0;

varying vec3 world_position;
varying vec3 world_normal;
varying float crest;

float tri(float x) {
	float f = abs(fract(x) - 0.5) * 2.0;
	return f * f * (3.0 - 2.0 * f);
}

void vertex() {
	vec2 p = VERTEX.xz;
	float p0 = dot(p, vec2(0.972, 0.233)) * 2.75 + visual_time * 0.72;
	float p1 = dot(p, vec2(-0.339, 0.941)) * 4.10 - visual_time * 0.49;
	float h = 0.020 * sin(p0) + 0.010 * sin(p1);
	vec2 g = vec2(0.020 * 2.75 * 0.972 * cos(p0) - 0.010 * 4.10 * 0.339 * cos(p1),
		0.020 * 2.75 * 0.233 * cos(p0) + 0.010 * 4.10 * 0.941 * cos(p1));

	VERTEX.y += h;
	NORMAL = normalize(vec3(-g.x, 1.0, -g.y));
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	crest = h;
}

void fragment() {
	vec3 n = normalize(world_normal);
	float facing = clamp(abs(n.y), 0.0, 1.0);
	float edge = 1.0 - facing;
	float edge2 = edge * edge;
	float wash = 0.62 * tri(dot(world_position.xz, vec2(0.13, 0.07)) + 0.21)
		+ 0.38 * tri(dot(world_position.xz, vec2(-0.08, 0.18)) + 0.57);
	float crest_light = smoothstep(0.014, 0.028, crest);

	vec3 color = surface_tint * (0.94 + 0.08 * wash);
	color = mix(color, highlight_tint, crest_light * 0.10);

	float alpha = (0.10 + 0.14 * edge2 + crest_light * 0.025) * surface_strength;
	ALBEDO = color;
	ALPHA = clamp(alpha, 0.05, 0.30);
}
