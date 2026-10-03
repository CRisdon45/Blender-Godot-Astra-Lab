shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;

uniform float time_seconds = 0.0;
uniform float wind_strength = 0.0;
uniform bool blossom = false;
varying vec3 local_position;

void vertex() {
    local_position = VERTEX;
    float weight = smoothstep(1.6, 6.7, VERTEX.y);
    float branch_phase = VERTEX.x * 0.63 + VERTEX.z * 0.44;
    VERTEX.x += sin(time_seconds * 0.9 + branch_phase) * weight * wind_strength;
    VERTEX.z += sin(time_seconds * 0.7 + branch_phase * 0.6) * weight * wind_strength * 0.4;
}

void fragment() {
    ALBEDO = COLOR.rgb;
    ROUGHNESS = 0.95;
    SPECULAR = 0.0;
    // Small constant fill keeps clustered foliage readable, while real shadows
    // and normals supply all directional shading. No baked sunlight in color.
    EMISSION = COLOR.rgb * (blossom ? 0.065 : 0.025);
}

void light() {
    float facing = dot(NORMAL, LIGHT);
    float wrap = clamp((facing + 0.35) / 1.35, 0.0, 1.0);
    float soft_band = mix(wrap, smoothstep(0.2, 0.75, wrap), 0.3);
    DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * soft_band / PI;
}
