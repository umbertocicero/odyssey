# Modelli custom (Blender)

Modelli low-poly generati da script Blender (5.3, headless) nello stile di `STYLE.md`: figurine e oggetti da diorama dipinto, palette calda, rosso come accento, bronzo leggermente metallico.

## Convenzioni

- **Scala**: metri, 1 casella = 1 m. Le figurine sono alte circa 1,5 m (con cresta fino a 1,55 m), come il segnaposto attuale di Ulisse.
- **Origine**: ai piedi o alla base (z = 0 in Blender, y = 0 in Godot).
- **Fronte**: +Y in Blender, cioè **-Z in Godot**: lo stesso verso del `FacingMarker` usato da `grid_unit.gd` (`_model.rotation.y = atan2(-dir.x, -dir.y)`).
- **Materiale**: uno solo per tutti i modelli (`M_Odyssey_Palette`), con una texture palette 256×256 dipinta (base color + ORM, filtro Closest). Ogni parte del modello usa una casella della palette, così un modello è una sola draw call: ideale per mobile e web. Le texture sono incluse in ogni `.glb`; le copie sorgente sono in `_source/textures/`.
- I modelli di `assets/models/troia/` hanno scale molto diverse tra loro (sono download grezzi). Questi invece sono già a scala reale e non vanno riscalati.

## Contenuto

| Cartella | File | Cosa | Triangoli |
|---|---|---|---|
| personaggi | `oplita_acheo.glb` | Oplita acheo: elmo corinzio con cresta rossa, corazza di bronzo, mantello rosso, scudo rosso con stella, lancia | ~2.650 |
| personaggi | `ulisse_oplita.glb` | Variante Ulisse (stesso scheletro): capelli e barba, tunica bianca, mantello rosso, scudo di bronzo con il gufo di Atena, spada | ~2.640 |
| personaggi | `arciere_troiano.glb` | Arciere troiano: berretto frigio, tunica blu, brache a righe, arco e faretra | ~2.010 |
| personaggi | `ufficiale_troiano.glb` | Ufficiale troiano: elmo con cresta chiara, corazza bronzo e oro, mantello blu, scudo blu con testa di cavallo, spada | ~2.710 |
| accampamento | `tenda_padiglione.glb` | Tenda a padiglione rotonda a strisce rosse e crema (Ø 2,6 m, alta 2,8 m), tiranti e picchetti | ~800 |
| accampamento | `tenda_padiglione_piccola.glb` | Variante piccola (Ø 1,7 m) | ~680 |
| accampamento | `rastrelliera_lance.glb` | Rastrelliera con 7 lance e uno scudo acheo appoggiato (1,6 × 0,7 m) | ~1.470 |
| campo/carri | `carro_4_ruote/carro_4_ruote.gltf` | Carro di legno a quattro ruote con sponde e due stanghe (0,95 × 3,0 × 0,9 m), da `Wooden_Cart_3.blend` (sostituisce `carro_coperto.glb`); script `_source/scripts/build_carro4.py` | 13.312 |
| navi | `trireme.glb` | Trireme: scafo nero di pece con fascia rossa, rostro di bronzo, occhi a prua, aplustre, 44 remi su due file, scudi sulla murata, vela rossa | ~4.470 |
| stendardi | `scudo_acheo.glb` / `scudo_ulisse.glb` / `scudo_troiano.glb` | Scudi rotondi (Ø 0,85 m) in piedi sul bordo, da appoggiare | 240–320 |
| stendardi | `stendardo_acheo.glb` / `stendardo_troiano.glb` | Stendardo su asta con base in pietra (alto 2,95 m) | ~620 |
| stendardi | `drappo_muro_acheo.glb` / `drappo_muro_troiano.glb` | Drappo da appendere a mura e portali (1 × 1,6 m), retro a y = 0 | ~410 |

Colori di fazione: **achei** rosso, bronzo e crema (emblema: stella a otto punte); **troiani** blu e ocra (emblema: testa di cavallo). Ulisse ha il gufo di Atena.

La trireme è a scala diorama (lunga 10 m, non i 37 m reali) come le navi di `troia/navi`. La linea di galleggiamento è circa a z = 0,45 m: in Godot va abbassata di quella quota nell'acqua.

## Terreno ed erba fotorealistici

La cartella `terreno/` contiene il terreno del livello 1 (superficie con rilievo e lati del blocco, versione PC e mobile), le texture PBR tileable degli strati del suolo, 14 ciuffi d'erba alpha-cutout per MultiMesh e gli shader Godot di riferimento. Hanno un README proprio con integrazione e budget: [terreno/README.md](terreno/README.md).

## Scudi realistici (PBR)

`scudi_realistici/`: scudo oplitico (aspis) **scaricato** da OpenGameArt, non generato. Licenza **CC0**, autore *ninelionar* ([pagina](https://opengameart.org/content/aspis-hoplite-shield)); citarlo nei crediti è facoltativo ma gentile.

| File | Variante |
|---|---|
| `scudo_oplita_bronzo.glb` | bronzo con greca a sbalzo |
| `scudo_oplita_nero.glb` | dipinto di nero con lambda rovesciata rossa, bordo in bronzo |
| `scudo_oplita_nero_usurato.glb` | come il nero, ma consumato e ossidato |

Ha circa 6.100 triangoli e un materiale PBR proprio (base color, metallic/roughness e normal a 2048 px, in JPEG dentro il .glb, ~1,4 MB per file). Il diametro è 1,02 m, a scala reale e quindi più grande degli scudi stilizzati da 0,85 m. Le convenzioni sono le stesse degli altri modelli: bordo inferiore a z = 0 e fronte -Z in Godot. Non usa la palette condivisa: va bene come oggetto di primo piano, ma è più pesante.

Per rigenerarlo, scaricare lo zip originale (131 MB, texture 4K, non salvato nel repo), estrarlo e lanciare `blender -b <estratto>/aspis.blend --factory-startup -P _source/scripts/build_aspis.py`. Le texture ridotte a 2K sono in `_source/textures/aspis/`, il sorgente in `_source/blend/scudi_realistici/`.

## Scheletro e animazioni dei personaggi

Tutti e quattro i personaggi condividono lo stesso scheletro (root, hips, spine, neck, head, cape, upperarm/forearm/hand .L/.R, thigh/shin/foot .L/.R) con skinning rigido per parte: ogni pezzo segue un osso, come una figurina articolata. Lo scudo segue `forearm.L`, l'arma `hand.R`.

| Animazione | Durata (24 fps) | Note |
|---|---|---|
| `idle_loop` | 2 s | respiro e mantello |
| `walk_loop` | 1 s | ciclo sul posto (niente root motion) |
| `attack` | ~0,9 s | affondo di lancia (oplita), fendente (Ulisse, ufficiale), tiro con l'arco (arciere) |
| `hit` | 0,5 s | colpo subito |
| `death` | 1,25 s | cade all'indietro e resta a terra |

Godot imposta il loop in automatico sulle animazioni il cui nome finisce con `loop`.

## Rigenerare

Gli script sono in `_source/scripts/` (la cartella `_source` ha un `.gdignore`, quindi Godot la ignora):

```bash
blender -b --factory-startup -P _source/scripts/build_characters.py            # tutti i personaggi
blender -b --factory-startup -P _source/scripts/build_props.py -- trireme      # uno o più oggetti
_source/scripts/render_all.sh                                                   # anteprime in _previews/
```

Ogni build salva il sorgente in `_source/blend/<categoria>/<nome>.blend` ed esporta il `.glb` nella cartella della categoria. Le anteprime sono in `_previews/` (anche questa con `.gdignore`). I render vanno lanciati **uno alla volta**: più render EEVEE in parallelo hanno bloccato il PC.

## Altri modelli importati

- [`polyhaven/`](polyhaven/README.md): 96 modelli CC0 di Poly Haven e 2 materiali del terreno, con [catalogo](polyhaven/CATALOGO.md) e piano d'uso per i livelli 1 e 2.
- [`sketchfab/`](sketchfab/README.md): 3 modelli da Sketchfab con **licenza da verificare** (edificio greco, colonna corinzia, rovina).

## Nave achea e torcia (mesh.ai)

- `navi/nave_achea/nave_achea[_lod].gltf`: lunga 12 m (in scena `fit_size` 8-8,5), prua verso -Z, origine al centro con il punto più basso a y=0; ~32.000 / 7.000 tri, texture 1024 / 512. Usata dalle 4 navi ormeggiate e da `NaveInSecca` (tirata in secca sulla riva, fuori dal corridoio camp-costa) in `level1.tscn`.
- `campo/luci/torcia_achea/torcia_achea[_lod].gltf`: lunga 0,62 m, origine nel punto di presa, testa verso +Y, con fiamma emissiva a carte; ~5.000 / 3.400 tri, texture 512. Usata da `night_cycle.gd` in mano sinistra (`hand.L`) di Ulisse e degli alleati di notte.
- Rigenerare: `blender -b art_source/models/<nave_achea|torcia>.blend --factory-startup -P _source/scripts/build_nave_torcia.py -- <nave|torcia>`, poi `tune_imports.py navi campo/luci`.

## Catapulta, balista, carro e barella (mesh.ai)

Cartella `campo/macchine/<nome>/<nome>[_lod].gltf`, fronte verso -Z, origine al centro con il punto più basso a y=0 (barella: origine sull'asse delle stanghe, lunga 2,5 m lungo Z, assi delle stanghe a x=±0,36).

| Modello | Dimensioni (X×Y×Z m) | Triangoli (normale / lod) | Texture | Uso |
|---|---|---|---|---|
| `catapulta` | 1,7 × 2,4 × 2,6 | 24.000 / 6.000 | 1024 / 512 | `scenes/enemies/troiano/catapulta.tscn` |
| `balista` | 1,2 × 1,6 × 1,7 | 24.000 / 6.000 | 1024 / 512 | `scenes/enemies/troiano/balista.tscn` |
| `carro` | 1,75 × 1,5 × 3,0 | 24.000 / 6.000 | 1024 / 512 | prop `n_carro_guerra` di `level1.tscn` (timone verso -Z) |
| `barella` | 0,83 × 0,23 × 2,5 | 12.000 / 3.000 | 1024 / 512 | `scripts/units/stretcher.gd` |

Catapulta e balista sono caricate da `WallShooter` (`model_path` / `model_lod_path`): alta qualità il modello pieno, bassa e media il `_lod`. Rigenerare: `blender -b art_source/models/<nome>.blend --factory-startup -P _source/scripts/build_macchine.py -- <nome>`, poi `tune_imports.py campo`. Vecchi `catapulta_contrappeso`, `balista_telaio` e `carro_da_guerra` non più usati nel livello 1.
