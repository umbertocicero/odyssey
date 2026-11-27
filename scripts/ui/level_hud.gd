class_name LevelHud
extends Control
## Interfaccia del livello ispirata allo stile HUD di STYLE.md: cornici di bronzo con greca,
## pergamena e palette smorzata, tutto disegnato da codice (HudWidgets), tutti i testi in inglese.
##   in alto a sinistra: ritratto di Ulisse, nome, livello, barra della vita;
##   in alto al centro: titolo del livello, timer di ritirata e ondata, OBJECTIVE;
##   in alto a destra: minimappa a pergamena e contatori (feriti al campo, sulle navi, persi);
##   a destra: ritratti dei feriti (a colori con barra della vita; grigi se morti);
##   in basso a sinistra: attacco con la spada (SWORD OF ITHACA, CLICK / F) con indicatore di ricarica;
##   in basso al centro: sottotitoli; in basso a destra: suggerimenti dei comandi.
## Si adatta alla finestra (scala `u`) e ai margini sicuri dei telefoni; su schermi stretti nasconde
## alleati e comandi. API invariata per LevelDirector: set_time, set_wounded, show_banner, show_end.

signal continue_pressed

const FONT_BOLD_OUTLINE := 5
## Ritratti (ritagli dalle foto in ispirazione/characters/, copiati in assets/ui/hud/) per nome mostrato.
## Nomi (unici, in ordine) dei feriti del livello nell'HUD.
const WOUNDED_NAMES := ["ELPENOR", "EURYLOCHUS", "EURYBATES", "PHILOCTETES", "POLITES", "DEIPHOBUS"]
const PORTRAITS := {
	"ELPENOR": "portrait_elpenore", "EURYLOCHUS": "portrait_euriloco", "EURYBATES": "portrait_euribate",
	"PHILOCTETES": "portrait_filotete", "POLITES": "portrait_polite", "DEIPHOBUS": "portrait_deifobo",
	"AGAMEMNON": "portrait_agamennone", "MENELAUS": "portrait_menelao", "PERIMEDES": "portrait_perimede", "PANDARUS": "portrait_pandaro", "TROJAN SOLDIER": "portrait_ufficiale_troiano", "TROJAN INFANTRY": "portrait_fanteria_troiana", "TROJAN CAPTAIN": "portrait_capitano_troiano", "TROJAN SPEARMAN": "portrait_ufficiale_troiano",
}

var _seconds_left := 0.0
var _wave := 0
var _attempt := 1
var _max_attempts := 3
var _saved := 0
var _lost := 0
var _total := 0
var _evacuated := 0
var _banner_text := ""
var _banner_alpha := 0.0
var _banner_tween: Tween
var _subtitle_speaker := ""
var _subtitle_text := ""
var _subtitle_alpha := 0.0
var _subtitle_tween: Tween
var _player: GridUnit
var _minimap: HudWidgets.MiniMap
var _marker_clock := 0.0
var _end_panel: PanelContainer
var _end_title: Label
var _end_body: Label
var _continue: Button
var _u := 1.0
var _styled_cell := 0.0
var _margin := Vector4(12, 12, 12, 12)   # sinistra, alto, destra, basso


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap = HudWidgets.MiniMap.new()
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_minimap)
	_build_end_panel()
	resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _process(delta: float) -> void:
	if HudWidgets.pixel_cell != _styled_cell:
		_styled_cell = HudWidgets.pixel_cell
		_style_end_panel_text()
	_marker_clock -= delta
	if _marker_clock <= 0.0:
		_marker_clock = 0.15
		_update_markers()
	queue_redraw()


func _layout() -> void:
	var sz := get_viewport_rect().size
	if sz.x / maxf(sz.y, 1.0) < 1.15:
		# Telefono in verticale: la larghezza virtuale resta ~1280, quindi l'interfaccia si ingrandisce.
		_u = clampf(sz.x / 600.0, 0.9, 2.6)
	else:
		_u = clampf(minf(sz.x / 960.0, sz.y / 540.0), 0.7, 1.7)
	var base := 12.0 * _u
	_margin = Vector4(base, base, base, base)
	# Margini sicuri (notch e barre dei telefoni), se il sistema li dichiara.
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if safe.size.x > 0 and screen.x > 0 and (safe.size.x < screen.x or safe.size.y < screen.y):
		var k := sz.x / float(screen.x)
		_margin += Vector4(safe.position.x * k, safe.position.y * k, (screen.x - safe.end.x) * k, (screen.y - safe.end.y) * k)
	var d := 124.0 * _u
	_minimap.size = Vector2(d, d)
	_minimap.position = Vector2(sz.x - _margin.z - d, _margin.y)
	queue_redraw()


func _narrow() -> bool:
	var sz := get_viewport_rect().size
	return sz.x < 760.0 * _u * 0.62 or sz.x / maxf(sz.y, 1.0) < 1.15


# --- Disegno ---------------------------------------------------------------------------------------

func _text(at: Vector2, s: String, size: float, color := HudWidgets.CREAM, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var font := HudWidgets.font()
	var fs := int(size * _u * HudWidgets.text_scale())
	if HudWidgets.pixel_cell > 0.0:
		# Mai sotto 6 blocchi di corpo e mai semitrasparente (il banner che sfuma si accende o si spegne):
		# a blocchi grossi un testo piccolo o sfumato non si leggerebbe.
		fs = maxi(fs, HudWidgets.min_font_px())
		if color.a < 0.3:
			return
		color.a = 1.0
		# Filtro pixel art: contorno scuro spesso un blocco, così il testo resta leggibile.
		draw_string_outline(font, at, s, align, width, fs, int(HudWidgets.pixel_cell) * (2 if fs >= 28 else 1), Color(HudWidgets.INK, color.a))
	else:
		# Ombra morbida al posto del contorno (meno chiamate di disegno 2D).
		draw_string(font, at + Vector2(1.5, 1.5) * _u, s, align, width, fs, Color(HudWidgets.INK, 0.9 * color.a))
	draw_string(font, at, s, align, width, fs, color)


func _draw() -> void:
	var sz := get_viewport_rect().size
	var u := _u
	var ml := _margin.x
	var mt := _margin.y
	var mr := _margin.z
	var mb := _margin.w
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as GridUnit
	# Ulisse: ritratto, nome, livello e vita.
	var pr := 42.0 * u
	var pc := Vector2(ml + pr, mt + pr)
	HudWidgets.draw_portrait(self, pc, pr, "portrait_ulisse", HudWidgets.RED, Color(0.55, 0.12, 0.1))
	var tx := ml + pr * 2.0 + 10.0 * u
	_text(Vector2(tx, mt + 22.0 * u), "ULYSSES", 20.0)
	_text(Vector2(tx, mt + 40.0 * u), "LEVEL 1", 12.0, HudWidgets.PARCHMENT)
	var hp := 1.0
	if _player:
		hp = float(_player.health) / maxf(float(_player.max_health), 1.0)
	HudWidgets.draw_bar(self, Rect2(tx, mt + 48.0 * u, 150.0 * u, 16.0 * u), hp, HudWidgets.RED)
	if _player and _player.get(&"stamina") != null and _player.get(&"max_stamina") != null:
		var st := float(_player.get(&"stamina")) / maxf(float(_player.get(&"max_stamina")), 1.0)
		HudWidgets.draw_bar(self, Rect2(tx, mt + 68.0 * u, 140.0 * u, 10.0 * u), st, HudWidgets.ORANGE)
	# Barra centrale: titolo, timer e ondata, OBJECTIVE.
	var narrow := _narrow()
	var bw := minf(430.0 * u, sz.x - (ml + pr * 2.0 + 180.0 * u) - (mr + 150.0 * u))
	if narrow:
		bw = sz.x - 2.0 * (ml + 4.0 * u)
	bw = maxf(bw, 220.0 * u)
	var bx := (sz.x - bw) * 0.5
	var by := mt if not narrow else mt + pr * 2.0 + 8.0 * u
	var s := maxi(int(ceil(_seconds_left)), 0)
	HudWidgets.draw_frame(self, Rect2(bx, by, bw, 50.0 * u))
	_text(Vector2(bx, by + 33.0 * u), "ATTEMPT %d / %d" % [_attempt, _max_attempts], 21.0, HudWidgets.CREAM, HORIZONTAL_ALIGNMENT_CENTER, bw)
	var obj := Rect2(bx + 14.0 * u, by + 54.0 * u, bw - 28.0 * u, 42.0 * u)
	HudWidgets.draw_frame(self, obj, Color(0.4, 0.3, 0.18, 0.72), false)
	if HudWidgets.pixel_cell <= 0.0:
		HudWidgets.draw_parchment(self, obj.grow(-3.0), Color(0.5, 0.4, 0.27, 0.85))
	_text(Vector2(obj.position.x + 8.0 * u, obj.position.y + 16.0 * u), "OBJECTIVE", 11.0, HudWidgets.GOLD)
	_text(Vector2(obj.position.x + 8.0 * u, obj.position.y + 32.0 * u), "Hold the line and carry the wounded to the ships", 12.5, HudWidgets.CREAM, HORIZONTAL_ALIGNMENT_LEFT, obj.size.x - 12.0 * u)
	# Minimappa e contatori.
	var mm_rect := Rect2(_minimap.position, _minimap.size)
	var cw := 176.0 * u
	var cx := sz.x - mr - cw
	var cy := mm_rect.end.y + 8.0 * u
	if narrow:
		cy = by + 54.0 * u + 42.0 * u + 12.0 * u
	HudWidgets.draw_frame(self, Rect2(cx, cy, cw, 62.0 * u))
	_text(Vector2(cx + 10.0 * u, cy + 26.0 * u), "WOUNDED  %d / %d" % [_saved, _total], 13.0)
	_text(Vector2(cx + 10.0 * u, cy + 41.0 * u), "ON THE SHIPS  %d" % _evacuated, 13.0, HudWidgets.PARCHMENT)
	_text(Vector2(cx + 10.0 * u, cy + 56.0 * u), "LOST  %d" % _lost, 13.0, Color(0.85, 0.45, 0.35))
	# Feriti da salvare: un ritratto per ciascuno (colori e barra se vivo, grigio se morto).
	if not narrow:
		var ay := cy + 62.0 * u + 10.0 * u
		var list := _wounded_list()
		for i in list.size():
			var w := list[i]
			var card := Rect2(cx, ay + i * 38.0 * u, cw, 33.0 * u)
			var dead := w.state == WoundedSoldier.State.LOST or w.health <= 0
			var card_name: String = WOUNDED_NAMES[i % WOUNDED_NAMES.size()]
			HudWidgets.draw_frame(self, card, Color(0.12, 0.08, 0.05, 0.78) if not dead else Color(0.1, 0.1, 0.1, 0.7), false)
			HudWidgets.draw_portrait(self, card.position + Vector2(17.0 * u, 16.5 * u), 14.0 * u, PORTRAITS.get(card_name, "portrait_oplita_acheo"),
				HudWidgets.BRONZE_LIGHT, Color(0.3, 0.32, 0.5), dead)
			_text(card.position + Vector2(38.0 * u, 14.0 * u), card_name, 11.0, HudWidgets.CREAM if not dead else Color(0.62, 0.6, 0.58))
			var ratio := 0.0 if dead else float(w.health) / maxf(float(w.max_health), 1.0)
			var tag := ""
			if w.state == WoundedSoldier.State.EVACUATED:
				tag = "ON SHIP"
			elif dead:
				tag = "LOST"
			if tag != "":
				_text(Vector2(card.end.x - 78.0 * u, card.position.y + 14.0 * u), tag, 9.5, HudWidgets.PARCHMENT if not dead else Color(0.62, 0.6, 0.58), HORIZONTAL_ALIGNMENT_RIGHT, 68.0 * u)
			HudWidgets.draw_bar(self, Rect2(card.position.x + 38.0 * u, card.position.y + 19.0 * u, cw - 48.0 * u, 9.0 * u), ratio,
				HudWidgets.OLIVE if not dead else Color(0.42, 0.42, 0.42))
	# In basso a sinistra: l'unica abilità del gioco oggi, l'attacco con la spada (CLICK / F). Parata, schivata,
	# pozioni e borsa non sono ancora implementati, quindi non hanno slot: nessuna icona senza funzione.
	var sr := 27.0 * u
	var sy := sz.y - mb - sr * 2.0 - 16.0 * u
	var sc := Vector2(ml + sr, sy + sr)
	if not HudWidgets.draw_icon(self, sc, sr, "icon_spada_itaca"):
		HudWidgets.draw_ring(self, sc, sr, Color(0.2, 0.13, 0.08))
	# Ricarica: spicchio scuro che si consuma finché Ulisse può colpire di nuovo.
	var cd := float(_player.get("_attack_cd")) if _player and is_instance_valid(_player) else 0.0
	var cd_max := maxf(float(_player.get("attack_cooldown")) if _player and is_instance_valid(_player) else 0.5, 0.01)
	if cd > 0.0:
		var frac := clampf(cd / cd_max, 0.0, 1.0)
		var pts := PackedVector2Array([sc])
		for k in 25:
			var a := -PI * 0.5 + TAU * frac * k / 24.0
			pts.append(sc + Vector2(cos(a), sin(a)) * (sr - 2.0))
		draw_colored_polygon(pts, Color(0.04, 0.02, 0.01, 0.7))
	var tx2 := ml + sr * 2.0 + 10.0 * u
	_text(Vector2(tx2, sy + sr - 2.0 * u), "SWORD OF ITHACA", 12.0, HudWidgets.GOLD)
	_text(Vector2(tx2, sy + sr + 16.0 * u), "CLICK / F - Attack", 11.0, HudWidgets.CREAM)
	# Comandi in basso a destra.
	var prompts := [["WASD", "Move"], ["CLICK / F", "Attack"], ["WALK UP", "Lift wounded"]]
	if narrow:
		prompts = [["CLICK / F", "Attack"]]  # a finestra stretta resta almeno il comando d'attacco
	if true:
		for i in prompts.size():
			var py := sz.y - mb - (prompts.size() - i) * 24.0 * u
			var wide := 1.0 if HudWidgets.pixel_cell <= 0.0 else 1.45   # testi più grandi con il filtro pixel art
			var kw := 70.0 * u * wide
			var kr := Rect2(sz.x - mr - 200.0 * u - 40.0 * u * (wide - 1.0) * 2.0, py, kw, 20.0 * u * minf(wide, 1.3))
			HudWidgets.draw_frame(self, kr, Color(0.14, 0.09, 0.06, 0.85), false)
			_text(kr.position + Vector2(0, 15.0 * u * minf(wide, 1.3)), prompts[i][0], 11.0, HudWidgets.CREAM, HORIZONTAL_ALIGNMENT_CENTER, kw)
			_text(Vector2(kr.end.x + 8.0 * u, py + 15.0 * u * minf(wide, 1.3)), prompts[i][1], 12.5)
	# Annuncio e sottotitolo.
	if _banner_alpha > 0.01:
		var col := Color(HudWidgets.CREAM, _banner_alpha)
		var by2 := mt + 150.0 * u if not narrow else cy + 62.0 * u + 34.0 * u
		if HudWidgets.pixel_cell > 0.0 and _banner_alpha >= 0.3:
			# Fascia scura dietro l'annuncio: su sabbia e cielo chiari il testo crema altrimenti si perde.
			var bh := 48.0 * u * HudWidgets.text_scale()
			var bw2 := minf(HudWidgets.font().get_string_size(_banner_text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(30.0 * u * HudWidgets.text_scale())).x + 48.0 * u, sz.x)
			draw_rect(Rect2((sz.x - bw2) * 0.5, by2 - bh * 0.72, bw2, bh), Color(HudWidgets.INK, 0.9))
		_text(Vector2(0, by2), _banner_text, 30.0, col, HORIZONTAL_ALIGNMENT_CENTER, sz.x)
	if _subtitle_alpha > 0.01:
		var line := "%s: %s" % [_subtitle_speaker.to_upper(), _subtitle_text] if _subtitle_speaker != "" else _subtitle_text
		var sw := clampf(sz.x - 2.0 * (ml + 12.0 * u), 240.0 * u, 760.0 * u)
		# Sopra gli slot e i comandi in basso (che occupano circa 82 px): i sottotitoli non li coprono.
		var rect := Rect2((sz.x - sw) * 0.5, sz.y - mb - 132.0 * u, sw, 44.0 * u)
		var frame_alpha := _subtitle_alpha * 0.8 if HudWidgets.pixel_cell <= 0.0 else (0.95 if _subtitle_alpha >= 0.3 else 0.0)
		draw_rect(rect, Color(0.08, 0.05, 0.03, frame_alpha))
		draw_rect(rect, Color(HudWidgets.BRONZE, _subtitle_alpha), false, 2.0)
		_text(rect.position + Vector2(0, 27.0 * u), line, 15.0, Color(HudWidgets.CREAM, _subtitle_alpha), HORIZONTAL_ALIGNMENT_CENTER, sw)


## I feriti del livello, nell'ordine in cui compaiono (Wounded1, Wounded2, ...).
func _wounded_list() -> Array[WoundedSoldier]:
	var list: Array[WoundedSoldier] = []
	for n in get_tree().get_nodes_in_group(&"units"):
		if n is WoundedSoldier:
			list.append(n)
	for n in get_tree().get_nodes_in_group(&"achei"):
		if n is WoundedSoldier and not list.has(n):
			list.append(n)
	list.sort_custom(func(a: WoundedSoldier, b: WoundedSoldier) -> bool: return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
	return list


func _update_markers() -> void:
	var markers: Array[Dictionary] = []
	for n in get_tree().get_nodes_in_group(&"units"):
		var g := n as GridUnit
		if g == null or g.health <= 0:
			continue
		var p := Vector2(g.global_position.x, g.global_position.z)
		if g == _player:
			markers.append({"pos": p, "color": HudWidgets.GOLD, "radius": 4.5})
		elif g is WoundedSoldier:
			markers.append({"pos": p, "color": HudWidgets.CREAM, "radius": 3.0})
		elif g.team == GridUnit.Team.ACHEI:
			markers.append({"pos": p, "color": Color(0.3, 0.45, 0.7), "radius": 3.0})
		else:
			markers.append({"pos": p, "color": HudWidgets.RED, "radius": 3.0})
	_minimap.markers = markers
	_minimap.queue_redraw()


# --- Pannello finale ---------------------------------------------------------------------------------

func _build_end_panel() -> void:
	_end_panel = PanelContainer.new()
	_end_panel.visible = false
	_end_panel.set_anchors_preset(Control.PRESET_CENTER)
	_end_panel.custom_minimum_size = Vector2(620, 0)
	_end_panel.offset_left = -310
	_end_panel.offset_right = 310
	_end_panel.offset_top = -190
	_end_panel.offset_bottom = 190
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.09, 0.06, 0.94)
	style.border_color = HudWidgets.BRONZE
	style.set_border_width_all(4)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(18)
	_end_panel.add_theme_stylebox_override(&"panel", style)
	add_child(_end_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 14)
	_end_panel.add_child(box)
	_end_title = Label.new()
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_title.add_theme_font_size_override(&"font_size", 36)
	_end_title.add_theme_color_override(&"font_color", HudWidgets.GOLD)
	box.add_child(_end_title)
	_end_body = Label.new()
	_end_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_end_body.custom_minimum_size = Vector2(560, 0)
	_end_body.add_theme_color_override(&"font_color", HudWidgets.CREAM)
	box.add_child(_end_body)
	_continue = Button.new()
	_continue.text = "Continue to Level 2"
	_continue.pressed.connect(func(): continue_pressed.emit())
	box.add_child(_continue)


## Con il filtro pixel art (K) i testi della schermata finale diventano più grandi, in grassetto e con
## un contorno scuro spesso un blocco; con il filtro spento tornano com'erano.
func _style_end_panel_text() -> void:
	if _end_panel == null:
		return
	var on := HudWidgets.pixel_cell > 0.0
	var outline := int(HudWidgets.pixel_cell) * 2 if on else 0
	var font: Font = HudWidgets.font() if on else null
	for c: Control in [_end_title, _end_body, _continue]:
		c.add_theme_constant_override(&"outline_size", outline)
		c.add_theme_color_override(&"font_outline_color", HudWidgets.INK)
		if on:
			c.add_theme_font_override(&"font", font)
		else:
			c.remove_theme_font_override(&"font")
	_end_body.add_theme_font_size_override(&"font_size", HudWidgets.min_font_px() if on else 16)
	_continue.add_theme_font_size_override(&"font_size", HudWidgets.min_font_px() if on else 16)


# --- API per LevelDirector ---------------------------------------------------------------------------

func set_time(seconds_left: float, wave: int) -> void:
	_seconds_left = seconds_left
	_wave = wave


func set_attempt(attempt: int, max_attempts: int) -> void:
	_attempt = attempt
	_max_attempts = max_attempts


func set_wounded(saved: int, lost: int, total: int, evacuated := 0) -> void:
	_saved = saved
	_lost = lost
	_total = total
	_evacuated = evacuated


func show_banner(text: String, seconds: float) -> void:
	_banner_text = text
	if _banner_tween:
		_banner_tween.kill()
	_banner_alpha = 1.0
	_banner_tween = create_tween()
	_banner_tween.tween_interval(seconds)
	_banner_tween.tween_property(self, "_banner_alpha", 0.0, 0.6)


## Sottotitolo di dialogo in basso al centro, con il nome di chi parla in evidenza.
func show_subtitle(speaker: String, text: String, seconds: float) -> void:
	_subtitle_speaker = speaker
	_subtitle_text = text
	if _subtitle_tween:
		_subtitle_tween.kill()
	_subtitle_alpha = 1.0
	_subtitle_tween = create_tween()
	_subtitle_tween.tween_interval(seconds)
	_subtitle_tween.tween_property(self, "_subtitle_alpha", 0.0, 0.5)


func show_end(s: Dictionary) -> void:
	_end_title.text = str(s["title"])
	_end_body.text = "%s\n\nWounded brought to camp: %d of %d\nWounded evacuated to the ships: %d\nTrojans defeated: %d\nWaves survived: %d\n\nScore: %d" % [
		s["text"], s["saved"], s["total"], s.get("evacuated", 0), s["kills"], s["waves"], s["score"]]
	_end_panel.visible = true
	_end_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_continue.grab_focus()


func end_panel_visible() -> bool:
	return _end_panel != null and _end_panel.visible
