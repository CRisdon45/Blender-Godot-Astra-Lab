shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

// Restrained surface: depth story remains on submerged geometry. This layer adds
// motion, Fresnel presence and selective sun response. Broad pigment variation is
// shape-first, world-space and deterministic rather than hash-noise based.
uniform float visual_time = 0.0;
uniform vec3 sun_ray_dir = vec3(0.3796774, -0.8193039, 0.4296350);
uniform vec3 surface_tint : source_color = vec3(0.26, 0.69, 0.75);
uniform vec3 highlight_tint : source_color = vec3(0.91, 0.98, 0.96);
uniform float motion_scale = 1.0;
uniform float surface_strength = 1.0;

varying vec3 world_position;
varying vec3 world_normal;
varying float wave_height;
varying vec2 media;

float paint_field(vec2 p) {
	float warp = sin(dot(p, vec2(0.77, 0.31)) * 0.43 + 1.7);
	float a = sin(dot(p, vec2(-0.42, 0.91)) * 0.86 + warp * 0.88);
	float b = sin(dot(p, vec2(0.68, 0.73)) * 1.37 - warp * 0.54 + 2.2);
	float c = sin(dot(p, vec2(0.93, -0.36)) * 2.12 + 4.1);
	return clamp(0.50 + 0.20 * a + 0.12 * b + 0.065 * c, 0.0, 1.0);
}

void wave_sample(vec2 p, float t, out float h, out vec2 grad) {
	h = 0.0;
	grad = vec2(0.0);

	vec2 d0 = normalize(vec2(1.00, 0.24));
	vec2 d1 = normalize(vec2(-0.36, 1.00));
	vec2 d2 = normalize(vec2(0.74, -0.67));
	vec2 d3 = normalize(vec2(-0.86, -0.51));

	float p0 = dot(p, d0) * 3.25 + t * 1.05;
	float p1 = dot(p, d1) * 4.10 - t * 0.73;
	float p2 = dot(p, d2) * 5.70 + t * 0.56;
	float p3 = dot(p, d3) * 7.60 - t * 1.27;

	h += 0.020 * sin(p0);
	h += 0.013 * sin(p1);
	h += 0.008 * sin(p2);
	h += 0.005 * sin(p3);

	grad += d0 * (0.020 * 3.25 * cos(p0));
	grad += d1 * (0.013 * 4.10 * cos(p1));
	grad += d2 * (0.008 * 5.70 * cos(p2));
	grad += d3 * (0.005 * 7.60 * cos(p3));
}

void vertex() {
	float h;
	vec2 grad;
	float t = visual_time * motion_scale;
	wave_sample(VERTEX.xz, t, h, grad);

	VERTEX.y += h;
	NORMAL = normalize(vec3(-grad.x, 1.0, -grad.y));
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	wave_height = h;
	media = world_position.xz;
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 to_camera = normalize(CAMERA_POSITION_WORLD - world_position);
	vec3 to_sun = normalize(-sun_ray_dir);

	float fresnel = pow(1.0 - clamp(dot(n, to_camera), 0.0, 1.0), 3.6);
	vec3 half_vector = normalize(to_camera + to_sun);
	float sun_glint = pow(max(dot(n, half_vector), 0.0), 72.0);

	float wash = paint_field(media * 0.46 + vec2(2.0, 5.0));
	float reserve = smoothstep(0.66, 0.82, paint_field(media * 0.79 + vec2(-6.0, 8.0)));
	float crest = smoothstep(0.006, 0.028, wave_height + 0.018);
	float broken_glint = sun_glint * smoothstep(0.52, 0.74, wash) * (1.0 - reserve * 0.55);

	vec3 color = surface_tint;
	color *= 0.93 + 0.10 * wash;
	color = mix(color, highlight_tint, clamp(broken_glint * 0.72 + crest * 0.08, 0.0, 0.82));

	float alpha = 0.105 + 0.22 * fresnel + 0.10 * broken_glint;
	alpha += 0.025 * (wash - 0.5);
	alpha *= surface_strength;

	ALBEDO = color;
	ALPHA = clamp(alpha, 0.04, 0.46);
}
