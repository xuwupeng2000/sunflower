shader_type spatial;
render_mode cull_disabled, specular_disabled;
#include "res://shaders/plant_impulse.gdshaderinc"
uniform sampler2D original_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 original_tint : source_color = vec4(1.0);
uniform mat4 rest_from_mesh;
uniform float leaf_ceiling = 0.56;
uniform float dry : hint_range(0.0, 1.0) = 0.0;
uniform float flower_bend = 0.0;
uniform float tap_amount = 0.0;
uniform vec3 wet_center = vec3(0.0);
uniform float wet_amount = 0.0;
uniform sampler2D planter_height : filter_linear, repeat_disable;
uniform vec4 planter_bounds = vec4(-0.5,-0.5,1.0,1.0);
uniform mat4 planter_from_world;
uniform mat4 planter_to_world;
uniform bool planter_contact = false;
varying vec3 rest_position;
varying vec3 world_position;
void vertex() {
	rest_position = (rest_from_mesh * vec4(VERTEX, 1.0)).xyz;
 vec3 offset = rest_position-vec3(0.0,leaf_ceiling,0.0);
 float bend=flower_bend*smoothstep(leaf_ceiling,leaf_ceiling+0.30,rest_position.y);
 vec3 posed=vec3(cos(bend)*offset.x-sin(bend)*offset.y,sin(bend)*offset.x+cos(bend)*offset.y,offset.z)+vec3(0.0,leaf_ceiling,0.0);
 VERTEX+=(inverse(rest_from_mesh)*vec4(posed-rest_position,0.0)).xyz;
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 world_position=elastic_plant_position(world_position);
 if(planter_contact) {
  vec3 in_pot=(planter_from_world*vec4(world_position,1.0)).xyz;
  vec2 uv=(in_pot.xz-planter_bounds.xy)/planter_bounds.zw;
  vec3 color=textureLod(original_albedo,UV,0.0).rgb;
  bool leaf=length(rest_position.xz)>0.12 && rest_position.y>0.04 && rest_position.y<leaf_ceiling && color.g>color.r*0.85 && color.g>color.b*0.85;
  if(leaf && all(greaterThanEqual(uv,vec2(0.0))) && all(lessThanEqual(uv,vec2(1.0)))) {
   float support=textureLod(planter_height,uv,0.0).r+0.012;
   in_pot.y=max(in_pot.y,support);
   world_position=(planter_to_world*vec4(in_pot,1.0)).xyz;
  }
 }
 VERTEX=(inverse(MODEL_MATRIX)*vec4(world_position,1.0)).xyz;
}
void fragment() {
	vec4 base = texture(original_albedo, UV) * original_tint;
	float radius = length(rest_position.xz);
	float foliage = smoothstep(0.045, 0.09, radius) * (1.0 - smoothstep(leaf_ceiling - 0.05, leaf_ceiling, rest_position.y));
	float green = smoothstep(0.93, 1.15, base.g / max(base.r, 0.005)) * smoothstep(1.2, 1.8, base.g / max(base.b, 0.005));
	float luma = dot(base.rgb, vec3(0.3, 0.59, 0.11));
	vec3 yellow = vec3(luma * 1.18 + 0.045, luma * 0.97 + 0.035, luma * 0.20 + 0.006);
	float patch = 0.88 + 0.12 * sin(UV.x * 45.0 + sin(UV.y * 39.0));
	ALBEDO = mix(base.rgb, yellow, clamp(dry * foliage * green * patch, 0.0, 1.0));
 float wet=wet_amount*exp(-dot(world_position-wet_center,world_position-wet_center)/0.045);
 ALBEDO*=1.0-wet*0.13;
 ROUGHNESS=mix(1.0,0.34,wet);
 SPECULAR=wet*0.35;
}
