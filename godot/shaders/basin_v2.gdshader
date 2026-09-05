shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/water_v2_common.gdshaderinc"
uniform float caustic_strength=1.65;
uniform float caustic_daylight=1.0;
uniform float water_time=0.0;
uniform float water_level=0.3225;
uniform vec3 sun_direction=vec3(-0.314,0.743,0.589);
uniform vec4 plaster : source_color=vec4(0.62,0.78,0.80,1.0);
varying vec3 world_position;
varying float focus;
void vertex() {world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment() {
    float depth=max(0.0,water_level-world_position.y);
    vec3 ray=refract(-normalize(sun_direction),vec3(0,1,0),1.0/1.333);
    vec2 source_point=world_position.xz-ray.xz*depth/max(-ray.y,0.1);
    vec2 warp=v2_slope(source_point,water_time)*2.6;
    float gap=v2_cell_gap(source_point*2.1+warp,water_time);
    float width=max(fwidth(gap)*1.3,0.018);
    float network=1.0-smoothstep(0.02,0.075+width,gap);
    float modulation=0.5+0.5*v2_noise(source_point*1.13+vec2(water_time*0.11,-water_time*0.09));
    focus=network*modulation*exp(-depth*0.26)*smoothstep(0.015,0.16,depth)*caustic_daylight;
    ALBEDO=plaster.rgb; ROUGHNESS=0.82; SPECULAR=0.18;
}
void light() {
    float diffuse=max(dot(NORMAL,LIGHT),0.0);
    vec3 sun_view=normalize((VIEW_MATRIX*vec4(sun_direction,0)).xyz);
    float direct_sun=LIGHT_IS_DIRECTIONAL ? smoothstep(0.97,0.999,dot(LIGHT,sun_view)) : 0.0;
    DIFFUSE_LIGHT+=ALBEDO*LIGHT_COLOR*ATTENUATION*diffuse*(1.0+focus*caustic_strength*direct_sun)/PI;
}
