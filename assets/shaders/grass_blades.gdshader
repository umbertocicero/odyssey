// Prato a lame vere (Poly Haven grass_medium_01): MultiMesh di ciuffi piccoli e fitti.
// Stesse uniform di grass_cards.gdshader (tint, wind_*, trample_*, lod_*), così
// NightCycle, WeatherFx e GrassCards lo pilotano senza saperlo.
// Le mesh non hanno UV2 né colori: il peso del vento si ricava dall'altezza del vertice.
// Istanza: traslazione + INSTANCE_CUSTOM (x angolo, y scala altezza, z fase, w soglia LOD)
//   + COLOR (rgb = tinta, a = secchezza 0..1: dal verde al paglierino, più forte in punta).
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert_wrap, specular_schlick_ggx;

uniform sampler2D albedo_alpha : source_color, filter_linear_mipmap, repeat_disable;
// Variante secca della stessa texture (paglierino): si mescola a quella verde.
uniform sampler2D dry_albedo : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 green_base : source_color = vec3(0.08, 0.17, 0.04);
uniform vec3 green_tip : source_color = vec3(0.30, 0.44, 0.10);
uniform sampler2D card_normal : hint_normal, filter_linear_mipmap, repeat_disable;
uniform sampler2D rough_map : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform float alpha_cut : hint_range(0.05, 0.95) = 0.5;
uniform float alpha_mip_bias : hint_range(-3.0, 0.0) = -0.7;
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);

// Larghezza delle lame rispetto al modello (1 = originale scalato).
uniform float width_scale : hint_range(0.3, 1.5) = 1.0;
// Inclinazione comune dovuta al vento: tutte le lame pendono nello stesso verso.
uniform float lean : hint_range(0.0, 0.5) = 0.12;

uniform vec2 wind_direction = vec2(1.0, 0.3);
uniform float wind_strength : hint_range(0.0, 0.6) = 0.12;
uniform float wind_speed : hint_range(0.0, 5.0) = 1.2;
uniform float gust_size : hint_range(1.0, 40.0) = 9.0;
uniform float flutter : hint_range(0.0, 1.0) = 0.2;

uniform vec3 translucency_color : source_color = vec3(0.62, 0.72, 0.22);
uniform float translucency : hint_range(0.0, 2.0) = 0.8;

uniform sampler2D trample_map : filter_linear, repeat_disable;
uniform vec2 trample_origin = vec2(-26.0, -30.0);
uniform vec2 trample_size = vec2(52.0, 52.0);
uniform float push_strength : hint_range(0.0, 1.5) = 0.55;
uniform float push_flatten : hint_range(0.0, 1.0) = 0.6;

uniform float lod_start = 12.0;
uniform float lod_end = 36.0;
uniform float lod_keep : hint_range(0.05, 1.0) = 0.3;

varying float height01;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	float cam_dist = length(root - INV_VIEW_MATRIX[3].xyz);
	float keep = mix(1.0, lod_keep, smoothstep(lod_start, lod_end, cam_dist));
	float pick = INSTANCE_CUSTOM.w;
	height01 = clamp(VERTEX.y / 0.28, 0.0, 1.0);
	if (pick > keep) {
		VERTEX = vec3(0.0, -10.0, 0.0);
	} else {
		float s = sin(INSTANCE_CUSTOM.x);
		float c = cos(INSTANCE_CUSTOM.x);
		vec3 v = VERTEX;
		float w = pow(clamp(v.y / 0.25, 0.0, 1.5), 1.5);
		v.xz = vec2(c * v.x - s * v.z, s * v.x + c * v.z);
		float sy = INSTANCE_CUSTOM.y > 0.0 ? INSTANCE_CUSTOM.y : 1.0;
		// Larghezza: segue l'altezza ma più lentamente (lame sottili anche se alte).
		v.xz *= width_scale * sqrt(sy) * inversesqrt(keep);
		v.y *= sy;
		vec2 dir = normalize(wind_direction);
		float t = TIME * wind_speed;
		float gust = sin(dot(root.xz, dir) * 6.2831 / gust_size - t) * 0.5 + 0.5;
		gust = gust * gust;
		float flt = sin(t * 3.7 + INSTANCE_CUSTOM.z * 6.2831 + root.x * 1.3 + root.z * 0.7) * flutter;
		// Piega comune (lean) + raffica; la variazione per ciuffo è piccola.
		vec2 d = dir * (lean + (0.2 + 0.8 * gust + flt) * wind_strength) * w * sy;
		vec4 tr = textureLod(trample_map, (root.xz - trample_origin) / trample_size, 0.0);
		d += (tr.rg * 2.0 - 1.0) * push_strength * w;
		float flat_down = length(d) * push_flatten + tr.b * 0.1 * w;
		VERTEX = v + vec3(d.x, -dot(d, d) * 1.5 - flat_down, d.y);
	}
}

void fragment() {
	vec4 a = texture(albedo_alpha, UV, alpha_mip_bias);
	float cov = a.a;
	float sharp = (cov - alpha_cut) / max(fwidth(cov), 0.0001) + 0.5;
	if (sharp < 0.5) {
		discard;
	}
	float dry = COLOR.a;
	// La texture verde è molto scura: se ne tiene solo il dettaglio (luminanza) e il
	// colore viene dal gradiente base -> punta; la secca arriva dalla texture paglierino.
	float detail = clamp(dot(a.rgb, vec3(0.3, 0.59, 0.11)) / 0.06, 0.45, 1.8);
	vec3 green = mix(green_base, green_tip, smoothstep(0.0, 0.9, height01)) * detail;
	vec3 straw = texture(dry_albedo, UV, alpha_mip_bias).rgb * 0.8;
	vec3 alb = mix(green, straw, clamp(dry * (0.3 + 0.7 * height01), 0.0, 1.0));
	ALBEDO = alb * tint * COLOR.rgb;
	ROUGHNESS = clamp(texture(rough_map, UV).r, 0.5, 1.0);
	SPECULAR = 0.2;
	NORMAL_MAP = texture(card_normal, UV).rgb;
	NORMAL_MAP_DEPTH = 0.5;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	BACKLIGHT = translucency_color * translucency * height01;
	AO = mix(0.45, 1.0, smoothstep(0.0, 0.5, height01));
	AO_LIGHT_AFFECT = 0.3;
}
