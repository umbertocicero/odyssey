class_name AttackProfile
extends Resource
## Parametri di un'arma da tiro sulle mura (arco, arco con frecce infiammate,
## balista, catapulta). Ogni arma usa un file .tres in data/combat/:
## si regola tutto dall'Inspector senza toccare il codice.

enum Shape { ARROW, BOLT, STONE }

## Nome mostrato al giocatore (in inglese, come tutti i testi del gioco).
@export var display_name := "Arrow"
## Gittata massima, in caselle (distanza dal tiratore al centro della casella).
@export_range(1, 40) var range_cells := 9
## Distanza minima: più vicino di così non riesce a tirare (es. catapulta).
@export_range(0, 40) var min_range_cells := 0
## Danno a chi è nelle caselle colpite.
@export_range(0, 200) var damage := 8
## Secondi tra un tiro e l'altro.
@export_range(0.2, 30.0, 0.1) var reload_time := 3.0
## Ritardo casuale aggiunto alla ricarica, per non tirare tutti insieme.
@export_range(0.0, 10.0, 0.1) var reload_jitter := 0.8
## Durata del volo, in secondi: è anche il tempo in cui l'avviso resta a terra
## sulla casella bersaglio, quindi il tempo che ha il giocatore per spostarsi.
@export_range(0.3, 5.0, 0.1) var warning_time := 1.2
## Altezza della parabola del proiettile, in metri.
@export_range(0.0, 15.0, 0.5) var arc_height := 2.5
## 0 = una casella; 1 = area 3×3; 2 = area 5×5.
@export_range(0, 2) var area_radius := 0
## Probabilità di mancare di una casella (0 = sempre preciso).
@export_range(0.0, 1.0, 0.05) var miss_chance := 0.2
## Secondi in cui le caselle colpite restano in fiamme (0 = niente fuoco).
@export_range(0.0, 30.0, 0.5) var burn_duration := 0.0
## Danno al secondo a chi sta in una casella in fiamme.
@export_range(0, 50) var burn_damage_per_second := 0
@export var projectile_shape: Shape = Shape.ARROW
@export var projectile_color := Color(0.35, 0.25, 0.15)
## Proiettile luminoso (frecce infiammate).
@export var projectile_glow := false
@export var projectile_scale := 1.0
