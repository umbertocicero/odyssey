// Ciuffi d'erba a cards (alpha-cutout) per MultiMesh: vento, occlusione cotta,
// translucenza in controluce e piegamento al passaggio di personaggi, proiettili e fuoco.
// Derivato da assets/models/custom/terreno/godot/erba_cards.gdshader (che non si modifica).
// Il piegamento arriva da una mappa di calpestio (trample_map) che GrassCards aggiorna
// ogni frame: un solo campionamento per vertice invece di un ciclo sugli interattori
// (il ciclo da 12 costava ~7 ms su GTX 860M), e nessun limite al numero di personaggi.
// Mesh: assets/models/custom/terreno/erba_ciuffi.gltf
//   COLOR.rgb = occlusione alla base, COLOR.a = translucenza (alta in punta)
//   UV2.x = peso del vento (0 base, 1 punta), UV2.y = fase casuale per card
// Istanza: traslazione + INSTANCE_CUSTOM (x angolo, y scala, z fase del vento) + colore = tinta.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert_wrap, specular_schlick_ggx;

uniform sampler2D albedo_alpha : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D card_normal : hint_normal, filter_linear_mipmap, repeat_disable;
// R translucenza, G roughness, B occlusione dentro il ciuffo
uniform sampler2D sss_rough_ao : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform float alpha_cut : hint_range(0.05, 0.95) = 0.5;
// Nitidezza del ritaglio: con le mipmap l'alpha dei fili sottili si sfuoca e i
// ciuffi diventano ventagli pieni ("pennellate"). Si campiona l'alpha con un
// bias di mip negativo e lo si riporta a un gradino largo un pixel (fwidth):
// i singoli fili restano distinti anche a distanza.
uniform float alpha_mip_bias : hint_range(-3.0, 0.0) = -1.0;
uniform float alpha_sharpness : hint_range(0.0, 1.0) = 1.0;
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);

uniform vec2 wind_direction = vec2(1.0, 0.3);
uniform float wind_strength : hint_range(0.0, 0.6) = 0.12;
uniform float wind_speed : hint_range(0.0, 5.0) = 1.2;
uniform float gust_size : hint_range(1.0, 40.0) = 9.0;
uniform float flutter : hint_range(0.0, 1.0) = 0.25;

uniform vec3 translucency_color : source_color = vec3(0.62, 0.72, 0.22);
uniform float translucency : hint_range(0.0, 2.0) = 0.9;

// Mappa di calpestio sul piano X-Z: RG = spinta (0.5 = nessuna), B = schiacciamento.
uniform sampler2D trample_map : filter_linear, repeat_disable;
uniform vec2 trample_origin = vec2(-26.0, -30.0);
uniform vec2 trample_size = vec2(52.0, 52.0);
uniform float push_strength : hint_range(0.0, 1.5) = 0.55;
uniform float push_flatten : hint_range(0.0, 1.0) = 0.6;

// LOD per distanza dalla camera: oltre lod_start metri si tiene solo una parte
// dei ciuffi (scelti dalla fase casuale dell'istanza) fino a lod_keep a lod_end;
// quelli rimasti si allargano per coprire lo stesso prato. I ciuffi scartati
// collassano in un punto: nessun pixel da disegnare.
uniform float lod_start = 12.0;
uniform float lod_end = 36.0;
uniform float lod_keep : hint_range(0.05, 1.0) = 0.3;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	float cam_dist = length(root - INV_VIEW_MATRIX[3].xyz);
	float keep = mix(1.0, lod_keep, smoothstep(lod_start, lod_end, cam_dist));
	float pick = INSTANCE_CUSTOM.w;
	if (pick > keep) {
		VERTEX = vec3(0.0, -10.0, 0.0);
	} else {
		float s = sin(INSTANCE_CUSTOM.x);
		float c = cos(INSTANCE_CUSTOM.x);
		vec3 v = VERTEX;
		v.xz = vec2(c * v.x - s * v.z, s * v.x + c * v.z);
		v *= (INSTANCE_CUSTOM.y > 0.0) ? INSTANCE_CUSTOM.y : 1.0;
		// I ciuffi rimasti si allargano (non si alzano) per coprire i vuoti.
		v.xz *= inversesqrt(keep);
		float w = UV2.x;
		vec2 dir = normalize(wind_direction);
		float t = TIME * wind_speed;
		float gust = sin(dot(root.xz, dir) * 6.2831 / gust_size - t) * 0.5 + 0.5;
		gust = gust * gust;
		float flt = sin(t * 3.7 + (UV2.y + INSTANCE_CUSTOM.z) * 6.2831 + root.x * 1.3 + root.z * 0.7) * flutter;
		vec2 d = dir * (0.25 + 0.75 * gust + flt) * wind_strength * w;

		vec4 tr = textureLod(trample_map, (root.xz - trample_origin) / trample_size, 0.0);
		float pressed = tr.b;
		d += (tr.rg * 2.0 - 1.0) * push_strength * w;
		float flat_down = length(d) * push_flatten * w + pressed * 0.1 * w;
		vec3 dw = vec3(d.x, -dot(d, d) * 1.5 - flat_down, d.y);
		// L'istanza ha solo la traslazione (base identità): lo spostamento è già nello spazio del modello.
		VERTEX = v + dw;
	}
}

void fragment() {
	vec4 a = texture(albedo_alpha, UV, alpha_mip_bias);
	float cov = a.a;
	float sharp = (cov - alpha_cut) / max(fwidth(cov), 0.0001) + 0.5;
	float alpha = mix(cov, sharp, alpha_sharpness);
	// Scarto esplicito prima di normal map, translucenza e luci: gran parte
	// dell'area delle cards è vuota e non deve pagare l'illuminazione.
	if (alpha < 0.5) {
		discard;
	}
	vec3 sra = texture(sss_rough_ao, UV).rgb;
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
