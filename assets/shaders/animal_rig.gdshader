shader_type spatial;
render_mode cull_disabled;
// Rig procedurale per animali statici (senza scheletro): le articolazioni sono ricavate dalla
// posizione del vertice nel modello (fronte -Z, piedi a y0). Zampe che oscillano attorno all'anca
// con ginocchio che si piega, collo e testa che ruotano attorno alla base del collo (peso crescente
// lungo il collo, così si piega invece di ruotare rigido), onda laterale della schiena, coda che ondeggia.
// Parametri per istanza: nessun materiale duplicato per animale.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float normal_depth = 1.0;
uniform float rough_scale = 1.0;

// (y0, altezza, centro z, lunghezza)
instance uniform vec4 dims = vec4(0.0, 1.0, 0.0, 1.0);
// (larghezza, base collo zf (negativa), base collo hy, lunghezza collo in zf)
instance uniform vec4 dims2 = vec4(0.5, -0.22, 0.8, 0.25);
// (ampiezza zampe rad, ampiezza testa rad, ampiezza coda m, ampiezza schiena m)
instance uniform vec4 style = vec4(0.4, 0.5, 0.05, 0.02);
// (camminata 0..1, fase andatura rad, testa -1 giu .. +1 su, sguardo -1..1)
instance uniform vec4 pose = vec4(0.0);
// (zampata 0..1, seme, respiro, 0)
instance uniform vec4 extra = vec4(0.0);

vec3 rot_x(vec3 p, vec3 pivot, float a) {
	vec3 r = p - pivot;
	float c = cos(a);
	float s = sin(a);
	return pivot + vec3(r.x, r.y * c - r.z * s, r.y * s + r.z * c);
}

vec3 rot_y(vec3 p, vec3 pivot, float a) {
	vec3 r = p - pivot;
	float c = cos(a);
	float s = sin(a);
	return pivot + vec3(r.x * c + r.z * s, r.y, -r.x * s + r.z * c);
}

void vertex() {
	float y0 = dims.x;
	float H = max(dims.y, 0.01);
	float cz = dims.z;
	float L = max(dims.w, 0.01);
	float W = max(dims2.x, 0.01);
	float walk = pose.x;
	float gait = pose.y;
	vec3 p = VERTEX;
	float hy = (p.y - y0) / H;
	float zf = (p.z - cz) / L;
	float xw = p.x / W;
	float leg_amp = style.x;

	// --- Zampe: oscillazione attorno all'anca, piede che si solleva, ginocchio piegato.
	float lm = 1.0 - smoothstep(0.38, 0.58, hy);               // 1 ai piedi, 0 nel corpo
	float sx = clamp(xw / 0.12, -1.0, 1.0);
	float sz = clamp(zf / 0.10, -1.0, 1.0);
	float ph = gait + 1.5707963 * (sx + 1.0) + 1.5707963 * (sz + 1.0);   // diagonali in coppia
	float hip = 0.58 * H;
	float below = max(hip - (p.y - y0), 0.0);
	float swing = sin(ph) * leg_amp * walk;
	float lift = max(cos(ph), 0.0) * walk;
	p.z += sin(swing) * below * lm * (0.6 + 0.4 * (1.0 - hy));
	p.y += lift * 0.07 * H * lm * (1.0 - hy / 0.58);
	// Zampata del piede anteriore sinistro (x > 0): si alza e si piega.
	float fl = smoothstep(0.0, 1.0, sx) * smoothstep(0.0, 1.0, -sz);
	float st = extra.x;
	p.y += st * fl * lm * 0.13 * H * (1.0 - hy / 0.58);
	p.z -= st * fl * lm * 0.05 * H;

	// --- Schiena: onda laterale lungo il corpo mentre cammina + dondolio del bacino.
	float body = smoothstep(0.35, 0.6, hy);
	p.x += sin(gait + zf * 4.0) * style.w * walk * body;
	p.y += sin(gait * 2.0 + zf * 3.0) * 0.006 * H * walk * body;
	// Respiro: il fianco si gonfia attorno all'asse del corpo.
	float br = extra.z;
	p.x += p.x * br * 0.6 * body;

	// --- Collo e testa: piegamento progressivo attorno alla base del collo.
	float nzf = dims2.y;
	float nhy = dims2.z;
	float reach = max(dims2.w, 0.05);
	float d = (-zf) - (-nzf);
	float u = clamp(d / reach, 0.0, 1.0);
	float wn = smoothstep(0.0, 1.0, u) * smoothstep(nhy - 0.35, nhy - 0.18, hy);
	vec3 pivot = vec3(0.0, y0 + nhy * H, cz + nzf * L);
	float head = pose.z;
	float look = pose.w;
	// Il segmento fra base e testa è diviso in due giunti (collo basso, testa) per una curva morbida.
	float a1 = head * style.y * 0.45 * smoothstep(0.0, 0.7, u);
	float a2 = head * style.y * 0.55 * smoothstep(0.5, 1.0, u);
	vec3 q = rot_x(p, pivot, (a1 + a2) * smoothstep(nhy - 0.35, nhy - 0.18, hy) * step(0.0, d));
	q = rot_y(q, pivot, look * 0.35 * wn);
	p = mix(p, q, step(0.0, d));

	// --- Coda: ondeggia in cima alla groppa (solo vertici centrali, lontani dalle zampe posteriori).
	float tm = smoothstep(0.38, 0.45, zf) * (1.0 - smoothstep(0.05, 0.13, abs(xw)));
	float tw = (zf - 0.38) / 0.12;
	float seed = extra.y;
	p.x += sin(TIME * 1.7 + seed + zf * 9.0) * style.z * tm * tw
		+ sin(TIME * 0.6 + seed) * style.z * 0.5 * tm * tw;

	VERTEX = p;
}

void fragment() {
	vec4 a = texture(albedo_tex, UV) * albedo_color;
	ALBEDO = a.rgb;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
	ROUGHNESS = clamp(texture(rough_tex, UV).g * rough_scale, 0.0, 1.0);
	METALLIC = 0.0;
	SPECULAR = 0.35;
}
