class_name HudWidgets
extends RefCounted
## Elementi grafici dell'interfaccia di STYLE.md (sezione HUD): cornici di bronzo con meandro greco,
## pergamena, barre e minimappa tonda. Tutto disegnato da codice (draw_*), nessun asset esterno.
## Palette smorzata: bronzo, marrone scuro, rosso profondo, oliva, crema.

const BRONZE := Color(0.62, 0.43, 0.2)
const BRONZE_LIGHT := Color(0.8, 0.6, 0.32)
const BRONZE_DARK := Color(0.27, 0.18, 0.09)
const PARCHMENT := Color(0.8, 0.7, 0.5)
const PARCHMENT_DARK := Color(0.58, 0.47, 0.3)
const INK := Color(0.16, 0.1, 0.06)
const CREAM := Color(0.96, 0.9, 0.74)
const RED := Color(0.62, 0.13, 0.1)
const ORANGE := Color(0.82, 0.5, 0.14)
const OLIVE := Color(0.42, 0.44, 0.2)
const GOLD := Color(0.9, 0.72, 0.28)
const DIR := "res://assets/ui/hud/"

static var _cache := {}


## Texture dell'HUD (assets/ui/hud/), caricata una volta. Vuota se il file manca: l'HUD ripiega sul disegno procedurale.
static func tex(file_name: String) -> Texture2D:
	if not _cache.has(file_name):
		var path := DIR + file_name + ".png"
		_cache[file_name] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _cache[file_name]


## Ritratto tondo: anello di bronzo con il ritratto dentro (o il busto disegnato se manca la texture).
static func draw_portrait(c: CanvasItem, center: Vector2, radius: float, portrait: String, crest: Color, cloak: Color) -> void:
	var texture := tex(portrait)
	draw_ring(c, center, radius, Color(0.22, 0.14, 0.09))
	if texture:
		var inner := radius - 3.0
		c.draw_texture_rect(texture, Rect2(center - Vector2(inner, inner), Vector2(inner, inner) * 2.0), false)
		c.draw_arc(center, radius - 1.5, 0.0, TAU, 48, BRONZE, 3.0, true)
	else:
		draw_bust(c, center + Vector2(0, radius * 0.08), radius * 0.68, crest, cloak)


## Icona di slot: usa il PNG (già con cornice di bronzo) se c'è; `alpha` < 1 per gli slot vuoti.
static func draw_icon(c: CanvasItem, center: Vector2, radius: float, icon: String, alpha := 1.0) -> bool:
	var texture := tex(icon)
	if texture == null:
		return false
	c.draw_texture_rect(texture, Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, Color(1, 1, 1, alpha))
	return true


## Riempimento a pergamena (texture ripetuta) di un rettangolo, scurita da `tint`.
static func draw_parchment(c: CanvasItem, rect: Rect2, tint := Color(0.62, 0.52, 0.36, 0.9)) -> void:
	var texture := tex("tex_pergamena")
	if texture:
		c.draw_texture_rect(texture, rect, true, tint)


## Greca (meandro greco) lungo un segmento orizzontale: una chiave per cella.
static func draw_meander(c: CanvasItem, from: Vector2, length: float, cell: float, color: Color, width := 1.5) -> void:
	var n := maxi(int(length / cell), 1)
	var step := length / n
	# Un solo disegno per tutta la greca (draw_multiline): meno chiamate di disegno 2D.
	var segs := PackedVector2Array()
	for i in n:
		var o := from + Vector2(i * step, 0)
		var s := step
		var pts := [Vector2(0, s * 0.7), Vector2(0, 0), Vector2(s, 0), Vector2(s, s * 0.7), Vector2(s * 0.3, s * 0.7), Vector2(s * 0.3, s * 0.3), Vector2(s * 0.7, s * 0.3)]
		for k in range(pts.size() - 1):
			segs.append(o + pts[k])
			segs.append(o + pts[k + 1])
	c.draw_multiline(segs, color, width, true)


## Cornice rettangolare di bronzo: bordo, filetto interno, riempimento scuro, greca in alto.
static func draw_frame(c: CanvasItem, rect: Rect2, fill := Color(0.12, 0.08, 0.05, 0.82), meander := true) -> void:
	c.draw_rect(rect, fill)
	c.draw_rect(rect, BRONZE, false, 3.0)
	c.draw_rect(rect.grow(-4.0), BRONZE_DARK, false, 1.0)
	c.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3.0)), BRONZE_LIGHT)
	for corner: Vector2 in [rect.position, rect.position + Vector2(rect.size.x, 0), rect.position + Vector2(0, rect.size.y), rect.end]:
		c.draw_circle(corner, 3.5, BRONZE_LIGHT)
	if meander and rect.size.y > 26.0:
		draw_meander(c, rect.position + Vector2(8, 7), rect.size.x - 16.0, 9.0, BRONZE, 1.2)


## Anello tondo di bronzo con riempimento.
static func draw_ring(c: CanvasItem, center: Vector2, radius: float, fill: Color) -> void:
	c.draw_circle(center, radius, BRONZE_DARK)
	c.draw_circle(center, radius - 3.0, fill)
	c.draw_arc(center, radius - 1.5, 0.0, TAU, 48, BRONZE, 3.0, true)
	c.draw_arc(center, radius - 5.0, 0.0, TAU, 48, BRONZE_DARK, 1.0, true)
	c.draw_arc(center, radius - 1.5, -2.6, -0.8, 16, BRONZE_LIGHT, 2.0, true)


## Barra con bordo di bronzo.
static func draw_bar(c: CanvasItem, rect: Rect2, ratio: float, color: Color) -> void:
	c.draw_rect(rect, Color(0.07, 0.04, 0.03, 0.9))
	var inner := rect.grow(-2.0)
	c.draw_rect(Rect2(inner.position, Vector2(inner.size.x * clampf(ratio, 0.0, 1.0), inner.size.y)), color)
	c.draw_rect(Rect2(inner.position, Vector2(inner.size.x * clampf(ratio, 0.0, 1.0), inner.size.y * 0.35)), color.lightened(0.18))
	c.draw_rect(rect, BRONZE, false, 2.0)


## Busto stilizzato: elmo con cresta, volto, spalle (ritratto segnaposto disegnato).
static func draw_bust(c: CanvasItem, center: Vector2, r: float, crest: Color, cloak: Color) -> void:
	c.draw_circle(center + Vector2(0, r * 0.95), r * 0.9, cloak)
	c.draw_circle(center + Vector2(0, r * 0.1), r * 0.45, Color(0.8, 0.58, 0.42))
	c.draw_arc(center + Vector2(0, r * 0.05), r * 0.52, PI, TAU, 16, BRONZE_LIGHT, r * 0.28, true)
	c.draw_rect(Rect2(center + Vector2(-r * 0.07, -r * 0.82), Vector2(r * 0.14, r * 0.42)), crest)
	c.draw_rect(Rect2(center + Vector2(-r * 0.5, -r * 0.05), Vector2(r * 0.12, r * 0.5)), BRONZE)
	c.draw_rect(Rect2(center + Vector2(r * 0.38, -r * 0.05), Vector2(r * 0.12, r * 0.5)), BRONZE)


## Minimappa tonda a pergamena: segnalini per Ulisse, alleati, nemici e feriti.
class MiniMap extends Control:
	var world_origin := Vector2(-26.0, -30.0)
	var world_size := Vector2(52.0, 52.0)
	var markers: Array[Dictionary] = []   # {pos: Vector2 (x, z), color: Color, radius: float}

	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.5
		var center := size * 0.5
		HudWidgets.draw_ring(self, center, r, HudWidgets.PARCHMENT)
		var inner := r - 7.0
		# Mare a ovest e strada: due tratti dipinti sulla pergamena.
		draw_circle(center, inner, HudWidgets.PARCHMENT)
		var parchment := HudWidgets.tex("tex_pergamena")
		if parchment:
			var pts := PackedVector2Array()
			var uvs := PackedVector2Array()
			for i in 48:
				var a := TAU * i / 48.0
				pts.append(center + Vector2(cos(a), sin(a)) * inner)
				uvs.append(Vector2(0.5, 0.5) + Vector2(cos(a), sin(a)) * 0.5)
			draw_colored_polygon(pts, Color(1, 1, 1, 1), uvs, parchment)
		_stroke(Vector2(-24.5, -18.0), Vector2(-24.5, 20.0), Color(0.45, 0.58, 0.55, 0.8), 4.0, center, inner)
		_stroke(Vector2(-17.0, 11.8), Vector2(5.0, 11.2), HudWidgets.PARCHMENT_DARK, 2.5, center, inner)
		_stroke(Vector2(5.0, 11.2), Vector2(6.6, -19.0), HudWidgets.PARCHMENT_DARK, 2.5, center, inner)
		_stroke(Vector2(-24.0, -21.6), Vector2(24.0, -21.6), HudWidgets.BRONZE_DARK, 3.0, center, inner)
		for m in markers:
			var p := _to_map(m["pos"], center, inner)
			if p.distance_to(center) < inner - 2.0:
				draw_circle(p, float(m.get("radius", 3.0)) + 1.0, HudWidgets.INK)
				draw_circle(p, float(m.get("radius", 3.0)), m["color"])
		draw_string(ThemeDB.fallback_font, center + Vector2(-5, -inner + 14.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, HudWidgets.INK)

	func _to_map(w: Vector2, center: Vector2, inner: float) -> Vector2:
		var n := (w - world_origin) / world_size - Vector2(0.5, 0.5)
		return center + n * inner * 2.0 * 0.92

	func _stroke(a: Vector2, b: Vector2, color: Color, width: float, center: Vector2, inner: float) -> void:
		var pa := _to_map(a, center, inner)
		var pb := _to_map(b, center, inner)
		if pa.distance_to(center) < inner and pb.distance_to(center) < inner:
			draw_line(pa, pb, color, width, true)
