# Modelli Poly Haven (CC0)

96 modelli e 2 materiali del terreno presi da [Poly Haven](https://polyhaven.com), convertiti per il gioco: LOD bassi, decimati, texture ridotte, un materiale PBR per modello. Licenza **CC0**: uso libero, anche commerciale, senza obbligo di crediti ([polyhaven.com/license](https://polyhaven.com/license)). Citare Poly Haven e gli artisti nei crediti del gioco resta buona educazione; la pagina di ogni modello è `https://polyhaven.com/a/<nome>`.

Originali scaricati da Umberto in `~/Scaricati` e `~/Scaricati/new` (collezione *Namaqualand* e altri). Gli zip originali (2,8 GB, texture 2K e 4K) **non** sono nel repository.

**Elenco completo con uso, livello, dimensioni e budget: [CATALOGO.md](CATALOGO.md).** Anteprime: `../_previews/polyhaven_*.png`.

## Cartelle

| Cartella | Contenuto |
|---|---|
| `rocce/` | 6 rocce e scogliere (2 costiere), 1 tronco morto |
| `vegetazione/` | erba, fiori, felci, cespugli (alpha cards) |
| `alberi/` | 4 abeti (3 giovani, 1 adulto), 2 alberelli |
| `fauna/` | un ratto |
| `oggetti/` | forziere, botti, secchio, cassa, scala, sgabello |
| `attrezzi/` | ascia, martelli, pialla, sega, vanga, piccone, trapano |
| `architettura/` | molo di legno modulare, pezzi di mura in pietra |
| `terreno_costa/` | 2 materiali PBR tileable per sabbia e scogliera (non sono mesh) |
| `attrezzi_fuori_epoca/`, `navi_fuori_epoca/` | modelli moderni o seicenteschi, **da non usare** per Troia |

## Convenzioni

- **Formato**: `.gltf` + `.bin` + `textures/` (come `../terreno/`), non `.glb`: l'editor Godot duplica le texture incorporate nei .glb.
- **Scala**: metri reali (1 casella = 1 m), come i modelli di `custom/`. Gli oggetti sono già a scala: non riscalare.
- **Origine**: al centro della base (x e z), con la base a y = 0.
- **Materiali**: un materiale PBR proprio per ogni modello (base color, roughness, normal OpenGL), non la palette condivisa di `custom/`. Niente metallic, tranne dove l'originale lo prevede.
- **Alpha** (erba, foglie): `alphaMode = MASK`, cutoff 0,5, doppia faccia. Niente blending, niente problemi di ordinamento. Per le ombre in Godot va bene l'alpha scissor.
- **Texture**: base color a 1024 (rocce 2048), roughness e normal a 1024. Tutto ciò che non ha alpha è in **JPEG qualità 90** (senza sottocampionamento del colore, adatto alle normal map); solo le texture con alpha reale (erba, foglie) restano PNG. Con i PNG la cartella pesava 485 MB.
- **Peso su disco**: circa 110 MB per le 96 mesh più i 2 materiali del terreno. Godot le ricomprime in VRAM (S3TC/ETC2) all'import: nel build pesano molto meno.

## Cose da sapere prima di integrarli

1. **Il fogliame è molto scuro alla fonte** (albedo medio circa RGB 24/22/8 per gli abeti e 30/35/4 per gli alberelli). Con la luce calda del tramonto di `STYLE.md` serve un moltiplicatore di albedo (circa 1,5 – 2) o un tint caldo, altrimenti gli alberi sembrano neri. Le erbe e i fiori sono già a un buon livello.
2. **Erba e fiori sono pensati per `MultiMesh`**: poche decine o centinaia di triangoli per ciuffo (`grass_medium_01_tiny/tall` fra 35 e 160). Ciuffi grandi e cespugli (`*_large`, `searsia`, `othonna`) sono da usare a decine, non a migliaia.
3. **I pezzi del forte sono giganteschi** rispetto a una casella (mura alte 8,5 m, tratti lunghi 14,8 m). Funzionano come mura in scala diorama solo se si accetta la proporzione, oppure scalati a circa 0,5. Stile europeo da bastione, meno omerico delle mura di `troia/architettura/`.
4. **Specie sudafricane**: eliofila, othonna e searsia vengono dal fynbos del Namaqualand, non dal Mediterraneo. Per il colpo d'occhio sono macchia plausibile; non servono nomi botanici in gioco.
5. **Alberi procedurali** (`island_tree_01/02`): sono geometry nodes di Poly Haven con la densità di foglie ridotta fino a circa 40.000 e 35.000 triangoli. Sono alberi da primo piano, pochi esemplari; per i boschi servono i billboard o `fir_sapling` ai margini.
6. **Origine dei pezzi modulari**: ogni pezzo del molo e del forte è centrato sulla propria base. Per incastrarli servono le dimensioni del catalogo (molo: sezioni da circa 2,5 m di larghezza).

## Regola: niente profilo ICC nelle texture

Il loader di Godot 4.7 **rifiuta le JPEG con profilo ICC incorporato** (l'import risulta `valid=false` e la texture non esiste). I JPEG originali di Poly Haven e i PNG con alpha scritti dall'esporter glTF lo contengono (sRGB, 480 byte). `compress_textures.py` lo toglie da ogni jpg e png sotto `polyhaven/`, senza ricodificare le JPEG (`jpegtran -copy none`, stessi pixel). Va lanciato **dopo ogni nuova importazione**. Se Godot ha già segnato `valid=false`, cancellare il file `.import` della texture prima di rifare l'import, altrimenti non lo riprova. Verifica: `grep -l valid=false $(find polyhaven -name '*.import')` non deve trovare nulla.

## Non convertiti

| Modello | Motivo |
|---|---|
| `jacaranda_tree` | geometry nodes da circa 140.000 triangoli: troppo pesante, e non è un albero omerico |
| `tree_small_02` | albero procedurale da curve con 1,15 milioni di triangoli |
| `ship_pinnace` | nave del Seicento riggata, con armatura e dipendenze cicliche tra le ossa; fuori epoca |
| `coast_land_rocks_01`, `coast_sand_rocks_02` | sono materiali PBR (piano e sfera di prova), convertiti come texture in `terreno_costa/` |

## Piano d'uso nei livelli

### Livello 1: la pianura di Troia (accampamento, pianura, mura)

L'immagine di riferimento ha un diorama pieno di dettagli: casse, barili, rastrelliere, scudi, molo, torce, vegetazione ai bordi. Dai modelli nuovi:

| Dove | Cosa | Note |
|---|---|---|
| Accampamento, vicino alle tende | `oggetti/wooden_barrels_01_barrel01/02`, `wooden_crate_01`, `wooden_stool_02`, `wooden_bucket_02`, `treasure_chest` | Come i modelli di `troia/oggetti`, ma con texture PBR vere. Il forziere è per l'interazione (immagine di Ulisse). |
| Molo sul mare (riferimento) | `architettura/modular_wooden_pier/*` | 5 sezioni da circa 2,5 m più impalcato e pali: un molo di 10–15 m con 3–4 sezioni. |
| Mura di Troia | `architettura/modular_fort_01/*` | Solo come alternativa o per varietà; vedi nota 3 sopra. La porta (`wall_thin_gate_01`) è utile per il livello 2. |
| Pianura, prato | `vegetazione/grass_medium_01`, `grass_medium_02`, `celandine`, `dandelion`, `periwinkle` | Manto d'erba in MultiMesh con accenti gialli e viola (STYLE.md). Densità alta nei punti sotto la camera, più rada ai bordi. |
| Margini e rovine | `fern_02`, `searsia_lucida`, `othonna_cerarioides`, `island_tree_01/02`, `rocce/boulder_01`, `namaqualand_boulder_02/03` | Un cuscino di verde e pietra ai piedi di muretti e colonne: nessuna zona vuota. |
| Cresta e sfondo | `namaqualand_cliff_02` | Parete di roccia lunga 20 m, solo per il bordo del blocco. |
| Dettagli di vita | `fauna/street_rat` | Un paio di esemplari sotto le casse. |

Alberi mediterranei veri (ulivi, cipressi) restano quelli di `troia/vegetazione`: i nuovi abeti non appartengono a questa pianura.

### Livello 2: il dono del mare (spiaggia, cantiere del cavallo)

`level2.MD` prevede esplicitamente scogliera con relitto, legni spiaggiati, abeti sullo sperone, impalcatura e attrezzi, tracce da cancellare con alghe e conchiglie.

| Voce del documento | Modelli |
|---|---|
| Scogliera nord-ovest, rilievo di sperone | `rocce/namaqualand_cliff_02` (parete), `namaqualand_boulder_03`, `coast_rocks_05` per gli scogli in acqua |
| Relitto sulla scogliera (6 fasci di legna) | `coast_rocks_05` e `coast_land_rocks_04` come base; lo scafo spaccato resta da modellare in Blender (nessuna nave nuova è adatta: sono tutte seicentesche) |
| Bagnasciuga e battigia | `rocce/coast_land_rocks_04` (piattaforma 10 × 11,5 m piana): base per il **cantiere H**, nasconde la sabbia e dà un piano solido |
| Legni portati dal mare (8 mucchi da 1 fascio) | `rocce/dead_tree_trunk_02`, ripetuto e ruotato; mucchi da 2–3 tronchi |
| Abeti dello sperone (4 abeti da 2 fasci) | `alberi/fir_sapling_medium_a/b/c` ai piedi, `fir_tree_01_c` come quinta alta; fogliame scuro, vedi nota 1 |
| Spiaggia e dune | `terreno_costa/coast_sand_rocks_02_4k` (sabbia con sassi), `coast_land_rocks_01_4k` (terra e roccia costiera) come strati dell'array texture del terreno; `flower_heliophila`, `othonna_cerarioides` sulle dune |
| Cantiere del cavallo: impalcatura e attrezzi | `oggetti/wooden_ladder_02` (scale), `wooden_crate`, `wooden_bucket_02`, `attrezzi/wooden_axe`, `wooden_hammer_01`, `cross_pein_hammer`, `handsaw_wood`, `hand_plane_no4`, `vintage_hand_drill` |
| Tracce da cancellare (fase 3) | `attrezzi/rusted_spade_01` (rastrello/vanga), `wooden_bucket_02` per bagnare il legno |
| Accampamento acheo che brucia | `oggetti/wooden_barrels_01_barrel01/02`, `wooden_crate_01`, `wooden_stool_02` |
| Molo/banchina per le navi tirate in secca | `architettura/modular_wooden_pier/*` |
| Porta e mura di Troia (percorso del cavallo, breccia) | `architettura/modular_fort_01/*`, in particolare `wall_thin_gate_01` e `wall_thick_*` come pezzi alternativi per la breccia |

Mancano ancora (da modellare in Blender, come già indicato in `level2.MD`): il cavallo in 5 stadi e in sezione, la trireme smontata, lo scafo del relitto, alghe e conchiglie, i rulli e le funi.

## Rigenerare

Script in `../_source/scripts/` (la cartella ha un `.gdignore`). **Un solo Blender alla volta**: render o import in parallelo hanno già bloccato il PC.

```bash
# estrarre gli zip in cartelle separate fuori dal progetto, poi:
_source/scripts/run_polyhaven.sh <cartella con le cartelle estratte>   # tutti i modelli (poi:)
python3 _source/scripts/compress_textures.py                           # PNG senza alpha -> JPEG, aggiorna i .gltf
blender -b <x>.blend --factory-startup -P _source/scripts/import_polyhaven.py -- <nome>
blender -b --factory-startup -P _source/scripts/convert_materials.py -- <cartella> <nome materiale>
python3 _source/scripts/gen_polyhaven_catalog.py                       # rigenera CATALOGO.md
_source/scripts/render_polyhaven.sh                                    # anteprime in _previews/
```

La configurazione (quale LOD, budget di triangoli, dimensione texture, categoria) sta in `CONFIG` dentro `import_polyhaven.py`; ogni conversione scrive una riga in `_report.jsonl`.
