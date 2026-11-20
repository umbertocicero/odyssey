// Ciuffi d'erba alpha-cutout per MultiMesh (GPU instancing): vento, occlusione cotta, translucenza.
// Mesh: assets/models/custom/terreno/erba_ciuffi.glb
//   COLOR.rgb = occlusione alla base del ciuffo, COLOR.a = translucenza (alta in punta)
//   UV2.x = peso del vento (0 base, 1 punta), UV2.y = fase casuale per card
// Istanze: stessa convenzione di assets/shaders/grass.gdshader (GrassField), cosi' i due si fondono facilmente:
//   trasformazione dell'istanza = solo traslazione (oppure completa, vedi rotation_from_custom)
//   INSTANCE_CUSTOM.x = angolo (rad), .y = scala, .z = fase del vento (0..1)
//   colore dell'istanza (MultiMesh.use_colors) = tinta: verde fresco ~ (1,1,1), secco ~ (1.25,1.05,0.62)
//   In Godot il colore d'istanza arriva gia' moltiplicato in COLOR insieme all'occlusione della mesh.
// Riferimento di integrazione: assets/models/custom/terreno/README.md
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert_wrap, specular_schlick_ggx;

uniform sampler2D albedo_alpha : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D card_normal : hint_normal, filter_linear_mipmap, repeat_disable;
// R translucenza, G roughness, B occlusione dentro il ciuffo
uniform sampler2D sss_rough_ao : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform float alpha_cut : hint_range(0.05, 0.95) = 0.5;
// true: rotazione e scala da INSTANCE_CUSTOM (come GrassField); false: dalla trasformazione dell'istanza
uniform bool rotation_from_custom = true;
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);

uniform vec2 wind_direction = vec2(0.8, 0.6);
uniform float wind_strength : hint_range(0.0, 0.6) = 0.12;
uniform float wind_speed : hint_range(0.0, 5.0) = 1.2;
// lunghezza d'onda delle raffiche in metri
uniform float gust_size : hint_range(1.0, 40.0) = 9.0;
uniform float flutter : hint_range(0.0, 1.0) = 0.25;

uniform vec3 translucency_color : source_color = vec3(0.62, 0.72, 0.22);
uniform float translucency : hint_range(0.0, 2.0) = 0.9;

void vertex() {
	vec3 v = VERTEX;
	float phase = 0.0;
	if (rotation_from_custom) {
		float s = sin(INSTANCE_CUSTOM.x);
		float c = cos(INSTANCE_CUSTOM.x);
		v.xz = vec2(c * v.x - s * v.z, s * v.x + c * v.z);
		v *= (INSTANCE_CUSTOM.y > 0.0) ? INSTANCE_CUSTOM.y : 1.0;
		phase = INSTANCE_CUSTOM.z;
	}
	vec3 root = MODEL_MATRIX[3].xyz;
	float w = UV2.x;
	vec2 dir = normalize(wind_direction);
	float t = TIME * wind_speed;
	float gust = sin(dot(root.xz, dir) * 6.2831 / gust_size - t) * 0.5 + 0.5;
	gust = gust * gust;
	float flt = sin(t * 3.7 + (UV2.y + phase) * 6.2831 + root.x * 1.3 + root.z * 0.7) * flutter;
	vec2 d = dir * (0.25 + 0.75 * gust + flt) * wind_strength * w;
	// spostamento in mondo riportato in locale; la punta si abbassa un po' per conservare la lunghezza
	vec3 dw = vec3(d.x, -dot(d, d) * 1.5, d.y);
	VERTEX = v + inverse(mat3(MODEL_MATRIX)) * dw;
}

void fragment() {
	vec4 a = texture(albedo_alpha, UV);
	vec3 sra = texture(sss_rough_ao, UV).rgb;
	ALPHA = a.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ALBEDO = a.rgb * tint * COLOR.rgb;
	ROUGHNESS = sra.g;
	SPECULAR = 0.25;
	NORMAL_MAP = texture(card_normal, UV).rgb;
	NORMAL_MAP_DEPTH = 0.6;
	// stesse normali morbide su entrambe le facce della card
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	// luce che attraversa i fili quando il sole e' dietro (controluce del tramonto)
	BACKLIGHT = translucency_color * translucency * sra.r * COLOR.a;
	AO = sra.b;
	AO_LIGHT_AFFECT = 0.25;
}
