shader_type spatial;
render_mode cull_back, depth_draw_opaque;
// Mare del diorama, qualità LOW (web / telefoni deboli): una sola normal map,
// niente depth texture. Gradiente riva->largo e schiuma di battigia da
// distanza + una lettura di rumore. Costo: 2 texture fetch.

uniform sampler2D normal_tex : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D height_tex : hint_default_white, repeat_enable, filter_linear_mipmap;

uniform vec4 deep_color : source_color = vec4(0.02, 0.17, 0.26, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.10, 0.48, 0.50, 1.0);
uniform vec4 seabed_color : source_color = vec4(0.62, 0.58, 0.42, 1.0);
uniform vec4 foam_color : source_color = vec4(0.96, 0.95, 0.92, 1.0);
uniform float shore_x = -21.6;
uniform float depth_distance = 3.0;
uniform float normal_strength = 0.45;
uniform float tile_a = 0.07;
uniform vec2 flow_a = vec2(0.020, 0.012);

varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float top = step(0.5, world_nrm.y);
	vec2 p = world_pos.xz;
	vec4 n = texture(normal_tex, p * tile_a + flow_a * TIME);
	NORMAL_MAP = n.rgb;
	NORMAL_MAP_DEPTH = normal_strength * top;

	float d = shore_x - world_pos.x;
	vec3 water = mix(shallow_color.rgb, deep_color.rgb, smoothstep(0.0, depth_distance, d));
	water = mix(water, seabed_color.rgb * 0.8, (1.0 - smoothstep(0.0, 1.3, d)) * 0.5);

	float h = texture(height_tex, p * 0.35 + vec2(0.0, TIME * 0.012)).r;
	float swash = 0.5 + 0.5 * sin(TIME * 0.9 + p.y * 0.55 + h * 4.0);
	float dd = d - swash * 0.45 + (h - 0.5) * 0.35;
	float foam = smoothstep(0.55, 0.0, dd) * top;

	ALBEDO = mix(water, foam_color.rgb, foam);
	if (top < 0.5) {
		ALBEDO = mix(deep_color.rgb * 0.7, seabed_color.rgb * 0.7, step(0.5, world_nrm.x));
	}
	ROUGHNESS = mix(0.1, 0.85, foam);
	SPECULAR = mix(0.6, 0.1, foam);
}
