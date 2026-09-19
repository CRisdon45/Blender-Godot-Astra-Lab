shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

// Four-wave Northstar surface.
// Depth/value still comes from submerged geometry. The surface now adds sparse,
// broken highlight passages extracted from iso-height contours of the *combined*
// wave field, so the marks bend with interference rather than forming a grid.
uniform float visual_time = 0.0;
uniform vec3 sun_ray_dir = vec3(0.3796774, -0.8193039, 0.4296350);
uniform vec3 surface_tint : source_color = vec3(0.23, 0.64, 0.72);
uniform vec3 highlight_tint : source_color = vec3(0.93, 0.99, 0.97);

varying vec3 world_position;
varying vec3 world_normal;
varying float wave_height;

float tri(float x) {
	float f = abs(fract(x) - 0.5) * 2.0;
	return f * f * (3.0 - 2.0 * f);
}

float paint_field(vec2 p) {
	float a = tri(dot(p, vec2(0.77, 0.31)) * 0.19 + 0.13);
	float b = tri(dot(p, vec2(-0.42, 0.91)) * 0.27 + a * 0.17 + 0.37);
	return clamp(0.22 + 0.50 * a + 0.28 * b, 0.0, 1.0);
}

void wave_sample(vec2 p, float t, out float h, out vec2 grad) {
	vec2 d0 = normalize(vec2(1.00, 0.24));
	vec2 d1 = normalize(vec2(-0.36, 1.00));
	vec2 d2 = normalize(vec2(0.74, -0.67));
	vec2 d3 = normalize(vec2(-0.86, -0.51));

	float k0 = 2.75;
	float k1 = 3.65;
	float k2 = 5.10;
	float k3 = 6.70;
	float p0 = dot(p, d0) * k0 + t * 0.72;
	float p1 = dot(p, d1) * k1 - t * 0.49;
	float p2 = dot(p, d2) * k2 + t * 0.37;
	float p3 = dot(p, d3) * k3 - t * 0.84;

	h =
		0.017 * sin(p0)
		+ 0.010 * sin(p1)
		+ 0.0055 * sin(p2)
		+ 0.0035 * sin(p3);

	grad =
		d0 * (0.017 * k0 * cos(p0))
		+ d1 * (0.010 * k1 * cos(p1))
		+ d2 * (0.0055 * k2 * cos(p2))
		+ d3 * (0.0035 * k3 * cos(p3));
}

void vertex() {
	float h;
	vec2 grad;
	wave_sample(VERTEX.xz, visual_time, h, grad);
	VERTEX.y += h;
	NORMAL = normalize(vec3(-grad.x, 1.0, -grad.y));

	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	wave_height = h;
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 to_camera = normalize(CAMERA_POSITION_WORLD - world_position);
	vec3 to_sun = normalize(-sun_ray_dir);

	float fresnel = pow(1.0 - clamp(dot(n, to_camera), 0.0, 1.0), 3.35);
	vec3 half_vector = normalize(to_camera + to_sun);
	float sun_glint = pow(max(dot(n, half_vector), 0.0), 34.0);

	float wash = paint_field(world_position.xz * 0.55 + vec2(3.0, 4.0));
	float broken = smoothstep(0.55, 0.78, wash);
	float crest = smoothstep(0.012, 0.026, wave_height);
	float glint = sun_glint * broken;

	// Irregular curved surface passages from the full interference field.
	// These are intentionally sparse and broken; they should read like selected
	// illustrated light gestures, not every wave crest.
	float contour_a = 1.0 - smoothstep(0.0025, 0.0085, abs(wave_height - 0.0085));
	float contour_b = 1.0 - smoothstep(0.0020, 0.0070, abs(wave_height + 0.0100));
	float passage_mask = smoothstep(0.62, 0.82,
		paint_field(world_position.xz * 0.78 + vec2(-4.0, 8.0)));
	float reserve = smoothstep(0.74, 0.90,
		paint_field(world_position.xz * 1.17 + vec2(9.0, -3.0)));
	float passage = max(contour_a, contour_b * 0.62);
	passage *= passage_mask * (1.0 - reserve * 0.72);

	vec3 color = surface_tint * (0.95 + 0.07 * wash);
	float light_mix = clamp(glint * 0.62 + crest * 0.060 + passage * 0.24, 0.0, 0.62);
	color = mix(color, highlight_tint, light_mix);

	float alpha = 0.064 + 0.165 * fresnel + 0.055 * glint + 0.014 * crest + 0.050 * passage;
	ALBEDO = color;
	ALPHA = clamp(alpha, 0.045, 0.27);
}
