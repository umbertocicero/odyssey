// Foce del ruscello nel mare: pennacchio di acqua dolce schiumosa che si apre verso il largo, onde concentriche
// che si propagano nel mare (rilievo vero sulla mesh suddivisa + creste di schiuma) e frangente sulla riva.
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, specular_schlick_ggx, cull_disabled;

uniform sampler2D normal_tex : hint_normal, repeat_enable, filter_linear_mipmap;
uniform vec2 out_dir = vec2(-1.0, 0.1);   // direzione di deflusso nel mondo (x, z)
uniform float radius = 7.0;
uniform float wave_speed = 1.7;
uniform float wave_amp = 0.05;
uniform vec3 river_color : source_color = vec3(0.16, 0.38, 0.36);
uniform vec3 foam_color : source_color = vec3(0.95, 0.95, 0.9);

varying vec2 loc;

void vertex() {
	loc = VERTEX.xz;
	float r = length(loc);
	float fall = 1.0 - smoothstep(0.0, radius, r);
	VERTEX.y += sin(r * 2.6 - TIME * wave_speed * 1.5) * wave_amp * fall * fall;
}

void fragment() {
	vec2 d = normalize(out_dir);
	float along = dot(loc, d);
	float across = dot(loc, vec2(-d.y, d.x));
	float r = length(loc);
	float fall = 1.0 - smoothstep(1.0, radius, r);
	// pennacchio: si allarga e si sfilaccia verso il largo
	float w = 0.9 + 0.55 * max(along, 0.0);
	float plume = exp(-(across * across) / (w * w)) * smoothstep(-1.0, 0.6, along) * (1.0 - smoothstep(0.0, radius * 0.95, along));
	float n = texture(normal_tex, loc * 0.12 + d * TIME * 0.04).r;
	float n2 = texture(normal_tex, loc * 0.31 - d * TIME * 0.07).g;
	// onde concentriche che nascono alla foce e si allontanano
	float ring = smoothstep(0.62, 0.98, sin(r * 2.4 - TIME * wave_speed) * 0.5 + 0.5) * fall * fall;
	// frangente sulla riva: striscia di schiuma attorno alla foce, sul lato verso terra
	float surf = smoothstep(1.8, 0.0, r) * (0.55 + 0.6 * n2);
	float foam = clamp(plume * (0.35 + 0.9 * n) + ring * (0.45 + 0.4 * n2) + surf, 0.0, 1.0);
	ALBEDO = mix(river_color, foam_color, foam);
	ROUGHNESS = mix(0.12, 0.7, foam);
	SPECULAR = 0.6;
	vec3 nm = texture(normal_tex, loc * 0.22 + vec2(TIME * 0.02)).rgb;
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = 0.8 * (0.4 + plume);
	ALPHA = clamp(plume * 0.55 + foam * 0.85, 0.0, 1.0) * smoothstep(0.0, 0.25, fall);
}
