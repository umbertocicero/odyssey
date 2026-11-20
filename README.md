# Odyssey

Odyssey è un gioco **2.5D** ispirato all'*Odissea* di Omero, sviluppato con **Godot 4** e con modelli 3D realizzati in **Blender**.

## L'idea

Il gioco è costruito come una serie di **diorami**. Ogni diorama è un livello: uno spazio raccolto e limitato, da osservare ed esplorare come un plastico, con una camera isometrica fissa.

La storia segue Ulisse. Il primo livello è un prologo ambientato alla fine della guerra di Troia, prima dell'inizio del viaggio di ritorno raccontato nell'*Odissea*.

L'obiettivo non è riscrivere Omero: il gioco può aggiungere missioni, nemici e combattimenti originali, purché non contraddicano gli eventi principali del poema.

## Caratteristiche principali

- **Visuale:** isometrica 2.5D, camera prospettica fissa.
- **Genere:** action RPG con combattimento in tempo reale, immediato e basato sull'abilità.
- **Stile:** 3D low-poly con resa pixel art.
- **Livelli:** diorami compatti e lineari, con piccoli spazi esplorabili e percorsi alternativi, non un mondo aperto.

## Livello 1: L'ultima notte di Troia

| Elemento | Definizione |
|---|---|
| Protagonista | Ulisse |
| Ambientazione | Accampamento acheo, mura e strade di Troia |
| Periodo | Ultima notte della guerra |
| Durata | 15–20 minuti |
| Obiettivo | Preparare e portare a termine lo stratagemma del cavallo |

Dopo dieci anni di assedio, gli Achei sono pronti a chiudere la guerra. Ulisse, ideatore dello stratagemma del cavallo, deve assicurarsi che il piano riesca nelle ore che precedono l'ingresso del cavallo in città.

Il livello è diviso in cinque aree collegate:

1. **L'accampamento acheo.** Ordini da Agamennone, recupero di spada e scudo, tutorial di movimento, interazione e attacco.
2. **La pianura di Troia.** Primo combattimento contro una pattuglia troiana, schivata e parata, raccolta di materiali.
3. **Le mura di Troia.** Soldati e arcieri, una breve esplorazione e un mini-boss originale: un ufficiale troiano.
4. **Il cavallo di Troia.** Sequenza narrativa con Sinone; Ulisse si nasconde nel cavallo. Nessun combattimento: silenzio e tensione.
5. **La caduta di Troia.** Apertura delle porte, scontri tra le strade in fiamme, ricongiungimento con i compagni. Il livello si chiude con Ulisse che guarda Troia bruciare.

**Personaggi:** Ulisse (giocabile), Agamennone, Sinone. Ettore è già morto ed è solo evocato nei dialoghi.

**Progressione:** esperienza, dracme, materiali ed equipaggiamento. Al termine del livello si sblocca l'abilità **Astuzia**, che rivela temporaneamente nemici vicini e punti di interesse.

Il primo prototipo previsto (vertical slice) è **la pianura di Troia**.

Il documento completo del livello è in [`scenes/levels/level1.MD`](scenes/levels/level1.MD).

## Controlli (previsti)

| Comando | Azione |
|---|---|
| WASD | Movimento |
| Mouse sinistro | Attacco |
| Mouse destro | Parata |
| Spazio | Schivata |
| E | Interazione |
| Q | Abilità speciale |

## Stack e strumenti

- **Godot 4.7.2** come engine (vedi `GAME.MD`), renderer **Compatibility** per supportare PC, mobile e web.
- **Blender** per i modelli 3D. I file sorgente `.blend` stanno in `art_source/`, gli export `.glb` in `assets/`.

Scelte tecniche previste per l'implementazione:

| Componente | Implementazione |
|---|---|
| Movimento | `CharacterBody3D` |
| Nemici | State machine |
| Combattimento | Hitbox / Hurtbox |
| Dialoghi | Sistema a eventi |
| Salvataggi | JSON o Resource |

## Struttura del progetto

```
Odyssey/
├── addons/              # Plugin di Godot
├── art_source/          # Sorgenti Blender (.blend), esclusi da Godot (.gdignore)
│   └── characters/
│       └── ulisse/ulisse.blend
├── assets/              # Asset importati in Godot
│   ├── audio/           # music/ e sfx/
│   ├── characters/
│   │   └── ulisse/ulisse.glb
│   ├── environment/
│   ├── fonts/
│   ├── props/
│   ├── shaders/
│   └── ui/
├── autoload/            # Script singleton (autoload) di Godot
├── data/                # Dati di gioco
├── ispirazione/         # Immagini di riferimento, escluse da Godot (.gdignore)
├── scenes/
│   ├── characters/      # Scene dei personaggi (ulisse/, achei/)
│   ├── enemies/         # Nemici (troiano/)
│   ├── levels/          # Un diorama per livello (level1/); level1.MD contiene la storia del livello 1
│   ├── main/            # main.tscn: scena principale e pipeline di rendering
│   ├── props/
│   └── ui/
├── scripts/             # Script condivisi: griglia, camera, unità, rendering
├── tests/
├── project.godot        # Progetto Godot 4.7, renderer Compatibility
└── GAME.MD
```

## Pipeline degli asset

1. Modellare in Blender e salvare il file in `art_source/<categoria>/<nome>/<nome>.blend`.
2. Esportare in glTF binario (`.glb`) in `assets/<categoria>/<nome>/<nome>.glb`.
3. Godot importa il `.glb`; la scena relativa va in `scenes/<categoria>/<nome>/`.

Le cartelle `art_source/` e `ispirazione/` contengono un file `.gdignore`, quindi Godot non le importa.

## Come aprire il progetto

1. Installare **Godot 4.7.2**.
2. Dal Project Manager di Godot: **Importa** e scegliere `Odyssey/project.godot`.
3. Premere **F5** (o il pulsante Play): parte `scenes/main/main.tscn`.

Da riga di comando: `godot --path /percorso/di/Odyssey` (aggiungere `--editor` per aprire l'editor).

## Prototipo del livello 1

Il prototipo contiene il diorama del livello 1 (`scenes/levels/level1/level1.tscn`), dalle navi achee alla porta di Troia, costruito con i modelli scaricati in `assets/models/troia/` (crediti in `assets/models/troia/CREDITS.md`):

- **Diorama quadrato**: una base di 52×52 m con il bordo, e dentro la griglia giocabile di 40×40 caselle. Il percorso è a L: dall'accampamento acheo (angolo sud-ovest, con il mare e le navi sul lato ovest) attraversa la pianura verso est, poi sale a nord tra le rovine fino allo spiazzo davanti alla porta, dove andrà il cavallo (`PuntoCavallo`). Sul lato nord, dentro la base, ci sono le mura e la porta di Troia, l'acropoli con il tempio e la città.
- **Griglia** (`scripts/grid/diorama_grid.gd`): 40×40 caselle da 1 m. Gli oggetti bloccano le caselle della loro impronta; all'avvio il livello controlla che non ci siano caselle chiuse.
- **Oggetti** (`scripts/props/grid_prop.gd`): ogni oggetto usa un `.glb` scaricato e lo porta alla misura giusta (`fit_size`), appoggiato a terra, senza modificare il file. Si può usare un solo pezzo di un pack (`piece`), correggere l'orientamento (`model_rotation_degrees`) e scegliere quali caselle bloccare (per esempio solo i pilastri di un arco).
- **Decorazioni** (`scripts/props/prop_scatter.gd`): alberi, cespugli, fiori ed erba ripetuti con MultiMesh, una chiamata di disegno per mesh. Non bloccano la griglia.
- **Camera fissa** (`scripts/camera/fixed_camera.gd`): angolo costante; segue Ulisse spostando solo il punto guardato, entro i limiti del diorama.
- **Ulisse** (`scenes/characters/ulisse/`): segnaposto a capsula, si muove di una casella alla volta. I comandi seguono lo schermo. Su mobile si muove con uno swipe. Se un soldato acheo gli sbarra la strada, si scambiano di posto.
- **Soldati achei** (`scripts/units/ally_soldier.gd`): seguono Ulisse sulla griglia.
- **Soldati troiani** (`scenes/enemies/troiano/`): segnaposto fermi, una pattuglia nella pianura e i difensori davanti alle mura.
- **Luci**: un sole e due luci puntiformi (falò e porta), per restare leggeri su mobile e web.

Test: `godot --headless --path . -s res://tests/test_grid_movement.gd` controlla che Ulisse non resti mai bloccato.

Le azioni di combattimento (attacco, parata, schivata, interazione, abilità) sono già nella mappa degli input, ma non sono ancora implementate.

### Rendering e filtro pixel art

Il progetto usa il renderer **Compatibility** (OpenGL), il più adatto a web e mobile.

Il mondo 3D viene disegnato dentro un `SubViewport` (`scenes/main/main.tscn`), separato dalla UI. Sul nodo `Main` ci sono due parametri pensati per il futuro filtro pixel art:

- **Pixel Size**: abbassa la risoluzione del rendering 3D; l'immagine viene ingrandita senza smussature, quindi a pixel.
- **Post Process Material**: uno shader applicato all'immagine 3D finale. `assets/shaders/post_process.gdshader` è un segnaposto che per ora non modifica nulla.

La UI resta fuori dal filtro e sempre nitida.

### Modelli da Blender

Per sostituire un segnaposto con un modello `.glb`, trascinare il `.glb` dentro il nodo `Model` della scena del personaggio (per esempio `assets/characters/ulisse/ulisse.glb` in `ulisse.tscn`) e nascondere le mesh segnaposto. Il modello deve guardare verso **-Z**.

## Stato

Il progetto Godot è creato: c'è il diorama del livello 1 con i modelli scaricati, camera fissa che segue Ulisse, griglia, alleati che lo seguono e nemici segnaposto. Mancano il combattimento, il cavallo, i modelli dei personaggi e il filtro pixel art.
