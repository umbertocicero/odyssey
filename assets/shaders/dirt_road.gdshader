// Strada di terra battuta (STYLE.md, sezione 6): nastro sottile steso sul terreno, con solchi
// profondi di ruote, impronte e sassolini, polvere chiara al centro e bordi irregolari che
// sfumano nell'erba. UV.x = -1..1 attraverso la strada, UV.y = metri lungo la strada.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec3 dirt_a : source_color = vec3(0.7, 0.54, 0.33);
uniform vec3 dirt_b : source_color = vec3(0.56, 0.41, 0.25);
uniform vec3 dust : source_color = vec3(0.84, 0.7, 0.47);
uniform float rut_offset = 0.36;
uniform float rut_width = 0.1;
uniform float rut_depth = 0.6;
uniform float edge_start = 0.6;
uniform float normal_strength = 1.0;

varying vec2 road_uv;

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

// Altezza del suolo: solchi + grumi. Larghezza della strada = 3,4 m (u in -1..1).
float ground(vec2 uv) {
	float x = uv.x * 1.7;
	float wobble = vnoise(vec2(uv.y * 0.7, 3.0)) * 0.12;
	float rut2 = exp(-pow((abs(x + wobble) - 0.62) / 0.17, 2.0));
	return -rut2 * rut_depth + vnoise(uv * vec2(3.0, 5.0) * 1.7) * 0.25 + vnoise(uv * vec2(12.0, 18.0)) * 0.1;
}

void vertex() {
	road_uv = UV;
}

void fragment() {
	vec2 uv = road_uv;
	float e = 0.02;
	float h = ground(uv);
	float dhu = (ground(uv + vec2(e, 0.0)) - h) / e;
	float dhv = (ground(uv + vec2(0.0, e * 3.0)) - h) / (e * 3.0);
	vec3 n = normalize(vec3(-dhu * 0.035 * normal_strength, -dhv * 0.035 * normal_strength, 1.0));
	NORMAL_MAP = n * 0.5 + 0.5;
	float grain = vnoise(uv * vec2(9.0, 14.0));
	vec3 col = mix(dirt_a, dirt_b, grain);
	col = mix(col, dust, smoothstep(0.55, 1.0, vnoise(uv * vec2(2.0, 1.2) + 7.0)) * (1.0 - abs(uv.x)) * 0.8);
	// solchi più scuri e umidi, sassolini chiari
	col *= 1.0 - smoothstep(-0.2, -0.8, h) * 0.45;
	col = mix(col, col * 1.35, step(0.93, hash(floor(uv * vec2(22.0, 34.0)))) * 0.7);
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
	AO = 1.0 - smoothstep(-0.2, -0.9, h) * 0.5;
	AO_LIGHT_AFFECT = 0.6;
	// bordi irregolari che sfumano nell'erba
	float edge = abs(uv.x) + (vnoise(vec2(uv.y * 1.3, 11.0)) - 0.5) * 0.35 + (vnoise(vec2(uv.y * 5.0, 2.0)) - 0.5) * 0.12;
	ALPHA = 1.0 - smoothstep(edge_start, 1.0, edge);
}
