shader_type canvas_item;
render_mode unshaded;
// Broadleaf-only color modulation. Coverage remains the retained blade mesh.
#include "res://presentation/northstar/regions/received_shade.gdshaderinc"
uniform float receiver_radius = 1.0;
// Modulate the retained paint marks, preserving real gaps between polygons.
uniform bool paint_enabled = true;
uniform float seed = 1.0;
varying vec2 paint_position;
float random_value(vec2 p) {
    return fract(sin(dot(p,vec2(127.1,311.7))+seed*.071)*43758.5453);
}
float pigment_noise(vec2 p) {
    vec2 i=floor(p), f=fract(p);
    f=f*f*(3.0-2.0*f);
    return mix(mix(random_value(i),random_value(i+vec2(1,0)),f.x),
               mix(random_value(i+vec2(0,1)),random_value(i+vec2(1,1)),f.x),f.y);
}
void vertex() { paint_position=VERTEX; }
void fragment() {
    vec4 mark=COLOR;
    if(paint_enabled) {
        vec2 p=paint_position;
        float wet= pigment_noise(p*7.0)*.65+pigment_noise(p*17.0+5.0)*.35;
        float grain=pigment_noise(p*93.0);
        float detail=1.0-smoothstep(.7,2.0,length(fwidth(p*93.0)));
        mark.rgb*=.86+.22*wet+(grain-.5)*.15*detail;
        float lift=smoothstep(.58,.81,wet)*.23;
        mark.rgb=mix(mark.rgb,vec3(.95,.95,.84),lift);
    }
    if(paint_enabled && neighbor_count>0) {
        mark.rgb*=received_transmission(paint_position/receiver_radius);
    }
    COLOR=mark;
}
