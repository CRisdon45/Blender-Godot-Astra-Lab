shader_type spatial;
render_mode specular_disabled, ambient_light_disabled;
uniform vec3 sun_direction = vec3(-0.314, 0.743, 0.589);
uniform vec4 shadow_color : source_color;
uniform vec4 middle_color : source_color;
uniform vec4 light_color : source_color;
varying vec3 world_normal;
void vertex() { world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL); }
void fragment() {
    float value = dot(normalize(world_normal), normalize(sun_direction)) * 0.5 + 0.5;
    vec3 paint = mix(shadow_color.rgb, middle_color.rgb, smoothstep(0.30, 0.43, value));
    paint = mix(paint, light_color.rgb, smoothstep(0.72, 0.79, value));
    ALBEDO = paint; EMISSION = paint * 0.70; ROUGHNESS = 1.0;
}
void light() { DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * 0.20; }
