shader_type spatial;
// Controlled comparison receiver: a stable painted base with real sun shadow attenuation.
render_mode ambient_light_disabled, specular_disabled;
uniform vec4 ground_color : source_color = vec4(0.73, 0.68, 0.56, 1.0);
void fragment() {
    ALBEDO = ground_color.rgb;
    EMISSION = ground_color.rgb * 0.74;
    ROUGHNESS = 1.0;
}
void light() { DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * 0.08; }
