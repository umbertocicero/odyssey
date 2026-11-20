class_name Quality
extends RefCounted
## Livello di qualità grafica: LOW, MEDIUM, HIGH. Regola particelle, ombre di
## contatto, densità dell'erba e dettagli sparsi per tenere fluidi mobile e web.
## Si può forzare da riga di comando (`-- --quality=low|medium|high`) o con la
## variabile d'ambiente ODYSSEY_QUALITY. Senza forzature: web = LOW,
## mobile = MEDIUM, PC = HIGH.

enum Level { LOW, MEDIUM, HIGH }

static var _cached := -1


static func current() -> Level:
	if _cached >= 0:
		return _cached as Level
	var wanted := OS.get_environment("ODYSSEY_QUALITY").to_lower()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--quality="):
			wanted = arg.substr(10).to_lower()
	match wanted:
		"low":
			_cached = Level.LOW
		"medium":
			_cached = Level.MEDIUM
		"high":
			_cached = Level.HIGH
		_:
			if OS.has_feature("web"):
				_cached = Level.LOW
			elif OS.has_feature("mobile"):
				_cached = Level.MEDIUM
			else:
				_cached = Level.HIGH
	return _cached as Level


## Forza un livello (menu opzioni, test). Chi lo usa deve ricreare ciò che dipende dal livello.
static func set_level(level: Level) -> void:
	_cached = level


## Moltiplicatore di densità per i dettagli sparsi: 0.35 / 0.7 / 1.0.
static func density() -> float:
	match current():
		Level.LOW:
			return 0.35
		Level.MEDIUM:
			return 0.7
	return 1.0


## Budget di ciuffi dell'erba a cards (GrassCards): web 3k, mobile 10k, PC 30k.
static func grass_budget() -> int:
	var forced := OS.get_environment("ODYSSEY_GRASS_BUDGET")
	if forced.is_valid_int():
		return forced.to_int()
	match current():
		Level.LOW:
			return 3000
		Level.MEDIUM:
			return 10000
	return 30000
