shader_type spatial;
render_mode cull_back, depth_draw_opaque;
// Mare del diorama: blu-verde con onde e schiuma bianca che scorrono piano.
// Costo basso: nessuna texture, solo qualche seno nel fragment shader.

uniform vec4 deep_color : source_color = vec4(0.05, 0.22, 0.32, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.12, 0.40, 0.46, 1.0);
uniform vec4 foam_color : source_color = vec4(0.95, 0.92, 0.85, 1.0);
uniform float alpha = 0.93;
uniform float wave_scale = 1.6;
uniform float speed = 0.35;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * wave_scale;
	float t = TIME * speed;
	float w = sin(p.x * 1.3 + t * 2.0) * 0.5 + sin(p.y * 1.7 - t * 1.6) * 0.5;
	w += sin((p.x + p.y) * 2.3 + t * 3.1) * 0.35;
	float bands = smoothstep(0.55, 0.95, w * 0.6 + 0.5);
	vec3 water = mix(deep_color.rgb, shallow_color.rgb, 0.5 + 0.5 * w * 0.5);
	ALBEDO = mix(water, foam_color.rgb, bands * 0.45);
	ROUGHNESS = 0.55;
	SPECULAR = 0.15;
	ALPHA = alpha;
}
