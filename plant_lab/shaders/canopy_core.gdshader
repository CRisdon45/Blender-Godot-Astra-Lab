shader_type spatial;
// Recessed opaque support canopy. It closes accidental holes but must not become the visible plant.
render_mode specular_disabled, ambient_light_disabled;
uniform sampler2D paint_mask : repeat_enable, filter_linear_mipmap;
uniform vec3 sun_direction = vec3(-0.314, 0.743, 0.589);
uniform vec4 shadow_color : source_color;
uniform vec4 middle_color : source_color;
uniform vec4 light_color : source_color;
varying vec3 crown_normal;
void vertex() {
    crown_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
    vec2 marks = texture(paint_mask, UV).rg;
    vec3 n = normalize(crown_normal);
    float value = dot(n, normalize(sun_direction)) * 0.5 + 0.5;
    float transition = 1.0 - smoothstep(0.07, 0.22, min(abs(value - 0.43), abs(value - 0.70)));
    value += (marks.r - 0.5) * 0.32 + (marks.g - 0.5) * transition * 0.12;
    vec3 paint = mix(shadow_color.rgb, middle_color.rgb, smoothstep(0.38, 0.46, value));
    paint = mix(paint, light_color.rgb, smoothstep(0.67, 0.74, value));
    paint *= 0.92 + (marks.r - 0.5) * 0.035 + (marks.g - 0.5) * 0.040;
    NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
    ALBEDO = paint;
    EMISSION = paint * 0.86;
    ROUGHNESS = 1.0;
}
void light() {
    DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * 0.045;
}
