class_name PolyhavenScatterDef
extends Resource
## Parametri di uno sparso Poly Haven (fiori, ciuffi, felci, cespugli) disegnato con MultiMesh da
## PolyhavenProps. Si modifica dall'Inspector del nodo PropsPolyhaven di level1.tscn: ogni sparso
## è troppo denso per avere un nodo per istanza, quindi resta generato, ma area, numero e seed sono qui.

@export var label := "Scatter"
## Identificatori del catalogo (PolyhavenCatalog) delle varianti da mescolare.
@export var ids: PackedStringArray = PackedStringArray()
## Rettangolo di sparpagliamento in metri (x, z, larghezza, profondità).
@export var rect := Rect2(-10, -10, 20, 20)
## Numero di istanze a densità piena (si moltiplica per Quality.density()).
@export var count := 20
## Altezza minima e massima di ogni pianta, in metri.
@export var height_min := 0.3
@export var height_max := 0.5
## Cambiando il seed cambia la disposizione, a parità di tutto il resto.
@export var random_seed := 1
@export var cast_shadows := false
## Rispetta la maschera dell'erba (niente su strade, piazzali, sabbia).
@export var use_mask := true
## Peso minimo della maschera dell'erba per piantare.
@export_range(0.0, 1.0) var min_grass := 0.6


## Stessa forma del dizionario del file JSON, così PolyhavenProps ha un solo percorso di costruzione.
func to_dict() -> Dictionary:
	return {
		"name": label, "ids": Array(ids), "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		"count": count, "height": [height_min, height_max], "seed": random_seed,
		"cast_shadows": cast_shadows, "use_mask": use_mask, "min_grass": min_grass,
	}
