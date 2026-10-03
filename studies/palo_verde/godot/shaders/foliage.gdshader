shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform float time_seconds = 0.0;
uniform float wind_strength = 0.0;
uniform bool blossom = false;
uniform bool woody = false;

void vertex() {
    // Shared spatial field keeps branches and their attached sprays together.
    float weight = smoothstep(1.6, 7.8, VERTEX.y);
    float branch_phase = VERTEX.x * 0.43 + VERTEX.z * 0.31;
    VERTEX.x += sin(time_seconds * 0.9 + branch_phase) * weight * wind_strength;
    VERTEX.z += sin(time_seconds * 0.7 + branch_phase * 0.6) * weight * wind_strength * 0.4;
}

void fragment() {
    vec3 base = COLOR.rgb;
    if (OUTPUT_IS_SRGB) {
        base = mix(base * 12.92, 1.055 * pow(max(base, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055,
                   step(vec3(0.0031308), base));
    }
    if (!FRONT_FACING) {
        NORMAL = -NORMAL;
    }
    ALBEDO = base;
    ROUGHNESS = woody ? 0.82 : 0.88;
    SPECULAR = woody ? 0.22 : 0.14;
    // Thin petals/leaflets receive transmitted light instead of constant emission.
    BACKLIGHT = woody ? vec3(0.0) : base * (blossom ? 0.18 : 0.16);
}
