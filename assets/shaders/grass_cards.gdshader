// Ciuffi d'erba a cards (alpha-cutout) per MultiMesh: vento, occlusione cotta,
// translucenza in controluce e piegamento al passaggio di personaggi, proiettili e fuoco.
// Derivato da assets/models/custom/terreno/godot/erba_cards.gdshader (che non si modifica):
// aggiunge gli interattori di GrassField / grass.gdshader (stesse uniform), così l'erba
// nuova si piega come quella procedurale.
// Mesh: assets/models/custom/terreno/erba_ciuffi.gltf
//   COLOR.rgb = occlusione alla base, COLOR.a = translucenza (alta in punta)
//   UV2.x = peso del vento (0 base, 1 punta), UV2.y = fase casuale per card
// Istanza: traslazione + INSTANCE_CUSTOM (x angolo, y scala, z fase del vento) + colore = tinta.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert_wrap, specular_schlick_ggx;

const int MAX_INTERACTORS = 12;

uniform sampler2D albedo_alpha : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D card_normal : hint_normal, filter_linear_mipmap, repeat_disable;
// R translucenza, G roughness, B occlusione dentro il ciuffo
uniform sampler2D sss_rough_ao : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform float alpha_cut : hint_range(0.05, 0.95) = 0.5;
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);

uniform vec2 wind_direction = vec2(1.0, 0.3);
uniform float wind_strength : hint_range(0.0, 0.6) = 0.12;
uniform float wind_speed : hint_range(0.0, 5.0) = 1.2;
uniform float gust_size : hint_range(1.0, 40.0) = 9.0;
uniform float flutter : hint_range(0.0, 1.0) = 0.25;

uniform vec3 translucency_color : source_color = vec3(0.62, 0.72, 0.22);
uniform float translucency : hint_range(0.0, 2.0) = 0.9;

// Interattori: xyz = posizione nel mondo, w = raggio d'azione (0 = spento).
uniform vec4 interactors[MAX_INTERACTORS];
uniform float push_strength : hint_range(0.0, 1.5) = 0.55;
uniform float push_flatten : hint_range(0.0, 1.0) = 0.6;

void vertex() {
	float s = sin(INSTANCE_CUSTOM.x);
	float c = cos(INSTANCE_CUSTOM.x);
	vec3 v = VERTEX;
	v.xz = vec2(c * v.x - s * v.z, s * v.x + c * v.z);
	v *= (INSTANCE_CUSTOM.y > 0.0) ? INSTANCE_CUSTOM.y : 1.0;
	vec3 root = MODEL_MATRIX[3].xyz;
	float w = UV2.x;
	vec2 dir = normalize(wind_direction);
	float t = TIME * wind_speed;
	float gust = sin(dot(root.xz, dir) * 6.2831 / gust_size - t) * 0.5 + 0.5;
	gust = gust * gust;
	float flt = sin(t * 3.7 + (UV2.y + INSTANCE_CUSTOM.z) * 6.2831 + root.x * 1.3 + root.z * 0.7) * flutter;
	vec2 d = dir * (0.25 + 0.75 * gust + flt) * wind_strength * w;

	float pressed = 0.0;
	for (int i = 0; i < MAX_INTERACTORS; i++) {
		vec4 it = interactors[i];
		if (it.w <= 0.001) {
			continue;
		}
		vec2 away = root.xz - it.xz;
		float dist = length(away);
		float f = 1.0 - smoothstep(0.0, it.w, dist);
		f *= f;
		f *= 1.0 - smoothstep(0.6, 1.4, abs(root.y - it.y));
		vec2 push_dir = dist > 0.001 ? away / dist : vec2(1.0, 0.0);
		d += push_dir * f * push_strength * w;
		pressed = max(pressed, f);
	}
	float flat_down = length(d) * push_flatten * w + pressed * 0.1 * w;
	vec3 dw = vec3(d.x, -dot(d, d) * 1.5 - flat_down, d.y);
	VERTEX = v + inverse(mat3(MODEL_MATRIX)) * dw;
}

void fragment() {
	vec4 a = texture(albedo_alpha, UV);
	vec3 sra = texture(sss_rough_ao, UV).rgb;
	ALPHA = a.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ALBEDO = a.rgb * tint * COLOR.rgb;
	ROUGHNESS = sra.g;
	SPECULAR = 0.25;
	NORMAL_MAP = texture(card_normal, UV).rgb;
	NORMAL_MAP_DEPTH = 0.6;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	BACKLIGHT = translucency_color * translucency * sra.r * COLOR.a;
	AO = sra.b;
	AO_LIGHT_AFFECT = 0.25;
}
