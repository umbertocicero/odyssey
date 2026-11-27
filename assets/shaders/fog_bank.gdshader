// Nebbia di confine al bordo nord del diorama (lato Troia): non e' un muro ma una densita' che cresce piano dal diorama
// (z = ramp_z0) verso la pianura troiana (z = ramp_z1). Strati verticali irregolari (rumore) e veli orizzontali a varie
// quote, che scorrono lentamente; i bordi si sfumano nella profondita' della scena (soft particles) e ai lati.
// Nel finale `open` apre un corridoio lungo il sentiero (corr_*) e dirada il resto.
// Compatibility renderer: niente FogVolume, solo quad con alpha, due letture di rumore e una di profondita'.
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 tint : source_color = vec3(0.82, 0.70, 0.62);
uniform float density : hint_range(0.0, 1.0) = 0.3;
uniform float bottom_y = -1.5;
uniform float top_y = 15.0;
uniform float drift = 0.010;
uniform float ramp_z0 = -13.0;    // qui la nebbia comincia (appena percettibile)
uniform float ramp_z1 = -31.0;    // qui e' alla massima densita'
uniform float soft_depth = 1.8;   // sfumatura contro terreno e alberi
uniform float open : hint_range(0.0, 1.0) = 0.0;
uniform float corr_x0 = 15.2;
uniform float corr_slope = -0.206;
uniform float corr_z0 = -26.5;
uniform float layer_seed = 0.0;
uniform bool horizontal = false;
uniform float flat_alpha = 0.5;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wpos.xy * vec2(0.040, 0.055) + vec2(wpos.z * 0.021 + TIME * drift + layer_seed, 0.0);
	if (horizontal) {
		uv = wpos.xz * vec2(0.035, 0.045) + vec2(TIME * drift + layer_seed, layer_seed * 1.7 - TIME * drift * 0.6);
	}
	float n1 = texture(noise_tex, uv).r;
	float n2 = texture(noise_tex, uv * 2.7 + vec2(0.31 + layer_seed, TIME * drift * 0.8)).g;
	float rough = n1 * 0.65 + n2 * 0.35;

	// crescita dolce verso la pianura troiana (profondita' del mondo, non una parete)
	float zk = 1.0 - smoothstep(ramp_z1, ramp_z0, wpos.z);
	zk = zk * zk * (3.0 - 2.0 * zk);
	float a;
	if (horizontal) {
		a = flat_alpha * zk * smoothstep(0.22, 0.85, rough + 0.12);
	} else {
		float h = clamp((wpos.y - bottom_y) / (top_y - bottom_y), 0.0, 1.0);
		// cima frastagliata e irregolare; piu' fitta in basso
		float body = 1.0 - smoothstep(0.15, 1.0, h + (rough - 0.5) * 0.9);
		a = body * (0.45 + 0.8 * n2) * density * (0.25 + 0.75 * zk);
		a *= smoothstep(0.0, 0.06, h);
	}
	// bordi laterali: si perde nel nulla, nessun margine visibile
	a *= 1.0 - smoothstep(32.0, 72.0, abs(wpos.x));
	// corridoio del finale
	float cx = corr_x0 + corr_slope * (wpos.z - corr_z0);
	float c = 1.0 - smoothstep(4.0, 12.0, abs(wpos.x - cx));
	a *= 1.0 - open * mix(0.82, 1.0, c);
	// sfumatura contro la geometria (terreno, alberi, fiume): niente linee nette d'intersezione
	float depth = texture(depth_tex, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float diff = -view.z + VERTEX.z;
	a *= clamp(diff / soft_depth, 0.0, 1.0);
	// luce che attraversa la foschia: chiazze piu' calde e luminose dove il rumore e' basso
	vec3 warm = tint * vec3(1.28, 1.12, 0.92);
	ALBEDO = mix(tint * 0.92, warm, smoothstep(0.35, 0.8, n1));
	ALPHA = clamp(a, 0.0, 1.0);
}
