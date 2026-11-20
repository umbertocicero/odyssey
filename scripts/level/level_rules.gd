class_name LevelRules
extends Resource
## Parametri del livello 1 (sopravvivere fino al segnale di ritirata mentre si
## salvano i compagni feriti). Si regolano dall'Inspector su data/level1/rules.tres.

@export_group("Tempo")
## Secondi da sopravvivere prima del segnale di ritirata.
@export_range(10.0, 900.0) var duration := 180.0
## Secondi prima della prima ondata.
@export_range(0.0, 120.0) var first_wave_delay := 8.0
## Secondi tra un'ondata e la successiva.
@export_range(3.0, 120.0) var wave_interval := 25.0

@export_group("Ondate troiane")
@export_range(0, 20) var base_trojans := 2
## Soldati in più a ogni ondata.
@export_range(0.0, 6.0) var trojans_per_wave := 1.0
@export_range(1, 30) var max_trojans_per_wave := 8
## Massimo di troiani vivi contemporaneamente (tiene bassi i costi su mobile).
@export_range(1, 40) var max_alive_trojans := 14
@export_range(5, 500) var trojan_health := 40
@export_range(0, 100) var trojan_health_per_wave := 6
@export_range(1, 100) var trojan_damage := 8
@export_range(0.0, 20.0) var trojan_damage_per_wave := 1.5
## Secondi per passo (più basso = più veloce).
@export_range(0.15, 1.5) var trojan_step_duration := 0.45
@export_range(0.0, 0.1) var trojan_step_faster_per_wave := 0.02
@export_range(0.3, 5.0) var trojan_attack_interval := 1.3
## Punti di partenza dei troiani (x, z in metri), sotto le mura.
@export var spawn_points := PackedVector2Array([Vector2(-18, -16), Vector2(-8, -17), Vector2(2, -17), Vector2(12, -16), Vector2(20, -14)])

@export_group("Difese sulle mura")
## A ogni ondata le postazioni tirano più spesso (+ questa frazione) ...
@export_range(0.0, 1.0) var defence_reload_gain_per_wave := 0.12
## ... e fanno più danno (+ questa frazione).
@export_range(0.0, 1.0) var defence_damage_gain_per_wave := 0.08

@export_group("Feriti")
@export_range(0, 20) var wounded_count := 6
@export_range(5, 300) var wounded_health := 40
## Dove giacciono i feriti (x, z in metri). Se la casella è occupata si usa la più vicina libera.
@export var wounded_points := PackedVector2Array([Vector2(-6, 1), Vector2(7, -3), Vector2(-15, -5), Vector2(13, 6), Vector2(-1, -11), Vector2(17, -6), Vector2(-9, 6), Vector2(4, 8)])
## Casella dell'accampamento (x, z, larghezza, altezza in caselle): lì i feriti sono in salvo.
@export var camp_rect := Rect2i(2, 28, 12, 7)

@export_group("Punteggio")
@export_range(0, 1000) var score_per_wounded := 100
@export_range(0, 200) var score_per_kill := 10
@export_range(0, 2000) var all_saved_bonus := 200
## Frazione di feriti salvati da cui la ritirata è "ordinata".
@export_range(0.0, 1.0) var good_threshold := 0.5


## Numero di troiani della n-esima ondata (n parte da 1).
func trojans_in_wave(n: int) -> int:
	return clampi(base_trojans + roundi(trojans_per_wave * (n - 1)), 0, max_trojans_per_wave)


func health_in_wave(n: int) -> int:
	return trojan_health + trojan_health_per_wave * (n - 1)


func damage_in_wave(n: int) -> int:
	return roundi(trojan_damage + trojan_damage_per_wave * (n - 1))


func step_in_wave(n: int) -> float:
	return maxf(0.15, trojan_step_duration - trojan_step_faster_per_wave * (n - 1))


func reload_scale_in_wave(n: int) -> float:
	return 1.0 + defence_reload_gain_per_wave * (n - 1)


func damage_scale_in_wave(n: int) -> float:
	return 1.0 + defence_damage_gain_per_wave * (n - 1)


func score_for(saved: int, kills: int, total: int) -> int:
	var s := saved * score_per_wounded + kills * score_per_kill
	if total > 0 and saved >= total:
		s += all_saved_bonus
	return s
