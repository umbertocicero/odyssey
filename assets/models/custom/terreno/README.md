# Terreno ed erba fotorealistici (pianura di Troia)

Asset per passare dal terreno stilizzato a un look fotorealistico (riferimento: prati alla Red Dead Redemption 2, texture PBR da scansione stile Quixel Megascans), dentro i limiti di GTX 860M, mobile e web con il renderer **Compatibility**. Niente poligoni radi o flat shading: normali smussate ovunque, ogni superficie ha texture PBR (albedo, normal, roughness, AO, altezza) con variazione macro e dettaglio fine.

Generati da script Blender 5.3 headless in `../_source/scripts/` (vedi [Rigenerare](#rigenerare)). Anteprime in `../_previews/terreno/`.

**Non sono ancora integrati nelle scene.** Le luci, le ombre, l'occlusione ambientale e la nebbia restano nel motore (nodo `Atmosfera`, `Environment` di `level1.tscn`): questi asset forniscono solo i dati che servono (AO cotta nelle texture e nei vertex color, translucenza dei fili).

## Contenuto

| File | Cosa |
|---|---|
| `terreno_pianura.gltf` (+ `.bin`) | Terreno del livello 1, qualità PC: `Terreno_Superficie` (52×52 m con rilievo) e `Terreno_Lati` (pareti del blocco fino a -8 m). Materiali `M_Terreno` (texture cotte 2K) e `M_Terreno_Lati` |
| `terreno_pianura_mobile.gltf` (+ `.bin`) | Stesso terreno per mobile e web: meno triangoli, texture cotte 1K (`M_Terreno_Mobile`) |
| `erba_ciuffi.gltf` (+ `.bin`) | 14 mesh di ciuffi d'erba e piante selvatiche (alpha-cutout cards), materiale condiviso `M_Erba_Cards` |
| `godot/terreno_splat.gdshader` | Shader di terreno a qualità piena: 6 strati PBR tileable mescolati con splat map e altezza, roccia triplanare |
| `godot/erba_cards.gdshader` | Shader dei ciuffi per MultiMesh: vento, occlusione cotta, translucenza (BACKLIGHT). Stessa convenzione d'istanza di `assets/shaders/grass.gdshader` |
| `textures/` | Tutte le texture usate in gioco (elenco sotto) |

I `.gltf` usano le texture di `textures/` per riferimento, quindi Godot non ne estrae copie.

### Texture (`textures/`)

| File | Risoluzione | Contenuto |
|---|---|---|
| `T_terreno_array_albedo_height.png` | 1024 × (6 × 1024) | Texture2DArray, 6 strati: RGB albedo (sRGB), A altezza per il blend |
| `T_terreno_array_normal.png` | 1024 × (6 × 1024) | Texture2DArray, normal map OpenGL (verde = su), come le vuole Godot |
| `T_terreno_array_orm.png` | 1024 × (6 × 1024) | Texture2DArray: R AO, G roughness, B altezza |
| `T_terreno_splat.png` | 1024² su 52 m (5 cm/px) | R terra, G terra secca, B sentiero, A sabbia; il prato è il resto (1 − somma) |
| `T_terreno_maschere.png` | 1024² su 52 m | R roccia (pareti), G occlusione del terreno, **B densità dell'erba**, **A secchezza dell'erba** |
| `T_terreno_baked_albedo/normal/orm.png` | 2048² su 52 m | Strati già mescolati e cotti, per `M_Terreno` (funziona con `StandardMaterial3D`, senza shader) |
| `T_terreno_baked_*_1k.png` | 1024² | Le stesse a 1K, per il terreno mobile |
| `T_terreno_maschere2.png` | 1024² su 52 m | R **altezza macro dell'erba** (0 = rasa vicino ai sentieri, 1 = alta; scala consigliata `0,5 + R`), G banda di colore a grandi chiazze (0 fresco, 1 giallastro, per variare la tinta) |
| `T_nuvole_ombra.png` | 512² tileable | Ombre di nuvole: 1 = sole, ~0,55 = ombra. Da moltiplicare sul colore del terreno e dell'erba (o proiettare come cookie del sole) facendola scorrere piano, circa 1 m/s: dà le ombre di nuvole sul paesaggio del riferimento |
| `T_lato_sezione_albedo/normal/orm.png` | 1024² su 8×8 m | Lato del blocco in sezione: cotica con erba che ricade, muro di blocchi di pietra con muschio, terra scura con radici e sassi |
| `T_erba_cards_albedo_alpha.png` | 1024×1536 | Atlas delle cards, 10 ciuffi da 256×512 px: RGB colore (sRGB), A ritaglio |
| `T_erba_cards_normal.png` | 1024×1536 | Normali dei fili (profilo arrotondato) |
| `T_erba_cards_sss_rough_ao.png` | 1024×1536 | R translucenza (spessore inverso: punte sottili più luminose in controluce), G roughness, B AO dentro il ciuffo |

Strati dell'array (indice = slice, dall'alto dell'immagine) e metri coperti da un tile:

| Slice | Strato | Tile | Note |
|---|---|---|---|
| 0 | `prato_muschio` | 2 m | prato basso con fili oliva e punte secche, cuscinetti di muschio, terra che affiora: è la massa d'erba sotto le istanze |
| 1 | `terra` | 2,5 m | terra fertile scura, zolle, sassolini, rametti e paglia |
| 2 | `terra_secca` | 3 m | terra secca crepata a chiazze, polvere chiara |
| 3 | `sentiero` | 2,5 m | terra battuta con ghiaino incastrato |
| 4 | `sabbia_ghiaia` | 3 m | sabbia con increspature, chiazze di ghiaia, conchiglie |
| 5 | `roccia` | 4 m | calcare caldo a strati, fratture, licheni e muschio nelle fessure |

Le sorgenti per strato (albedo, normal, ORM, height separate, 1024²) sono in `../_source/textures/terreno_layers/` e si possono usare anche su altri oggetti con uno `StandardMaterial3D` (per esempio la roccia sulle rovine).

## Coordinate e scala

- **Ondulazioni**: le superfici piane hanno colline basse e dolci (±10 cm su onde di 10–25 m, parametro `UND_AMP` in `build_terrain.py`), come l'erba su terreno mosso del riferimento. Il gameplay usa ancora `TerrainRelief` (quote a gradini): le unità possono quindi sprofondare o galleggiare fino a 10 cm rispetto alla mesh. L'erba alta lo nasconde; per azzerarlo si imposta `UND_AMP = 0` e si rigenera, oppure si fa campionare la mesh alle unità.

- **Metri**, 1 casella = 1 m. I `.gltf` sono già in coordinate di mondo: si mettono **all'origine, senza trasformazioni**, sotto `Terreno`.
- Il blocco copre X −26..26 e Z −30..22, come `TerrainRelief` (`origin = (-26, -30)`, 52×52). La superficie segue la stessa mappa di livelli (letta da `level1.tscn`, 1 livello = 0,8 m): pianura a y ≈ 0 (micro-rilievo ±2 cm), altopiani a 0,8 / 1,6 / 2,4 m. Il gameplay resta su `TerrainRelief` e `DioramaGrid`: la mesh è solo visiva e combacia con le loro quote. Le pareti tra un livello e l'altro sono pendii rocciosi frastagliati larghi circa 0,3–0,5 m, centrati sul bordo tra le caselle.
- Mare incassato a ovest (X < −21,6, Z −19..22): fondale a −0,6 m, spiaggia in pendenza fino a X ≈ −19,8. Il `Mare` attuale (box a y −0,3) ci sta sopra senza modifiche.
- Strade, accampamento e spiaggia della splat map seguono `StradaAccampamento`, `StradaPorta`, `Spiaggia` e le tende di `level1.tscn`. Se il livello cambia, si rigenera il terreno (lo script rilegge la mappa).
- I lati vanno dal bordo del terreno fino a y = −8, come `BlockSides`.
- Cosa sostituisce, se l'integrazione lo decide: `Prato`, `PratoNordOvest`, `Fondale`, `Strade*`, `Spiaggia`, la parte visiva di `Rilievo` (i due MultiMesh) e di `BlockSides`.

## Integrazione in Godot

### Terreno

**Subito, senza shader**: istanziare `terreno_pianura.gltf` (o `_mobile`). I materiali importati sono `StandardMaterial3D` con albedo, normal e ORM cotti: funziona così com'è.

**Qualità piena** (dettaglio a pochi millimetri invece che 2,5 cm/px): sostituire il materiale di `Terreno_Superficie` con uno `ShaderMaterial` su `godot/terreno_splat.gdshader`.

1. Import delle tre `T_terreno_array_*.png`: nel pannello Import scegliere **Texture2DArray**, `slices/horizontal = 1`, `slices/vertical = 6`, `mipmaps/generate = on`, compressione VRAM. Reimport.
2. `T_terreno_splat.png` e `T_terreno_maschere.png`: import come Texture2D, compressione **Lossless** (sono maschere, la compressione a blocchi sporca i bordi), mipmap on.
3. Parametri dello shader:

| Parametro | Valore |
|---|---|
| `layer_albedo_height` | `T_terreno_array_albedo_height.png` (Texture2DArray) |
| `layer_normal` | `T_terreno_array_normal.png` |
| `layer_orm` | `T_terreno_array_orm.png` |
| `splat_map` | `T_terreno_splat.png` |
| `mask_map` | `T_terreno_maschere.png` |
| `tile_meters_a` / `tile_meters_b` | (2, 2,5, 3, 2,5) / (3, 4): già i default |
| `height_blend`, `blend_contrast` | 0,5 e 0,25: più basso il contrasto, più netti i bordi tra gli strati |
| `anti_tiling` | 0,35: secondo campione ruotato contro la ripetizione |
| `grass_tint` | tinta del prato, per accordarlo con l'erba istanziata |

Costo: 5 sampler; per pixel 2–3 strati attivi in media (il ciclo salta quelli a peso zero), la roccia triplanare solo sulle pareti. Splat e maschere usano le UV della mesh, gli strati la posizione nel mondo.

Per i lati basta il materiale importato (`M_Terreno_Lati`): texture 8×8 m ripetuta in orizzontale, con il rilievo vero nella geometria (i blocchi di pietra sporgono fino a 8 cm).

### Erba (GPU instancing)

Ogni mesh di `erba_ciuffi.gltf` va in un `MultiMeshInstance3D`: **una draw call per variante**, qualunque sia il numero di ciuffi. Tutte condividono lo stesso materiale.

| Mesh | Alta | Triangoli | Uso |
|---|---|---|---|
| `Erba_Alta` | 0,55 m | 32 | verde fresco |
| `Erba_PunteSecche` | 0,60 m | 32 | verde con punte gialle |
| `Erba_Media` | 0,38 m | 32 | riempimento |
| `Erba_Bassa` | 0,18 m | 32 | bordi dei sentieri, sotto le unità |
| `Erba_Secca` | 0,55 m | 32 | chiazze secche |
| `Erbacce_Foglie` | 0,40 m | 16 | piante a foglia larga, accento |
| `Fiori_Selvatici` | 0,42 m | 16 | fiori viola, gialli e bianchi (accenti di STYLE.md), rari |
| `Graminacee_Semi` | 0,68 m | 32 | spighe secche, rare |
| `Erba_Lunga` | 0,95 m | 32 | fili lunghi e sottili, **già piegati verso +X** (direzione del vento, come nel riferimento RDR2): per le chiazze alte |
| `Erba_Lunga_Secca` | 0,95 m | 32 | come sopra, con punte e fili paglierini |
| `Prato_Alto` | ~0,9 m, Ø 0,7 m | 112 | zolla di 14 cards lunghe piegate dal vento: massa alta e fitta con poche istanze |
| `Prato_Denso_A` | ~0,5 m, Ø 0,7 m | 96 | zolla di 12 cards miste: massa continua con poche istanze |
| `Prato_Denso_B` | ~0,5 m, Ø 0,7 m | 104 | zolla di 13 cards, più secca, con fiori e spighe |
| `Prato_Denso_C` | ~0,4 m, Ø 0,7 m | 96 | tappeto basso e fitto di 12 cards: riempie i vuoti tra i ciuffi alti |

Origine alla base del ciuffo, fronte qualsiasi (vanno ruotati a caso). Ogni ciuffo singolo ha 4 card; ogni card ha 220–340 fili disegnati nell'atlas ed è un quad in 4 segmenti verticali, già piegato e inclinato in fuori; le normali puntano in alto e in fuori, così la luce è morbida su entrambe le facce.

Dati nella mesh, letti da `godot/erba_cards.gdshader`:

- `COLOR.rgb` = **occlusione cotta** alla base del ciuffo (0,28 alla base → 1 a 0,6 dell'altezza). Per glTF il vertex color moltiplica il colore base, quindi anche con un materiale standard il ciuffo è già scuro alla base.
- `COLOR.a` = **translucenza** per vertice (0,35 alla base → 1 in punta), moltiplicata per il canale R di `T_erba_cards_sss_rough_ao.png`: va in `BACKLIGHT`, la luce del sole basso attraversa i fili in controluce.
- `UV2.x` = **peso del vento** (0 alla base, 1 in punta, curva t^1,6): la base resta ferma. `UV2.y` = fase casuale per card.

Materiale: `ShaderMaterial` su `godot/erba_cards.gdshader` con `albedo_alpha = T_erba_cards_albedo_alpha.png`, `card_normal = T_erba_cards_normal.png`, `sss_rough_ao = T_erba_cards_sss_rough_ao.png`. Ritaglio con `ALPHA_SCISSOR_THRESHOLD` (alpha test, niente trasparenza ordinata: niente problemi di sorting). Il colore dei fili è già dilatato sotto l'alpha, quindi non ci sono aloni scuri sui bordi con le mipmap.

Convenzione d'istanza, la stessa di `GrassField` / `grass.gdshader` (così i due shader si fondono: a quello esistente basta prendere texture, `UV2` per il vento e `COLOR.a` per la translucenza):

- trasformazione dell'istanza: solo traslazione (con `rotation_from_custom = false` si può usare la trasformazione completa);
- `INSTANCE_CUSTOM` (`use_custom_data = true`): x angolo in radianti, y scala (0,75–1,3), z fase del vento 0..1;
- colore d'istanza (`use_colors = true`): tinta. Verde fresco ≈ `Color(1, 1, 1)`, secco ≈ `Color(1.25, 1.05, 0.62)`: interpolare con la secchezza della maschera.

Scatter: campionare `T_terreno_maschere.png` nel punto (x, z) del mondo con `u = (x + 26) / 52`, `v = (z + 30) / 52` (v = 0 è la riga in alto dell'immagine, cioè il nord). Canale B = probabilità di piazzare un ciuffo, canale A = secchezza (sceglie le varianti secche e la tinta). La quota si prende da `TerrainRelief.height_at_world()`; sulle pareti (canale R > 0,5) non si piazza niente. Esempio:

```gdscript
var img := preload("res://assets/models/custom/terreno/textures/T_terreno_maschere.png").get_image()
img.decompress()
var rng := RandomNumberGenerator.new()
for i in candidates:  # punti jitterati su una griglia di passo 0,12-0,2 m
	var p: Vector3 = candidates[i]
	var m := img.get_pixelv(Vector2((p.x + 26.0) / 52.0, (p.z + 30.0) / 52.0) * Vector2(img.get_size()))
	if m.r > 0.5 or rng.randf() > m.b:
		continue
	# variante: secca se rng.randf() < m.a, altrimenti verde (pesi suggeriti sotto)
	# transform: Transform3D(Basis(), Vector3(p.x, relief.height_at_world(p.x, p.z) - 0.02, p.z))
	# custom data: Color(rng.randf() * TAU, rng.randf_range(0.75, 1.3) * (0.6 + 0.6 * m.b), rng.randf(), 0)
	# colore: Color(1, 1, 1).lerp(Color(1.25, 1.05, 0.62), m.a * rng.randf_range(0.6, 1.0))
```

Pesi suggeriti per le varianti (quelli delle anteprime; a questi si aggiungono `Erba_Lunga` 6·R², `Prato_Alto` 7·R² tra i verdi e `Erba_Lunga_Secca` 6·R², `Prato_Alto` 3·R² tra i secchi): verdi `Erba_Alta` 3, `Erba_Media` 4, `Erba_Bassa` 3, `Prato_Denso_A` 5, `Prato_Denso_C` 5, `Erbacce_Foglie` 0,7, `Fiori_Selvatici` 0,6; secche `Erba_PunteSecche` 4, `Erba_Secca` 3, `Prato_Denso_B` 5, `Erba_Media` 2, `Graminacee_Semi` 0,7.

**Culling**: un MultiMesh viene scartato solo per intero. Dividere il prato in blocchi da 8×8 m (un `MultiMeshInstance3D` per variante e per blocco) così quello che è fuori dall'inquadratura della camera fissa non si disegna; impostare `visibility_range_end` per spegnere i blocchi lontani.

**Piegatura**: le mesh `Erba_Lunga*` e `Prato_Alto` sono inclinate verso +X: il vento di `erba_cards.gdshader` va tenuto con `wind_direction` vicino a (1, 0,3) perché le raffiche le spingano nello stesso verso in cui sono già piegate (con una direzione opposta sembrano pettinate al contrario).

**Macro-variazione**: la scala di ogni ciuffo segue `T_terreno_maschere2.png` (R): `scala = (0,5 + R) × random(0,85–1,15)`. Dove R > 0,6 si scelgono `Erba_Lunga`, `Erba_Lunga_Secca` e `Prato_Alto` (peso ∝ R²); vicino ai sentieri R scende e restano erbe medie e basse, quindi la transizione verso il sentiero è naturale. Il canale G dà la banda di colore a grandi chiazze: usarlo per interpolare la tinta d'istanza tra verde e giallastro oltre alla secchezza.

**Vento**: `wind_direction`, `wind_strength` (metri di spostamento in punta, 0,12), `wind_speed`, `gust_size` (lunghezza d'onda delle raffiche, 9 m), `flutter` (tremolio per card). Le raffiche dipendono dalla posizione dell'istanza, quindi attraversano il prato come onde. L'interazione con i personaggi resta quella di `grass.gdshader` (interattori): si aggiunge allo spostamento del vento con lo stesso peso `UV2.x`.

## Budget di prestazioni

| Asset | Triangoli | Draw call | Texture (VRAM, compresse con mipmap) |
|---|---|---|---|
| Terreno PC (superficie + lati) | 55.400 + 43.300 | 2 | cotte 2K: ~12 MB; con shader splat: array ~20 MB + maschere ~8 MB |
| Terreno mobile/web | 19.000 + 10.800 | 2 | cotte 1K: ~3 MB |
| Erba, per ciuffo | 16–104 (in media ~60 con i pesi suggeriti) | 1 per variante (per blocco) | atlas 3 × 1K: ~3 MB |

Godot genera da solo i LOD delle mesh all'import (`meshes/generate_lods`), utile soprattutto per i lati.

Numero di ciuffi consigliato (la camera fissa vede circa 20×15 m alla volta; il resto va spento col culling a blocchi):

| Qualità (`Quality`) | Ciuffi visibili | Triangoli d'erba | Varianti | Note |
|---|---|---|---|---|
| alta (PC) | 20.000–30.000 | ~1,3–2 M | tutte | passo 0,10–0,14 m: massa continua, il suolo non si vede (anteprima `terreno_hero.png`) |
| media (mobile) | 6.000–9.000 | ~0,5 M | 4 (Prato_Denso_A/B/C, Erba_PunteSecche) | passo 0,25 m, quasi solo zolle dense |
| bassa (web) | 2.500–3.500 | ~0,2 M | 2 (Prato_Denso_A/C) | passo 0,4 m; il resto lo fa la texture `prato_muschio` |

Il costo vero dell'erba non sono i triangoli ma i pixel ripetuti (overdraw) delle card con alpha test: per abbassarlo conviene ridurre la densità dove la camera è più vicina al suolo e usare `Erba_Bassa` vicino ai sentieri. Su web niente `BACKLIGHT` se le prestazioni non bastano (translucency = 0).

## Rigenerare

Dalla cartella `assets/models/custom/`, **un comando alla volta** (render paralleli hanno bloccato il PC):

```bash
blender -b --factory-startup -P _source/scripts/gen_terrain_textures.py
```

```bash
blender -b --factory-startup -P _source/scripts/build_terrain.py
```

```bash
blender -b --factory-startup -P _source/scripts/build_grass.py
```

```bash
blender -b --factory-startup -P _source/scripts/render_terrain.py -- hero _previews/terreno/terreno_hero.png
```

- `gen_terrain_textures.py`: tutte le texture, procedurali e periodiche (rumore frattale filtrato in frequenza, Voronoi avvolto, fili d'erba rasterizzati a 2× e ridotti). Circa 1 minuto. Si può limitare a qualche strato: `-- terra roccia`.
- `build_terrain.py`: legge la mappa dei livelli da `scenes/levels/level1/level1.tscn`, costruisce il campo di altezza a 12,5 cm, decima la superficie mantenendo il perimetro, calcola splat, maschere e texture cotte. Circa 40 s.
- `build_grass.py`: le 14 mesh di ciuffi.
- `render_terrain.py`: anteprime `overview`, `hero`, `close`, `ground` (camera bassa come nel riferimento), `cards` (aggiungere `--mobile` per il terreno mobile). Lo scatter delle anteprime usa la stessa maschera e gli stessi pesi descritti sopra.

Sorgenti `.blend` in `../_source/blend/terreno/`.
