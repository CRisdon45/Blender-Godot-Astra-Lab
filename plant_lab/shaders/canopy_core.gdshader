shader_type spatial;
// Opaque interior surface: no alpha sampling/discard, screen textures or ray marching.
// Original analytical proxy normals and packed painted masks; not tutorial assets.
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
    float transition = 1.0 - smoothstep(0.10, 0.30, abs(value - 0.53));
    value += (marks.r - 0.5) * 0.16 + marks.g * transition * 0.035;
    vec3 paint = mix(shadow_color.rgb, middle_color.rgb, smoothstep(0.30, 0.54, value));
    paint = mix(paint, light_color.rgb, smoothstep(0.69, 0.87, value));
    paint *= 1.0 + (marks.r - 0.5) * 0.055;
    NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
    ALBEDO = paint;
    EMISSION = paint * 0.86;
    ROUGHNESS = 1.0;
}
void light() {
    DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * 0.045;
}
