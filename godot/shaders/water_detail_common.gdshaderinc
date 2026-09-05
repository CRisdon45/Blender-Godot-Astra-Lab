// Deterministic incommensurate wave directions. Positions are metres, phase seconds.
// The same analytic field and its Hessian drive the surface and receiver study.
vec3 detail_wave(vec2 p, float t, vec2 direction, float k, float amplitude, float speed, float phase) {
	vec2 d = normalize(direction);
	float a = dot(p,d)*k-speed*t+phase;
	return vec3(d*amplitude*k*cos(a), amplitude*sin(a));
}
vec3 detail_curvature(vec2 p, float t, vec2 direction, float k, float amplitude, float speed, float phase) {
	vec2 d = normalize(direction);
	return -vec3(d.x*d.x,d.x*d.y,d.y*d.y)*amplitude*k*k*sin(dot(p,d)*k-speed*t+phase);
}
vec3 detail_field(vec2 p, float t) {
	return detail_wave(p,t,vec2(1.0,0.31),5.17,0.0055,1.23,0.3)
		+detail_wave(p,t,vec2(-0.57,1.0),7.83,0.0032,-1.57,2.7)
		+detail_wave(p,t,vec2(0.22,1.0),11.61,0.0021,2.11,4.1)
		+detail_wave(p,t,vec2(1.0,-0.73),17.37,0.0017,-2.73,1.4)
		+detail_wave(p,t,vec2(-0.86,-0.51),23.91,0.0010,3.19,5.2)
		+detail_wave(p,t,vec2(0.67,0.91),31.13,0.00065,-3.67,3.3)
		+detail_wave(p,t,vec2(0.97,-0.19),39.71,0.0004,4.29,0.8);
}
vec3 detail_hessian(vec2 p, float t) {
	return detail_curvature(p,t,vec2(1.0,0.31),5.17,0.0055,1.23,0.3)
		+detail_curvature(p,t,vec2(-0.57,1.0),7.83,0.0032,-1.57,2.7)
		+detail_curvature(p,t,vec2(0.22,1.0),11.61,0.0021,2.11,4.1)
		+detail_curvature(p,t,vec2(1.0,-0.73),17.37,0.0017,-2.73,1.4)
		+detail_curvature(p,t,vec2(-0.86,-0.51),23.91,0.0010,3.19,5.2)
		+detail_curvature(p,t,vec2(0.67,0.91),31.13,0.00065,-3.67,3.3)
		+detail_curvature(p,t,vec2(0.97,-0.19),39.71,0.0004,4.29,0.8);
}
float detail_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float detail_noise(vec2 p) {
	vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(detail_hash(i),detail_hash(i+vec2(1.0,0.0)),f.x),
		mix(detail_hash(i+vec2(0.0,1.0)),detail_hash(i+vec2(1.0,1.0)),f.x),f.y);
}
