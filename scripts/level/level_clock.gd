class_name LevelClock
extends Node
## Orologio di livello (todo.md, sezione 0): tempo che passa in modo continuo dal tramonto alla notte,
## vento variabile e pioggia casuale. È l'unica fonte di ora, vento e meteo: gli altri sistemi
## (LevelAtmosphere, erba, particelle) leggono da qui. Nessuno stage è visibile al giocatore.

signal rain_changed(amount: float)

## Ora di partenza e velocità: ore di gioco al secondo reale (0,008 = 4 ore in ~8 minuti).
@export_range(0.0, 24.0) var start_hour := 17.5
@export_range(0.0, 0.1) var hours_per_second := 0.008
@export_range(0.0, 24.0) var end_hour := 23.5
@export var running := true
@export var random_seed := 1234
## Probabilità di pioggia a ogni lancio del dado (ogni 60-120 s) e durata.
@export_range(0.0, 1.0) var rain_chance := 0.2
@export var rain_enabled := true

## Uscite lette dagli altri sistemi.
var time_of_day := 17.5
var wind_direction := Vector2(1.0, 0.3)
var wind_strength := 0.1
var rain := 0.0          # 0..1, intensità (sale e scende gradualmente)
var wetness := 0.0       # 0..1, terreno bagnato: scende piano quando smette di piovere

var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _t := 0.0
var _next_roll := 45.0
var _rain_left := 0.0
var _raining := false


func _enter_tree() -> void:
	add_to_group(&"level_clock")


func _ready() -> void:
	_rng.seed = random_seed
	_noise.seed = random_seed
	_noise.frequency = 0.05
	time_of_day = start_hour


## 0 = giorno pieno, 1 = notte piena (smoothstep tra le 19:30 e le 21:30).
func night_amount() -> float:
	return smoothstep(19.5, 21.5, time_of_day)


## 0 = tramonto fino a 1 = giorno (sole alto prima delle 17:30), solo per curve.
func is_raining() -> bool:
	return _raining


func advance(delta: float) -> void:
	_t += delta
	if running:
		time_of_day = minf(time_of_day + hours_per_second * delta, end_hour)
	# Vento: direzione che ruota piano, forza di base più raffiche.
	var angle := _noise.get_noise_1d(_t * 0.6) * PI
	wind_direction = Vector2(cos(angle), sin(angle) * 0.6).normalized()
	var gust := maxf(_noise.get_noise_1d(_t * 4.0 + 100.0), 0.0)
	wind_strength = clampf(0.08 + gust * 0.22 + rain * 0.12, 0.0, 0.5)
	# Pioggia: macchina a stati con dado ogni 60-120 s.
	if rain_enabled:
		_next_roll -= delta
		if _next_roll <= 0.0 and not _raining:
			_next_roll = _rng.randf_range(60.0, 120.0)
			if _rng.randf() < rain_chance:
				_raining = true
				_rain_left = _rng.randf_range(40.0, 120.0)
		if _raining:
			_rain_left -= delta
			if _rain_left <= 0.0:
				_raining = false
	var target := 1.0 if _raining else 0.0
	var before := rain
	rain = move_toward(rain, target, delta / 8.0)
	if not is_equal_approx(before, rain):
		rain_changed.emit(rain)
	# Il terreno si bagna in fretta e si asciuga piano (circa 60 s dopo il sole).
	if rain > wetness:
		wetness = move_toward(wetness, rain, delta / 6.0)
	else:
		wetness = move_toward(wetness, rain, delta / 60.0)


## Per i test: forza la pioggia per un tempo.
func start_rain(seconds: float) -> void:
	_raining = true
	_rain_left = seconds


func _process(delta: float) -> void:
	advance(delta)
