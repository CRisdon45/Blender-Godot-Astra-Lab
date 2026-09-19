shader_type spatial;
render_mode unshaded;

// Submerged geometry carries the depth story. Caustics are evaluated on the
// receiver, back-projecting toward the moving surface and estimating local
// refracted-ray concentration. This keeps them coherent with the surface wave
// field and avoids the old static Voronoi/cellular net.
uniform float visual_time = 0.0;
uniform float water_level = 0.0;
uniform vec3 sun_ray_dir = vec3(0.3796774, -0.8193039, 0.4296350);
uniform bool caustics_enabled = true;
uniform float caustic_strength = 0.55;
uniform vec3 shallow_color : source_color = vec3(0.52, 0.82, 0.81);
uniform vec3 deep_color : source_color = vec3(0.08, 0.49, 0.61);
uniform vec3 wall_shallow : source_color = vec3(0.66, 0.84, 0.82);
uniform vec3 wall_deep : source_color = vec3(0.16, 0.54, 0.62);
uniform vec3 light_tint : source_color = vec3(0.90, 0.98, 0.94);

varying vec3 world_position;
varying vec3 world_normal;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

float broad_wash(vec2 p) {
	return 0.62 * value_noise(p)
		+ 0.27 * value_noise(p * 2.03 + 11.0)
		+ 0.11 * value_noise(p * 4.07 + 29.0);
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

vec3 water_normal(vec2 p) {
	float h;
	vec2 grad;
	wave_sample(p, visual_time, h, grad);
	return normalize(vec3(-grad.x, 1.0, -grad.y));
}

vec2 refracted_receiver(vec2 surface_point, float depth) {
	vec3 n = water_normal(surface_point);
	vec3 ray = refract(normalize(sun_ray_dir), n, 1.0 / 1.333);
	float distance_to_receiver = depth / max(-ray.y, 0.08);
	return surface_point + ray.xz * distance_to_receiver;
}

vec2 find_surface_for_receiver(vec2 receiver, float depth) {
	vec2 surface_point = receiver
		- sun_ray_dir.xz * depth / max(-sun_ray_dir.y, 0.08);

	// Two fixed-point corrections are enough for this shallow pool and keep
	// runtime predictable. The lab can raise this later only if images justify it.
	for (int i = 0; i < 2; i++) {
		vec2 mapped = refracted_receiver(surface_point, depth);
		surface_point += (receiver - mapped) * 0.88;
	}
	return surface_point;
}

float floor_caustic(vec2 receiver, float depth) {
	vec2 surface_point = find_surface_for_receiver(receiver, depth);
	float eps = 0.0275;

	vec2 m0 = refracted_receiver(surface_point, depth);
	vec2 mx = refracted_receiver(surface_point + vec2(eps, 0.0), depth);
	vec2 mz = refracted_receiver(surface_point + vec2(0.0, eps), depth);

	vec2 dx = (mx - m0) / eps;
	vec2 dz = (mz - m0) / eps;
	float jacobian = abs(dx.x * dz.y - dx.y * dz.x);
	float focus = 1.0 / max(jacobian, 0.20);

	float band = smoothstep(1.08, 2.15, focus);
	band *= 0.62 + 0.38 * broad_wash(surface_point * 0.82 + 23.0);
	band *= exp(-depth * 0.18);
	return band;
}

float wall_caustic(vec2 p, float depth) {
	float a = sin(p.x * 4.2 + visual_time * 1.00 + sin(p.y * 1.4) * 0.8);
	float b = sin(p.x * 6.1 - visual_time * 0.72 - p.y * 2.6);
	float c = sin(p.x * 2.7 + visual_time * 0.44 + p.y * 3.7);
	float signal = (a + 0.72 * b + 0.48 * c) / 2.20;
	float width = 0.11 + fwidth(signal) * 1.4;
	float ribbon = 1.0 - smoothstep(width, width + 0.18, abs(signal));
	ribbon *= 0.46 + 0.54 * broad_wash(p * 0.74 + 37.0);
	ribbon *= exp(-depth * 0.22);
	return ribbon;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	float depth = max(0.0, water_level - world_position.y);
	vec3 n = normalize(world_normal);
	bool horizontal = abs(n.y) > 0.55;

	float depth_mix = smoothstep(0.16, 1.58, depth);
	vec3 horizontal_color = mix(shallow_color, deep_color, depth_mix);
	vec3 vertical_color = mix(wall_shallow, wall_deep, depth_mix);
	vec3 color = horizontal ? horizontal_color : vertical_color;

	vec2 plan = world_position.xz;
	float wash = broad_wash(plan * 0.40 + vec2(7.0, 13.0));
	float reserve = smoothstep(0.56, 0.76, broad_wash(plan * 0.67 + 31.0));
	color *= 0.91 + 0.13 * wash;
	color = mix(color, color * vec3(0.92, 0.97, 0.98), reserve * 0.24);

	float caustic = 0.0;
	if (caustics_enabled && depth > 0.03) {
		if (horizontal) {
			caustic = floor_caustic(plan, depth);
		} else {
			vec2 wall_p = abs(n.x) > 0.55
				? vec2(world_position.z, depth)
				: vec2(world_position.x, depth);
			caustic = wall_caustic(wall_p, depth) * 0.72;
		}
	}

	// Northstar target: readable concentrated light, not a white neon net.
	float light_amount = clamp(caustic * caustic_strength, 0.0, 0.48);
	color = mix(color, light_tint, light_amount);

	ALBEDO = color;
}
