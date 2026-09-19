shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, unshaded;
// Small cards keep fixed 3D centers. UV identifies atlas tile/corner, UV2 holds
// size, COLOR.b holds roll, and the vertex stage faces each card to the camera.
uniform sampler2D brush_atlas : repeat_disable, filter_linear_mipmap;
uniform vec2 sun_direction = vec2(0.0,-1.0);
uniform float leader_family_value = 0.0;
uniform vec3 foliage_dark : source_color = vec3(0.19,0.27,0.15);
uniform vec3 foliage_middle : source_color = vec3(0.38,0.45,0.24);
uniform vec3 foliage_light : source_color = vec3(0.57,0.58,0.34);
uniform float plant_height = 1.0;
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
float macro_pigment(vec3 p){
 return .5+.23*sin(p.x*.78+p.y*.43-p.z*.31)+.13*cos(p.z*.91-p.x*.27+p.y*.36);
}
void fragment(){
 vec4 brush=texture(brush_atlas,UV);
 float mask=brush.a;
 ALPHA=mask;
 ALPHA_SCISSOR_THRESHOLD=.42;
 float family_value=0.0;
 vec2 family_dir=vec2(cos(family_angle),sin(family_angle));
 float alignment=dot(family_dir,sun_direction);
  if(alignment>.28) family_value=.042;
  else if(alignment<-.28) family_value=-.042;
 float height_band=clamp(group_local.y/max(plant_height,.001),0.0,1.0);
 float height_value=(smoothstep(.24,.92,height_band)-.5)*.150;
 float card_variation=(COLOR.r-.5)*.024;
 float wash_value=(brush.r-.5)*.080;
 float broad_value=(macro_pigment(group_local)-.5)*.285;
 float tone=clamp(.52+family_value+leader_family_value*.18+height_value+card_variation+wash_value+broad_value-interior_occlusion*.155,.16,.84);
 // Narrow transitions make a few large plant-space washes read before the
 // individual retained cards, matching the reference's dark/mid/light masses.
 vec3 color=mix(foliage_dark,foliage_middle,smoothstep(.37,.49,tone));
 color=mix(color,foliage_light,smoothstep(.60,.70,tone));
 float edge_pool=1.0-smoothstep(.42,.80,mask);
 color*=1.0-edge_pool*.030;
 ALBEDO=color;
 ROUGHNESS=1.0;
}
