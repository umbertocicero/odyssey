shader_type canvas_item;
// Sovrapposizione a tutto schermo del duello in prima persona: gradazione cinematografica (colore
// smorzato, contrasto, vignettatura, grana di pellicola) e sangue sull'obiettivo (schizzi con colature)
// quando Ulisse viene ferito. Una sola passata, poche letture di texture: costa poco anche su GPU deboli.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float strength : hint_range(0.0, 1.0) = 1.0;   // dissolvenza dell'intero effetto
uniform float vignette : hint_range(0.0, 1.0) = 0.6;
uniform float grain : hint_range(0.0, 0.2) = 0.045;
uniform float desaturate : hint_range(0.0, 1.0) = 0.18;
uniform float contrast : hint_range(0.8, 1.6) = 1.12;
uniform vec3 tint = vec3(1.0, 0.98, 0.95);            // luce calda del tramonto
uniform float hurt : hint_range(0.0, 1.0) = 0.0;       // lampo rosso ai bordi quando si è colpiti
uniform float low_health : hint_range(0.0, 1.0) = 0.0; // pulsazione quando la vita è bassa
uniform float aspect = 1.7778;
// Schizzi sull'obiettivo: xy = posizione (0..1), z = raggio (in altezza schermo), w = età (s), < 0 = spento.
uniform vec4 splats[6];

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col = texture(screen_tex, uv).rgb;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 graded = mix(col, vec3(luma), desaturate);
	graded = (graded - 0.5) * contrast + 0.5;
	graded *= tint;
	vec2 c = uv - 0.5;
	c.x *= aspect;
	float vig = smoothstep(0.35, 1.05, length(c));
	graded *= 1.0 - vig * vignette;
	float g = hash(uv * vec2(1280.0, 720.0) + fract(TIME) * 91.7) - 0.5;
	graded += g * grain;
	col = mix(col, graded, strength);

	// Ferita: bordi rossi che pulsano.
	float edge = smoothstep(0.25, 1.0, length(c));
	float pulse = 0.5 + 0.5 * sin(TIME * 5.0);
	col = mix(col, vec3(0.45, 0.02, 0.02), clamp(edge * (hurt * 0.85 + low_health * 0.28 * (0.55 + 0.45 * pulse)), 0.0, 0.9) * strength);

	// Sangue sull'obiettivo.
	float blood_a = 0.0;
	float shine = 0.0;
	for (int i = 0; i < 6; i++) {
		vec4 s = splats[i];
		if (s.w < 0.0) {
			continue;
		}
		vec2 d = uv - s.xy;
		d.x *= aspect;
		float ang = atan(d.y, d.x);
		float wob = 0.72 + 0.3 * noise(vec2(ang * 2.0 + float(i) * 7.0, float(i)));
		wob += 0.12 * noise(vec2(ang * 7.0, float(i) * 3.0));
		float r = length(d);
		float body = smoothstep(s.z * wob, s.z * wob * 0.82, r);
		// Gocce satelliti attorno alla macchia.
		float sat = noise(d * 38.0 + float(i) * 11.0);
		body = max(body, smoothstep(0.74, 0.8, sat) * smoothstep(s.z * 1.9, s.z * 0.8, r) * 0.75);
		// Colatura verso il basso: cresce con l'età.
		float drip_len = min(s.w * 0.035, s.z * 2.4);
		float colx = floor(d.x / (s.z * 0.28));
		float col_h = hash(vec2(colx, float(i)));
		float in_col = step(0.62, col_h) * step(abs(d.x), s.z * 0.75);
		float cx = fract(d.x / (s.z * 0.28)) - 0.5;
		float streak = smoothstep(0.2, 0.08, abs(cx)) * in_col * step(0.0, d.y) * step(d.y, drip_len * (0.4 + col_h));
		float a = clamp(max(body, streak * 0.9), 0.0, 1.0) * clamp((7.0 - s.w) / 2.0, 0.0, 1.0);
		blood_a = max(blood_a, a);
		shine = max(shine, a * smoothstep(0.2, 0.0, abs(noise(d * 20.0) - 0.62)));
	}
	// Sangue fresco: rosso scuro e denso, quasi nero dove è più spesso, con riflessi umidi.
	vec3 blood = mix(vec3(0.48, 0.02, 0.018), vec3(0.16, 0.004, 0.004), noise(uv * 14.0) * 0.8 + blood_a * 0.2);
	blood += vec3(0.5, 0.35, 0.3) * shine * 0.35;
	col = mix(col, blood, blood_a * 0.94 * strength);
	COLOR = vec4(col, 1.0);
}
