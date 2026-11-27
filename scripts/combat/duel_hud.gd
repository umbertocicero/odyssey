class_name DuelHud
extends Control
## Interfaccia del duello in prima persona (tutto il testo è in inglese, come il resto del gioco):
##  - in alto il nemico: nome, barra della vita e della stamina, e la direzione in cui si copre;
##  - in basso a sinistra Ulisse: vita e stamina. Quando una barra cala, la parte persa resta in
##    bianco per un istante e poi si svuota (le "detrazioni": si vede quanto è costato un colpo o
##    un'azione);
##  - al centro quattro frecce: la direzione scelta (oro), quella del colpo in arrivo (rosso, con
##    un anello che si stringe fino all'impatto) e quella della guardia nemica (azzurro);
##  - scritte di esito (parata perfetta, schivata, colpo parato...) e i comandi, all'inizio.

var duel: Duel
## Trasparenza generale (la transizione la porta da 0 a 1).
var alpha := 0.0

const AIM_ANGLE := [-PI / 2.0, PI, 0.0, PI / 2.0]   # alto, sinistra, destra, basso
const GOLD := Color(1.0, 0.82, 0.38)
const RED := Color(0.95, 0.18, 0.12)
const BLUE := Color(0.45, 0.7, 1.0)

var _popups: Array[Dictionary] = []
var _foe_hp_ghost := 1.0
var _foe_st_ghost := 1.0
var _pl_hp_ghost := 1.0
var _pl_st_ghost := 1.0
var _time := 0.0


func popup(text: String, color: Color) -> void:
	_popups.append({"text": text, "color": color, "age": 0.0})
	if _popups.size() > 3:
		_popups.pop_front()


func _process(delta: float) -> void:
	_time += delta / maxf(Engine.time_scale, 0.01)
	for p in _popups:
		p["age"] = float(p["age"]) + delta / maxf(Engine.time_scale, 0.01)
	_popups = _popups.filter(func(p: Dictionary) -> bool: return float(p["age"]) < 1.6)
	if duel != null and is_instance_valid(duel.foe) and is_instance_valid(duel.player):
		var real := delta / maxf(Engine.time_scale, 0.01)
		_foe_hp_ghost = _drain(_foe_hp_ghost, _foe_hp(), real)
		_foe_st_ghost = _drain(_foe_st_ghost, duel.foe_stamina / Duel.MAX_STAMINA, real)
		_pl_hp_ghost = _drain(_pl_hp_ghost, _pl_hp(), real)
		_pl_st_ghost = _drain(_pl_st_ghost, duel.player_stamina / Duel.MAX_STAMINA, real)
	queue_redraw()


func _drain(ghost: float, value: float, dt: float) -> float:
	if value >= ghost:
		return value
	return maxf(value, ghost - dt * 0.35)


func _foe_hp() -> float:
	return float(duel.foe.health) / float(maxi(duel.foe.max_health, 1))


func _pl_hp() -> float:
	return float(duel.player.health) / float(maxi(duel.player.max_health, 1))


func _draw() -> void:
	if duel == null or alpha <= 0.01 or not is_instance_valid(duel.foe) or not is_instance_valid(duel.player):
		return
	var s := size
	var font := HudWidgets.font()
	var k := clampf(s.y / 720.0, 0.7, 1.8)
	modulate.a = alpha
	_draw_foe(Vector2(s.x * 0.5, 22.0 * k), k, font)
	_draw_player(Vector2(24.0 * k, s.y - 96.0 * k), k, font)
	_draw_aim_cross(Vector2(s.x * 0.5, s.y * 0.5 - 4.0 * k), k)
	_draw_popups(Vector2(s.x * 0.5, s.y * 0.5 - 150.0 * k), k, font)
	_draw_hint(Vector2(s.x * 0.5, s.y - 28.0 * k), k, font)


func _bar(rect: Rect2, ratio: float, ghost: float, color: Color) -> void:
	draw_rect(rect, Color(0.06, 0.035, 0.025, 0.92))
	var inner := rect.grow(-2.0)
	if ghost > ratio:
		draw_rect(Rect2(inner.position, Vector2(inner.size.x * clampf(ghost, 0.0, 1.0), inner.size.y)), Color(0.95, 0.92, 0.85, 0.85))
	draw_rect(Rect2(inner.position, Vector2(inner.size.x * clampf(ratio, 0.0, 1.0), inner.size.y)), color)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x * clampf(ratio, 0.0, 1.0), inner.size.y * 0.38)), color.lightened(0.2))
	draw_rect(rect, HudWidgets.BRONZE, false, 2.0)


func _draw_foe(top_center: Vector2, k: float, font: Font) -> void:
	var w := 440.0 * k
	var rect := Rect2(top_center.x - w * 0.5, top_center.y, w, 76.0 * k)
	HudWidgets.draw_frame(self, rect, Color(0.1, 0.06, 0.04, 0.78), false)
	var title := "TROJAN CAPTAIN" if duel.foe.scene_file_path.contains("capitano") else "TROJAN SOLDIER"
	draw_string(font, rect.position + Vector2(16.0 * k, 24.0 * k), title, HORIZONTAL_ALIGNMENT_LEFT, -1, int(16.0 * k), Color(0.97, 0.9, 0.75))
	_bar(Rect2(rect.position + Vector2(14.0 * k, 32.0 * k), Vector2(w - 28.0 * k, 17.0 * k)), _foe_hp(), _foe_hp_ghost, Color(0.78, 0.12, 0.1))
	var st := duel.foe_stamina / Duel.MAX_STAMINA
	_bar(Rect2(rect.position + Vector2(14.0 * k, 54.0 * k), Vector2((w - 28.0 * k) * 0.7, 9.0 * k)), st, _foe_st_ghost, Color(0.86, 0.72, 0.2))
	# Guardia del nemico: freccia azzurra della direzione che copre.
	var gc := rect.position + Vector2(w - 70.0 * k, 24.0 * k)
	draw_string(font, rect.position + Vector2(w - 160.0 * k, 24.0 * k), "GUARD", HORIZONTAL_ALIGNMENT_LEFT, -1, int(12.0 * k), Color(0.7, 0.8, 0.95))
	var state := duel.foe_state
	var col := BLUE if state == Duel.FoeState.IDLE else Color(0.5, 0.5, 0.5, 0.5)
	_arrow(gc + Vector2(30.0 * k, 0.0), AIM_ANGLE[duel.guard_aim], 9.0 * k, col, true)
	if state == Duel.FoeState.STAGGER:
		draw_string(font, rect.position + Vector2(w - 160.0 * k, 66.0 * k), "STAGGERED", HORIZONTAL_ALIGNMENT_LEFT, -1, int(13.0 * k), Color(1.0, 0.7, 0.3))


func _draw_player(pos: Vector2, k: float, font: Font) -> void:
	var rect := Rect2(pos, Vector2(300.0 * k, 76.0 * k))
	HudWidgets.draw_frame(self, rect, Color(0.1, 0.06, 0.04, 0.78), false)
	draw_string(font, rect.position + Vector2(16.0 * k, 24.0 * k), "ODYSSEUS", HORIZONTAL_ALIGNMENT_LEFT, -1, int(16.0 * k), Color(0.97, 0.9, 0.75))
	_bar(Rect2(rect.position + Vector2(14.0 * k, 32.0 * k), Vector2(rect.size.x - 28.0 * k, 17.0 * k)), _pl_hp(), _pl_hp_ghost, Color(0.82, 0.2, 0.14))
	var tired := duel.player_exhausted
	var col := Color(0.8, 0.45, 0.15) if tired else Color(0.45, 0.78, 0.3)
	_bar(Rect2(rect.position + Vector2(14.0 * k, 54.0 * k), Vector2(rect.size.x - 28.0 * k, 10.0 * k)), duel.player_stamina / Duel.MAX_STAMINA, _pl_st_ghost, col)
	if tired:
		draw_string(font, rect.position + Vector2(rect.size.x - 112.0 * k, 24.0 * k), "EXHAUSTED", HORIZONTAL_ALIGNMENT_LEFT, -1, int(13.0 * k), Color(1.0, 0.6, 0.25))


func _arrow(center: Vector2, angle: float, r: float, color: Color, filled: bool) -> void:
	var dir := Vector2(cos(angle), sin(angle))
	var perp := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([center + dir * r, center - dir * r * 0.6 + perp * r * 0.85, center - dir * r * 0.6 - perp * r * 0.85])
	if filled:
		draw_colored_polygon(pts, color)
	pts.append(pts[0])
	draw_polyline(pts, Color(0.06, 0.035, 0.025, 0.9), 2.0, true)


## Quattro frecce attorno al centro dello schermo (mirino).
func _draw_aim_cross(center: Vector2, k: float) -> void:
	var radius := 92.0 * k
	var foe_attack := duel.foe_state == Duel.FoeState.WINDUP
	for i in 4:
		var ang: float = AIM_ANGLE[i]
		var pos := center + Vector2(cos(ang), sin(ang)) * radius
		var col := Color(1, 1, 1, 0.16)
		var r := 11.0 * k
		if duel.player_aim == i:
			col = GOLD
			r = 14.0 * k
		if duel.guard_aim == i and duel.foe_state == Duel.FoeState.IDLE:
			draw_arc(pos, r + 8.0 * k, 0.0, TAU, 24, Color(BLUE, 0.6), 2.0 * k, true)
		if foe_attack and duel.foe_aim == i:
			var pulse := 0.6 + 0.4 * sin(_time * 22.0)
			col = Color(RED, 0.65 + 0.35 * pulse)
			r = (16.0 + 6.0 * pulse) * k
			# Anello che si stringe: all'impatto è chiuso.
			var ring := lerpf(48.0, 15.0, duel.windup_progress) * k
			draw_arc(pos, ring, 0.0, TAU, 32, Color(RED, 0.8), 3.0 * k, true)
		_arrow(pos, ang, r, col, true)
	# Mirino centrale.
	draw_circle(center, 2.5 * k, Color(1, 1, 1, 0.45))


## Lampo del colpo appena sferrato: una striscia che attraversa lo schermo nella direzione del fendente.
func _draw_slash(s: Vector2, k: float) -> void:
	if duel.slash_flash <= 0.02:
		return
	var f := duel.slash_flash
	var c := s * 0.5 + Vector2(0.0, -20.0 * k)
	var a := Vector2.ZERO
	var b := Vector2.ZERO
	match duel.slash_aim:
		Duel.Aim.HIGH:
			a = c + Vector2(-170, -220) * k
			b = c + Vector2(190, 200) * k
		Duel.Aim.LEFT:
			a = c + Vector2(-330, -40) * k
			b = c + Vector2(300, 60) * k
		Duel.Aim.RIGHT:
			a = c + Vector2(330, -40) * k
			b = c + Vector2(-300, 60) * k
		_:
			a = c + Vector2(-60, 240) * k
			b = c + Vector2(40, -120) * k
	var mid := a.lerp(b, 1.0 - f * 0.5)
	draw_line(a, mid, Color(1.0, 0.95, 0.85, f * 0.5), 5.0 * k * f, true)
	draw_line(a, mid, Color(1.0, 1.0, 1.0, f * 0.8), 2.0 * k, true)


func _draw_popups(pos: Vector2, k: float, font: Font) -> void:
	var y := 0.0
	for p in _popups:
		var age := float(p["age"])
		var a := clampf(1.0 - maxf(age - 1.0, 0.0) / 0.6, 0.0, 1.0) * clampf(age / 0.08, 0.0, 1.0)
		var size_px := int((26.0 + 6.0 * (1.0 - clampf(age / 0.25, 0.0, 1.0))) * k)
		var text := p["text"] as String
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		var at := pos + Vector2(-tw * 0.5, y - age * 24.0 * k)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, int(6.0 * k), Color(0.05, 0.02, 0.01, a * 0.9))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(p["color"] as Color, a))
		y += 34.0 * k


func _draw_hint(pos: Vector2, k: float, font: Font) -> void:
	var a := clampf(1.0 - (duel.fight_time - 7.0) / 2.0, 0.0, 1.0)
	if a <= 0.0:
		return
	var text := "LMB attack   |   RMB parry   |   SPACE dodge   |   W A S D choose the strike direction"
	var size_px := int(15.0 * k)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	draw_string_outline(font, pos + Vector2(-tw * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, int(5.0 * k), Color(0.05, 0.02, 0.01, a * 0.9))
	draw_string(font, pos + Vector2(-tw * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(0.97, 0.9, 0.75, a))
	var tip := "Parry in the SAME direction as the incoming strike for a perfect parry"
	var tw2 := font.get_string_size(tip, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	draw_string_outline(font, pos + Vector2(-tw2 * 0.5, -24.0 * k), tip, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, int(5.0 * k), Color(0.05, 0.02, 0.01, a * 0.9))
	draw_string(font, pos + Vector2(-tw2 * 0.5, -24.0 * k), tip, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(GOLD, a))
