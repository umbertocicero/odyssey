shader_type spatial;
render_mode cull_back, blend_mix, depth_draw_opaque;
// Mare del diorama, qualità LOW (web / telefoni deboli): una sola normal map, niente depth
// texture. Profondità dal profilo analitico della riva (shore_profile.gdshaderinc): trasparente
// nel basso fondale, schiuma sulla linea d'acqua. Costo: 2 texture fetch.

#include "res://assets/shaders/shore_profile.gdshaderinc"

uniform sampler2D normal_tex : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D height_tex : hint_default_white, repeat_enable, filter_linear_mipmap;

uniform vec4 deep_color : source_color = vec4(0.03, 0.22, 0.32, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.09, 0.60, 0.58, 1.0);
uniform vec4 seabed_color : source_color = vec4(0.62, 0.58, 0.42, 1.0);
uniform vec4 foam_color : source_color = vec4(0.96, 0.95, 0.92, 1.0);
uniform float shore_x = -21.6;      // riva dritta del terreno procedurale (solo con analytic_shore = false)
uniform bool analytic_shore = true; // false: terreno procedurale con riva dritta
uniform float depth_distance = 3.0;
uniform float normal_strength = 0.45;
uniform float tile_a = 0.07;
uniform vec2 flow_a = vec2(0.020, 0.012);

varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float top = step(0.5, world_nrm.y);
	vec2 p = world_pos.xz;
	float th = analytic_shore ? WATER_Y - shore_floor(p.x, p.y) : 0.5;
	if (top > 0.5 && th <= 0.0) {
		discard;
	}
	vec4 n = texture(normal_tex, p * tile_a + flow_a * TIME);
	NORMAL_MAP = n.rgb;
	NORMAL_MAP_DEPTH = normal_strength * top * (0.3 + 0.7 * smooth01(0.0, 0.25, th));

	float d = max((analytic_shore ? shore_line(p.y) : shore_x) - p.x, 0.0);
	vec3 water = mix(shallow_color.rgb, deep_color.rgb, smooth01(0.15, 1.3, th * 1.5 + smooth01(0.0, depth_distance, d) * 0.55));
	water = mix(water, seabed_color.rgb * 0.7, (1.0 - smooth01(0.0, 0.25, th)) * 0.25);

	float h = texture(height_tex, p * 0.35 + vec2(0.0, TIME * 0.012)).r;
	float w = fract(d * 0.42 + TIME * 0.20 + h * 0.55);
	float crest = smooth01(0.0, 0.04, w) * (1.0 - smooth01(0.04, 0.22, w)) * (1.0 - smooth01(0.3, 2.8, d));
	float foam = clamp((1.0 - smooth01(0.012, 0.05 + 0.05 * h, th)) * 0.9 + crest * 0.6, 0.0, 1.0) * top;

	ALBEDO = mix(water, foam_color.rgb, foam);
	if (top < 0.5) {
		ALBEDO = mix(deep_color.rgb * 0.7, seabed_color.rgb * 0.7, step(0.5, world_nrm.x));
	}
	ROUGHNESS = mix(0.1, 0.85, foam);
	SPECULAR = mix(0.6, 0.1, foam);
	ALPHA = top > 0.5 ? max(1.0 - exp(-(th * 3.4 + d * 0.20)), foam * 0.9) : 1.0;
}
