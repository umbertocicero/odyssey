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
