class_name SeaWater
extends MeshInstance3D
## Mare del livello: sceglie lo shader in base alla qualità grafica (Quality).
## LOW (web) = sea_low.gdshader, MEDIUM (mobile) = sea.gdshader senza strato
## di dettaglio né schiuma di contatto, HIGH (PC) = sea.gdshader completo.

const SHADER_FULL := preload("res://assets/shaders/sea.gdshader")
const SHADER_LOW := preload("res://assets/shaders/sea_low.gdshader")
const NORMAL_TEX := preload("res://assets/environment/water/sea_normal.png")
const HEIGHT_TEX := preload("res://assets/environment/water/sea_height.png")

## x mondiale della battigia (bordo della spiaggia lato mare).
@export var shore_x := -21.6
## Per i test: -1 = usa Quality.current(), 0/1/2 = forza LOW/MEDIUM/HIGH.
@export var quality_override := -1


func _ready() -> void:
	var level: int = quality_override if quality_override >= 0 else int(Quality.current())
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_LOW if level == Quality.Level.LOW else SHADER_FULL
	mat.set_shader_parameter(&"normal_tex", NORMAL_TEX)
	mat.set_shader_parameter(&"height_tex", HEIGHT_TEX)
	mat.set_shader_parameter(&"shore_x", shore_x)
	if level != Quality.Level.LOW:
		mat.set_shader_parameter(&"detail", 1 if level == Quality.Level.HIGH else 0)
	material_override = mat
