// Ruscello e cascate del livello 2: nastro d'acqua con normali che scorrono e schiuma ai bordi.
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, specular_schlick_ggx, cull_disabled;

uniform sampler2D normal_tex : hint_normal, repeat_enable, filter_linear_mipmap;
uniform vec3 deep_color : source_color = vec3(0.10, 0.24, 0.24);
uniform vec3 foam_color : source_color = vec3(0.86, 0.9, 0.88);
uniform float flow_speed = 0.35;
uniform float foam_amount : hint_range(0.0, 1.0) = 0.25;
uniform float uv_scale = 1.0;
uniform vec2 mouth = vec2(0.0, 0.0);   // foce nel mare (x, z): vicino si fa tutta schiuma

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = vec2(UV.x * 1.3, UV.y * uv_scale);
	vec2 f = vec2(0.0, -TIME * flow_speed);
	vec3 n1 = texture(normal_tex, uv + f).rgb;
	vec3 n2 = texture(normal_tex, uv * 1.7 + f * 1.6 + vec2(0.37, 0.11)).rgb;
	NORMAL_MAP = normalize(n1 + n2 - 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.2;
	float edge = abs(UV.x - 0.5) * 2.0;
	float foam = smoothstep(0.72, 1.0, edge) * 0.8;
	foam += foam_amount * smoothstep(0.55, 0.9, n1.r * n2.g + 0.25);
	float near_mouth = 1.0 - smoothstep(0.5, 6.0, distance(wpos.xz, mouth));
	foam += near_mouth * (0.35 + 0.5 * n1.r * n2.g);
	foam = clamp(foam, 0.0, 1.0);
	ALBEDO = mix(deep_color, foam_color, foam);
	ROUGHNESS = mix(0.06, 0.6, foam);
	SPECULAR = 0.7;
	ALPHA = mix(0.86, 0.95, foam) * (1.0 - smoothstep(0.93, 1.0, edge));
}
