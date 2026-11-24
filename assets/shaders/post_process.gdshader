shader_type canvas_item;
// Post-process dell'immagine 3D, in ordine: sfocatura da miniatura (tilt-shift),
// colore caldo e vignettatura. Qui, DOPO questi passaggi, andrà il filtro
// pixel art (gaussiano + quantizzazione). Con blur_amount = 0 la sfocatura è
// spenta e non costa nulla (nessuna lettura extra della texture).

// Quanta sfocatura ai bordi (in pixel di raggio massimo). 0 = spenta.
uniform float blur_amount : hint_range(0.0, 8.0) = 3.0;
// Altezza (0..1 sullo schermo) del centro nitido.
uniform float focus_center : hint_range(0.0, 1.0) = 0.55;
// Metà altezza della fascia nitida.
uniform float focus_width : hint_range(0.0, 0.5) = 0.22;
// Quanto presto la sfocatura cresce fuori dalla fascia nitida.
uniform float focus_falloff : hint_range(0.05, 1.0) = 0.35;
uniform float saturation : hint_range(0.5, 1.6) = 0.88;
uniform vec3 warm_tint : source_color = vec3(1.02, 1.0, 0.97);
uniform float vignette : hint_range(0.0, 1.0) = 0.45;
// Color grading da cinema (look "film"): toni freddi nelle ombre, caldi nelle luci,
// curva a S per il contrasto e neri leggermente alzati. Costo: solo calcoli, nessuna lettura.
uniform vec3 shadow_tint : source_color = vec3(0.80, 0.93, 1.0);
uniform vec3 highlight_tint : source_color = vec3(1.08, 1.0, 0.88);
uniform float grade_amount : hint_range(0.0, 1.0) = 0.65;
uniform float contrast : hint_range(0.8, 1.6) = 1.22;
uniform float black_lift : hint_range(0.0, 0.1) = 0.02;
// Grana pellicola animata (0 = spenta) e aberrazione cromatica ai bordi (0 = spenta, costa 2 letture).
uniform float grain : hint_range(0.0, 0.15) = 0.045;
uniform float chroma : hint_range(0.0, 3.0) = 0.6;
// Foschia di distanza: la parte alta dello schermo (la più lontana, vista
// dall'alto) si schiarisce verso il colore caldo del tramonto. 0 = spenta.
uniform float haze_strength : hint_range(0.0, 0.6) = 0.2;
uniform vec3 haze_color : source_color = vec3(0.82, 0.76, 0.70);
// Fino a che altezza dello schermo (0 = in alto, 1 = in basso) arriva la foschia.
uniform float haze_reach : hint_range(0.1, 1.0) = 0.6;

// --- Pixel art sperimentale (opzionale) ---------------------------------------
// pixelart_mode: 0 = spento (non costa nulla), 1 = palette fissa + Bayer (da "Pixel Dither"
// di Francisco Cidade, CC0), 2 = rampa di luminanza a pochi toni + Bayer 8x8 (idea di
// samuelbigos/godot_dither_shader, MIT: dither sulla luminosità tra due toni adiacenti).
// I pixel grossi li dà RenderPipeline (stretch_shrink): qui una cella = un texel.
uniform int pixelart_mode : hint_range(0, 2) = 0;
// Solo modo 1: 0 = PICO-8, 1 = Sweetie 16, 2 = Endesga 32.
uniform int pixelart_palette : hint_range(0, 2) = 2;
uniform float pixelart_dither : hint_range(0.0, 1.0) = 0.5;
uniform float pixelart_contrast : hint_range(0.5, 2.0) = 1.1;

const vec3 PA_PALETTE[64] = vec3[64](
	vec3(0.0, 0.0, 0.0), vec3(29.0, 43.0, 83.0), vec3(126.0, 37.0, 83.0), vec3(0.0, 135.0, 81.0),
	vec3(171.0, 82.0, 54.0), vec3(95.0, 87.0, 79.0), vec3(194.0, 195.0, 199.0), vec3(255.0, 241.0, 232.0),
	vec3(255.0, 0.0, 77.0), vec3(255.0, 163.0, 0.0), vec3(255.0, 236.0, 39.0), vec3(0.0, 228.0, 54.0),
	vec3(41.0, 173.0, 255.0), vec3(131.0, 118.0, 156.0), vec3(255.0, 119.0, 168.0), vec3(255.0, 204.0, 170.0),
	vec3(26.0, 28.0, 44.0), vec3(93.0, 39.0, 93.0), vec3(177.0, 62.0, 83.0), vec3(239.0, 125.0, 87.0),
	vec3(255.0, 205.0, 117.0), vec3(167.0, 240.0, 112.0), vec3(56.0, 183.0, 100.0), vec3(37.0, 113.0, 121.0),
	vec3(41.0, 54.0, 111.0), vec3(59.0, 93.0, 201.0), vec3(65.0, 166.0, 246.0), vec3(115.0, 239.0, 247.0),
	vec3(244.0, 244.0, 244.0), vec3(148.0, 176.0, 194.0), vec3(86.0, 108.0, 134.0), vec3(51.0, 60.0, 87.0),
	vec3(190.0, 74.0, 47.0), vec3(215.0, 118.0, 67.0), vec3(234.0, 212.0, 170.0), vec3(228.0, 166.0, 114.0),
	vec3(184.0, 111.0, 80.0), vec3(115.0, 62.0, 57.0), vec3(62.0, 39.0, 49.0), vec3(162.0, 38.0, 51.0),
	vec3(228.0, 59.0, 68.0), vec3(247.0, 118.0, 34.0), vec3(254.0, 174.0, 52.0), vec3(254.0, 231.0, 97.0),
	vec3(99.0, 199.0, 77.0), vec3(62.0, 137.0, 72.0), vec3(38.0, 92.0, 66.0), vec3(25.0, 60.0, 62.0),
	vec3(18.0, 78.0, 137.0), vec3(0.0, 153.0, 219.0), vec3(44.0, 232.0, 245.0), vec3(255.0, 255.0, 255.0),
	vec3(192.0, 203.0, 220.0), vec3(139.0, 155.0, 180.0), vec3(90.0, 105.0, 136.0), vec3(58.0, 68.0, 102.0),
	vec3(38.0, 43.0, 68.0), vec3(24.0, 20.0, 37.0), vec3(255.0, 0.0, 68.0), vec3(104.0, 56.0, 108.0),
	vec3(181.0, 80.0, 136.0), vec3(246.0, 117.0, 122.0), vec3(232.0, 183.0, 150.0), vec3(194.0, 133.0, 105.0)
);
// Rampa del modo 2: dal buio ai chiari, toni smorzati da Età del bronzo.
const vec3 PA_RAMP[6] = vec3[6](
	vec3(0.06, 0.04, 0.05), vec3(0.24, 0.15, 0.13), vec3(0.45, 0.30, 0.20),
	vec3(0.66, 0.48, 0.28), vec3(0.86, 0.72, 0.46), vec3(0.97, 0.91, 0.72));

const int PA_BAYER4[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
const int PA_BAYER2[4] = int[4](0, 2, 3, 1);

float pa_bayer8(ivec2 p) {
	int v4 = PA_BAYER4[(p.y & 3) * 4 + (p.x & 3)];
	return (float(4 * v4 + PA_BAYER2[((p.y >> 2) & 1) * 2 + ((p.x >> 2) & 1)]) + 0.5) / 64.0;
}

vec3 pa_nearest(vec3 c, int start, int count) {
	float best = 1e9;
	vec3 result = vec3(0.0);
	for (int i = 0; i < count; i++) {
		vec3 p = PA_PALETTE[start + i] / 255.0;
		vec3 d = c - p;
		float dist = dot(d * d, vec3(0.3, 0.59, 0.11));
		if (dist < best) { best = dist; result = p; }
	}
	return result;
}

vec3 pixelart_apply(vec3 col, ivec2 cell) {
	vec3 c = (col - 0.5) * pixelart_contrast + 0.5;
	float th = pa_bayer8(cell);
	if (pixelart_mode == 1) {
		// Palette con 16 o 32 colori: più ce ne sono, meno spread serve.
		float spread = pixelart_palette == 2 ? 0.15 : 0.2;
		c = clamp(c + (th - 0.5) * pixelart_dither * spread, 0.0, 1.0);
		return pixelart_palette == 0 ? pa_nearest(c, 0, 16)
			: (pixelart_palette == 1 ? pa_nearest(c, 16, 16) : pa_nearest(c, 32, 32));
	}
	float lum = clamp(dot(c, vec3(0.299, 0.587, 0.114)), 0.0, 0.99999);
	float x = lum * 5.0;
	int i = int(floor(x));
	float f = fract(x);
	return PA_RAMP[(f < mix(0.5, th, pixelart_dither)) ? i : i + 1];
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	float d = max(abs(UV.y - focus_center) - focus_width, 0.0) / focus_falloff;
	float radius = clamp(d, 0.0, 1.0) * blur_amount;
	vec3 col = texture(TEXTURE, UV).rgb;
	vec2 qc = UV - 0.5;
	if (chroma > 0.0) {
		// Aberrazione cromatica da obiettivo: rosso e blu si separano verso i bordi.
		vec2 off = qc * dot(qc, qc) * chroma * 14.0 * px;
		col.r = texture(TEXTURE, UV + off).r;
		col.b = texture(TEXTURE, UV - off).b;
	}
	if (radius > 0.25) {
		// 8 letture in cerchio più il centro: sfocatura economica.
		vec3 sum = col;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.785398;
			sum += texture(TEXTURE, UV + vec2(cos(a), sin(a)) * px * radius).rgb;
		}
		col = sum / 9.0;
	}
	float grey = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(grey), col, saturation) * warm_tint;
	// Color grading: split toning, curva a S attorno al grigio medio, neri alzati.
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 toned = col * mix(shadow_tint, highlight_tint, smoothstep(0.1, 0.7, lum));
	col = mix(col, toned, grade_amount);
	col = clamp((col - 0.5) * contrast + 0.5, 0.0, 1.0);
	col = col * (1.0 - black_lift) + black_lift;
	vec2 q = UV - 0.5;
	col *= 1.0 - vignette * dot(q, q) * 2.0;
	// Foschia: sfumata in modo morbido e solo sopra la zona di gioco.
	float haze = smoothstep(haze_reach, 0.0, UV.y);
	col = mix(col, haze_color * max(grey, 0.55), haze * haze * haze_strength);
	// Rumore minimo: elimina le bande nei gradienti (cielo, nebbia).
	vec2 noise_px = FRAGCOORD.xy;
	if (pixelart_mode > 0) {
		noise_px = floor(UV / px); // griglia dei pixel grossi, non quella dello schermo
	}
	float n = fract(sin(dot(noise_px + fract(TIME) * 61.7, vec2(12.9898, 78.233))) * 43758.5453);
	// Grana: più visibile nei mezzi toni, quasi nulla nei bianchi.
	float glum = dot(col, vec3(0.299, 0.587, 0.114));
	col += (n - 0.5) * (grain * (1.0 - glum * 0.6) + 1.0 / 255.0);
	if (pixelart_mode > 0) {
		col = pixelart_apply(clamp(col, 0.0, 1.0), ivec2(floor(UV / px)));
	}
	COLOR = vec4(col, 1.0);
}
