# TODO — Atmosfera del livello 1 (vento, foglie, particelle, tempo, pioggia)

Stato: **solo piano, niente implementato.** Un solo Godot alla volta (il PC si è bloccato con più render in parallelo).
Regole: testi visibili nel gioco in **inglese**; commenti nel codice e questo documento in italiano.

## Punti di partenza nel codice

- `assets/shaders/grass.gdshader`: ha già vento (uniform `wind_strength`, `wind_speed`, `wind_direction`, `wind_scale`) e interattori. Il vento è però statico.
- `scripts/props/level_atmosphere.gd` (nodo `LevelAtmosphere`): luce del sole, cielo, ambiente, falò con fiamma, fumo e scintille (CPUParticles3D), ombre di contatto.
- `scripts/rendering/quality.gd` (`Quality`): LOW (web), MEDIUM (mobile), HIGH (PC); `Quality.density()` = 0.35 / 0.7 / 1.0.
- `scripts/level/level_director.gd`: segnali `wave_started(number, trojan_count)`, `time_changed`, `level_finished`. Le **ondate sono gli stage** del livello: sono il clock naturale del tempo che passa.
- `scripts/props/grass_field.gd`: MultiMesh dell'erba; `post_process.gdshader` per l'immagine finale.
- Nota: in `outputs/w2..w4` ci sono versioni più recenti di `level_atmosphere.gd`, `grass_field.gd`, `quality.gd`; controllare quale copia è quella viva sul PC.

## Ordine di lavoro consigliato

1. **Orologio di livello e vento globale** (fondamenta, quasi gratis)
2. **Ciclo giorno/notte per stage**
3. **Particelle d'ambiente** (polvere, polline, scintille bracieri)
4. **Foglie che cadono**
5. **Pioggia casuale** (ultima: dipende da luce, vento e particelle)
6. **Misure reali per qualità e web**, poi taratura

Ogni passo deve essere regolabile da `@export` e spegnibile per qualità.

---

## 0. Orologio di livello (nuovo, prerequisito)

Nuovo script `scripts/level/level_clock.gd` (`LevelClock`), figlio del livello:

- `time_of_day` in ore (0–24) e segnale `time_changed_hour`. Tempo di gioco, non reale.
- Ogni `wave_started(n, …)` del `LevelDirector` imposta un orario di destinazione (es. stage 1 = 17:30, … ultimo = 21:30). Tra uno stage e l'altro l'orario avanza in modo continuo, così la luce cambia piano durante la battaglia.
- Orari per stage in `data/level1/rules.tres` (nuovo array `stage_hours`).
- Un solo nodo `LevelClock` con tre output (`time_of_day`, `wind`, `rain`) letto da tutti.

Costo: trascurabile. Rischio: basso (aggiungere solo la connessione ai segnali, non cambiare le regole).

## 1. Vento variabile

Obiettivo: brezza che muove erba, cespugli, chiome e stendardi, con direzione e intensità che cambiano.

- `LevelClock` genera `wind_direction` (rotazione lenta con rumore) e `wind_strength` (base + raffiche con `FastNoiseLite`, una raffica ogni 6–15 s).
- Erba: `grass_field.gd` aggiorna gli uniform ogni frame via `set_shader_parameter` (costo 3 uniform per frame). Aggiungere un uniform `gust`.
- Cespugli e chiome: piccolo shader `foliage_sway.gdshader` (vertex displacement con maschera da altezza) come `material_overlay` o sui materiali dei GLB delle piante.
- Stendardi: shader `banner_wave.gdshader` (onda sinusoidale ancorata all'asta); se sono mesh rigide, servono più vertici (thread Blender).
- Vento anche per fumo e scintille: `gravity`/`direction` leggermente orientati dal vento.

Bassa: solo erba + stendardi. Media: + cespugli e chiome. Alta: + raffiche con più armoniche, fumo guidato.
Rischi: il vertex shader dell'erba è già pesante; niente letture di texture nel vertex (WebGL2). Onde procedurali con `sin`.

## 2. Foglie che cadono

- `CPUParticles3D` (più sicuro su web) sopra alberi e cespugli: pochi emettitori a box che coprono le zone alberate, non uno per albero.
- Quad con texture foglia (alpha cutout, 2–3 varianti in atlas), rotazione su tutti gli assi, gravità bassa e drag, deriva dal vento di `LevelClock`.
- `StandardMaterial3D` senza billboard, `alpha_scissor`, niente trasparenza vera.
- Foglie a terra che si muovono: opzionale, solo qualità alta.

Bassa: 0–15 particelle, un emettitore. Media: ~60. Alta: ~150.
Rischi: emettitori numerosi su web = molti draw call; limitare a 1–3 totali.

## 3. Particelle d'ambiente

- **Polvere e sabbia**: velo basso sulla pianura, sollevato dal vento e dai passi (hook in `grid_unit.gd`, pool riusabile, max ~8 puff). Riusare `_soft_texture()` di `level_atmosphere.gd`.
- **Fumo dei fuochi**: già presente (`_add_smoke`); aggiungere inclinazione dal vento e spegnere i fuochi lontani dalla camera.
- **Scintille dei bracieri**: `_add_sparks` esiste già; estendere ai bracieri nuovi, più forti al buio.
- **Polline / foschia dorata**: particelle sottili nella luce del tramonto, forti alle 17–18, zero di notte, una `CPUParticles3D` che segue la camera (box ~20 m).
- **Foschia**: `Environment.fog` (supportata in Compatibility), colore e densità legati a ora e pioggia. Niente nebbia volumetrica.

Bassa: solo fog + fumo vicino. Media: + polvere dai passi + polline. Alta: tutto.
Tetto particelle attive: bassa ≤ 60, media ≤ 250, alta ≤ 600. Pool di emettitori, mai `instantiate` per ogni passo.

## 4. Tempo che passa: dal tramonto alla notte

Gestito da `LevelAtmosphere` leggendo `LevelClock.time_of_day` (oggi i valori sono fissi in `_setup_light`).

- **Sole**: `DirectionalLight3D` ruota con l'ora (elevazione da ~25° a sotto l'orizzonte); colore da arancione caldo a viola-blu; `light_energy` scende, ombre più lunghe e morbide. Dopo il tramonto subentra una luce "luna" blu fioca (secondo DirectionalLight3D senza ombre, ombre solo alta qualità).
- **Cielo**: `sky_top_color`, `sky_horizon_color` e `ambient_energy` come `Gradient`/`Curve` indicizzati dall'ora (risorse `.tres`). Stelle di notte: parametro `stars` nello shader del cielo.
- **Fuochi**: fuochi, torce e bracieri si accendono al buio: `OmniLight3D.light_energy` e fiamma scalano con una curva `fire_intensity(t)`.
- **Post-process**: color grading leggero in `post_process.gdshader` (uniform `tint`, `desaturation`, `vignette` pilotati dall'ora).
- **UI (inglese)**: facoltativo, indicazione dell'orario nell'HUD ("Dusk", "Night").
- **Gameplay**: la notte non deve nascondere i feriti; luce ambiente minima e leggero alone sui feriti da salvare. Da concordare con Umberto.

Bassa: sole e cielo interpolati, 1 luce, luci dei fuochi solo vicino alla camera. Media: + più luci fuochi (max 8 OmniLight3D) e tint. Alta: + luce luna, ombre morbide, stelle.
Rischio: numero di luci in Compatibility (verificare il limite in `project.godot`); sulle qualità basse sostituire le luci lontane con un quad emissivo (falso alone).

## 5. Pioggia casuale

Macchina a stati in `LevelClock`: `CLEAR → RAIN_START → RAIN → RAIN_END → CLEAR`.

- **Scelta casuale**: a ogni `wave_started` e ogni 60–120 s si tira un dado: `rain_chance` (15–25 %, in `rules.tres`). Durata 40–120 s, transizione di 6–10 s (`rain` 0→1). `RandomNumberGenerator` con seed registrato per riprodurre i bug.
- **Particelle**: un emettitore a box che segue la camera (~30×30 m), righe sottili stirate, inclinate dal vento; splash opzionale (alta qualità).
- **Terreno bagnato**: uniform globale `wetness` (`RenderingServer.global_shader_parameter_set`) che abbassa `ROUGHNESS` e scurisce l'albedo; su bassa qualità solo tint nel post-process.
- **Vento ed erba**: durante la pioggia vento più forte ed erba più scura.
- **Luce**: sole più debole e freddo, `fog_density` su, `ambient_energy` giù; fuochi più piccoli e con più fumo.
- **Suoni**: pioggia in loop e vento, quando ci saranno gli audio.
- **Gameplay (da decidere con Umberto)**: archi e frecce infuocate meno efficaci? Per ora solo estetico.

Bassa/web: semplificata a costo fisso (nessuna particella 3D, overlay 2D con shader canvas_item su `ColorRect` + fog/tint). Media: ~250 particelle CPU vicino alla camera, wetness solo sul terreno. Alta: ~700 particelle, splash, wetness su tutti i materiali principali.
Vincolo di Umberto: la pioggia non deve aumentare il costo su bassa qualità e web; in LOW la pioggia sostituisce foschia e polvere e si spengono polline e polvere mentre piove.

## Costo complessivo stimato per qualità

| Voce | Bassa (web) | Media (mobile) | Alta (PC) |
|---|---|---|---|
| Vento | erba + stendardi | + cespugli/chiome | + raffiche, fumo guidato |
| Foglie | 0–15 | ~60 | ~150 |
| Particelle ambiente | fog + fumo vicino | + polvere, polline | piene |
| Giorno/notte | 1 luce, curve | + tint, più luci | + luna, stelle, ombre |
| Pioggia | overlay 2D | ~250 particelle | ~700 + splash |
| Particelle attive (tetto) | ≤ 60 | ≤ 250 | ≤ 600 |

Le cifre sono stime di partenza da confermare con misure reali (PC, telefono medio, browser). Umberto accetta di escludere il web solo dopo le misure.

## Rischi trasversali

- Compatibility renderer (web/mobile): niente SSAO, nebbia volumetrica, SSS vero; `GPUParticles3D` su WebGL2 va testato, in dubbio `CPUParticles3D`.
- MultiMesh dell'erba: i nuovi shader devono rispettare il layout di INSTANCE_CUSTOM.
- Numero di luci con molti fuochi di notte.
- Uniform globali (`wind`, `wetness`, `time_of_day`) come *global shader parameters* in `project.godot`.
- Tutte le modifiche passano da `LevelClock`.
- Un solo Godot alla volta; test con qualità bassa per primo.

## Test da scrivere (in `tests/`, sul modello di `test_gameplay.gd`)

- `test_level_clock.gd`: l'orario avanza con gli stage e non torna indietro; il seed del meteo è riproducibile; la pioggia parte e finisce.
- `test_atmosphere.gd`: luce a ora data e fuochi accesi di notte.
- Controllo di particelle e luci per qualità (tetti sopra).
- Screenshot a 17:30, 19:30, 21:30 e sotto la pioggia, qualità alta e bassa (uno alla volta).

## Domande aperte per Umberto

1. Quanti stage ha il livello 1 e quali orari (propongo da 17:30 a 21:30)?
2. La pioggia deve influire sul gameplay o solo estetica?
3. Luna e stelle, o notte molto scura illuminata solo dai fuochi?
4. Il web resta un target obbligatorio o si decide dopo le misure?
