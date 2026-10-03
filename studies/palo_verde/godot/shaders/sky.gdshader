shader_type sky;

vec3 linear_color(vec3 color) {
    return mix(color / 12.92, pow((color + 0.055) / 1.055, vec3(2.4)),
               step(vec3(0.04045), color));
}

void sky() {
    float height = clamp(EYEDIR.y, 0.0, 1.0);
    vec3 horizon = vec3(0.69, 0.81, 0.88);
    vec3 zenith = vec3(0.23, 0.49, 0.78);
    COLOR = linear_color(mix(horizon, zenith, pow(height, 0.48)));
    // Fixed, broad, quiet cloud wisps; no image textures or frame-random noise.
    vec2 p = EYEDIR.xz / max(0.18, EYEDIR.y + 0.35);
    float cloud = sin(p.x * 3.7 + sin(p.y * 2.6)) * cos(p.y * 3.4);
    cloud = smoothstep(0.62, 0.94, cloud) * smoothstep(0.03, 0.22, height);
    COLOR = mix(COLOR, linear_color(vec3(0.9, 0.94, 0.95)), cloud * 0.35);
}
