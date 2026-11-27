class_name SeaWater
extends MeshInstance3D
## Mare del livello: sceglie lo shader in base alla qualità grafica (Quality).
## LOW (web) = sea_low.gdshader, MEDIUM (mobile) = sea.gdshader senza strato
## di dettaglio né schiuma di contatto, HIGH (PC) = sea.gdshader completo.
##
## Con il terreno fotorealistico il mare si estende sotto la spiaggia (la riva la decide la quota
## della sabbia, non il bordo del box) e crea la riva naturale (SeaShore). Con il terreno
## procedurale resta il box con la riva dritta.

const SHADER_FULL := preload("res://assets/shaders/sea.gdshader")
const SHADER_LOW := preload("res://assets/shaders/sea_low.gdshader")
const NORMAL_TEX := preload("res://assets/environment/water/sea_normal.png")
const HEIGHT_TEX := preload("res://assets/environment/water/sea_height.png")

## x mondiale della battigia del terreno procedurale (bordo della spiaggia lato mare).
@export var shore_x := -21.6
## Per i test: -1 = usa Quality.current(), 0/1/2 = forza LOW/MEDIUM/HIGH.
@export var quality_override := -1
## Riva naturale (sabbia sinuosa, bagnasciuga, detriti) quando il terreno è fotorealistico.
@export var natural_shore := true
## x mondiale fino a cui arriva il box del mare verso terra: sta sotto la spiaggia, non si vede.
@export var inland_x := -19.0

var shore: SeaShore
var fall: SeaFall


func _ready() -> void:
	var level: int = quality_override if quality_override >= 0 else int(Quality.current())
	var west_edge := global_position.x - (mesh as BoxMesh).size.x * 0.5 if mesh is BoxMesh else -26.0
	var photo := natural_shore and TerrainStyle.photo() and OS.get_environment("ODYSSEY_NO_SHORE") != "1"   # ODYSSEY_NO_SHORE=1: confronto prima/dopo
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_LOW if level == Quality.Level.LOW else SHADER_FULL
	mat.set_shader_parameter(&"normal_tex", NORMAL_TEX)
	mat.set_shader_parameter(&"height_tex", HEIGHT_TEX)
	mat.set_shader_parameter(&"shore_x", shore_x)
	mat.set_shader_parameter(&"analytic_shore", photo)
	mat.set_shader_parameter(&"shore_base_x", ShoreProfile.BASE_X)
	if level != Quality.Level.LOW:
		mat.set_shader_parameter(&"detail", 1 if level == Quality.Level.HIGH else 0)
	material_override = mat
	if photo:
		_build_natural_shore()
	_build_waterfall(west_edge)


func _build_natural_shore() -> void:
	var box := mesh as BoxMesh
	var west := global_position.x
	if box:
		west -= box.size.x * 0.5
		var wide := box.duplicate() as BoxMesh
		wide.size.x = inland_x - west
		mesh = wide
		global_position.x = (west + inland_x) * 0.5
	shore = SeaShore.new()
	shore.name = "Riva"
	shore.west_x = west
	add_child(shore)


## Il lato ovest del mare non finisce sul bordo del blocco: l'acqua cade lungo il fianco come una cascata.
func _build_waterfall(west: float) -> void:
	fall = SeaFall.new()
	fall.name = "Cascata"
	fall.edge_x = west
	add_child(fall)
