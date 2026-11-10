shader_type spatial;
render_mode specular_disabled;
#include "res://shaders/plant_impulse.gdshaderinc"
void vertex() {
 vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX=(inverse(MODEL_MATRIX)*vec4(elastic_plant_position(world),1.0)).xyz;
}
uniform sampler2D stalk_skin : source_color, filter_linear_mipmap, repeat_enable;
void fragment() {
	// Original cut-ring colours are used exactly at the two interfaces.
	// Interior uses the original stalk's reprojected texture; no alpha blur.
	ALBEDO = mix(texture(stalk_skin, UV).rgb, COLOR.rgb, UV2.x);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
