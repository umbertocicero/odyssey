shader_type canvas_item;
// Segnaposto per il futuro filtro pixel art (gaussiano + quantizzazione).
// Per provarlo: crea un ShaderMaterial con questo shader e assegnalo a
// "Post Process Material" sul nodo Main (scenes/main/main.tscn).
// Ora lascia l'immagine invariata.

void fragment() {
	COLOR = texture(TEXTURE, UV);
}
