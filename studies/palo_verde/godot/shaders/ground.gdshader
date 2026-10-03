shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
varying vec3 world_position;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    float wash = sin(world_position.x * 0.17 + sin(world_position.z * 0.13))
               * cos(world_position.z * 0.24) * 0.5 + 0.5;
    ALBEDO = mix(vec3(0.18, 0.24, 0.065), vec3(0.29, 0.35, 0.11), wash);
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}
