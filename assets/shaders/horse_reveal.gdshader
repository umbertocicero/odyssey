// Cavallo di Troia che "si costruisce": un piano di taglio locale sale a scatti (reveal_y) e il bordo
// e' sfrangiato da un rumore a celle, come assi appena montate. Texture PBR del modello Meshy.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_roughness_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(0.86, 0.78, 0.68);
uniform float reveal_y = -10.0;
uniform float fringe = 0.05;

varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
}

void fragment() {
	vec2 cell = floor(lpos.xz * 48.0 + lpos.y * 31.0);
	float n = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	if (lpos.y > reveal_y - n * fringe) {
		discard;
	}
	vec4 a = texture(albedo_tex, UV);
	vec4 o = texture(orm_tex, UV);
	ALBEDO = a.rgb * tint;
	ROUGHNESS = clamp(o.g, 0.35, 1.0);
	METALLIC = 0.0;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = 0.8;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
