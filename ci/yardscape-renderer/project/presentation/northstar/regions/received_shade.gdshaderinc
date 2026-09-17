// Color-only receiver shading. Geometry/alpha/mark caches are not changed.
// At most eight spatially relevant higher/later crowns; max-union avoids
// multiplying a lower crown into black for every overlapping neighbor.
uniform int neighbor_count=0;
uniform vec4 neighbor_cast[8]; // receiver-local centre, radius ratio, strength
uniform vec4 neighbor_contact[8];
uniform vec4 neighbor_meta[8]; // source seed, lobe count, family, reserved
uniform vec4 neighbor_lobes[80];
float shade_hash(vec2 p,float s){return fract(sin(dot(p,vec2(127.1,311.7))+s*.19)*43758.5453);}
float shade_noise(vec2 p,float s){vec2 i=floor(p),u=fract(p);u=u*u*(3.-2.*u);return mix(mix(shade_hash(i,s),shade_hash(i+vec2(1,0),s),u.x),mix(shade_hash(i+vec2(0,1),s),shade_hash(i+vec2(1,1),s),u.x),u.y);}
float shade_field(vec2 p,float s){return .56*shade_noise(p,s)+.28*shade_noise(p*2.11+6.,s)+.16*shade_noise(p*4.03-9.,s);}
float neighbor_coverage(vec2 p,int index){
 vec4 meta=neighbor_meta[index];float d=length(p)-.49;
 for(int i=0;i<10;i++){
  if(i>=int(meta.y))break;
  vec4 lobe=neighbor_lobes[index*10+i];d=min(d,length(p-lobe.xy)-lobe.z);
 }
 d+=(shade_field(p*(meta.z<.5?19.:23.),meta.x)-.5)*.15;
 float gaps=smoothstep(.59,.71,shade_field(p*6.+meta.x,meta.x))*smoothstep(-.25,.5,dot(p,normalize(vec2(.65,-.76))));
 // Receiver softness is intentionally a low-frequency penumbra, not its own
 // geometry or a lighting-dependent alpha mask on the receiving plant.
 return (1.-smoothstep(-.035,.065,d))*(1.-gaps*.85);
}
vec3 received_transmission(vec2 point){
 float shade=0.;
 for(int i=0;i<8;i++){
  if(i>=neighbor_count)break;
  vec4 cast=neighbor_cast[i],contact=neighbor_contact[i];
  float projected=neighbor_coverage((point-cast.xy)/cast.z,i)*cast.w;
  float overlap=neighbor_coverage((point-contact.xy)/contact.z,i)*contact.w;
  shade=max(shade,max(projected,overlap));
 }
 return exp(-vec3(.78,.60,.64)*shade);
}
