shader_type spatial;
render_mode unshaded;

// Coherent curvature-caustic study.
// The same four analytic waves used by the surface define local curvature here.
// A cheap refracted travel direction turns that curvature into a receiver-side
// concentration cue. No scrolling caustic texture and no cellular/Voronoi net.
uniform float visual_time = 0.0;
uniform float water_level = 0.0;
uniform bool caustics_enabled = true;
uniform vec3 sun_ray_dir = vec3(0.3796774, -0.8193039, 0.4296350);
uniform vec3 shallow_color : source_color = vec3(0.51, 0.82, 0.82);
uniform vec3 deep_color : source_color = vec3(0.065, 0.43, 0.57);
uniform vec3 light_tint : source_color = vec3(0.91, 0.98, 0.95);

varying vec3 world_position;

float tri(float x) {
	float f = abs(fract(x) - 0.5) * 2.0;
	return f * f * (3.0 - 2.0 * f);
}

float paint_field(vec2 p) {
	float a = tri(dot(p, vec2(0.77, 0.31)) * 0.19 + 0.13);
	float b = tri(dot(p, vec2(-0.42, 0.91)) * 0.27 + a * 0.17 + 0.37);
	float c = tri(dot(p, vec2(0.68, 0.73)) * 0.43 - b * 0.13 + 0.71);
	return clamp(0.16 + 0.44 * a + 0.28 * b + 0.12 * c, 0.0, 1.0);
}

void wave_curvature(vec2 p, float t, vec2 travel_dir, out float laplacian, out float directional) {
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

	float c0 = -0.017 * k0 * k0 * sin(p0);
	float c1 = -0.010 * k1 * k1 * sin(p1);
	float c2 = -0.0055 * k2 * k2 * sin(p2);
	float c3 = -0.0035 * k3 * k3 * sin(p3);

	laplacian = c0 + c1 + c2 + c3;
	directional =
		c0 * pow(dot(d0, travel_dir), 2.0)
		+ c1 * pow(dot(d1, travel_dir), 2.0)
		+ c2 * pow(dot(d2, travel_dir), 2.0)
		+ c3 * pow(dot(d3, travel_dir), 2.0);
}

float caustic_field(vec2 receiver, float depth) {
	vec3 flat_ray = refract(normalize(sun_ray_dir), vec3(0.0, 1.0, 0.0), 1.0 / 1.333);
	float travel = depth / max(-flat_ray.y, 0.08);
	vec2 surface_point = receiver - flat_ray.xz * travel;
	vec2 travel_dir = normalize(flat_ray.xz + vec2(0.00001));

	float laplacian;
	float directional;
	wave_curvature(surface_point, visual_time, travel_dir, laplacian, directional);

	float curvature = -(directional * 0.72 + laplacian * 0.28);
	float scaled = curvature * (0.48 + depth * 0.42);

	// Stylized caustic ribbons: two soft iso-curvature bands extracted from the
	// physically motivated convergence field. They keep the wave interference
	// shape without turning the pool into a cellular or crosshatched net.
	float ribbon_a = 1.0 - smoothstep(0.020, 0.064, abs(scaled - 0.15));
	float ribbon_b = 1.0 - smoothstep(0.018, 0.056, abs(scaled - 0.31));
	float concentrated = max(ribbon_a, ribbon_b * 0.58);

	// Stronger but much sparser art direction: caustics survive only in selected
	// world-space passages. This preserves coherent curvature while avoiding a
	// continuous procedural net across the whole basin.
	float broad = paint_field(surface_point * 0.72 + vec2(7.0, 3.0));
	float gate_a = smoothstep(0.60, 0.77,
		paint_field(surface_point * 0.96 + vec2(-2.0, 12.0)));
	float gate_b = 1.0 - smoothstep(0.78, 0.91,
		paint_field(surface_point * 1.41 + vec2(-11.0, 1.0)));
	float gate_c = smoothstep(0.52, 0.69,
		paint_field(surface_point * 1.18 + vec2(4.0, -7.0)));
	float fragments = gate_a * gate_c * mix(0.46, 1.0, gate_b);
	float breakup = 0.50 + 0.50 * broad;
	float shallow_control = mix(0.58, 1.0, smoothstep(0.25, 0.72, depth));
	concentrated *= breakup * fragments * shallow_control;
	concentrated *= exp(-depth * 0.12);
	return concentrated;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float depth = max(0.0, water_level - world_position.y);
	float depth_mix = smoothstep(0.10, 1.58, depth);
	vec3 color = mix(shallow_color, deep_color, depth_mix);

	vec2 p = world_position.xz;
	float wash = paint_field(p * 0.43 + vec2(2.0, 6.0));
	float reserve = smoothstep(0.68, 0.84, paint_field(p * 0.71 + vec2(-7.0, 4.0)));
	color *= 0.91 + 0.12 * wash;
	color = mix(color, color * vec3(0.93, 0.98, 1.00), reserve * 0.18);

	if (caustics_enabled && depth > 0.03) {
		float light = caustic_field(p, depth) * 0.44;
		color = mix(color, light_tint, clamp(light, 0.0, 0.30));
	}

	ALBEDO = color;
}
