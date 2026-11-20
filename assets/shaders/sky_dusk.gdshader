// Cielo di tramonto drammatico (STYLE.md, sezione 10): sole basso arancione-oro, cumuli
// stratificati grigio-viola con bordi arancio/rosa/oro, foschia dorata all'orizzonte e
// contrasto caldo-freddo (oro contro blu ardesia/viola in alto).
// Funziona con il renderer Compatibility: nessuna texture, solo rumore procedurale.
// Qualità: `octaves` (2 web, 3 mobile, 5 PC) regola il dettaglio delle nuvole.
shader_type sky;

uniform vec3 sun_dir = vec3(-0.7, 0.3, -0.6);
uniform vec3 zenith_color : source_color = vec3(0.17, 0.2, 0.34);
uniform vec3 mid_color : source_color = vec3(0.42, 0.34, 0.45);
uniform vec3 horizon_color : source_color = vec3(1.0, 0.62, 0.32);
uniform vec3 sun_color : source_color = vec3(1.0, 0.8, 0.5);
uniform vec3 ground_color : source_color = vec3(0.35, 0.2, 0.14);
uniform vec3 cloud_dark : source_color = vec3(0.3, 0.26, 0.38);
uniform vec3 cloud_rim : source_color = vec3(1.0, 0.6, 0.35);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.55;
uniform float cloud_scale = 1.6;
uniform float cloud_speed = 0.004;
uniform int octaves : hint_range(1, 6) = 4;

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
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 6; i++) {
		if (i >= octaves) {
			break;
		}
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 sun = normalize(sun_dir);
	float up = clamp(dir.y, 0.0, 1.0);
	float sun_amount = max(dot(dir, sun), 0.0);
	// Gradiente: oro all'orizzonte, viola a metà, blu ardesia allo zenit.
	vec3 col = mix(horizon_color, mid_color, smoothstep(0.0, 0.22, up));
	col = mix(col, zenith_color, smoothstep(0.15, 0.85, up));
	// Alone del sole e disco.
	col += sun_color * pow(sun_amount, 6.0) * 0.45;
	col += sun_color * pow(sun_amount, 64.0) * 0.9;
	col = mix(col, sun_color * 1.6, smoothstep(0.9995, 0.9999, sun_amount));
	// Nuvole stratificate: piano proiettato, stirato in orizzontale.
	if (dir.y > 0.01) {
		vec2 uv = dir.xz / (dir.y + 0.18) * cloud_scale;
		uv.x *= 0.45;
		uv += vec2(TIME * cloud_speed, 0.0);
		float d = fbm(uv * vec2(1.0, 2.4));
		float cov = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.25, d);
		// Bordo illuminato dal sole: densità più bassa verso il sole = bordo.
		vec2 toward_sun = normalize(sun.xz + vec2(0.0001)) * 0.07;
		float d_sun = fbm((uv + toward_sun) * vec2(1.0, 2.4));
		float rim = clamp((d - d_sun) * 6.0 + 0.35, 0.0, 1.0) * (1.0 - cov * 0.35);
		float facing = pow(sun_amount, 1.5) * 0.7 + 0.3;
		vec3 cloud = mix(cloud_dark, cloud_rim, rim * facing);
		cloud += sun_color * pow(sun_amount, 8.0) * 0.35;
		// Verso l'orizzonte le nuvole si dissolvono nella foschia dorata.
		float fade = smoothstep(0.01, 0.2, dir.y);
		col = mix(col, cloud, cov * fade * 0.92);
	}
	// Sotto l'orizzonte: terra calda (la scena la copre quasi sempre).
	col = mix(col, ground_color, smoothstep(0.0, -0.15, dir.y));
	COLOR = col;
}
