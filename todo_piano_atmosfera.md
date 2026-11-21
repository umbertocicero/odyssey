# TODO — Atmosfera del livello 1 (vento, foglie, particelle, tempo, pioggia)

Stato: **solo piano, niente implementato.** Un solo Godot alla volta (il PC si è bloccato con più render in parallelo).
Regole: testi visibili nel gioco in **inglese**; commenti nel codice e questo documento in italiano.

## Punti di partenza nel codice

- `assets/shaders/grass.gdshader`: ha già vento (uniform `wind_strength`, `wind_speed`, `wind_direction`, `wind_scale`) e interattori. Il vento è statico: direzione e forza fisse.
- `scripts/props/level_atmosphere.gd` (`LevelAtmosphere`): sole, cielo, ambiente, falò con fiamma, fumo e scintille (CPUParticles3D), ombre di contatto. Per i fuochi c'è già un controllo per qualità.
- `scripts/rendering/quality.gd` (`Quality`): LOW (web), MEDIUM (mobile), HIGH (PC); `Quality.density()` = 0.35 / 0.7 / 1.0.
- `scripts/level/level_director.gd`: segnali `wave_started`, `time_changed`, `level_finished`. Le **ondate sono gli stage**: il clock naturale del tempo che passa.
- `scripts/props/grass_field.gd`: MultiMesh dell'erba; `assets/shaders/post_process.gdshader` per l'immagine finale.
- Nota: nel progetto cloud ci sono versioni più recenti di `level_atmosphere.gd`, `grass_field.gd`, `quality.gd` (cartelle outputs/w2..w4); controllare quale copia è viva sul PC prima di lavorare.

## Ordine di lavoro consigliato

1. Orologio di livello e vento globale (fondamenta, quasi gratis)
2. Ciclo giorno/notte per stage (sfrutta l'orologio)
3. Particelle d'ambiente (polvere, polline, scintille bracieri)
4. Foglie che cadono
5. Pioggia casuale (ultima: dipende da luce, vento e particelle)
6. Misure reali per qualità e web, poi taratura

Ogni passo deve essere regolabile da `@export` e spegnibile per qualità.

---

## 0. Orologio di livello (prerequisito)

Nuovo nodo/script `scripts/level/level_clock.gd` (`LevelClock`), figlio del livello:

- `time_of_day` in ore (0–24) e segnale `time_changed_hour`. Tempo di gioco, non reale.
- Ogni `wave_started(n, …)` imposta un orario di destinazione (es. stage 1 = 17:30, ultimo = 21:30). Tra uno stage e l'altro l'orario avanza con un lerp lento.
- Orari per stage in `data/level1/rules.tres` (nuovo array `stage_hours`).
- Un solo nodo `LevelClock` con tre output (`time_of_day`, `wind`, `rain`) letto da tutti.

Costo: trascurabile. Rischio: basso.

## 1. Vento variabile

- `LevelClock` genera direzione (rotazione lenta con rumore) e forza (base + raffiche con `FastNoiseLite`, ogni 6–15 s).
- Erba: `grass_field.gd` aggiorna gli uniform di `grass.gdshader` ogni frame con `set_shader_parameter`; aggiungere `gust`.
- Cespugli e chiome: shader `foliage_sway.gdshader` (vertex displacement con maschera da colore/altezza vertice).
- Stendardi: shader `banner_wave.gdshader` ancorato all'asta; se le mesh sono rigide servono più vertici (verificare in Blender).
- Fumo e scintille: direzione leggermente guidata dal vento, aggiornamento lento.

| Qualità | Costo |
|---|---|
| Bassa | erba + stendardi; cespugli statici. Solo vertex, ~0 ms extra |
| Media | + cespugli e chiome |
| Alta | + raffiche più ricche, fumo guidato |

Rischi: il vertex shader dell'erba è già pesante con MultiMesh; niente letture di texture nel vertex (WebGL2).

## 2. Foglie che cadono

- `CPUParticles3D` sopra alberi e cespugli, pochi emettitori a box (posizioni dalle istanze degli alberi nei GridProp). In Compatibility `CPUParticles3D` è più sicuro sul web; `GPUParticles3D` solo da testare.
- Quad con texture foglia (alpha cutout, 2–3 varianti), rotazione su tutti gli assi, gravità bassa e drag, deriva dal vento.
- Materiale senza billboard, `alpha_scissor`, niente trasparenza vera.

| Qualità | Foglie |
|---|---|
| Bassa | 0 o ~15 particelle, un solo emettitore |
| Media | ~60 |
| Alta | ~150 |

Rischi: più emettitori = più draw call. Limitare a 1–3 emettitori totali.

## 3. Particelle d'ambiente

- Polvere e sabbia: velo basso sulla pianura, sollevato dal vento e dai passi (hook in `grid_unit.gd`, pool di max ~8 puff). Riusare `_soft_texture()`.
- Fumo dei fuochi: già presente (`_add_smoke`); aggiungere inclinazione dal vento.
- Scintille dei bracieri: `_add_sparks` esiste; più in alto al buio.
- Polline / foschia dorata: una sola `CPUParticles3D` che segue la camera (box ~20 m), intensa alle 17–18, zero di notte.
- Foschia: `Environment.fog` (supportata in Compatibility), legata a ora e pioggia. Niente nebbia volumetrica.

| Qualità | Costo |
|---|---|
| Bassa | fog + fumo vicino; polvere ridotta a pochi puff |
| Media | + polvere dai passi + polline |
| Alta | tutto, densità piena |

Tetto suggerito di particelle attive: bassa ≤ 60, media ≤ 250, alta ≤ 600. Pool di emettitori, mai `instantiate` per ogni passo.

## 4. Tempo che passa: dal tramonto alla notte

Gestito da `LevelAtmosphere` leggendo `LevelClock.time_of_day` (oggi i valori sono fissi in `_setup_light`).

- Sole: `DirectionalLight3D` ruota con l'ora; colore da arancione a viola-blu; energia in calo, ombre più lunghe e morbide. Dopo il tramonto subentra una luce "luna" fioca (solo qualità alta).
- Cielo: colori e `ambient_energy` come `Gradient`/`Curve` indicizzati dall'ora. Stelle di notte: parametro `stars` nello shader del cielo.
- Fuochi: si accendono al buio. `OmniLight3D.light_energy` e fiamma scalano con una curva `fire_intensity(t)`.
- Post-process: color grading leggero in `post_process.gdshader` (`tint`, `desaturation`, `vignette` dall'ora).
- UI (inglese): facoltativo, indicazione di orario nell'HUD, es. "Dusk", "Night".
- Gameplay: la notte non deve nascondere i feriti; minimo di luce ambiente e alone sui feriti. Da concordare con Umberto.

| Qualità | Costo |
|---|---|
| Bassa | sole e cielo interpolati, 1 luce, luci fuochi solo vicine alla camera; niente luna |
| Media | + più luci fuochi (max 8 OmniLight3D attive), tint |
| Alta | + luna, ombre morbide complete, stelle |

Rischi: numero di luci in Compatibility; con molti fuochi accesi, sulle qualità basse accendere solo le luci vicine e sostituire le altre con un quad emissivo.

## 5. Pioggia casuale

Meteo gestito da `LevelClock`: `CLEAR → RAIN_START → RAIN → RAIN_END → CLEAR`.

- Scelta casuale: a ogni `wave_started` e ogni 60–120 s si tira un dado (`rain_chance`, es. 15–25 %, in `rules.tres`). Durata 40–120 s, transizione 6–10 s. `RandomNumberGenerator` con seed registrato.
- Particelle: un emettitore a box che segue la camera (~30×30 m), righe sottili, direzione dal vento; splash opzionale in alta qualità.
- Terreno bagnato: uniform globale `wetness` che abbassa la rugosità e scurisce l'albedo. Su bassa qualità basta scurire il tint nel post-process.
- Vento e erba più forti e più scuri durante la pioggia; sole più debole e freddo; fog più alta; fuochi più piccoli con più fumo.
- Suoni: pioggia e vento in loop, da pianificare con gli audio.
- Gameplay (da decidere con Umberto): archi e frecce infuocate meno efficaci sotto la pioggia?

| Qualità | Pioggia |
|---|---|
| Bassa / web | semplificata e a costo fisso: nessuna particella 3D; overlay 2D animato (shader canvas_item) + fog/tint |
| Media | ~250 particelle CPU vicino alla camera, terreno bagnato |
| Alta | ~700 particelle, splash, bagnato su tutti i materiali principali |

Vincolo: la pioggia non deve aumentare il costo su bassa qualità e web. In LOW la pioggia sostituisce polvere e polline.

## Costo complessivo stimato

| Voce | Bassa (web) | Media (mobile) | Alta (PC) |
|---|---|---|---|
| Vento | erba + stendardi | + cespugli/chiome | + raffiche, fumo guidato |
| Foglie | 0–15 | ~60 | ~150 |
| Particelle ambiente | fog + fumo vicino | + polvere, polline | piene |
| Giorno/notte | 1 luce, curve | + tint, più luci | + luna, stelle, ombre |
| Pioggia | overlay 2D | ~250 particelle | ~700 + splash |
| Tetto particelle attive | ≤ 60 | ≤ 250 | ≤ 600 |

Stime da confermare con misure reali (frame time sul PC con iGPU Intel, un telefono medio, browser). Il web si esclude solo dopo le misure.

## Rischi trasversali

- Compatibility (web/mobile): niente SSAO, nebbia volumetrica, SSS vero; `GPUParticles3D` su WebGL2 da testare.
- MultiMesh: l'erba usa INSTANCE_CUSTOM; nuovi shader sullo stesso MultiMesh devono rispettare il layout (angolo, scala, fase).
- Shader condivisi: `wind`, `wetness`, `time_of_day` come global shader parameters in `project.godot`.
- Tutte le modifiche passano da `LevelClock`; nessuno script legge ora o meteo da altre fonti.
- Un solo Godot alla volta; test con `--quality=low` per primo.

## Test da scrivere (in `tests/`)

- `test_level_clock.gd`: l'ora avanza con gli stage e non torna indietro; seed meteo riproducibile; pioggia che parte e finisce.
- `test_atmosphere.gd`: luce a ora data, fuochi accesi di notte.
- Controllo di particelle e luci per qualità.
- Screenshot a 17:30, 19:30, 21:30 e sotto pioggia, qualità alta e bassa (uno alla volta).

## Domande aperte per Umberto

1. Quanti stage ha il livello 1 e quali orari (propongo dal tramonto, 17:30, fino a 21:30)?
2. La pioggia incide sul gameplay (archi, fuochi) o solo estetica?
3. Luna e stelle, o notte molto scura illuminata solo dai fuochi?
4. Il web resta un target obbligatorio o decidiamo dopo le misure?
