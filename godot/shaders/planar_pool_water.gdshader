shader_type spatial;
render_mode cull_back, depth_draw_never, ambient_light_disabled;
#include "res://shaders/water_detail_common.gdshaderinc"
uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
// Optical coefficients, not color swatches: do NOT apply sRGB decoding.
uniform vec3 absorption_per_metre = vec3(0.62, 0.125, 0.055);
uniform vec4 in_scatter : source_color = vec4(0.025,0.39,0.55,1.0);
uniform float surface_strength = 0.55; // Art-directed shading strength, independent of receiver focus.
uniform float scatter_illumination = 1.0;
uniform float water_time = 0.0;
uniform float water_level = 0.3225;
uniform float flow_strength = 1.0;
uniform int impact_count = 0;
uniform vec4 impact_segments[4];
uniform sampler2D planar_texture : repeat_disable, filter_linear; // Linear HDR, no source_color.
uniform mat4 reflection_view_projection;
uniform bool planar_enabled = false;
uniform float reflection_distortion = 0.016;
uniform int debug_view = 0; // 1 depth, 2 transmitted, 3 reflected, 4 raw opaque receiver.
varying vec3 world_position;
varying vec3 face_normal;

vec3 view_position(vec2 uv, mat4 inverse_projection) {
	float z = texture(scene_depth,uv).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv,z)*2.0-1.0;
#else
	vec3 ndc = vec3(uv*2.0-1.0,z);
#endif
	vec4 point = inverse_projection*vec4(ndc,1.0);
	return point.xyz/point.w;
}
void vertex() {
	world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	face_normal = normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
	// The legacy asset is a thin closed box. Render only its top, not two
	// refracting layers and four artificial blue side walls.
	if (face_normal.y < 0.8) { discard; }
	vec2 slope = detail_field(world_position.xz,water_time).xy*surface_strength;
	float foam = 0.0;
	for (int i=0;i<4;i++) {
		if (i>=impact_count) { break; }
		vec4 span = impact_segments[i];
		vec2 axis = span.zw-span.xy;
		float along = clamp(dot(world_position.xz-span.xy,axis)/max(dot(axis,axis),0.00001),0.0,1.0);
		vec2 offset = world_position.xz-(span.xy+axis*along);
		float distance_to_sheet = length(offset);
		float envelope = exp(-distance_to_sheet*2.8)*(1.0-smoothstep(0.6,1.5,distance_to_sheet));
		float phase = distance_to_sheet*23.0-water_time*5.1+detail_noise(world_position.xz*3.0)*1.1;
		slope += offset/max(distance_to_sheet,0.002)*cos(phase)*envelope*0.038*flow_strength;
		float breakup = smoothstep(0.28,0.78,detail_noise(vec2(along*28.0-water_time*0.8,distance_to_sheet*20.0+water_time*1.3)));
		foam = max(foam,(1.0-smoothstep(0.022,0.18,distance_to_sheet))*breakup*flow_strength);
	}
	vec3 n_world = normalize(vec3(-slope.x,1.0,-slope.y));
	vec3 n_view = normalize((VIEW_MATRIX*vec4(n_world,0.0)).xyz);
	vec3 receiver = view_position(SCREEN_UV,INV_PROJECTION_MATRIX);
	float path_length = max(0.0,length(receiver-VERTEX));
	vec2 shift = (VIEW_MATRIX*vec4(-slope.x,0.0,-slope.y,0.0)).xy;
	vec2 refracted_uv = SCREEN_UV + shift*min(path_length,2.5)*0.026;
	vec3 refracted_receiver = view_position(clamp(refracted_uv,vec2(0.001),vec2(0.999)),INV_PROJECTION_MATRIX);
	vec3 receiver_world = (INV_VIEW_MATRIX*vec4(refracted_receiver,1.0)).xyz;
	// Reject displaced samples on coping/chairs above the plane and at screen edges.
	bool valid_uv = all(greaterThan(refracted_uv,vec2(0.001))) && all(lessThan(refracted_uv,vec2(0.999)));
	if (!valid_uv || receiver_world.y>water_level+0.002 || refracted_receiver.z>VERTEX.z) {
		refracted_uv = SCREEN_UV;
		refracted_receiver = receiver;
		receiver_world = (INV_VIEW_MATRIX*vec4(receiver,1.0)).xyz;
	}
	path_length = clamp(length(refracted_receiver-VERTEX),0.0,12.0);
	vec3 transmittance = exp(-absorption_per_metre*path_length);
	vec3 transmitted = textureLod(scene_color,refracted_uv,0.0).rgb*transmittance + in_scatter.rgb*scatter_illumination*(vec3(1.0)-transmittance);
	float fresnel = 0.02037+(1.0-0.02037)*pow(1.0-clamp(dot(n_view,VIEW),0.0,1.0),5.0);
	// Project the actual point on the plane through the reflected camera.
	// Camera projection is CPU/Y-up; viewport texture is top-left/Y-down.
	vec4 projected = reflection_view_projection*vec4(world_position,1.0);
	vec2 reflected_uv = projected.xy / max(projected.w,0.0001) * vec2(0.5,-0.5) + vec2(0.5);
	vec2 distortion = vec2(dot(slope,vec2(0.83,0.56)),dot(slope,vec2(-0.56,0.83)))*reflection_distortion;
	vec2 sample_uv = reflected_uv+distortion;
	// Avoid edge smear: fade distortion before clamping to the real texture.
	vec2 border = min(reflected_uv,vec2(1.0)-reflected_uv);
	float safe_edge = smoothstep(0.0,0.025,min(border.x,border.y));
	sample_uv = clamp(reflected_uv+distortion*safe_edge,vec2(0.001),vec2(0.999));
	vec3 reflected = texture(planar_texture,sample_uv).rgb;
	bool reflection_valid = planar_enabled && projected.w>0.0;
	float reflection_weight = reflection_valid ? fresnel : 0.0;
	// Both inputs are already-lit linear HDR. Combine once before main tonemapping.
	NORMAL=n_view;
	ALBEDO=vec3(0.72,0.85,0.84)*foam*0.38;
	EMISSION=(transmitted*(1.0-reflection_weight)+reflected*reflection_weight)*(1.0-foam*0.38);
	ROUGHNESS=mix(0.08,0.32,foam);
	SPECULAR=0.0; // Do not add a second sky/probe reflection over the planar result.
	METALLIC=0.0;
	if (debug_view==1) {
		ALBEDO=vec3(0.0);
		EMISSION=mix(vec3(0.95,0.74,0.26),vec3(0.06,0.20,0.65),clamp((water_level-receiver_world.y)/1.0,0.0,1.0));
		SPECULAR=0.0;
	} else if (debug_view==2) {
		ALBEDO=vec3(0.0); EMISSION=transmitted; SPECULAR=0.0; ROUGHNESS=1.0;
	} else if (debug_view==3) {
		ALBEDO=vec3(0.0); EMISSION=reflection_valid ? reflected : vec3(0.0);
	} else if (debug_view==4) {
		ALBEDO=vec3(0.0); EMISSION=textureLod(scene_color,SCREEN_UV,0.0).rgb;
		SPECULAR=0.0; ROUGHNESS=1.0;
	}
}
