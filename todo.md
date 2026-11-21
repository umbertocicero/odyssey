# TODO — Atmosfera del livello 1 (vento, foglie, particelle, tempo, pioggia)

Stato: **solo piano, niente implementato.** Nessun commit. Un solo Godot alla volta (il PC si è bloccato con più render in parallelo).
Regole: testi visibili nel gioco in **inglese**; commenti nel codice e questo documento in italiano.

## Punti di partenza nel codice

- `assets/shaders/grass.gdshader`: ha già vento (uniform `wind_strength`, `wind_speed`, `wind_direction`, `wind_scale`) e interattori. Il vento è però statico: direzione e forza fisse.
- `scripts/props/level_atmosphere.gd` (nodo `LevelAtmosphere`): luce del sole, cielo, ambiente, falò con fiamma, fumo e scintille (CPUParticles3D), ombre di contatto. Qui vive già `Quality`-gating per i fuochi.
- `scripts/rendering/quality.gd` (`Quality`): LOW (web), MEDIUM (mobile), HIGH (PC); `Quality.density()` = 0.35 / 0.7 / 1.0.
- `scripts/level/level_director.gd`: segnali `wave_started(number, trojan_count)`, `time_changed`, `level_finished`. Le **ondate sono gli stage** del livello: sono il clock naturale del tempo che passa.
- `scripts/props/grass_field.gd`: MultiMesh dell'erba, `post_process.gdshader` per l'immagine finale (oggi quasi passthrough + blur da miniatura).
- Nota: nella cartella `outputs/w2..w4` ci sono versioni più recenti di `level_atmosphere.gd`, `grass_field.gd`, `quality.gd`; prima di lavorare, controllare quale copia è quella viva sul PC.

## Ordine di lavoro consigliato

1. **Orologio di livello e vento globale** (fondamenta, quasi gratis)
2. **Ciclo giorno/notte per stage** (sfrutta l'orologio)
3. **Particelle d'ambiente** (polvere, polline, scintille bracieri)
4. **Foglie che cadono**
5. **Pioggia casuale** (ultima: dipende da luce, vento e particelle)
6. **Misure reali per qualità e web**, poi taratura

Ogni passo deve essere regolabile da `@export` e spegnibile per qualità.

---

## 0. Orologio di livello (nuovo, prerequisito)

Nuovo nodo/script `scripts/level/level_clock.gd` (`LevelClock`), figlio del livello:

- `time_of_day` in ore (0–24) e segnale `time_changed_hour`. Tempo di gioco, non reale.
- Ogni `wave_started(n, …)` del `LevelDirector` imposta un **orario di destinazione** (es. stage 1 = 17:30, … ultimo = 21:30). Tra uno stage e l'altro l'orario avanza in modo continuo (lerp lento), così la luce cambia piano durante la battaglia.
- Orari per stage in `data/level1/rules.tres` (nuovo array `stage_hours`), così si tarano senza toccare codice.
- Serve anche un valore `wind` condiviso (direzione, forza, raffica) e `rain` (0..1): li espone lo stesso nodo, oppure un singolo `Weather` autoload leggero. Raccomandato: **un solo nodo `LevelClock` con tre outputs** (`time_of_day`, `wind`, `rain`) letto da tutti.

Costo: trascurabile (qualche float per frame). Rischio: basso. Dipende dal `LevelDirector` per i segnali: aggiungere solo la connessione, non cambiare le regole.

## 1. Vento variabile

Obiettivo: brezza che muove erba, cespugli, chiome e stendardi, con direzione e intensità che cambiano.

- `LevelClock` genera `wind_direction` (rotazione lenta con rumore) e `wind_strength` (base + raffiche con `FastNoiseLite`, raffica ogni 6–15 s).
- Erba: `grass.gdshader` ha già gli uniform; basta che `grass_field.gd` li aggiorni ogni frame via `set_shader_parameter` (lo shader è condiviso: costo = 3 uniform per frame, nessun costo GPU extra). Aggiungere un uniform `gust` per l'increspatura veloce.
- Cespugli e chiome: stessa idea con un piccolo shader `foliage_sway.gdshader` (vertex displacement con maschera da altezza/colore vertice) applicato come `material_overlay` o ai materiali dei GLB delle piante. Se i GLB hanno materiali unici, serve un passaggio di sostituzione automatica (script editor-only).
- Stendardi: shader `banner_wave.gdshader` (onda sinusoidale lungo l'asse dello stendardo, ancorata all'asta); se gli stendardi sono mesh rigide nei GLB, serve una mesh con vertici sufficienti (verificare in Blender, thread Blender).
- Vento anche per fumo e scintille: aggiungere `gravity`/`direction` leggermente orientati dal vento (aggiornamento lento, non per particella).

| Qualità | Costo |
|---|---|
| Bassa | solo erba + stendardi; cespugli statici. Vertex-only, ~0 ms extra |
| Media | + cespugli e chiome (vertex shader) |
| Alta | + raffiche con più armoniche, fumo/scintille guidati |

Rischi: il vertex shader dell'erba è già pesante con MultiMesh; non aggiungere letture di texture nel vertex (WebGL2 lo regge male). Mantenere le onde procedurali con `sin` come adesso.

## 2. Foglie che cadono

- Emettitore `GPUParticles3D`/`CPUParticles3D` (in Compatibility **CPUParticles3D è più sicuro sul web**: usare quello per LOW) sopra alberi e cespugli. Non uno per albero: **pochi emettitori a box** coprono le zone alberate (posizioni prese dalle istanze dei GridProp "albero").
- Quad con texture foglia (alpha cutout, 2–3 varianti in atlas), rotazione su tutti gli assi (`angle_*`, `angular_velocity_*`), gravità bassa + drag, deriva dal vento (la direzione del vento viene da `LevelClock`; si aggiorna `direction` dell'emettitore).
- Materiale `StandardMaterial3D` con `billboard_mode` disattivato (le foglie ruotano davvero), `alpha_scissor`, niente trasparenza vera (evita ordinamento).
- Foglie anche a terra che si muovono: opzionale, solo qualità alta (decal/MultiMesh statico, già coperto da `PropScatter`).

| Qualità | Foglie |
|---|---|
| Bassa | 0 o ~15 particelle totali, CPU, un solo emettitore |
| Media | ~60 |
| Alta | ~150, più varianti |

Rischi: emettitori numerosi su web = molti draw call. Limitare a 1–3 emettitori totali.

## 3. Particelle d'ambiente

- **Polvere e sabbia**: velo basso lungo la pianura, sollevato dal vento (quantità legata a `wind_strength`) e dai passi (hook in `grid_unit.gd` quando un'unità si muove: piccolo burst a pool riusabile, max ~8 puff attivi). Quad morbidi (`_soft_texture()` esiste già in `level_atmosphere.gd`, riusarlo).
- **Fumo dei fuochi**: già presente (`_add_smoke`); aggiungere inclinazione dal vento e ridurre/spegnere i fuochi lontani dalla camera.
- **Scintille dei bracieri**: `_add_sparks` esiste già; estendere ai bracieri nuovi e farle salire di più al buio (energia legata a `time_of_day`).
- **Polline / foschia dorata**: particelle sottilissime e lente nella luce del tramonto, intensità alta alle 17–18, a zero di notte. Una sola `CPUParticles3D` che segue la camera (area box ~20 m), non sparsa nel livello.
- **Foschia**: `Environment.fog` (supportata in Compatibility), colore e densità legati a ora e pioggia. Costo praticamente zero. Niente nebbia volumetrica (non c'è nel renderer Compatibility).

| Qualità | Costo |
|---|---|
| Bassa | solo foschia (fog) + fumo dei fuochi vicini; niente polline, polvere ridotta a pochi puff |
| Media | + polvere dai passi + polline |
| Alta | tutto, densità piena |

Rischi: CPUParticles3D con molti `amount` pesano sulla CPU (mobile). Tetto totale suggerito: bassa ≤ 60, media ≤ 250, alta ≤ 600 particelle attive. Pool di emettitori, mai `instantiate` per ogni passo.

## 4. Tempo che passa: dal tramonto alla notte

Gestito da `LevelAtmosphere` leggendo `LevelClock.time_of_day` (oggi i valori sono fissi in `_setup_light`).

- **Sole**: `DirectionalLight3D` ruota con l'ora (elevazione da ~25° a sotto l'orizzonte); colore da arancione caldo a viola-blu; `light_energy` scende, ombre più lunghe e morbide (`shadow_opacity` e `shadow_blur` interpolati). Dopo il tramonto il sole si spegne e subentra una luce "luna" blu fioca (secondo DirectionalLight3D senza ombre per risparmiare, solo alta qualità con ombre).
- **Cielo**: `sky_top_color`, `sky_horizon_color` e `ambient_energy` come `Gradient`/`Curve` indicizzati dall'ora (risorse `.tres` modificabili). Stelle a notte: texture/shader nel sky o un semplice MultiMesh di punti sulla volta; basta un parametro `stars` nello shader del cielo (costo ~0).
- **Fuochi**: i fuochi/torce/bracieri **si accendono al buio**: `OmniLight3D.light_energy` e emissione fiamma scalano con una curva `fire_intensity(t)`; di giorno restano piccoli. La fiamma già oscilla (`flicker_amount`).
- **Post-process**: leggero color grading in `post_process.gdshader` (uniform `tint`, `desaturation`, `vignette` pilotati dall'ora). Aggiungere un uniform non costa più di una moltiplicazione per pixel.
- **UI (inglese)**: facoltativo, una piccola indicazione di orario nell'HUD, es. "Dusk", "Night". Testo in inglese.
- **Gameplay**: la notte non deve nascondere i feriti; tenere un valore minimo di luce ambiente e un leggero alone sui feriti da salvare. Da concordare con Umberto.

| Qualità | Costo |
|---|---|
| Bassa | sole e cielo interpolati, 1 sola luce, fuochi con luce solo vicino alla camera; niente seconda luce luna |
| Media | + luci fuochi più numerose (max 8 OmniLight3D attive), tint post-process |
| Alta | + luce luna, ombre morbide complete, stelle |

Rischi: **numero di luci in Compatibility** (limite per mesh/oggetto: massimo 8 OmniLight per mesh in forward+compatibility è più basso; verificare il limite del progetto in `project.godot`). Con la notte molti fuochi accesi insieme: sulle qualità basse accendere solo le luci dei fuochi vicini al giocatore e sostituire le altre con un quad emissivo (falso alone).

## 5. Pioggia casuale

Meteo gestito da `LevelClock` come macchina a stati: `CLEAR → (probabilità) → RAIN_START → RAIN → RAIN_END → CLEAR`.

- **Scelta casuale**: a ogni cambio di stage (`wave_started`) e ogni 60–120 s lancia un dado: probabilità pioggia (es. 15–25 %, parametro in `rules.tres`: `rain_chance`). Durata 40–120 s, attacco e rilascio con transizione di 6–10 s (valore `rain` 0→1). `RandomNumberGenerator` con seed registrato per riprodurre bug nei test.
- **Particelle**: un unico emettitore a box che segue la camera (area ~30×30 m), righe sottili stirate (quad lunghi, non punti), direzione inclinata dal vento; splash opzionale vicino alla camera (alta qualità).
- **Terreno bagnato**: nel terreno e nei materiali principali un uniform globale `wetness` (`RenderingServer.global_shader_parameter_set`) che abbassa `ROUGHNESS` e scurisce l'albedo. Richiede shader o `material_overlay`; alternativa semplice su bassa qualità: solo scurire il tint nel post-process.
- **Vento e erba**: durante la pioggia vento più forte e erba più scura (`tip_color` ridotto).
- **Luce**: sole più debole e freddo, `fog_density` su, `ambient_energy` giù; fuochi più piccoli (pioggia) con più fumo.
- **Suoni**: pioggia in loop e rumore del vento, se arrivano gli audio (tono più cupo). Da pianificare con i file audio; non ancora disponibili.
- **Gameplay (da decidere con Umberto)**: archi e frecce infuocate meno efficaci sotto la pioggia? Fuochi più deboli? Per ora solo estetico.
- **UI (inglese)**: nessun testo necessario; eventuale banner "Rain begins to fall..." solo se utile.

| Qualità | Pioggia |
|---|---|
| Bassa / web | **semplificata e a costo fisso**: nessuna particella 3D; overlay 2D animato (shader canvas_item su `ColorRect`, righe diagonali procedurali) + fog/tint. Costo: un solo passaggio a schermo intero, già sostituibile dal blur esistente |
| Media | ~250 particelle CPU a box vicino alla camera, wetness solo sul terreno |
| Alta | ~700 particelle, splash, wetness su tutti i materiali principali, nebbia più densa |

Vincolo di Umberto: la pioggia **non deve aumentare il costo su bassa qualità e web**. Quindi in LOW la pioggia sostituisce (non si somma a) il costo di foschia/polvere: spegnere polline e polvere mentre piove.

## Costo complessivo stimato per qualità

| Voce | Bassa (web) | Media (mobile) | Alta (PC) |
|---|---|---|---|
| Vento | erba + stendardi | + cespugli/chiome | + raffiche, fumo guidato |
| Foglie | 0–15 | ~60 | ~150 |
| Particelle ambiente | fog + fumo vicino | + polvere, polline | piene |
| Giorno/notte | 1 luce, curve | + tint, più luci | + luna, stelle, ombre |
| Pioggia | overlay 2D | ~250 particelle | ~700 + splash |
| Particelle attive (tetto) | ≤ 60 | ≤ 250 | ≤ 600 |

Le cifre sono stime di partenza: vanno confermate con **misure reali** (frame time sul PC con la iGPU Intel, un telefono medio e il browser) prima di decidere se il web resta supportato. Umberto accetta di escludere il web solo dopo misure.

## Rischi trasversali

- **Compatibility renderer (web/mobile)**: niente SSAO, nebbia volumetrica, SSS vero, Glow limitato; `GPUParticles3D` su WebGL2 va testato, in dubbio usare `CPUParticles3D`.
- **GPU instancing / MultiMesh**: l'erba usa INSTANCE_CUSTOM; qualsiasi nuovo shader sullo stesso MultiMesh deve rispettare lo stesso layout (angolo, scala, fase).
- **Numero di luci**: la notte con molti fuochi può superare il limite di luci per oggetto (vedi sezione 4).
- **Shader condivisi**: gli uniform globali (`wind`, `wetness`, `time_of_day`) vanno dichiarati come *global shader parameters* in `project.godot` e letti negli shader invece di impostarli su ogni materiale.
- **Sincronizzazione**: tutte le modifiche passano da `LevelClock`; nessuno script deve leggere l'ora o il meteo da altre fonti.
- **Prestazioni di sviluppo**: un solo Godot alla volta; test con `--quality=low` per primo.

## Test da scrivere (in `tests/`, sul modello di `test_gameplay.gd`)

- `test_level_clock.gd`: l'orario avanza con gli stage e non torna indietro; il seed del meteo è riproducibile; la pioggia parte e finisce.
- `test_atmosphere.gd` (esiste in `outputs/w2/tests`): estendere con luce a ora data e fuochi accesi di notte.
- Controllo del numero di particelle e di luci per qualità (asserzioni sui tetti sopra).
- Screenshot a 17:30, 19:30, 21:30 e sotto la pioggia, per qualità alta e bassa (uno alla volta).

## Domande aperte per Umberto

1. Quanti stage ha il livello 1 e quali orari vuoi per ciascuno (propongo da 17:30 al tramonto fino a 21:30)?
2. La pioggia deve influire sul gameplay (archi, fuochi) o solo estetica?
3. Vuoi la luna e le stelle, o notte molto scura illuminata solo dai fuochi?
4. Il web resta un target obbligatorio o decidiamo dopo le misure?
