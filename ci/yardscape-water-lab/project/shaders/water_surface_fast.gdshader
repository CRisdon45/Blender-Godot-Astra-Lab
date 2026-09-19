shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

// Four-wave surface shared conceptually with basin curvature caustics.
// Surface remains restrained; underwater depth/value should do most of the work.
uniform float visual_time = 0.0;
uniform vec3 sun_ray_dir = vec3(0.3796774, -0.8193039, 0.4296350);
uniform vec3 surface_tint : source_color = vec3(0.23, 0.64, 0.72);
uniform vec3 highlight_tint : source_color = vec3(0.92, 0.99, 0.97);

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

	float fresnel = pow(1.0 - clamp(dot(n, to_camera), 0.0, 1.0), 3.5);
	vec3 half_vector = normalize(to_camera + to_sun);
	float sun_glint = pow(max(dot(n, half_vector), 0.0), 54.0);

	float wash = paint_field(world_position.xz * 0.55 + vec2(3.0, 4.0));
	float broken = smoothstep(0.56, 0.78, wash);
	float crest = smoothstep(0.013, 0.026, wave_height);
	float glint = sun_glint * broken;

	vec3 color = surface_tint * (0.95 + 0.07 * wash);
	color = mix(color, highlight_tint, clamp(glint * 0.52 + crest * 0.045, 0.0, 0.55));

	float alpha = 0.050 + 0.145 * fresnel + 0.050 * glint + 0.012 * crest;
	ALBEDO = color;
	ALPHA = clamp(alpha, 0.04, 0.24);
}
