shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Geometry carries the volume. This first look intentionally avoids canopy-wide
// normal guidance, alpha cutouts, view-facing tricks, or baked light direction.
uniform float seed_phase=1.0;
uniform vec3 base_green : source_color=vec3(.29,.43,.19);
uniform vec3 light_green : source_color=vec3(.49,.58,.28);
varying vec3 local_pos;
void vertex(){local_pos=VERTEX;}
float field(vec3 p){return .5+.25*sin(p.x*8.3+seed_phase)+.15*sin(p.y*11.7-p.z*7.1+seed_phase*.7);}
void fragment(){
 float v=field(local_pos);
 vec3 c=mix(base_green,light_green,smoothstep(.30,.72,v)*.42);
 float detail=1.-smoothstep(.55,1.25,length(fwidth(local_pos*18.)));
 c*=1.+(field(local_pos*3.1)-.5)*.045*detail;
 ALBEDO=c;
 ROUGHNESS=1.;
}
