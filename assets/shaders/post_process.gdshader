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
	float n = fract(sin(dot(FRAGCOORD.xy + fract(TIME) * 61.7, vec2(12.9898, 78.233))) * 43758.5453);
	// Grana: più visibile nei mezzi toni, quasi nulla nei bianchi.
	float glum = dot(col, vec3(0.299, 0.587, 0.114));
	col += (n - 0.5) * (grain * (1.0 - glum * 0.6) + 1.0 / 255.0);
	COLOR = vec4(col, 1.0);
}
