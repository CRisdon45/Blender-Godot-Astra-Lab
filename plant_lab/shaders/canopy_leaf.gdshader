shader_type spatial;
// Opaque visible foliage. Broad color blocks communicate volume without photoreal detail.
// Brush silhouettes are geometry; cull-disabled makes the small fixed 3D strokes readable
// from either side without alpha discard or camera-facing billboarding.
render_mode cull_disabled, specular_disabled, ambient_light_disabled;
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
    float top = smoothstep(0.10, 0.72, n.y);
    float bottom = smoothstep(0.12, 0.72, -n.y);
    float boundary = 1.0 - smoothstep(0.07, 0.21, min(abs(value - 0.44), abs(value - 0.71)));
    value += top * 0.085 - bottom * 0.070;
    value += (marks.r - 0.5) * 0.22 + (marks.g - 0.5) * boundary * 0.08;
    vec3 paint = mix(shadow_color.rgb, middle_color.rgb, smoothstep(0.37, 0.48, value));
    paint = mix(paint, light_color.rgb, smoothstep(0.68, 0.79, value));
    paint *= 0.965 + top * 0.050 - bottom * 0.035 + (marks.r - 0.5) * 0.035;
    NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
    ALBEDO = paint;
    EMISSION = paint * 0.86;
    ROUGHNESS = 1.0;
}
void light() {
    DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * 0.045;
}
