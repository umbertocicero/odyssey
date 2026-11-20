// Terreno della pianura di Troia: 6 strati PBR tileable in Texture2DArray, mescolati con la splat map
// e con l'altezza di ogni strato (le pietre del sentiero emergono dall'erba, la terra riempie le fessure).
// La roccia arriva dalla maschera delle pareti e usa la proiezione triplanare (niente stiramenti in verticale).
// Pensato per il renderer Compatibility: 5 sampler, nessuna feature solo Forward+.
// Riferimento di integrazione: assets/models/custom/terreno/README.md
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Slice: 0 prato_muschio, 1 terra, 2 terra_secca, 3 sentiero, 4 sabbia_ghiaia, 5 roccia
uniform sampler2DArray layer_albedo_height : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray layer_normal : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray layer_orm : filter_linear_mipmap, repeat_enable;
// R terra, G terra secca, B sentiero, A sabbia; il prato e' il resto (1 - somma)
uniform sampler2D splat_map : filter_linear, repeat_disable;
// R roccia (pareti), G occlusione del terreno, B densita' erba, A secchezza erba
uniform sampler2D mask_map : filter_linear, repeat_disable;

uniform vec4 tile_meters_a = vec4(2.0, 2.5, 3.0, 2.5); // prato, terra, terra secca, sentiero
uniform vec2 tile_meters_b = vec2(3.0, 4.0);           // sabbia, roccia
uniform float height_blend : hint_range(0.0, 1.0) = 0.5;
uniform float blend_contrast : hint_range(0.02, 1.0) = 0.25;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
uniform float terrain_ao : hint_range(0.0, 1.0) = 0.7;
uniform vec3 grass_tint : source_color = vec3(1.0);
// Rompe la ripetizione: secondo campione dello strato a scala e rotazione diverse, mescolato col rumore
uniform float anti_tiling : hint_range(0.0, 1.0) = 0.35;

varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float tile_of(int i) {
	if (i == 0) return tile_meters_a.x;
	if (i == 1) return tile_meters_a.y;
	if (i == 2) return tile_meters_a.z;
	if (i == 3) return tile_meters_a.w;
	if (i == 4) return tile_meters_b.x;
	return tile_meters_b.y;
}

vec2 layer_uv(vec2 p, int i) {
	return p / tile_of(i);
}

vec4 sample_alb(vec2 uv, int i, float mixv) {
	vec4 a = texture(layer_albedo_height, vec3(uv, float(i)));
	if (anti_tiling > 0.0) {
		mat2 r = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
		vec4 b = texture(layer_albedo_height, vec3(r * uv * 0.43 + 0.37, float(i)));
		a = mix(a, b, mixv * anti_tiling);
	}
	return a;
}

void fragment() {
	vec4 s = texture(splat_map, UV);
	vec4 m = texture(mask_map, UV);
	float rock = m.r;
	float w[6];
	w[1] = s.r; w[2] = s.g; w[3] = s.b; w[4] = s.a;
	w[0] = max(1.0 - s.r - s.g - s.b - s.a, 0.0);
	for (int i = 0; i < 5; i++) { w[i] *= (1.0 - rock); }
	w[5] = rock;

	vec2 p = world_pos.xz;
	// rumore economico per l'anti-tiling
	float n = sin(p.x * 0.31 + sin(p.y * 0.23) * 2.0) * sin(p.y * 0.27 + sin(p.x * 0.19) * 2.0) * 0.5 + 0.5;

	// triplanare solo per la roccia
	vec3 tw = pow(abs(normalize(world_nrm)), vec3(4.0));
	tw /= (tw.x + tw.y + tw.z);

	vec4 alb[6];
	float hb[6];
	float hmax = -10.0;
	for (int i = 0; i < 6; i++) {
		alb[i] = vec4(0.0);
		hb[i] = -10.0;
		if (w[i] > 0.002) {
			if (i == 5) {
				float t = tile_of(5);
				alb[i] = texture(layer_albedo_height, vec3(world_pos.xz / t, 5.0)) * tw.y
					+ texture(layer_albedo_height, vec3(world_pos.xy / t, 5.0)) * tw.z
					+ texture(layer_albedo_height, vec3(world_pos.zy / t, 5.0)) * tw.x;
			} else {
				alb[i] = sample_alb(layer_uv(p, i), i, n);
			}
			hb[i] = w[i] + alb[i].a * height_blend;
			hmax = max(hmax, hb[i]);
		}
	}
	float wsum = 0.0;
	vec3 albedo = vec3(0.0);
	vec3 nrm = vec3(0.0);
	vec3 orm = vec3(0.0);
	for (int i = 0; i < 6; i++) {
		float k = max(hb[i] - hmax + blend_contrast, 0.0);
		if (k > 0.0) {
			vec2 uv = (i == 5) ? world_pos.xz / tile_of(5) : layer_uv(p, i);
			vec3 c = alb[i].rgb;
			if (i == 0) c *= grass_tint;
			albedo += c * k;
			nrm += (texture(layer_normal, vec3(uv, float(i))).rgb * 2.0 - 1.0) * k;
			orm += texture(layer_orm, vec3(uv, float(i))).rgb * k;
			wsum += k;
		}
	}
	albedo /= max(wsum, 1e-4);
	orm /= max(wsum, 1e-4);
	nrm = normalize(nrm / max(wsum, 1e-4));

	ALBEDO = albedo * mix(1.0, m.g, terrain_ao * 0.5);
	ROUGHNESS = orm.g;
	METALLIC = 0.0;
	SPECULAR = 0.35;
	AO = orm.r * mix(1.0, m.g, terrain_ao);
	AO_LIGHT_AFFECT = 0.4;
	NORMAL_MAP = nrm * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = normal_strength;
}
