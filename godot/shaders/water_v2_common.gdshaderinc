// Original deterministic lookdev spectrum. Metres/seconds; no engine clock.
// Unequal directions/scales avoid the old four-wave lattice. Slope is analytic.
vec2 v2_wave(vec2 p, float t, vec2 direction, float k, float amplitude, float speed, float phase) {
    vec2 d=normalize(direction);
    return d*(amplitude*k)*cos(dot(p,d)*k-t*speed+phase);
}
vec2 v2_slope(vec2 p, float t) {
    return v2_wave(p,t,vec2(1.0,0.19),3.1,0.010,0.91,0.3)
        +v2_wave(p,t,vec2(-0.27,1.0),5.7,0.004,1.17,2.1)
        +v2_wave(p,t,vec2(0.63,0.77),9.2,0.0021,1.63,4.7)
        +v2_wave(p,t,vec2(-0.81,0.33),15.3,0.0007,2.13,1.2)
        +v2_wave(p,t,vec2(0.14,-0.97),21.7,0.0004,2.59,5.3)
        +v2_wave(p,t,vec2(0.93,-0.48),29.9,0.00022,3.07,3.4);
}
vec2 v2_hash(vec2 p) {
    return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);
}
float v2_noise(vec2 p) {
    vec2 i=floor(p), f=fract(p); vec2 u=f*f*(3.0-2.0*f);
    return mix(mix(v2_hash(i).x,v2_hash(i+vec2(1,0)).x,u.x),
        mix(v2_hash(i+vec2(0,1)).x,v2_hash(i+vec2(1,1)).x,u.x),u.y);
}
// Bounded artist-directed receiver light network, NOT photon tracing.
// Neighbor cells are animated coherently; fwidth in the receiver filters thin ridges.
float v2_cell_gap(vec2 p, float t) {
    vec2 cell=floor(p), f=fract(p); float first=8.0, second=8.0;
    for(int y=-1;y<=1;y++) { for(int x=-1;x<=1;x++) {
        vec2 offset=vec2(float(x),float(y)); vec2 random=v2_hash(cell+offset);
        vec2 center=0.5+0.34*sin(vec2(t*0.42,t*0.37)+random*6.283185);
        float dist=length(offset+center-f);
        if(dist<first) {second=first;first=dist;} else {second=min(second,dist);}
    }}
    return second-first;
}
