shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Spatial transfer of the retained 2D paving wash/joint vocabulary.
// World metres keep the four deck meshes aligned. No camera/time repainting.
uniform float seed = 19.0;
uniform vec2 slab_size = vec2(0.6096,0.3048);
uniform vec3 paper_color : source_color = vec3(.80,.765,.695);
uniform vec3 ink_color : source_color = vec3(.21,.235,.205);
uniform bool coping = false;
uniform vec2 half_size = vec2(1.0);
varying vec3 world_point;
varying vec3 object_point;
varying vec3 world_normal;
void vertex(){
 world_point=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
 object_point=VERTEX;
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
float hash_value(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7))+seed*.73)*43758.5453);}
float noise_value(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash_value(i),hash_value(i+vec2(1,0)),f.x),mix(hash_value(i+vec2(0,1)),hash_value(i+vec2(1,1)),f.x),f.y);}
float field(vec2 p){return .63*noise_value(p)+.25*noise_value(p*2.07+17.1)+.12*noise_value(p*4.13-8.4);}
float pen(float d,float r,float pixel){return clamp((r+.5*pixel-d)/max(pixel,.00005),0.,1.);}
void fragment(){
 vec2 p=vec2(world_point.x,-world_point.z);
 vec2 grid=p/slab_size;float row=floor(grid.y);grid.x+=mod(row,2.)*.5;
 vec2 cell=floor(grid),f=fract(grid);
 float hdist=min(f.y,1.-f.y)*slab_size.y;
 float vdist=min(f.x,1.-f.x)*slab_size.x;
 vec2 footprint=max(fwidth(p),vec2(.00005));
 float passage=field(p*vec2(.38,.70)+vec2(7.,-3.));
 float reserve=smoothstep(.46,.66,field(p*vec2(.45,.26)+31.));
 float body=(.055+.16*smoothstep(.30,.67,passage))*(1.-.70*reserve);
 body*=.86+.20*hash_value(cell);
 vec3 rgb=paper_color*exp(-body*vec3(.53,.76,1.09));
 float nearest=min(hdist,vdist);
 float load=smoothstep(.39,.72,field(p*2.1+cell*.08));
 rgb*=exp(-exp(-nearest*74.)*load*.045*vec3(.70,.87,1.10));
 float grain_fade=1.-smoothstep(.55,1.4,length(fwidth(p*19.)));
 rgb*=1.+(field(p*19.)-.5)*body*.09*grain_fade;
 float stroke_h=smoothstep(.38,.67,noise_value(vec2(p.x*1.45,round(p.y/slab_size.y)*.71)+9.));
 float stroke_v=smoothstep(.39,.71,noise_value(vec2(round(grid.x)*.67,p.y*2.2)-4.));
 float line=max(pen(hdist,.0045,footprint.y)*(.16+.40*stroke_h),pen(vdist,.0039,footprint.x)*(.11+.34*stroke_v));
 if(world_normal.y>.7){
  rgb=mix(rgb,ink_color,line*(coping?.50:1.));
  if(coping){
   vec2 edge=half_size-abs(object_point.xz);
   float contour=max(pen(edge.x,.008,footprint.x),pen(edge.y,.008,footprint.y));
   rgb=mix(rgb,ink_color,contour*.76);
  }
 }
 ALBEDO=rgb;ROUGHNESS=1.;
}
