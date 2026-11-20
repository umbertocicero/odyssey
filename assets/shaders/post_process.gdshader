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
uniform float saturation : hint_range(0.5, 1.6) = 1.1;
uniform vec3 warm_tint : source_color = vec3(1.04, 1.0, 0.94);
uniform float vignette : hint_range(0.0, 1.0) = 0.25;
// Foschia di distanza: la parte alta dello schermo (la più lontana, vista
// dall'alto) si schiarisce verso il colore caldo del tramonto. 0 = spenta.
uniform float haze_strength : hint_range(0.0, 0.6) = 0.2;
uniform vec3 haze_color : source_color = vec3(0.98, 0.68, 0.50);
// Fino a che altezza dello schermo (0 = in alto, 1 = in basso) arriva la foschia.
uniform float haze_reach : hint_range(0.1, 1.0) = 0.6;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	float d = max(abs(UV.y - focus_center) - focus_width, 0.0) / focus_falloff;
	float radius = clamp(d, 0.0, 1.0) * blur_amount;
	vec3 col = texture(TEXTURE, UV).rgb;
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
	vec2 q = UV - 0.5;
	col *= 1.0 - vignette * dot(q, q) * 2.0;
	// Foschia: sfumata in modo morbido e solo sopra la zona di gioco.
	float haze = smoothstep(haze_reach, 0.0, UV.y);
	col = mix(col, haze_color * max(grey, 0.55), haze * haze * haze_strength);
	// Rumore minimo: elimina le bande nei gradienti (cielo, nebbia).
	float n = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
	col += (n - 0.5) / 255.0;
	COLOR = vec4(col, 1.0);
}
