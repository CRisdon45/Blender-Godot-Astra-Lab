shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Same lit pigment palette as the opaque test. Cutout coverage is the new variable.
uniform float height=3.5;
uniform float radius=1.2;
uniform float seed_phase=1.0;
uniform vec3 leaf_green : source_color=vec3(.32,.46,.205);
uniform vec3 sunlit_green : source_color=vec3(.55,.63,.31);
uniform sampler2D coverage_tex : filter_linear_mipmap, repeat_disable;
uniform bool coverage_enabled=true;
varying vec3 media;
void vertex(){media=VERTEX/vec3(radius,height,radius);}
float f(vec3 p){return .5+.25*sin(p.x*2.7+seed_phase)*sin(p.y*3.1+p.z*.8)+.15*sin(p.z*4.3-p.x*1.2+seed_phase);}
void fragment(){
 float mass=f(media*2.1);
 float pigment=smoothstep(.32,.70,mass);
 vec3 color=mix(leaf_green,sunlit_green,pigment*.56);
 float dry=f(media*8.);
 float lod=1.-smoothstep(.25,.9,length(fwidth(media*8.)));
 color*=1.+(dry-.5)*.055*lod;
 ALBEDO=color;ROUGHNESS=1.;
 ALPHA=coverage_enabled?texture(coverage_tex,UV).r:1.;
 ALPHA_SCISSOR_THRESHOLD=.5;
}
