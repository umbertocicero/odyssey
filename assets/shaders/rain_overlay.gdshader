// Pioggia come overlay 2D a costo fisso (un solo passaggio a schermo intero, uguale a ogni qualità):
// righe diagonali procedurali su due strati, più un velo grigio-blu leggero.
shader_type canvas_item;

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float speed = 1.6;
uniform vec2 wind = vec2(0.25, 0.0);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float layer(vec2 uv, float scale, float len, float t) {
	vec2 p = uv * vec2(scale * 1.7, scale);
	p.x += p.y * wind.x * 3.0;
	vec2 id = floor(p);
	float col_rand = hash(vec2(id.x, 3.0));
	p.y += t * (0.8 + col_rand * 0.6) * speed * scale * 0.5;
	vec2 cell = fract(p);
	vec2 cid = floor(p);
	float h = hash(cid + id.x);
	float on = step(0.82, h);
	float streak = smoothstep(0.5 - 0.04, 0.5, cell.x) * (1.0 - smoothstep(0.5, 0.5 + 0.04, cell.x));
	float along = smoothstep(0.0, len, cell.y) * (1.0 - smoothstep(len, len * 2.0, cell.y));
	return on * streak * along;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;
	float r = layer(uv, 90.0, 0.3, t) * 0.55 + layer(uv + 0.37, 55.0, 0.4, t * 1.2) * 0.4;
	vec3 col = vec3(0.72, 0.8, 0.9);
	float veil = 0.07 * amount;
	COLOR = vec4(col, clamp(r * amount * 0.7 + veil, 0.0, 0.8));
}
