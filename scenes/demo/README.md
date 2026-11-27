# Demo automatica del livello 1

Sequenza di circa 2 minuti che gira da sola: camera cinematica, Ulisse automatico e
testi a schermo in inglese (la voce fuori campo la fa chi presenta). Usa i sistemi
veri del gioco (`level_director`, `ulisse.gd`, `ferry_system.gd`, `level_hud.gd`);
`level1.tscn` non viene toccato. La camera di gioco (`FixedCamera`) resta intatta:
la demo aggiunge una `Camera3D` separata.

| Tempo | Capitolo | Cosa succede |
|-------|----------|--------------|
| 0:00 | 1 Overview | camera alta sul diorama, "Hold the line until the retreat signal!" |
| 0:20 | 2 Path to the walls | camera bassa sul sentiero verso le mura: arcieri, balista, catapulta |
| 0:45 | 3 Odysseus runs | corre nell'erba, scavalca una cassa, passa sotto un ulivo, combatte con i compagni |
| 1:10 | 4 Rescue | raggiunge un ferito e lo sorregge (55% velocità da solo, 70% con un compagno), HUD feriti |
| 1:30 | 5 Stretcher and boat | barella con quattro soldati, barca a remi verso la nave |
| 1:50 | 6 Retreat | "Retreat!" e schermata finale con i feriti salvati |

## Come lanciarla

**Dall'editor:** apri `scenes/demo/demo.tscn` e premi **F6** (Run Current Scene).

**Da terminale** (dalla radice del progetto):

```bash
godot --path . res://scenes/demo/demo.tscn
# oppure
scenes/demo/run_demo.sh
```

**Chiedendolo a Claude:** "lancia la demo" (o "fai gli screenshot della demo").

Opzioni, dopo `--`:

| Opzione | Effetto |
|---------|---------|
| `--chapter=N` | parte dal capitolo N (1-6) |
| `--clean` | nasconde l'indicatore del capitolo e l'aiuto tasti (per video) |
| `--auto-quit` | chiude Godot qualche secondo dopo la schermata finale |
| `--shots=DIR` | salva PNG in DIR (`demo_<secondo>.png`); servono una finestra o Xvfb |
| `--shot-times=5,30,60` | secondi in cui fare gli screenshot (default: ogni ~10 s) |
| `--quality=low\|medium\|high` | qualità grafica del gioco |
| `--timescale=N` | accelera il tempo (solo per prove veloci) |
| `--debug` | stampa ogni 2 s posizione di Ulisse e stato del ferito |

Esempio per registrare un video (frame fissi, deterministico):

```bash
godot --path . --write-movie /tmp/demo.avi --fixed-fps 30 res://scenes/demo/demo.tscn -- --clean --auto-quit
```

## Tasti durante la demo

| Tasto | Azione |
|-------|--------|
| `N` / `→` | capitolo successivo |
| `P` / `←` | riparte dal capitolo corrente (entro 3 s da quando è iniziato: quello precedente) |
| `1`-`6` | salta al capitolo |
| `R` | ricomincia da capo (anche il pulsante "Replay the demo" a fine demo) |
| `Space` | pausa |
| `G` | prendi il controllo di Ulisse con la camera di gioco |
| `H` | nasconde/mostra l'aiuto tasti |
| `Esc` | esci |

Saltare a un capitolo ricrea il livello e mette il mondo nello stato giusto
(es. dal capitolo 5 c'è già un ferito in salvo).

## Dove modificare

Tutto è in `scripts/demo/level_demo.gd`:
- tempi dei capitoli: `CHAPTER_START`;
- inquadrature: `_enter_chapter()` (fotogrammi chiave `_key(tempo, punto guardato, yaw, pitch, distanza, fov)`);
- percorso di Ulisse: `_run_chapter_run()`, `_run_chapter_rescue()`, `_run_chapter_stretcher()`;
- testi: le liste `_captions` in `_enter_chapter()`.

Durante la demo Ulisse, i compagni e i feriti vengono tenuti in vita (niente sconfitte in scena).

## Demo 2 (per registrare il video)

`scenes/demo/demo2.tscn` è la stessa regia senza aiuti a schermo né tasti, che si
chiude da sola. Registra a 30 fps fissi (tempo deterministico, niente scatti):

```bash
scenes/demo/run_demo2.sh            # scrive out/demo2.avi
scenes/demo/run_demo2.sh /tmp/v.avi # percorso a scelta
```

Se `--write-movie` non va col renderer, alternativa: `--shots=DIR --shot-times=...`
della demo normale e poi `ffmpeg`.

## Demo 3 (speedrun senza cheat)

`scenes/demo/demo3.tscn` (**F6**) fa giocare il livello 1 a un bot, nel minor tempo possibile.
Nessun cheat: usa `main.tscn` con le regole vere (`data/level1/rules.tres`), nessuna modifica a
vita, danni, tempo, velocità o posizioni; il bot muove Ulisse e attacca con gli stessi input del
giocatore (camera di gioco). Feriti, barella (4 soldati liberi, altrimenti trascinamento da 2 o 1),
barche e ondate sono i sistemi del gioco. A schermo: tempo, contatori, stato del bot e riepilogo finale.
Il livello finisce quando ogni ferito è in salvo sulle navi o perso.

```bash
scenes/demo/run_demo3.sh                      # finestra, F6 equivalente
scenes/demo/run_demo3.sh --record             # video in out/demo3.avi (30 fps fissi, esce da solo)
scenes/demo/run_demo3.sh --record=/tmp/v.avi
```

Opzioni: `--seed=N` (default 1207), `--plan=5,6,2,4,C,3,1,W` (visite in ordine: numero = ferito,
`C` = porta in accampamento chi ti segue, `W` = idem dal lato della riva), `--trace`, `--auto-quit`,
`--clean`. Tasti: `R` ricomincia, `Space` pausa, `Esc` esce. Prove veloci senza finestra:
`godot --headless --path . --fixed-fps 60 res://scenes/demo/demo3.tscn -- --auto-quit`
(stampa `[demo3] RESULT time=...`). Codice: `scripts/demo/level_demo3.gd`.

## Demo 4 (tempo e meteo)

`scenes/demo/demo4.tscn` (**F6**) mostra in ~95 s il diorama del livello 1 dal pomeriggio alla notte:
vento sull'erba, un acquazzone (inizio e durata casuali ma con seme fisso), pozze che si asciugano
quando torna il sole, tramonto, notte con torce accese e luna fredda. Usa i sistemi veri
(`LevelClock`, `NightCycle`, `WeatherFx`, `LevelAtmosphere`); il Director parte senza ondate né feriti.
La demo pilota solo l'ora e la pioggia; la camera ha movimenti lenti (Catmull-Rom). A schermo: orologio
discreto e brevi didascalie in inglese. Solo per il video, sopra l'overlay della pioggia di gioco, ci sono
strisce di pioggia 3D davanti alla camera (non fanno parte del livello).

```bash
scenes/demo/run_demo4.sh                    # finestra
scenes/demo/run_demo4.sh --record           # video in out/demo4.avi (30 fps fissi, esce da solo)
scenes/demo/run_demo4.sh --record=/tmp/v.avi --quality=high
```

Opzioni: `--seed=N` (cambia momento e durata della pioggia), `--clean`, `--auto-quit`,
`--shots=DIR --shot-times=3,20,...`, `--timescale=N` (solo prove). Tasti: `Space` pausa, `R` ricomincia, `Esc` esce.
Codice: `scripts/demo/level_demo4.gd` (orari: `HOUR_KEYS`, camera: `CAM_KEYS`, testi: `CAPTIONS`).

## Demo 5 (animali)

`scenes/demo/demo5.tscn` (**F6**) mostra in ~90 s gli animali del livello 1: gregge e maiali che brucano e fanno
qualche passo senza girare su se stessi, cavalli fermi (respiro, testa, ogni tanto un cenno o uno zoccolo), cavalli sui
rilievi vicino alle mura con i piedi sul terreno. Livello vero, tramonto fisso, camera con Catmull-Rom e didascalie in inglese.

```bash
scenes/demo/run_demo5.sh                    # finestra (qualità alta)
scenes/demo/run_demo5.sh --record           # video in out/demo5.avi
```

Opzioni come la demo 4 (`--clean`, `--auto-quit`, `--shots=DIR --shot-times=...`, `--timescale=N`, `--quality=...`).
Codice: `scripts/demo/level_demo5.gd` (camera: `CAM_KEYS`, testi: `CAPTIONS`). Animali: `scripts/props/animal_idle.gd` + `assets/shaders/animal_rig.gdshader`.

## Demo 6 (effetto intermedio)

`scenes/demo/demo6.tscn` (**F6**) è la demo 4 (stesso percorso di ~95 s, stesse opzioni) con l'effetto intermedio:
pixel 3x3, colore a 12 bit (16 livelli per canale) e dither Bayer 4x4 leggero. `--pixelart=1|2|3` prova la palette
Endesga 32, la rampa di luminanza o il "32 bit" (pixel 2x2, 15 bit), `--pixelart=0` lo spegne (vale anche sulla demo 4).
Nel gioco normale l'effetto si cicla con **K** (spento, palette, rampa, 32 bit, intermedio).
Codice: `scripts/demo/level_demo6.gd`; script di avvio: `scenes/demo/run_demo6.sh`.


## Demo del livello 2 ("Il dono del mare")

`scenes/demo/demo_level2.tscn` (o `scenes/demo/run_demo_level2.sh`): circa 5 minuti, un bot gioca il livello 2 con gli
stessi input del giocatore (movimento, E, spada) usando il vero `Level2World` / `Level2Director`. Capitoli: la baia, legname
e ruscello (abbatte e sfronda due abeti, li porta con un compagno, li fa galleggiare, li squadra), il cavallo che cresce con
i soldati che aiutano Epeo, l'incursione notturna, l'entrata nel cavallo e il finale. Dopo un tratto di lavoro "il tempo
passa" (le travi arrivano a ritmo serrato). Opzioni dopo `--`: `--chapter=N` (1-5), `--clean`, `--auto-quit`,
`--shots=DIR`, `--shot-times=...`, `--timescale=N`, `--quality=...`. Esc esce.


## Demo dei personaggi (rig a 17 ossa, skinning e clip Mixamo)

`demo_characters.tscn`: i 15 personaggi di `personaggi_nuovi/` in tre file con il nome sopra la testa; un giro automatico di azioni (idle, walk, run,
attack, block, death, get up) con clip Mixamo per camminata, corsa e morte e animazioni procedurali per il resto. Si puo' fermare e guidare a mano.

```bash
scenes/demo/run_demo_characters.sh                      # tutti in fila, giro automatico
scenes/demo/run_demo_characters.sh --focus=menelao --zoom=1.7   # primo piano su un personaggio
scenes/demo/run_demo_characters.sh --procedural         # clip procedurali (confronto)
```

Tasti: `1`-`7` azione, `Space` giro automatico, `Left`/`Right` primo piano, `Esc` tutti, trascina = ruota, rotella = zoom,
`M` clip Mixamo/procedurali, `G` armi e scudi, `H` aiuto, `Q` esci. Opzioni: `--noauto`, `--nogear`, `--once` (esce a fine giro),
`--shots=DIR` (un PNG a meta' di ogni azione). Nomi dei personaggi: Ulysses, Menelaus, Agamemnon, Elpenor, Eurylochus, Eurybates, Polites,
Philoctetes (con e senza elmo), Perimedes, Trojan Infantry, Trojan Captain, Deiphobus A/B, Trojan Archer (Pandarus).
