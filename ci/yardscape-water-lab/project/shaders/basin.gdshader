shader_type spatial;
render_mode unshaded;

// Fast Northstar basin treatment. Depth comes from real geometry. Caustics are
// evaluated on receiving geometry from the same four-wave field as the surface.
// Instead of a per-pixel finite-difference refracted Jacobian, this candidate uses
// an analytic curvature/focusing proxy after one flat-surface Snell back-projection.
// The slower Jacobian experiment is retained under shaders/experiments/.
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

void wave_curvature(vec2 p, float t, vec2 travel_dir, out float laplacian, out float directional) {
	laplacian = 0.0;
	directional = 0.0;

	vec2 d0 = normalize(vec2(1.00, 0.24));
	vec2 d1 = normalize(vec2(-0.36, 1.00));
	vec2 d2 = normalize(vec2(0.74, -0.67));
	vec2 d3 = normalize(vec2(-0.86, -0.51));

	float p0 = dot(p, d0) * 3.25 + t * 1.05;
	float p1 = dot(p, d1) * 4.10 - t * 0.73;
	float p2 = dot(p, d2) * 5.70 + t * 0.56;
	float p3 = dot(p, d3) * 7.60 - t * 1.27;

	float c0 = -0.020 * 3.25 * 3.25 * sin(p0);
	float c1 = -0.013 * 4.10 * 4.10 * sin(p1);
	float c2 = -0.008 * 5.70 * 5.70 * sin(p2);
	float c3 = -0.005 * 7.60 * 7.60 * sin(p3);

	laplacian = c0 + c1 + c2 + c3;
	directional =
		c0 * pow(dot(d0, travel_dir), 2.0)
		+ c1 * pow(dot(d1, travel_dir), 2.0)
		+ c2 * pow(dot(d2, travel_dir), 2.0)
		+ c3 * pow(dot(d3, travel_dir), 2.0);
}

float floor_caustic(vec2 receiver, float depth) {
	vec3 flat_ray = refract(normalize(sun_ray_dir), vec3(0.0, 1.0, 0.0), 1.0 / 1.333);
	float travel = depth / max(-flat_ray.y, 0.08);
	vec2 surface_point = receiver - flat_ray.xz * travel;
	vec2 travel_dir = normalize(flat_ray.xz + vec2(0.00001));

	float laplacian;
	float directional;
	wave_curvature(surface_point, visual_time, travel_dir, laplacian, directional);

	// Curvature is an inexpensive proxy for local ray compression. The sign keeps
	// only converging regions, avoiding a glowing line on every wave crest/trough.
	float convergence = -depth * (directional * 0.72 + laplacian * 0.28) * 0.70;
	float focus = 1.0 / max(1.0 - convergence, 0.32);
	float band = smoothstep(1.12, 2.30, focus);

	// Painterly breakup prevents a mathematically uniform network while remaining
	// fixed in world coordinates and independent from viewport pixels.
	float breakup = 0.60 + 0.40 * broad_wash(surface_point * 0.86 + 23.0);
	float reserve = smoothstep(0.63, 0.78, broad_wash(surface_point * 1.23 + 51.0));
	band *= breakup * (1.0 - reserve * 0.42);
	band *= exp(-depth * 0.14);
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

	float light_amount = clamp(caustic * caustic_strength, 0.0, 0.44);
	color = mix(color, light_tint, light_amount);
	ALBEDO = color;
}
