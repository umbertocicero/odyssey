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

Il prototipo contiene un diorama di prova della pianura di Troia (`scenes/levels/level1/level1.tscn`):

- **Camera fissa** (`scripts/camera/fixed_camera.gd`): guarda il diorama da distanza, inclinazione e rotazione costanti, regolabili dall'Inspector.
- **Griglia** (`scripts/grid/diorama_grid.gd`): 12×8 caselle da 1 m. I nodi nel gruppo `grid_obstacle` bloccano la loro casella; le unità occupano la casella su cui si trovano.
- **Ulisse** (`scenes/characters/ulisse/`): segnaposto a capsula, si muove di una casella alla volta. I comandi seguono lo schermo (su = verso l'alto dello schermo). Su mobile si muove con uno swipe.
- **Soldati achei** (`scripts/units/ally_soldier.gd`): seguono Ulisse sulla griglia. Qui andrà la logica con cui lo aiutano a combattere.
- **Soldati troiani** (`scenes/enemies/troiano/`): segnaposto fermi, pronti per state machine e combattimento.

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

Il progetto Godot è creato: c'è il diorama di prova del livello 1 con camera fissa, griglia, Ulisse controllabile, alleati che lo seguono e nemici segnaposto. Mancano il combattimento, i modelli definitivi e il filtro pixel art.
