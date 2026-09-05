shader_type spatial;
render_mode cull_disabled, depth_draw_never;
#include "res://shaders/water_v2_common.gdshaderinc"
uniform float water_time=0.0;
uniform float water_level=0.3225;
uniform float flow_strength=1.0;
uniform float sheet_top=1.4;
varying vec3 p;
void vertex() {
    vec3 original=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
    float drop=clamp((sheet_top-original.y)/max(sheet_top-water_level,0.02),0.0,1.0);
    // Slot stays pinned. The actual film flexes by millimetres, not just its color.
    float flex=sin(original.x*7.1-water_time*3.3+drop*8.0)*0.007;
    flex+=sin(original.x*13.7+water_time*2.1-drop*11.0)*0.003;
    VERTEX+=NORMAL*flex*smoothstep(0.0,0.18,drop)*flow_strength;
    p=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
}
void fragment() {
    if(flow_strength<=0.0 || (CAMERA_VISIBLE_LAYERS==4u && p.y<water_level)) {discard;}
    float fall=max(0.0,sheet_top-p.y);
    float travelled=sqrt(fall+0.03)*2.5+water_time*2.1;
    float broad=v2_noise(vec2(p.x*14.1,travelled*3.7));
    float fine=v2_noise(vec2(p.x*51.7,travelled*7.3));
    float aeration=1.0-smoothstep(water_level+0.015,water_level+0.20,p.y);
    ALBEDO=mix(vec3(0.09,0.28,0.32),vec3(0.78,0.86,0.83),aeration*0.65+pow(fine,4.0)*0.3);
    ROUGHNESS=mix(0.055,0.25,aeration); SPECULAR=0.25;
    ALPHA=clamp(0.19+broad*0.12+pow(fine,3.0)*0.16+aeration*0.25,0.0,0.75);
}
