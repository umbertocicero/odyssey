shader_type spatial;
render_mode cull_back, blend_mix, depth_draw_opaque, specular_schlick_ggx;
// Mare del diorama, qualità MEDIUM/HIGH (Compatibility-safe).
// Due strati di normal map che scorrono in direzioni diverse, fresnel con riflesso del cielo.
// La profondità dell'acqua si ricava dal profilo analitico della riva (shore_profile.gdshaderinc,
// lo stesso che genera la mesh della sabbia): turchese trasparente nel basso fondale, che
// lascia vedere la sabbia, e sempre più scuro e opaco al largo. Schiuma sottile sulla linea
// d'acqua e treni di onde che arrivano a riva; schiuma di contatto attorno agli scafi
// (depth texture, solo con detail = 1). Le mappe sono procedurali
// (assets/environment/water/gen_water.py), quindi nessuna licenza esterna.
// `detail`: 0 = una sola normal map, niente schiuma di contatto; 1 = completo.

#include "res://assets/shaders/shore_profile.gdshaderinc"

uniform sampler2D normal_tex : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D height_tex : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;

uniform vec4 deep_color : source_color = vec4(0.03, 0.22, 0.32, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.09, 0.60, 0.58, 1.0);
uniform vec4 seabed_color : source_color = vec4(0.62, 0.58, 0.42, 1.0);
uniform vec4 sky_color : source_color = vec4(0.62, 0.74, 0.86, 1.0);
uniform vec4 foam_color : source_color = vec4(0.96, 0.95, 0.92, 1.0);

uniform float shore_x = -21.6;      // riva dritta del terreno procedurale (solo con analytic_shore = false)
uniform bool analytic_shore = true; // false: terreno procedurale con riva dritta
uniform float depth_distance = 3.0; // distanza dalla riva alla quale il mare è "profondo"
uniform float normal_strength = 0.45;
uniform float tile_a = 0.07;
uniform float tile_b = 0.19;
uniform vec2 flow_a = vec2(0.020, 0.012);
uniform vec2 flow_b = vec2(-0.012, 0.028);
uniform float foam_width = 0.55;
uniform float contact_foam_depth = 0.35;
uniform float fresnel_power = 4.0;
uniform int detail = 1;

varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float top = step(0.5, world_nrm.y);
	float t = TIME;
	vec2 p = world_pos.xz;

	// --- profondità dell'acqua e distanza dalla linea d'acqua ---
	float th = analytic_shore ? WATER_Y - shore_floor(p.x, p.y) : 0.5;
	if (top > 0.5 && th <= 0.0) {
		discard;
	}
	float d = max((analytic_shore ? shore_line(p.y) : shore_x) - p.x, 0.0);
	float depth_look = th * 1.5 + smooth01(0.0, depth_distance, d) * 0.55;   // profondità "ottica": il box è basso, il mare deve sembrare profondo
	float alpha = 1.0 - exp(-(th * 3.4 + d * 0.20));

	// --- normali: due strati incrociati, ondine fini sopra onde lunghe (appiattite dove l'acqua è sottilissima) ---
	vec3 na = texture(normal_tex, p * tile_a + flow_a * t).rgb * 2.0 - 1.0;
	vec3 nmix = na;
	if (detail > 0) {
		vec3 nb = texture(normal_tex, p * tile_b + flow_b * t).rgb * 2.0 - 1.0;
		nmix = normalize(vec3(na.xy + nb.xy * 0.8, na.z * nb.z));
	}
	NORMAL_MAP = nmix * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = normal_strength * top * (0.3 + 0.7 * smooth01(0.0, 0.25, th));

	vec3 water = mix(shallow_color.rgb, deep_color.rgb, smooth01(0.15, 1.3, depth_look));
	// un po' di sabbia in sospensione e luce che filtra nel bassofondale
	water = mix(water, seabed_color.rgb * 0.7, (1.0 - smooth01(0.0, 0.25, th)) * 0.25);

	// --- schiuma: bordo sottile sulla linea d'acqua + onde che arrivano a riva ---
	float h = texture(height_tex, p * 0.35 + vec2(0.0, t * 0.012)).r;
	float h2 = texture(height_tex, p * 1.3 + vec2(t * 0.02, 0.0)).r;
	float edge = 1.0 - smooth01(0.012, 0.05 + 0.05 * h, th);
	float w = fract(d * 0.42 + t * 0.20 + h * 0.55);
	float crest = smooth01(0.0, 0.04, w) * (1.0 - smooth01(0.04, 0.22, w));
	float near_shore = 1.0 - smooth01(0.3, 2.8, d);
	float waves = crest * near_shore * (0.30 + 0.70 * smooth01(0.30, 0.65, h2)) * (0.35 + 0.65 * (1.0 - smooth01(0.1, 0.5, th)));
	float foam = clamp(edge * (0.6 + 0.4 * h2) + waves * 0.85, 0.0, 1.0);

	// --- schiuma di contatto attorno a scafi e oggetti che toccano l'acqua ---
	if (detail > 0) {
		float depth = texture(depth_tex, SCREEN_UV).x;
		vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
		vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		view.xyz /= view.w;
		float diff = -view.z + VERTEX.z;
		float contact = 1.0 - smoothstep(0.0, contact_foam_depth, diff);
		contact *= 0.5 + 0.5 * texture(height_tex, p * 0.9 + vec2(t * 0.03, t * 0.02)).r;
		foam = max(foam, contact * 0.85);
	}
	foam *= top;

	// --- fresnel: il cielo si riflette a incidenza radente ---
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);

	ALBEDO = mix(water, foam_color.rgb, foam);
	EMISSION = sky_color.rgb * fres * 0.55 * (1.0 - foam);
	ROUGHNESS = mix(0.06, 0.85, foam);
	SPECULAR = mix(0.7, 0.1, foam);
	METALLIC = 0.0;
	ALPHA = max(alpha, foam * 0.9);
	if (top < 0.5) {
		ALBEDO = mix(deep_color.rgb * 0.7, seabed_color.rgb * 0.7, step(0.5, world_nrm.x));
		ROUGHNESS = 0.6;
		ALPHA = 1.0;
	}
}
