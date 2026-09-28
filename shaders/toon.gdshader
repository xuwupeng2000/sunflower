shader_type spatial;
render_mode cull_disabled, specular_disabled, ambient_light_disabled;

group_uniforms albedo;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_tint : source_color = vec4(1.0);

group_uniforms bands;
uniform float light_split : hint_range(0.0, 1.0) = 0.25;
uniform float light_softness : hint_range(0.0, 0.2) = 0.02;
uniform vec3 shadow_color : source_color = vec3(0.55, 0.42, 0.25);

group_uniforms rim;
uniform vec3 rim_color : source_color = vec3(1.0, 0.78, 0.42);
uniform float rim_split : hint_range(0.0, 1.0) = 0.62;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.45;

group_uniforms wind;
uniform float wind_strength : hint_range(0.0, 0.8) = 0.28;
uniform float wind_speed : hint_range(0.0, 4.0) = 1.15;
uniform vec2 wind_direction = vec2(1.0, 0.12);

group_uniforms clip;
uniform bool two_sided = false;
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.5;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float mask = smoothstep(0.35, 3.2, max(world.y, 0.0));
	float gust = 0.62 + 0.38 * sin(TIME * wind_speed + world.y * 0.35);
	float amount = wind_strength * mask * gust;
	vec3 offset = vec3(wind_direction.x, 0.0, wind_direction.y) * amount;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(offset, 0.0)).xyz;
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV) * albedo_tint;
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	if (two_sided && !FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	EMISSION = tex.rgb * shadow_color;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float edge = max(light_softness, 0.001);
	float ndotl = dot(NORMAL, LIGHT);
	float band = smoothstep(light_split - edge, light_split + edge, ndotl);
	float cover = smoothstep(0.2, 0.55, ATTENUATION);
	float lit = band * cover;
	float energy = max(LIGHT_COLOR.r, max(LIGHT_COLOR.g, LIGHT_COLOR.b));
	vec3 light_rgb = energy > 0.001 ? LIGHT_COLOR / energy : vec3(0.0);
	float weight = clamp(energy, 0.0, 1.45);
	DIFFUSE_LIGHT += ALBEDO * (vec3(1.0) - shadow_color) * lit * light_rgb * weight;
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim_band = smoothstep(rim_split - edge, rim_split + edge, rim);
	DIFFUSE_LIGHT += rim_color * rim_band * lit * rim_strength * weight;
}
