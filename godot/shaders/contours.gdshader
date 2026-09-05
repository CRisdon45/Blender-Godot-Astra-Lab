shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, repeat_disable, filter_nearest;
float linear_depth(vec2 uv,mat4 inv){
 float d=texture(depth_tex,uv).r;
 vec4 p=inv*vec4(uv*2.0-1.0,d,1.0);
 return -p.z/p.w;
}
void vertex(){POSITION=vec4(VERTEX.xy,1.0,1.0);}
void fragment(){
 vec2 uv=SCREEN_UV; vec2 px=1.0/VIEWPORT_SIZE;
 float d=linear_depth(uv,INV_PROJECTION_MATRIX);
 vec3 n=texture(normal_tex,uv).xyz;
 float de=0.0; float ne=0.0;
 for(int i=0;i<4;i++){
  vec2 offset=vec2(i==0 ? 1.0 : (i==1 ? -1.0 : 0.0),i==2 ? 1.0 : (i==3 ? -1.0 : 0.0))*px;
  float nd=linear_depth(uv+offset,INV_PROJECTION_MATRIX);
  de=max(de,clamp((nd-d)/max(d,0.1),0.0,1.0));
  ne=max(ne,length(n-texture(normal_tex,uv+offset).xyz));
 }
 float edge=max(smoothstep(0.003,0.02,de),smoothstep(0.3,0.8,ne)*0.5);
 vec3 col=texture(screen_tex,uv).rgb;
 ALBEDO=col*(1.0-edge*0.21);
}
