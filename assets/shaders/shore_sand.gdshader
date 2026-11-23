shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_schlick_ggx;
// Sabbia della riva (mesh generata da SeaShore): sabbia PBR con rughe, ghiaino e conchiglie
// (strato "sabbia_ghiaia" del terreno), variazione di tinta a grandi chiazze, sabbia bagnata
// più scura vicino all'acqua, pellicola lucida dell'onda che si ritira, schiuma e bordo
// della risacca che salgono e scendono, linee di alta marea. Verso est, nord e sud si fonde
// con le texture cotte del terreno fotorealistico (niente giunture).
// Compatibility-safe: 5 texture, nessuna depth texture.

#include "res://assets/shaders/shore_profile.gdshaderinc"

uniform sampler2D sand_albedo : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D sand_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D sand_orm : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform sampler2D terrain_albedo : source_color, repeat_disable, filter_linear_mipmap;
uniform sampler2D noise_tex : hint_default_white, repeat_enable, filter_linear_mipmap;

uniform vec2 terrain_origin = vec2(-26.0, -30.0);
uniform float terrain_size = 52.0;
uniform vec4 foam_color : source_color = vec4(0.95, 0.93, 0.88, 1.0);
uniform float wet_strength = 1.0;
uniform float sand_tile = 0.30;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float h = world_pos.y;
	float t = TIME;

	float macro = texture(noise_tex, p * 0.07).r;
	float meso = texture(noise_tex, p * 0.31 + 3.7).r;
	vec2 uv1 = p * sand_tile;
	vec2 uv2 = p * (sand_tile * 0.37) + vec2(0.37, 0.71);
	vec3 alb = texture(sand_albedo, uv1).rgb;
	vec3 alb2 = texture(sand_albedo, uv2).rgb;
	alb = mix(alb, alb2, 0.3) * (0.86 + 0.28 * macro);
	vec3 n1 = texture(sand_normal, uv1).rgb * 2.0 - 1.0;
	vec3 n2 = texture(sand_normal, uv2).rgb * 2.0 - 1.0;
	vec3 nm = normalize(vec3(n1.xy + n2.xy * 0.6, n1.z));
	vec3 orm = texture(sand_orm, uv1).rgb;
	float rough = orm.g;
	float ao = orm.r;

	// Fusione col terreno originale ai bordi della mesh.
	float tw = shore_terrain_weight(p, (meso - 0.5) * 1.1);
	vec3 terr = texture(terrain_albedo, (p - terrain_origin) / terrain_size).rgb;
	alb = mix(alb, terr, tw);

	// Sabbia bagnata: fascia umida fino a ~16 cm sopra il pelo dell'acqua, più scura e meno ruvida.
	float swash = swash_level(p, t);
	float damp = (1.0 - smooth01(WATER_Y + 0.02, WATER_Y + 0.17 + (macro - 0.5) * 0.08, h)) * wet_strength * (1.0 - tw);
	float fresh = (1.0 - smooth01(swash - 0.012, swash + 0.006, h)) * (1.0 - tw);
	alb *= mix(1.0, 0.58, damp);
	alb *= mix(1.0, 0.82, fresh);
	rough = mix(rough, 0.45, damp);
	rough = mix(rough, 0.10, fresh);

	// Linee di alta marea: strisce scure di sabbia umida e detriti minuti ai livelli di vecchie mareggiate.
	float line1 = 1.0 - smooth01(0.0, 0.010, abs(h - (WATER_Y + 0.20 + (meso - 0.5) * 0.05)));
	float line2 = 1.0 - smooth01(0.0, 0.008, abs(h - (WATER_Y + 0.31 + (macro - 0.5) * 0.06)));
	float tide = clamp(line1 * 0.8 + line2 * 0.5, 0.0, 1.0) * (0.35 + 0.65 * meso) * (1.0 - tw);
	alb = mix(alb, alb * vec3(0.55, 0.5, 0.42), tide * 0.6);

	// Schiuma della risacca sulla sabbia: merletto sul bordo dell'onda e bolle che restano sul bagnato.
	float nz = texture(noise_tex, p * 0.9 + vec2(t * 0.02, 0.0)).r;
	float rim = (1.0 - smooth01(0.0, 0.022 + 0.02 * nz, abs(h - swash + 0.006))) * (0.55 + 0.45 * nz);
	float trail = (1.0 - smooth01(swash - 0.07, swash - 0.012, h)) * smooth01(swash - 0.11, swash - 0.04, h);
	float bubbles = smooth01(0.58, 0.82, texture(noise_tex, p * 2.3 + vec2(0.0, t * 0.03)).r) * trail;
	float foam = clamp(rim * 0.85 + bubbles * 0.6, 0.0, 1.0) * (1.0 - tw) * (1.0 - smooth01(WATER_Y + 0.22, WATER_Y + 0.28, h));
	alb = mix(alb, foam_color.rgb, foam);
	rough = mix(rough, 0.7, foam);

	ALBEDO = alb;
	ROUGHNESS = clamp(rough, 0.05, 1.0);
	SPECULAR = mix(0.4, 0.9, fresh);
	AO = mix(1.0, ao, 0.8);
	AO_LIGHT_AFFECT = 0.5;
	NORMAL_MAP = nm * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = mix(1.0, 0.25, fresh) * (1.0 - tw * 0.7);
}
