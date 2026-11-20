# Odyssey

Odyssey è un gioco **2.5D** ispirato all'*Odissea* di Omero, sviluppato con **Godot 4** e con modelli 3D realizzati in **Blender**.

## L'idea

Il gioco è costruito come una serie di **diorami**. Ogni diorama è un livello: uno spazio raccolto e limitato, da osservare ed esplorare come un plastico, con una camera isometrica fissa.

La storia segue Ulisse. Il primo livello è un prologo ambientato alla fine della guerra di Troia, prima dell'inizio del viaggio di ritorno raccontato nell'*Odissea*.

L'obiettivo non è riscrivere Omero: il gioco può aggiungere missioni, nemici e combattimenti originali, purché non contraddicano gli eventi principali del poema.

## Caratteristiche principali

- **Visuale:** isometrica 2.5D, camera prospettica fissa.
- **Genere:** action RPG con combattimento in tempo reale, immediato e basato sull'abilità.
- **Stile:** diorama in miniatura dipinto a mano, luce calda del tramonto (riferimento `ispirazione/realistic.png`, dettagli in [STYLE.md](STYLE.md)). Il filtro pixel art verrà applicato sopra questo look.
- **Livelli:** diorami compatti e lineari, con piccoli spazi esplorabili e percorsi alternativi, non un mondo aperto.

## Livello 1: Verso le mura di Troia

| Elemento | Definizione |
|---|---|
| Protagonista | Ulisse |
| Ambientazione | Accampamento acheo, pianura e mura di Troia |
| Periodo | Gli ultimi giorni dell'assedio |
| Durata | 15–20 minuti |
| Obiettivo | Raggiungere le mura di Troia e neutralizzarne le difese |

Dopo dieci anni di assedio, gli Achei sono pronti a chiudere la guerra. Ulisse lascia l'accampamento, attraversa la pianura e deve neutralizzare le difese troiane davanti alle mura, per preparare l'attacco finale.

Il livello è diviso in tre aree collegate:

1. **L'accampamento acheo.** Ordini da Agamennone, recupero di spada e scudo, tutorial di movimento, interazione e attacco.
2. **La pianura di Troia.** Primo combattimento contro una pattuglia troiana, schivata e parata, raccolta di materiali.
3. **Le mura di Troia.** Soldati e arcieri tra rovine e postazioni, una breve esplorazione e, davanti alla porta, un mini-boss originale: un ufficiale troiano con la sua guardia.

Gli eventi successivi della caduta di Troia sono nei livelli seguenti.

**Personaggi:** Ulisse (giocabile), Agamennone. Ettore è già morto ed è solo evocato nei dialoghi.

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

## Convenzioni

- **Lingua dei testi del gioco:** tutti i testi visibili nel gioco (UI, HUD, menu, messaggi, dialoghi, titoli, tutorial, nomi mostrati al giocatore) sono **sempre in inglese**.
- Documentazione (README, file `.MD`) e commenti nel codice possono restare in italiano, come i nomi dei nodi e i messaggi di debug.

## Prototipo del livello 1

Il prototipo contiene il diorama del livello 1 (`scenes/levels/level1/level1.tscn`), dalle navi achee alla porta di Troia, costruito con i modelli scaricati in `assets/models/troia/` (crediti in `assets/models/troia/CREDITS.md`):

- **Diorama a blocco**: un unico blocco quadrato di 52×52 m, alto 8 m, con la superficie piatta in cima e i lati in sezione (erba, terra, roccia). Tutto sta sulla faccia superiore, compreso il mare incassato con le navi sul lato ovest. Dentro c'è la griglia giocabile di 40×40 caselle. Il percorso è a L: dall'accampamento acheo (angolo sud-ovest) attraversa la pianura verso est, poi sale a nord tra le rovine fino alla postazione troiana davanti alla porta, dove si affronta l'ufficiale troiano (`PuntoUfficiale`). Sul lato nord ci sono le mura e la porta di Troia, l'acropoli con il tempio e la città.
- **Griglia** (`scripts/grid/diorama_grid.gd`): 40×40 caselle da 1 m. Gli oggetti bloccano le caselle della loro impronta; all'avvio il livello controlla che non ci siano caselle chiuse.
- **Oggetti** (`scripts/props/grid_prop.gd`): ogni oggetto usa un `.glb` scaricato e lo porta alla misura giusta (`fit_size`), appoggiato a terra, senza modificare il file. Si può usare un solo pezzo di un pack (`piece`), correggere l'orientamento (`model_rotation_degrees`) e scegliere quali caselle bloccare (per esempio solo i pilastri di un arco).
- **Decorazioni** (`scripts/props/prop_scatter.gd`): alberi, cespugli, fiori ed erba ripetuti con MultiMesh, una chiamata di disegno per mesh. Non bloccano la griglia.
- **Camera fissa** (`scripts/camera/fixed_camera.gd`): angolo costante; segue Ulisse spostando solo il punto guardato, entro i limiti del diorama.
- **Ulisse** (`scenes/characters/ulisse/`): segnaposto a capsula, si muove di una casella alla volta. I comandi seguono lo schermo. Su mobile si muove con uno swipe. Se un soldato acheo gli sbarra la strada, si scambiano di posto.
- **Soldati achei** (`scripts/units/ally_soldier.gd`): seguono Ulisse sulla griglia.
- **Soldati troiani** (`scenes/enemies/troiano/`): segnaposto fermi, una pattuglia nella pianura e i difensori davanti alle mura.
- **Luci**: un sole e due luci puntiformi (falò e porta), per restare leggeri su mobile e web.
- **Vita**: Ulisse ha 100 punti vita (barra in alto a sinistra), i soldati achei 60 (barra sopra la testa, visibile solo quando sono feriti). Un soldato che arriva a zero cade; Ulisse riparte dall'accampamento con la vita piena.

### Rilievo e foschia

Il terreno non è piatto: ai bordi del diorama ci sono blocchi rialzati su roccia, mentre il centro e il percorso restano in pianura.

- **Livelli di altezza** (`scripts/props/terrain_relief.gd`, nodo `Terreno/Rilievo`): una mappa con un livello per ogni quadrato di 1 m (1 livello = 0,8 m). Dove il livello è maggiore di 0 ci sono pareti di blocchi di pietra, un blocco per livello, e un tappeto d'erba in cima. Sono due MultiMesh, quindi leggeri su mobile e web.
- **Dove sono:** sperone nord-ovest (fino al livello 3), cresta nord-est (fino al 3), rampa davanti alla porta, bordo est fuori griglia (livelli 1–2) e altopiano nord (livello 2) con mura, acropoli e città.
- **Movimento:** con un passo si sale o si scende di un livello (`DioramaGrid.max_step_levels`); una parete più alta non si supera. Le unità prendono la quota della casella, la camera segue anche l'altezza. Il controllo delle caselle chiuse tiene conto dei dislivelli.
- **Tiro:** il rilievo può coprire il bersaglio (`DioramaGrid.has_line_of_fire`): se un blocco sta sopra la retta tra tiratore e bersaglio, il difensore non tira. Dalle mura, che stanno in alto, la pianura è sempre visibile.
- **Foschia:** nebbia di distanza morbida e calda nell'ambiente (`level1.tscn`, `Environment`: `fog_depth_begin/end/curve`, `fog_density`), più una sfumatura in alto nello shader di post-process (`haze_strength`, `haze_reach`) con un leggero rumore contro le bande. `haze_strength = 0` la spegne.

### Erba che si muove

L'erba (`scripts/props/grass_field.gd`, nodo `ErbaMossa`) è un solo MultiMesh di ciuffi, piegati da uno shader (`assets/shaders/grass.gdshader`). Si muove col vento leggero e si piega quando la toccano personaggi (Ulisse, soldati achei e troiani), proiettili in volo e caselle in fiamme.

- **Come funziona:** lo script passa allo shader fino a 12 interattori (posizione e raggio), i più vicini a Ulisse. Le posizioni sono ammorbidite, quindi l'erba si piega subito e si rialza piano; un oggetto che sparisce lascia un'influenza che svanisce. Dopo un teletrasporto non resta nessuna scia.
- **Costo:** un disegno solo, nessuna texture, al massimo 12 interattori per vertice. `interaction_enabled = false` spegne l'interazione e lascia solo il vento.
- **Parametri** (Inspector di `ErbaMossa`):

| Parametro | Significato |
|---|---|
| `count`, `blade_height`, `height_variation` | quanti ciuffi e quanto alti |
| `base_color`, `tip_color` | colori dalla base alla punta (olive e oro, come in `STYLE.md`) |
| `wind_strength`, `wind_speed`, `wind_direction_degrees` | vento: piegatura in metri, velocità e direzione |
| `push_strength` | di quanto si sposta la punta del filo al centro di un interattore |
| `radius_scale`, `unit_radius`, `projectile_radius`, `fire_radius` | raggio d'azione dei vari interattori |
| `stiffness` | rigidità: più è alta, più l'erba si rialza in fretta |

### Difese troiane sulle mura

Sulle mura (gruppo `DifeseSulleMura` in `level1.tscn`) ci sono 8 arcieri, 4 arcieri con frecce infiammate, 2 baliste e, sull'acropoli, una catapulta. Quando un acheo entra nella gittata, il difensore tira sulla sua casella:

1. sulla casella bersaglio compare subito un avviso a terra (rosso, arancione per il fuoco) che si intensifica;
2. il proiettile vola con una parabola visibile e arriva dopo `warning_time` secondi;
3. chi è ancora nelle caselle colpite perde vita. Basta un passo per schivare.

Le frecce infiammate lasciano la casella in fiamme per qualche secondo: chi ci passa o ci resta perde vita ogni secondo. La catapulta colpisce un'area 3×3 ma non riesce a tirare sotto le mura.

Ogni arma è un file in `data/combat/` (risorsa `AttackProfile`) che si modifica dall'Inspector:

| Parametro | Significato |
|---|---|
| `range_cells` / `min_range_cells` | gittata massima e minima, in caselle |
| `damage` | danno a chi è nelle caselle colpite |
| `reload_time` / `reload_jitter` | secondi tra un tiro e l'altro, più un ritardo casuale |
| `warning_time` | durata del volo = tempo per schivare |
| `arc_height` | altezza della parabola, in metri |
| `area_radius` | 0 = una casella, 1 = 3×3, 2 = 5×5 |
| `miss_chance` | probabilità di mancare di una casella |
| `burn_duration` / `burn_damage_per_second` | fuoco lasciato a terra |

| Arma | Gittata | Danno | Ricarica | Volo/avviso | Note |
|---|---|---|---|---|---|
| `freccia.tres` | 9 | 8 | 3 s | 1,2 s | 20% di mancare |
| `freccia_infuocata.tres` | 8 | 6 | 4 s | 1,3 s | fuoco 4 s, 4 danni/s |
| `balista.tres` | 14 | 25 | 6 s | 1,5 s | dardo teso, preciso |
| `catapulta.tres` | 8–20 | 30 | 9 s | 2,2 s | area 3×3 |

Ogni difensore (`scripts/combat/wall_shooter.gd`) ha anche `auto_fire` (spento = tira solo su comando, utile per eventi e test). Le scene segnaposto sono in `scenes/enemies/troiano/` (`arciere_mura`, `arciere_fuoco`, `balista`, `catapulta`). All'accampamento si è fuori portata.

Test:

- `godot --headless --path . -s res://tests/test_grid_movement.gd` controlla che Ulisse non resti mai bloccato.
- `godot --headless --path . -s res://tests/test_grass.gd` controlla gli interattori dell'erba (personaggi, proiettili, fuoco), il ritardo e la dissolvenza.
- `godot --headless --path . -s res://tests/test_relief.gd` controlla altezze, scalini, pareti, caselle chiuse e linea di tiro.
- `godot --headless --path . -s res://tests/test_wall_combat.gd` controlla avviso, colpo, schivata, fuoco, gittata, tiro automatico e sconfitta.
- `godot --headless --path . -s res://tests/test_gameplay.gd` controlla il gioco del livello 1: ondate, attacco di Ulisse, feriti (salvati e persi), punteggio e schermata finale.

L'attacco corpo a corpo è implementato; parata, schivata, interazione e abilità sono già nella mappa degli input, ma non ancora implementate.

### Gameplay del livello 1

Il livello è una prova di resistenza che finisce con una ritirata (sconfitta narrativa) e porta al livello 2. La regia è in `scripts/level/level_director.gd` (nodo `Director` in `main.tscn`), l'interfaccia in `scripts/ui/level_hud.gd`.

- **Tempo:** bisogna resistere fino al segnale di ritirata (3 minuti). Il conto alla rovescia e il numero dell'ondata sono in alto al centro.
- **Ondate:** la prima parte dopo 8 s, poi una ogni 25 s. I troiani (`scripts/units/trojan_soldier.gd`, modello Blender) escono da sotto le mura e avanzano verso l'acheo più vicino, feriti compresi, e lo colpiscono quando gli sono accanto. Ogni ondata ha più soldati, con più vita e danno e passo più rapido; intanto le difese sulle mura tirano più spesso e fanno più male.
- **Feriti:** 6 compagni feriti (`scripts/units/wounded_soldier.gd`) giacciono nella pianura. Quando Ulisse arriva accanto a uno, si rialza e lo segue; entrato nell'accampamento è in salvo. Se muore prima è perso. Il contatore è in alto a destra.
- **Combattimento:** Ulisse attacca con il clic (azione `attack`) il troiano davanti o accanto; anche i soldati achei colpiscono i troiani vicini.
- **Fine e punteggio:** allo scadere del tempo compare la schermata finale con salvati, troiani sconfitti, ondate e punteggio (100 per ferito salvato, 10 per troiano, +200 se si salvano tutti). Con almeno metà dei feriti salvi la ritirata è "ordinata", altrimenti "disperata". Il pulsante porta al segnaposto del livello 2 (`scenes/levels/level2/level2_placeholder.tscn`).

Tutti i parametri (durata, ondate, forza dei troiani, crescita delle difese, numero e posizione dei feriti, area dell'accampamento, punteggio) si regolano dall'Inspector su `data/level1/rules.tres` (risorsa `LevelRules`, `scripts/level/level_rules.gd`).

### Rendering e filtro pixel art

Il progetto usa il renderer **Compatibility** (OpenGL), il più adatto a web e mobile.

Il mondo 3D viene disegnato dentro un `SubViewport` (`scenes/main/main.tscn`), separato dalla UI. Sul nodo `Main` ci sono due parametri pensati per il futuro filtro pixel art:

- **Pixel Size**: abbassa la risoluzione del rendering 3D; l'immagine viene ingrandita senza smussature, quindi a pixel.
- **Post Process Material**: uno shader applicato all'immagine 3D finale. `assets/shaders/post_process.gdshader` è un segnaposto che per ora non modifica nulla.

La UI resta fuori dal filtro e sempre nitida.

### Modelli da Blender

Per sostituire un segnaposto con un modello `.glb`, trascinare il `.glb` dentro il nodo `Model` della scena del personaggio (per esempio `assets/characters/ulisse/ulisse.glb` in `ulisse.tscn`) e nascondere le mesh segnaposto. Il modello deve guardare verso **-Z**.

## Stato

Il progetto Godot è creato: c'è il diorama del livello 1 con i modelli scaricati, camera fissa che segue Ulisse, griglia, alleati che lo seguono e nemici segnaposto. Mancano il combattimento, i modelli dei personaggi e il filtro pixel art.

## Movimento e ostacoli

La griglia (1 m per casella) resta la logica del gioco: la camera è fissa e le difese avvisano sulla casella bersaglio. Gli ostacoli però non sono più muri rigidi:

- **Si aggirano** passando nelle caselle vicine.
- **Gli ostacoli bassi si scavalcano** con un balzo atletico: casse, barili, scudi e lance a terra, sassi piccoli. Basta muoversi contro l'ostacolo: l'unità salta e atterra nella casella subito oltre (che deve essere libera). Il balzo dura circa mezzo secondo (`vault_duration` in GridUnit), con un arco e un'inclinazione in avanti, quindi costa un po' di tempo rispetto a un passo (0,18 s) e per questo conviene non farlo sotto il tiro delle mura. Le caselle di atterraggio si vedono evidenziate come le altre mosse.
- **Restano bloccanti** le mura e le torri, le tende, i carri, gli alberi, le rocce grandi e i dislivelli di rilievo troppo alti (oltre uno scalino): tutto ciò che occupa più di una casella o supera `vault_max_size` (1,6 m) in `GridProp`. Per ogni oggetto si può forzare con `vault_mode` (Auto, Yes, No).
- Il balzo vale per tutte le unità (Ulisse, soldati alleati, feriti e troiani), quindi anche i nemici scavalcano gli ostacoli bassi mentre avanzano.
- Ulisse non resta mai bloccato: il controllo di connettività della griglia continua a segnalare le caselle chiuse e lo scavalcamento si aggiunge ai percorsi.

## Prato e cespugli

Il prato alto circa 20 cm copre tutto il piano (non solo a chiazze) con un unico MultiMesh (`ErbaMossa`), e i cespugli (`Cespugli`, alti circa 50 cm) sono sparsi sopra. Non sono ostacoli: si calpestano e si piegano al passaggio di personaggi, proiettili e fuoco. La densità segue la qualità grafica (`Quality`: alta, media, bassa).

## Atmosfera e qualità

`LevelAtmosphere` (nodo `Atmosfera` nel livello 1) rende le ombre del sole più morbide e corte, tinge di azzurro il cielo in alto per un ambiente freddo nelle ombre, fa oscillare le luci del fuoco, aggiunge fumo e scintille al falò e fiamme alle torce, mette ombre di contatto sotto gli oggetti (al posto dello SSAO, che il renderer Compatibility non ha) e inclina e infossa leggermente gli oggetti a terra. La qualità (`Quality`) si forza con `-- --quality=low|medium|high` o con la variabile `ODYSSEY_QUALITY`; senza forzature: web bassa, mobile media, PC alta. Test: `tests/test_vault.gd`, `tests/test_atmosphere.gd`.

## Maschera dell'erba

L'erba (`GrassField`) cresce solo dove la maschera `GrassMask` lo consente, per tipo di superficie e non per coordinate: nel gruppo `grass_ground` sta la mesh del prato (l'erba non esce dai suoi bordi), nel gruppo `grass_exclude` stanno mare, riva e sabbia, strade e piazzali lastricati. Le basi di costruzioni e oggetti alti (tende, torri, carri, alberi, rocce grandi) sono escluse in automatico. Ai bordi la densità scende gradualmente (`mask_fade`, 0,6 m) verso sabbia, sentieri e costruzioni. Il numero di ciuffi (`count`, `blades_per_tuft`) è la densità sul prato pieno e resta uniforme: a qualità più bassa si abbassa il numero totale, non la distribuzione. Il prato nuovo del secondo agente usa la stessa maschera: `GrassMask.from_tree(get_tree())` e poi `weight(Vector2(x, z))` per ogni punto, oppure basta mettere i suoi nodi nei due gruppi. Test: `tests/test_grass_mask.gd`.


## Crediti dei modelli di terzi (Sketchfab, CC-BY)
- Tenda degli ufficiali (`assets/models/custom/sketchfab/tende/`): "Tent" di Gajk.Mv (https://sketchfab.com/Gajk.Mv), licenza CC-BY-4.0, modificata (colori, pelli e rami aggiunti). Testi completi in `assets/models/custom/sketchfab/CREDITI.md` (da mostrare nei crediti del gioco).
