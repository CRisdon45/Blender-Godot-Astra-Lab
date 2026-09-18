shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform vec2 sun_direction=vec2(0.0,-1.0);
varying vec3 media;
varying float base_tone;
varying float family_angle;
varying float seed_phase;

void vertex(){
 media=VERTEX;
 base_tone=COLOR.r;
 seed_phase=COLOR.g*6.28318530718;
 family_angle=COLOR.a*6.28318530718;
}

float field(vec3 p,float phase){
 return .5
  +.22*sin(p.x*2.1+p.y*.8+phase)*sin(p.z*2.4-p.y*.6-phase*.4)
  +.10*sin(p.x*4.3-p.z*3.1+phase*.7);
}

void fragment(){
 vec2 family_dir=vec2(cos(family_angle),sin(family_angle));
 float alignment=dot(family_dir,sun_direction);
 float family_value=alignment>.28 ? .075 : (alignment<-.28 ? -.075 : 0.0);
 float pigment=field(media*1.55,seed_phase);
 float tone=clamp(base_tone+family_value+(pigment-.5)*.15,.18,.80);
 vec3 dark=vec3(.145,.235,.085);
 vec3 middle=vec3(.315,.425,.18);
 vec3 light_value=vec3(.565,.595,.30);
 vec3 color=mix(dark,middle,smoothstep(.31,.52,tone));
 color=mix(color,light_value,smoothstep(.49,.67,tone)*.42);
 float dry=field(media*6.2,seed_phase+1.7);
 float lod=1.0-smoothstep(.18,.72,length(fwidth(media*6.2)));
 color*=.985+(dry-.5)*.045*lod;
 ALBEDO=color;
 ROUGHNESS=1.0;
}
