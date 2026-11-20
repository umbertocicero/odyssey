shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, shadows_disabled;
// Erba: ogni ciuffo è una istanza di un MultiMesh con pochi fili a strisce.
// Il vertex shader piega i fili con due effetti, entrambi più forti verso la
// punta (UV.y = 0 alla base, 1 in cima):
//  1. vento leggero: onde che attraversano il campo;
//  2. interattori: personaggi, proiettili e fuoco spingono via i fili vicini.
// Le posizioni degli interattori arrivano dallo script GrassField, che le
// ammorbidisce nel tempo: l'erba si piega subito e si rialza piano.
// L'istanza ha solo la traslazione; rotazione e scala stanno in INSTANCE_CUSTOM
// (x = angolo, y = scala, z = fase del vento), il colore dell'istanza è la tinta.

const int MAX_INTERACTORS = 12;

uniform vec4 base_color : source_color = vec4(0.30, 0.36, 0.14, 1.0);
uniform vec4 tip_color : source_color = vec4(0.66, 0.62, 0.30, 1.0);
// Vento: forza (metri alla punta del filo), velocità, direzione (xz) e ampiezza delle onde.
uniform float wind_strength : hint_range(0.0, 0.5) = 0.07;
uniform float wind_speed : hint_range(0.0, 6.0) = 1.4;
uniform vec2 wind_direction = vec2(0.8, 0.6);
uniform float wind_scale : hint_range(0.05, 2.0) = 0.35;
// Interattori: xyz = posizione nel mondo, w = raggio d'azione (0 = spento).
uniform vec4 interactors[MAX_INTERACTORS];
// Di quanto si sposta la punta di un filo al centro di un interattore, in metri.
uniform float push_strength : hint_range(0.0, 1.5) = 0.45;
// Quanto si abbassa il filo quando viene piegato (0 = non si abbassa).
uniform float push_flatten : hint_range(0.0, 1.0) = 0.6;
// Quanto traslucida è l'erba controluce.
uniform float backlight : hint_range(0.0, 1.0) = 0.35;

varying float height_fraction;
varying vec3 tint;

void vertex() {
	float angle = INSTANCE_CUSTOM.x;
	float s = sin(angle);
	float c = cos(angle);
	vec3 v = VERTEX;
	v.xz = vec2(c * v.x - s * v.z, s * v.x + c * v.z);
	v *= INSTANCE_CUSTOM.y;
	height_fraction = UV.y;
	tint = COLOR.rgb;

	float weight = UV.y * UV.y; // la base resta ferma, la punta si piega
	vec3 world = (MODEL_MATRIX * vec4(v, 1.0)).xyz;

	// Vento: onda lungo la direzione del vento più un'increspatura veloce.
	vec2 wd = normalize(wind_direction);
	float phase = dot(world.xz, wd) * wind_scale * 3.0 + TIME * wind_speed + INSTANCE_CUSTOM.z * 6.2831;
	float gust = sin(phase) + 0.5 * sin(phase * 2.3 + world.x * 0.7);
	vec2 bend = wd * gust * wind_strength * weight;

	// Interattori: spinta via dal centro, con caduta morbida verso il bordo.
	float pressed = 0.0;
	for (int i = 0; i < MAX_INTERACTORS; i++) {
		vec4 it = interactors[i];
		if (it.w <= 0.001) {
			continue;
		}
		vec2 d = world.xz - it.xz;
		float dist = length(d);
		float f = 1.0 - smoothstep(0.0, it.w, dist);
		f *= f;
		// Fuori dal raggio o in un'altra quota (altro piano del rilievo): nessun effetto.
		f *= 1.0 - smoothstep(0.6, 1.4, abs(world.y - it.y));
		vec2 dir = dist > 0.001 ? d / dist : vec2(1.0, 0.0);
		bend += dir * f * push_strength * weight;
		pressed = max(pressed, f);
	}

	v.xz += bend;
	v.y -= length(bend) * push_flatten * weight + pressed * 0.1 * weight;
	VERTEX = v;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec3 col = mix(base_color.rgb, tip_color.rgb, smoothstep(0.0, 1.0, height_fraction)) * tint;
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	BACKLIGHT = col * backlight;
}
