shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform float plastic_alpha : hint_range(0.15, 1.0) = 0.46;
uniform float plastic_roughness : hint_range(0.0, 0.4) = 0.04;

varying vec3 color;

void vertex() {
	color = COLOR.rgb;
}

void fragment() {
	ALBEDO = color;
	float green = smoothstep(0.05, 0.18, color.g - max(color.r, color.b));
	ALPHA = mix(1.0, plastic_alpha, green);
	ROUGHNESS = mix(0.8, plastic_roughness, green);
	SPECULAR = mix(0.2, 0.95, green);
}
