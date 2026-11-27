shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_opaque, specular_schlick_ggx;
// Cascata del mare sul fianco ovest del diorama: l'acqua scivola oltre il bordo e cade lungo il blocco.
// Strisce verticali (la stessa mappa di rumore del mare, stirata e fatta scorrere verso il basso a due
// velocità), schiuma spessa sul ciglio che si arricchisce d'aria cadendo, e in fondo l'acqua si
// dissolve in nebbia. Il profilo del fondale (shore_profile.gdshaderinc) toglie la cascata dove il
// bacino diventa basso (testa nord). Costo: 3 texture fetch.

#include "res://assets/shaders/shore_profile.gdshaderinc"

uniform sampler2D height_tex : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform vec4 deep_color : source_color = vec4(0.05, 0.22, 0.32, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.12, 0.4, 0.46, 1.0);
uniform vec4 foam_color : source_color = vec4(0.95, 0.92, 0.85, 1.0);
uniform vec4 mist_color : source_color = vec4(0.82, 0.78, 0.7, 1.0);
uniform vec4 sky_color : source_color = vec4(0.62, 0.74, 0.86, 1.0);
uniform float top_y = -0.1;
uniform float bottom_y = -8.6;
uniform float fade_start = -5.0;     // da qui in giù l'acqua si dissolve in nebbia
uniform float fall_speed = 1.6;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME;
	float y = world_pos.y;
	float z = world_pos.z;
	float depth_below = clamp((top_y - y) / (top_y - bottom_y), 0.0, 1.0);

	// niente cascata dove il bacino è asciutto (testa nord)
	float th = WATER_Y - shore_floor(world_pos.x + 0.6, z);
	float basin = smooth01(0.0, 0.3, th);

	// strisce che cadono: due scale, la seconda più veloce e fitta
	float s1 = texture(height_tex, vec2(z * 0.30, y * 0.03 + t * fall_speed * 0.35)).r;
	float s2 = texture(height_tex, vec2(z * 0.8 + 0.37, y * 0.05 + t * fall_speed * 0.62)).r;
	float s3 = texture(height_tex, vec2(z * 1.7 + 0.71, y * 0.08 + t * fall_speed * 0.95)).r;
	float streak = s1 * 0.5 + s2 * 0.35 + s3 * 0.15;

	// schiuma: ciglio (appena sotto il pelo dell'acqua) + aria inglobata che aumenta con la caduta
	float lip = 1.0 - smooth01(0.0, 1.6, top_y - y);
	float aer = smooth01(0.05, 0.9, depth_below * 1.6);
	float foam = clamp(lip * (0.25 + 0.6 * s2) + aer * smooth01(0.50, 0.78, streak) * 0.55 + aer * 0.08, 0.0, 1.0);

	vec3 water = mix(shallow_color.rgb, deep_color.rgb, smooth01(0.15, 0.5, streak));
	water = mix(water, shallow_color.rgb * 1.2, lip * 0.5);
	vec3 col = mix(water, foam_color.rgb * 0.92, foam);
	// in basso tutto si fa nebbia
	float fog = smooth01(fade_start, bottom_y, y);
	col = mix(col, mist_color.rgb, fog * 0.8);

	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	ALBEDO = col;
	EMISSION = sky_color.rgb * fres * 0.35 * (1.0 - foam) + mist_color.rgb * fog * 0.12;
	ROUGHNESS = mix(0.12, 0.8, max(foam, fog));
	SPECULAR = mix(0.7, 0.15, foam);
	METALLIC = 0.0;
	float body = 1.0;
	ALPHA = body * (1.0 - fog) * basin * (0.9 + 0.1 * streak);
	ALPHA = max(ALPHA, 0.0);
	if (ALPHA < 0.01) {
		discard;
	}
}
