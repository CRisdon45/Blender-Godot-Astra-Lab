shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert, specular_disabled;
// One translucent surface; the depth tones and light net live on real basin
// geometry below. No screen/depth texture, screenshot projection or TIME noise.
uniform vec3 tint : source_color = vec3(.32,.73,.77);
uniform vec3 highlight : source_color = vec3(.90,.98,.96);
varying vec2 media;
void vertex(){vec3 w=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;media=vec2(w.x,-w.z);}
float n(vec2 p){return sin(p.x*.67+sin(p.y*.83))*.5+.5;}
void fragment(){
 float curve=media.x*6.2+media.y*3.7+sin(media.y*1.65)*.9;
 float ridge=abs(sin(curve));float aa=max(fwidth(curve)*.6,.015);
 float line=(1.-smoothstep(.018,.018+aa,ridge))*smoothstep(.62,.87,n(media*1.8));
 float grazing=pow(1.-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.,1.),3.);
 ALBEDO=mix(tint,highlight,line*.75);
 ALPHA=.075+.13*grazing+line*.08;ROUGHNESS=1.;
}
