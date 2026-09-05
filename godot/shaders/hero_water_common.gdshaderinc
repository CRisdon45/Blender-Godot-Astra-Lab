// Original bounded pool ripple spectrum, shared by optics and receiver caustics.
// Units are scene metres and seconds. No engine TIME: frozen reviews stay aligned.
vec2 pool_slope(vec2 p, float t) {
	vec2 a = normalize(vec2(1.0, 0.43));
	vec2 b = normalize(vec2(-0.38, 1.0));
	vec2 c = normalize(vec2(0.71, -0.92));
	vec2 d = normalize(vec2(0.28, 1.0));
	return a * (0.0050 * 12.9) * cos(dot(p,a)*12.9-t*1.8)
		+ b * (0.0032 * 17.3) * cos(dot(p,b)*17.3+t*2.2+1.7)
		+ c * (0.0015 * 23.1) * cos(dot(p,c)*23.1-t*2.6+3.1)
		+ d * (0.0040 * 8.7) * cos(dot(p,d)*8.7+t*1.3+0.6);
}

// Hessian of the same height field: xx, xz, zz. Thin-surface focusing study,
// not a photon solver. Its bounded Jacobian gives moving receiver highlights.
vec3 pool_hessian(vec2 p, float t) {
	vec2 a = normalize(vec2(1.0, 0.43));
	vec2 b = normalize(vec2(-0.38, 1.0));
	vec2 c = normalize(vec2(0.71, -0.92));
	vec2 d = normalize(vec2(0.28, 1.0));
	return -vec3(a.x*a.x,a.x*a.y,a.y*a.y) * (0.0050*12.9*12.9) * sin(dot(p,a)*12.9-t*1.8)
		-vec3(b.x*b.x,b.x*b.y,b.y*b.y) * (0.0032*17.3*17.3) * sin(dot(p,b)*17.3+t*2.2+1.7)
		-vec3(c.x*c.x,c.x*c.y,c.y*c.y) * (0.0015*23.1*23.1) * sin(dot(p,c)*23.1-t*2.6+3.1)
		-vec3(d.x*d.x,d.x*d.y,d.y*d.y) * (0.0040*8.7*8.7) * sin(dot(p,d)*8.7+t*1.3+0.6);
}
