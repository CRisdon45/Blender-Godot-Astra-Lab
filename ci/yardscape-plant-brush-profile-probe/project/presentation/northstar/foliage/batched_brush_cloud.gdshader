shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert, specular_disabled;
// Small cards keep fixed 3D centers. UV identifies atlas tile/corner, UV2 holds
// size, COLOR.b holds roll, and the vertex stage faces each card to the camera.
uniform sampler2D brush_atlas : repeat_disable, filter_linear_mipmap;
uniform vec2 sun_direction = vec2(0.0,-1.0);
uniform float leader_family_value = 0.0;
varying vec3 group_local;
varying float family_angle;
varying float interior_occlusion;
void vertex(){
 vec2 corner=(vec2(fract(UV.x*4.0),UV.y)-vec2(0.5))*UV2;
 float roll=COLOR.b*6.28318530718-3.14159265359;
 vec2 rotated=vec2(corner.x*cos(roll)-corner.y*sin(roll),corner.x*sin(roll)+corner.y*cos(roll));
 vec3 center=VERTEX-vec3(rotated,0.0);
 vec3 world_center=(MODEL_MATRIX*vec4(center,1.0)).xyz;
 vec3 right=normalize(MAIN_CAM_INV_VIEW_MATRIX[0].xyz);
 vec3 up=normalize(MAIN_CAM_INV_VIEW_MATRIX[1].xyz);
 vec3 position=world_center+right*rotated.x+up*rotated.y;
 VERTEX=(inverse(MODEL_MATRIX)*vec4(position,1.0)).xyz;
 group_local=center;
 family_angle=COLOR.a*6.28318530718;
 interior_occlusion=COLOR.g;
}
float grain(vec3 p){return .5+.23*sin(p.x*4.7+p.y*3.3)+.12*sin(p.z*6.1-p.y*2.4);}
void fragment(){
 vec4 brush=texture(brush_atlas,UV);
 float mask=brush.a;
 ALPHA=mask;
 ALPHA_SCISSOR_THRESHOLD=.42;
 float family_value=0.0;
 vec2 family_dir=vec2(cos(family_angle),sin(family_angle));
 float alignment=dot(family_dir,sun_direction);
  if(alignment>.28) family_value=.068;
  else if(alignment<-.28) family_value=-.068;
 float wash_value=(brush.r-.5)*.17;
 float local_tone=mix(.5,COLOR.r,.24)-interior_occlusion*.045+wash_value;
 float tone=clamp(local_tone+family_value,.18,.80);
 vec3 dark=vec3(.14,.235,.085);
 vec3 middle=vec3(.325,.425,.185);
 vec3 light_value=vec3(.565,.595,.305);
 vec3 color=mix(dark,middle,smoothstep(.33,.52,tone));
 color=mix(color,light_value,smoothstep(.50,.66,tone)*.36);
 float edge_pool=1.0-smoothstep(.42,.76,mask);
 color*=.992+.018*grain(group_local)-edge_pool*.035;
 ALBEDO=color;
 ROUGHNESS=1.0;
}
