shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
// Fiamma di torcia/braciere: un solo quad che guarda la camera ma resta dritto (la fiamma sale sempre verso l'alto
// nel mondo, anche se la torcia è inclinata nella mano). Forma, guizzo e colore sono procedurali: niente texture,
// quindi nessuna VRAM. La fase è per torcia (uniform), vento e intensità arrivano da TorchFlame.

uniform vec2 size = vec2(0.34, 0.6);       // larghezza, altezza in metri
uniform float phase = 0.0;
uniform vec2 wind = vec2(0.1, 0.0);        // piano XZ del mondo, già scalato
uniform float intensity = 1.0;
uniform vec3 core_color : source_color = vec3(1.0, 0.92, 0.62);
uniform vec3 mid_color : source_color = vec3(1.0, 0.52, 0.12);
uniform vec3 edge_color : source_color = vec3(0.75, 0.14, 0.03);

varying float v_lean;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.1 + 7.3) * 0.3 + vnoise(p * 4.3 + 1.7) * 0.15;
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 to_cam = INV_VIEW_MATRIX[3].xyz - origin;
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 right = normalize(cross(up, to_cam));
	// altezza che respira: la fiamma si allunga e si accorcia
	float t = TIME + phase;
	float breathe = 1.0 + 0.16 * sin(t * 9.0) * sin(t * 3.7 + 1.0) + 0.08 * sin(t * 17.0 + 2.0);
	vec3 p = right * VERTEX.x * size.x + up * (VERTEX.y + 0.5) * size.y * breathe;
	// la punta si piega con il vento e ondeggia piano
	float h = VERTEX.y + 0.5;
	float sway = sin(t * 5.3) * 0.05 + sin(t * 8.9 + 1.3) * 0.03;
	p += (vec3(wind.x, 0.0, wind.y) + right * sway) * h * h * size.y;
	v_lean = h;
	vec4 w = vec4(origin + p, 1.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * w;
}

void fragment() {
	float t = TIME + phase;
	vec2 uv = UV;
	float h = 1.0 - uv.y;                 // 0 base, 1 punta
	float x = (uv.x - 0.5) * 2.0;         // -1..1
	// il rumore scorre verso l'alto e deforma i bordi (lingue di fuoco)
	float n1 = fbm(vec2(x * 1.6 + phase, h * 2.2 - t * 2.6));
	float n2 = fbm(vec2(x * 3.1 - phase, h * 3.6 - t * 4.1) + 9.0);
	x += (n1 - 0.5) * 0.9 * h + (n2 - 0.5) * 0.35 * h;
	float width = mix(0.78, 0.04, pow(h, 0.85));
	float body = 1.0 - smoothstep(width * 0.55, width, abs(x));
	// lingue che si staccano in cima
	float tongue = smoothstep(0.35, 0.85, n2 + (1.0 - h) * 0.55);
	float top_fade = 1.0 - smoothstep(0.62 + 0.25 * n1, 1.0, h);
	float base_fade = smoothstep(0.0, 0.07, h);
	float d = body * tongue * top_fade * base_fade;
	// nucleo caldo al centro-basso
	float core = smoothstep(0.55, 0.0, abs(x) / max(width, 0.05)) * (1.0 - smoothstep(0.0, 0.7, h));
	float heat = clamp(d * 0.9 + core * 0.7, 0.0, 1.0);
	vec3 col = mix(edge_color, mid_color, smoothstep(0.1, 0.5, heat));
	col = mix(col, core_color, smoothstep(0.55, 0.95, heat));
	float flick = 0.88 + 0.12 * sin(t * 23.0 + phase * 3.0) * sin(t * 7.1);
	ALBEDO = col * d * 2.2 * intensity * flick;
	ALPHA = clamp(d * 1.4, 0.0, 1.0);
}
