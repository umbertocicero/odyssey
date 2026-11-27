shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
// Nebbia di spruzzi alla base della cascata del mare: una striscia orizzontale sotto il blocco,
// con rumore che si muove piano e dissolvenza verso l'esterno e alle estremità. 2 texture fetch.

#include "res://assets/shaders/shore_profile.gdshaderinc"

uniform sampler2D height_tex : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform vec4 mist_color : source_color = vec4(0.88, 0.82, 0.72, 1.0);
uniform float intensity = 0.55;
uniform float x_inner = -26.75;
uniform float x_outer = -30.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME;
	vec2 p = world_pos.xz;
	float n1 = texture(height_tex, p * 0.07 + vec2(-t * 0.035, t * 0.02)).r;
	float n2 = texture(height_tex, p * 0.19 + vec2(t * 0.05, -t * 0.03)).r;
	float cloud = smooth01(0.2, 0.9, n1 * 0.65 + n2 * 0.35);
	float across = (world_pos.x - x_inner) / (x_outer - x_inner);
	float fade = smooth01(0.0, 0.15, across) * (1.0 - smooth01(0.4, 1.0, across));
	float th = WATER_Y - shore_floor(x_inner + 0.6, p.y);
	float basin = smooth01(0.0, 0.3, th);
	ALBEDO = mist_color.rgb;
	ALPHA = cloud * fade * basin * intensity;
}
