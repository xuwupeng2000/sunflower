shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D albedo_texture : source_color;
uniform mat4 rest_from_mesh;
uniform float maturity = 0.0;
// 0 stalk, 1 individually anchored leaf, 2 flower, 3 original juvenile.
uniform int part_kind = 0;
uniform vec3 anchor = vec3(0.0);
varying vec3 rest;
varying float opened;
void vertex() {
 rest=(rest_from_mesh*vec4(VERTEX,1.0)).xyz;
 float tip=mix(0.20,1.04,smoothstep(0.05,0.70,maturity));
 vec3 grown=rest;
 opened=1.0;
 if(part_kind==1) {
  float birth=mix(0.08,0.55,clamp((anchor.y-0.2)/0.7,0.0,1.0));
  opened=smoothstep(birth,birth+0.18,maturity);
  vec3 offset=rest-anchor;
  // New leaves emerge folded upwards from their own petiole, then open.
  float angle=(1.0-opened)*0.8;
  grown=anchor+offset*opened;
  grown.y+=length(offset.xz)*sin(angle)*opened;
 } else if(part_kind==2) {
  float bloom=smoothstep(0.68,1.0,maturity);
  float size=mix(0.001,1.0,smoothstep(0.68,1.0,maturity));
  vec3 offset=rest-vec3(-0.007,1.04,-0.017);
  grown=vec3(-0.007,tip,-0.017)+offset*vec3(size*mix(0.3,1.0,bloom),size,size*mix(0.4,1.0,bloom));
  opened=smoothstep(0.68,0.72,maturity);
 } else if(part_kind==3) {
  // Keep the user's seedling throughout the animation, including cotyledons.
  float leaf=smoothstep(0.13,0.23,rest.y);
  grown.xz*=1.0+0.35*smoothstep(0.0,0.4,maturity)*leaf;
 }
 VERTEX+=(inverse(rest_from_mesh)*vec4(grown-rest,0.0)).xyz;
}
void fragment() {
 float tip=mix(0.20,1.04,smoothstep(0.05,0.70,maturity));
 if(part_kind==0 && rest.y>tip) discard;
 if(opened<0.001) discard;
 vec3 base=texture(albedo_texture,UV).rgb;
 if(part_kind==2) base=mix(vec3(0.28,0.37,0.06),base,smoothstep(0.68,0.87,maturity));
 ALBEDO=base;
 ROUGHNESS=1.0;
}
