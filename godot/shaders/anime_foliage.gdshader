shader_type spatial;
// Opaque alpha-cut geometry: stable depth, no blended leaf sorting.
render_mode cull_disabled, specular_disabled, ambient_light_disabled;
uniform sampler2D brush_atlas : repeat_disable, filter_linear_mipmap;
// Default preserves the approved daytime study. Hero lighting can dim painted light.
uniform float paint_illumination : hint_range(0.0, 2.0) = 1.0;
uniform vec3 sun_direction = vec3(-0.314, 0.743, 0.589);
uniform vec4 shadow_color : source_color = vec4(0.18, 0.29, 0.18, 1.0);
uniform vec4 middle_color : source_color = vec4(0.36, 0.48, 0.23, 1.0);
uniform vec4 light_color : source_color = vec4(0.58, 0.64, 0.34, 1.0);
varying vec3 crown_normal;
varying float brush_variant;
varying float local_shade;
void vertex() {
    // Blender's exporter flips V on both UV sets. UV2 stores physical width/height.
    vec2 offset = vec2(UV.x - 0.5, 0.5 - UV.y) * UV2;
    vec3 center = VERTEX - vec3(offset, 0.0);
    vec3 world_center = (MODEL_MATRIX * vec4(center, 1.0)).xyz;
    vec3 right = normalize(MAIN_CAM_INV_VIEW_MATRIX[0].xyz);
    vec3 up = normalize(MAIN_CAM_INV_VIEW_MATRIX[1].xyz);
    vec3 world_position = world_center + right * offset.x + up * offset.y;
    VERTEX = (inverse(MODEL_MATRIX) * vec4(world_position, 1.0)).xyz;
    crown_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
    brush_variant = floor(COLOR.r * 7.0 + 0.5);
    local_shade = COLOR.g;
}
void fragment() {
    vec2 tile = vec2(mod(brush_variant, 4.0), floor(brush_variant / 4.0));
    vec2 atlas_uv = (tile + clamp(UV, vec2(0.008), vec2(0.992))) / vec2(4.0, 2.0);
    if (texture(brush_atlas, atlas_uv).a < 0.5) { discard; }
    vec3 n = normalize(crown_normal);
    // Calm three-value masses, not per-card random color or leaf-normal highlights.
    float value = dot(n, normalize(sun_direction)) * 0.5 + 0.5;
    value += (local_shade - 0.5) * 0.065;
    vec3 paint = mix(shadow_color.rgb, middle_color.rgb, smoothstep(0.33, 0.43, value));
    paint = mix(paint, light_color.rgb, smoothstep(0.70, 0.78, value));
    NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
    ALBEDO = paint;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
    // Mostly authored paint, with restrained real shadow response. Casts real shadows.
    EMISSION = paint * 0.82 * paint_illumination;
}
void light() {
    DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * 0.12;
}
