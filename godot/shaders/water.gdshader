shader_type spatial;
render_mode cull_disabled;
uniform vec4 shallow_color : source_color = vec4(0.23, 0.68, 0.79, 1.0);
uniform vec4 deep_color : source_color = vec4(0.025, 0.43, 0.62, 1.0);
uniform float water_time = 0.0;
uniform float flow_strength : hint_range(0.0, 1.0) = 0.0;
uniform float water_level = 0.3225;
uniform int impact_count = 0;
// Each vec4 is the two XZ endpoints of a sheet/pool contact span, in world space.
uniform vec4 impact_segments[4];
varying vec3 p;
varying vec3 world_normal;

vec2 hash2(vec2 v) {
	return fract(sin(vec2(dot(v, vec2(127.1, 311.7)), dot(v, vec2(269.5, 183.3)))) * 43758.5453);
}

float cells(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	float a = 8.0;
	float b = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 n = vec2(float(x), float(y));
			vec2 point = hash2(i + n);
			point = 0.5 + 0.36 * sin(water_time * 0.6 + 6.2831 * point);
			float d = length(n + point - f);
			if (d < a) { b = a; a = d; } else if (d < b) { b = d; }
		}
	}
	return 1.0 - smoothstep(0.015, 0.07, b - a);
}

void vertex() {
	p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	// Keep the original small background motion; contact ripples do not need tessellation.
	VERTEX.y += sin(p.x * 6.0 + p.z * 7.0 + water_time) * 0.007;
}

void fragment() {
	vec2 uv = p.xz;
	float caustic = cells(uv * 3.3 + vec2(sin(uv.y * 4.0 + water_time) * 0.1, cos(uv.x * 3.0 + water_time) * 0.1));
	float fine = pow(max(0.0, sin(uv.y * 43.0 + sin(uv.x * 5.0 + uv.y * 3.0) * 4.0 + sin(uv.x * 18.0 + water_time) * 1.4 + water_time * 1.2)), 12.0);
	// Existing art-directed shelf gradient, NOT a measured depth reconstruction.
	float shallow = smoothstep(-0.2, 1.2, p.z);
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, 0.35 + shallow * 0.6);
	col = mix(col, vec3(0.61, 0.87, 0.91), caustic * 0.20 + fine * 0.045);
	float top = smoothstep(0.6, 0.98, world_normal.y) * smoothstep(water_level - 0.04, water_level - 0.002, p.y);
	float foam = 0.0;
	float rings = 0.0;
	vec2 slope = vec2(0.0);
	for (int index = 0; index < 4; index++) {
		if (index >= impact_count) { break; }
		vec4 span = impact_segments[index];
		vec2 axis = span.zw - span.xy;
		float along = clamp(dot(uv - span.xy, axis) / max(dot(axis, axis), 0.000001), 0.0, 1.0);
		vec2 offset = uv - (span.xy + axis * along);
		float distance_to_sheet = length(offset);
		vec2 direction = offset / max(distance_to_sheet, 0.001);
		float envelope = exp(-distance_to_sheet * 2.1) * (1.0 - smoothstep(0.8, 1.6, distance_to_sheet));
		float phase = distance_to_sheet * 14.0 - water_time * 3.2;
		float wave = sin(phase);
		// A restrained contact band, not a pool-wide white particle cloud.
		float pulse = 0.88 + 0.12 * sin(water_time * 3.2 + along * 6.2831);
		foam = max(foam, (1.0 - smoothstep(0.025, 0.13, distance_to_sheet)) * pulse);
		rings += smoothstep(0.75, 1.0, wave) * envelope;
		slope += direction * cos(phase) * envelope * 0.09;
	}
	float response = clamp(flow_strength, 0.0, 1.0) * top;
	col = mix(col, vec3(0.75, 0.91, 0.92), clamp(foam * 0.55 + rings * 0.10, 0.0, 0.65) * response);
	vec3 background = vec3(sin(uv.x * 14.0 + uv.y * 8.0 + water_time) * 0.08, 0.0, cos(uv.y * 19.0 + water_time) * 0.08);
	vec3 normal_world = normalize(world_normal + background * top + vec3(-slope.x, 0.0, -slope.y) * response);
	// Fragment NORMAL is view-space. World-space slopes must be transformed with it.
	NORMAL = normalize((VIEW_MATRIX * vec4(normal_world, 0.0)).xyz);
	ALBEDO = col;
	ROUGHNESS = mix(0.22, 0.38, foam * response);
	SPECULAR = 0.65;
	METALLIC = 0.08;
}
