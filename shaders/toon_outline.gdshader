shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled, ambient_light_disabled;

group_uniforms outline;
uniform float outline_width : hint_range(0.0, 0.08, 0.001) = 0.012;
uniform vec4 outline_color : source_color = vec4(0.16, 0.1, 0.06, 1.0);

group_uniforms wind;
uniform float wind_strength : hint_range(0.0, 0.8) = 0.28;
uniform float wind_speed : hint_range(0.0, 4.0) = 1.15;
uniform vec2 wind_direction = vec2(1.0, 0.12);

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float mask = smoothstep(0.35, 3.2, max(world.y, 0.0));
	float gust = 0.62 + 0.38 * sin(TIME * wind_speed + world.y * 0.35);
	float amount = wind_strength * mask * gust;
	vec3 offset = vec3(wind_direction.x, 0.0, wind_direction.y) * amount;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(offset, 0.0)).xyz;
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
