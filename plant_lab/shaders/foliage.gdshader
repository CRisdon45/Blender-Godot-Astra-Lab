shader_type spatial;
// Same fixed-3D-centre brush construction as the courtyard study.
// No blended alpha, screen/normal texture, compute shader, or Forward+ feature.
render_mode cull_disabled, specular_disabled, ambient_light_disabled;
uniform sampler2D brush_atlas : repeat_disable, filter_linear_mipmap;
uniform vec3 sun_direction = vec3(-0.314, 0.743, 0.589);
uniform vec4 shadow_color : source_color;
uniform vec4 middle_color : source_color;
uniform vec4 light_color : source_color;
uniform bool flower_layer = false;
uniform float bloom : hint_range(0.0, 1.0) = 0.0;
varying vec3 crown_normal;
varying float variant;
varying float local_shade;
varying float rank;
void vertex() {
    vec2 offset = vec2(UV.x - 0.5, 0.5 - UV.y) * UV2;
    vec3 center = VERTEX - vec3(offset, 0.0);
    vec3 world_center = (MODEL_MATRIX * vec4(center, 1.0)).xyz;
    vec3 right = normalize(MAIN_CAM_INV_VIEW_MATRIX[0].xyz);
    vec3 up = normalize(MAIN_CAM_INV_VIEW_MATRIX[1].xyz);
    // Runtime instances use rotation and translation, never unaccounted mesh scaling.
    vec3 world_position = world_center + right * offset.x + up * offset.y;
    VERTEX = (inverse(MODEL_MATRIX) * vec4(world_position, 1.0)).xyz;
    crown_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
    variant = floor(COLOR.r * 3.0 + 0.5);
    local_shade = COLOR.g;
    rank = COLOR.b;
}
void fragment() {
    if (flower_layer && rank >= bloom) { discard; }
    vec2 atlas_uv = vec2((variant + clamp(UV.x, 0.012, 0.988)) / 4.0, clamp(UV.y, 0.012, 0.988));
    vec4 brush = texture(brush_atlas, atlas_uv);
    if (brush.a < 0.5) { discard; }
    vec3 n = normalize(crown_normal);
    float value = dot(n, normalize(sun_direction)) * 0.5 + 0.5 + (local_shade-0.5)*0.06;
    vec3 paint = mix(shadow_color.rgb, middle_color.rgb, smoothstep(0.33, 0.43, value));
    paint = mix(paint, light_color.rgb, smoothstep(0.70, 0.78, value));
    paint *= 1.0 - brush.g * 0.10;
    NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
    ALBEDO = paint;
    EMISSION = paint * 0.82;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}
void light() {
    DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * 0.12;
}
