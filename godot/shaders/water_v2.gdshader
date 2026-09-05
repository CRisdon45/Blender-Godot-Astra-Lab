shader_type spatial;
render_mode cull_back, depth_draw_never;
#include "res://shaders/water_v2_common.gdshaderinc"
uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
// Optical coefficients, not color swatches: do NOT apply sRGB decoding.
uniform vec3 absorption_per_metre = vec3(0.62, 0.125, 0.055);
uniform vec4 in_scatter : source_color = vec4(0.025,0.39,0.55,1.0);
uniform float surface_strength = 0.35; // Art-directed shading strength, independent of receiver focus.
uniform float scatter_illumination = 1.0;
uniform float water_time = 0.0;
uniform float water_level = 0.3225;
uniform float flow_strength = 1.0;
uniform int impact_count = 0;
uniform vec4 impact_segments[4];
uniform sampler2D planar_color : repeat_disable, filter_linear;
uniform mat4 planar_view_projection;
uniform bool planar_enabled = true;
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
	vec2 slope = v2_slope(world_position.xz,water_time)*surface_strength;
	float foam = 0.0;
	for (int i=0;i<4;i++) {
		if (i>=impact_count) { break; }
		vec4 span = impact_segments[i];
		vec2 axis = span.zw-span.xy;
		float along = clamp(dot(world_position.xz-span.xy,axis)/max(dot(axis,axis),0.00001),0.0,1.0);
		vec2 offset = world_position.xz-(span.xy+axis*along);
		float distance_to_sheet = length(offset);
		float envelope = exp(-distance_to_sheet*2.8)*(1.0-smoothstep(0.6,1.5,distance_to_sheet));
		float phase = distance_to_sheet*19.0-water_time*3.7;
		slope += offset/max(distance_to_sheet,0.002)*cos(phase)*envelope*0.055*flow_strength;
		float breakup = 0.30+0.70*v2_noise(vec2(along*11.7,water_time*1.9));
		foam = max(foam,(1.0-smoothstep(0.012,0.19,distance_to_sheet))*breakup*flow_strength);
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
    // Project this actual world point into the mirrored camera, not a static probe.
    // Godot camera projection has +Y up; viewport textures have +Y down.
    vec3 reflected_point=world_position+vec3(-slope.x,0.0,-slope.y)*0.65;
    vec4 reflected_clip=planar_view_projection*vec4(reflected_point,1.0);
    vec2 reflected_uv=reflected_clip.xy/max(reflected_clip.w,0.00001)*vec2(0.5,-0.5)+0.5;
    bool reflected_valid=reflected_clip.w>0.0 && all(greaterThan(reflected_uv,vec2(0.002))) && all(lessThan(reflected_uv,vec2(0.998)));
    vec3 reflected=texture(planar_color,clamp(reflected_uv,vec2(0.002),vec2(0.998))).rgb;
    // Replace environment radiance only. Godot still applies dielectric Fresnel and sun.
    RADIANCE=vec4(reflected,(planar_enabled && reflected_valid)?1.0:0.0);
	// The screen sample is already lit. EMISSION avoids lighting it a second time.
	// Ordinary dielectric specular still supplies sky/probe and sun reflections.
	NORMAL = n_view;
	ALBEDO = vec3(0.0);
	EMISSION = transmitted*(1.0-fresnel)*(1.0-foam*0.5);
	ALBEDO += vec3(0.72,0.85,0.84)*foam*0.5;
	ROUGHNESS = mix(0.06,0.32,foam);
	SPECULAR = 0.25;
	METALLIC = 0.0;
	if (debug_view==1) {
		ALBEDO=vec3(0.0);
		EMISSION=mix(vec3(0.95,0.74,0.26),vec3(0.06,0.20,0.65),clamp((water_level-receiver_world.y)/1.0,0.0,1.0));
		SPECULAR=0.0;
	} else if (debug_view==2) {
		ALBEDO=vec3(0.0); EMISSION=transmitted; SPECULAR=0.0; ROUGHNESS=1.0;
	} else if (debug_view==3) {
		ALBEDO=vec3(0.0); EMISSION=vec3(0.0);
	} else if (debug_view==4) {
		ALBEDO=vec3(0.0); EMISSION=textureLod(scene_color,SCREEN_UV,0.0).rgb;
		SPECULAR=0.0; ROUGHNESS=1.0;
	}
}
