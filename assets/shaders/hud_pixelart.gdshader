shader_type canvas_item;
// HUD in stile "32 bit" (vedi post_process.gdshader, modo 3): l'HUD è già disegnato a metà risoluzione
// in un SubViewport e ingrandito con filtro nearest (blocchi 2x2); qui si riduce solo il colore a 15 bit
// (32 livelli per canale), lo stesso del modo 32 bit del mondo. Vale per tutti i modi di K.
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	c.rgb = floor(c.rgb * 31.0 + 0.5) / 31.0;
	COLOR = c;
}
