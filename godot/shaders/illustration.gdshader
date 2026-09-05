shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float line_strength=0.24;
uniform float grain_strength=0.013;
float lum(vec3 c){return dot(c,vec3(0.299,0.587,0.114));}
void fragment(){
 vec2 u=SCREEN_UV; vec2 p=SCREEN_PIXEL_SIZE;
 vec3 c=texture(screen_texture,u).rgb;
 float l=lum(texture(screen_texture,u-vec2(p.x,0.0)).rgb);
 float r=lum(texture(screen_texture,u+vec2(p.x,0.0)).rgb);
 float t=lum(texture(screen_texture,u-vec2(0.0,p.y)).rgb);
 float b=lum(texture(screen_texture,u+vec2(0.0,p.y)).rgb);
 float edge=smoothstep(0.06,0.3,length(vec2(r-l,b-t)));
 float grain=fract(sin(dot(floor(FRAGCOORD.xy),vec2(12.9898,78.233)))*43758.5453)-0.5;
 c*=1.0-edge*line_strength;
 c+=grain*grain_strength;
 COLOR=vec4(c,1.0);
}
