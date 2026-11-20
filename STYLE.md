# Stile grafico di Odyssey

Riferimento: `ispirazione/realistic.png`. Il gioco deve assomigliare a questa immagine: un **diorama in miniatura dipinto a mano**, posato su un tavolo da lavoro, illuminato da un tramonto caldo. Qui sotto c'è solo ciò che si vede nell'immagine, seguito da indicazioni pratiche per ottenerlo.

## 1. Cosa si vede nell'immagine

### Soggetto e forma del diorama
- Un blocco unico, spesso, con la superficie in cima e i lati in sezione. I lati non sono strati lisci: sono **muri di blocchi di pietra** in basso e **terra scura con radici** che spuntano, con bordi irregolari e sbrecciati.
- Il bordo superiore è chiuso da **muretti e rovine di pietra** che fanno da cornice al terreno di gioco.
- Il mare occupa un lato intero del blocco. Sul bordo il taglio mostra l'acqua in sezione, come resina trasparente verde-azzurra.
- Sul terreno: piazzale lastricato, una tenda a strisce, una torre di legno, un braciere acceso, un molo di legno, navi con vele rosse e bianche, colonne, un portale di pietra con stendardi.

### Palette e colori dominanti
- **Luce e cielo**: arancio, pesca e rosa del tramonto, con il sole basso e bianco-dorato sull'orizzonte.
- **Pietra**: beige, sabbia e grigio caldo. Il lastricato tende al terracotta chiaro.
- **Vegetazione**: verdi oliva e muschio, mai verde acido. Cipressi verde scuro, fiori viola e gialli come piccoli accenti.
- **Rosso**: è il colore d'accento principale. Lo hanno stendardi, vele, mantelli e creste degli elmi.
- **Bronzo e oro**: elmi, scudi e decorazioni.
- **Acqua**: blu-verde con molta schiuma bianca e riflessi caldi del sole.
- Nel complesso la palette è calda e satura ma non accesa. Gli unici toni freddi sono l'acqua e le montagne lontane.

### Illuminazione e ombre
- Il sole è basso, dietro la scena, verso l'orizzonte: la luce arriva in **controluce** e accende i bordi di oggetti e personaggi (rim light dorata).
- Il riempimento è caldo: le zone in ombra sono marroni o ambrate, **mai nere**.
- Le ombre sono morbide, brevi sotto gli oggetti, con molta occlusione nelle fessure tra le pietre.
- Ci sono luci locali calde: il braciere e i fuochi della città lontana, con un leggero alone luminoso.

### Materiali e texture
- Tutto sembra **modellato e dipinto a mano**, come una miniatura.
- Pietra: ogni blocco è distinto, con spigoli smussati e scheggiati e fughe scure. Il lastricato è irregolare, con erba e muschio tra le pietre.
- Legno: venature visibili e assi separate (molo, torre, casse, barili, staccionate).
- Stoffa: tenda e vele a strisce rosse e bianche, con pieghe morbide.
- Muschio ed edera crescono sui muri e alla base delle rovine.
- I materiali sono opachi. Lucidi sono solo il bronzo (un riflesso leggero) e l'acqua.

### Livello di dettaglio
- Densità alta: in poco spazio ci sono molti piccoli oggetti (casse, barili, rastrelliere di armi, scudi appoggiati, torce, staccionate, cespugli, fiori). Non ci sono zone vuote.
- I personaggi sono **figurine stilizzate**: teste ed elmi grandi, elmo con cresta rossa, scudo rotondo con emblema, lancia o spada, mantello rosso. Si leggono bene da lontano grazie a sagoma e colore.
- Gli oggetti hanno forme semplici ma con molti dettagli piccoli: niente geometria piatta e liscia.

### Composizione e camera
- Vista dall'alto di tre quarti, inclinata di circa 30–40° sul piano, con una prospettiva moderata (non ortografica).
- Il diorama riempie i due terzi inferiori. L'orizzonte sta nel terzo superiore, con il sole quasi al centro.
- Il percorso parte dal primo piano (in basso a sinistra) e porta lo sguardo verso il mare e la città sullo sfondo.

### Atmosfera, profondità di campo ed effetti
- Tono epico e caldo. Troia brucia in lontananza, con colonne di fumo e fuochi.
- **Profondità di campo** da miniatura: è a fuoco il centro del diorama, mentre il tavolo, lo studio e i bordi sono sfocati (effetto tilt-shift).
- Foschia atmosferica calda verso l'orizzonte: montagne e città sono più chiare e meno contrastate.
- Bagliore (bloom) leggero su sole, fuochi e riflessi dell'acqua.
- Fuori dal blocco l'immagine mostra un banco da lavoro e delle mani che dipingono: è la cornice "miniatura", non parte del gioco.

### Cosa evitare (per contrasto con il riferimento)
- Luce fredda o neutra, ombre nere, ambiente violaceo o grigio.
- Superfici piatte senza texture, lati del blocco lisci a strati.
- Spazi vuoti e oggetti isolati e lontani tra loro.
- Colori acidi o troppo saturi, verde brillante.
- Personaggi senza sagoma riconoscibile.
- Griglia di gioco ben visibile sopra il terreno: nel riferimento non si vede.
- Modelli di stili diversi mescolati, per esempio low-poly a tinta unita accanto a pietra dettagliata.

## 2. Indicazioni pratiche

### Godot (renderer Compatibility: mobile, PC, web)
Il renderer Compatibility non offre SSAO, SSR, SDFGI né nebbia volumetrica: il look va ottenuto con luce, ambiente, materiali e texture.

- **Sole** (`DirectionalLight3D`):
  - basso, 15–25° sull'orizzonte, dal lato opposto alla camera, così fa da controluce;
  - colore arancio-dorato (circa `#FFB070`), energia 1.2–1.6;
  - ombre attive, con `shadow_blur` alto per averle morbide.
- **Ambiente** (`WorldEnvironment`):
  - cielo `ProceduralSkyMaterial` o un'immagine panoramica del tramonto: in alto pesca e rosa, all'orizzonte arancio;
  - luce ambientale presa dal cielo o di un colore caldo (circa `#C8906A`), energia 0.5–0.8, così le ombre restano ambrate;
  - tonemap Filmic o AgX (se disponibile nella build), con esposizione leggermente alta;
  - glow attivo con soglia alta, solo su sole, fuoco e acqua;
  - nebbia di profondità leggera e calda per la foschia verso l'orizzonte;
  - Adjustments: un po' di saturazione e contrasto in più.
- **Luci locali**: `OmniLight3D` arancioni su bracieri e torce, poche e senza ombre per restare leggeri. La fiamma va fatta con un materiale emissivo.
- **Materiali**:
  - `StandardMaterial3D` opaco (roughness 0.8–1), texture albedo dipinte;
  - occlusione già cotta in Blender nel colore dei vertici o nella texture, visto che SSAO non c'è;
  - metallic basso solo sul bronzo;
  - acqua con un materiale trasparente, schiuma dipinta o animata con uno shader semplice.
- **Profondità di campo**: in Compatibility la sfocatura della camera non è garantita. Si può fare nello shader di post-process già previsto (`assets/shaders/post_process.gdshader`), con una sfocatura tilt-shift: bande in alto e in basso sfocate, centro nitido.
- **Griglia**: non deve vedersi durante il gioco. Le caselle si possono mostrare solo come evidenziazione (casella bersaglio, mosse possibili).
- **Camera**: inclinazione 35–40°, campo visivo stretto (25–35°), più vicina al terreno, in modo da vedere poche caselle alla volta ma piene di dettagli.

### Blender
- **Pietra**: blocchi separati con bevel e scheggiature, fughe scure. Per muri e lastricato si possono usare moduli riutilizzabili (kit).
- **Lati del blocco**: muro di pietra in basso, terra con radici in alto, bordo superiore irregolare con muretti e rovine.
- **Personaggi**: proporzioni da figurina (testa ed elmo grandi), cresta rossa, scudo rotondo con emblema, mantello. Sagoma chiara e pochi colori forti.
- **Texture**:
  - dipinte a mano o generate con colori caldi e variazioni;
  - AO e sporco cotti nella texture o nel colore dei vertici;
  - una palette condivisa, cioè un'unica texture atlas per molti oggetti, che tiene leggero mobile e web.
- **Poligoni**: poligoni bassi ma senza spigoli vivi. Meglio pochi bevel ben messi che geometria liscia.
- **Esportazione**: `.glb` in `assets/`, scala reale (1 casella = 1 m), con l'asse in avanti coerente.

### Rapporto con il filtro pixel art previsto
- Il riferimento non è pixel art. Il filtro va applicato sopra questo look, quindi prima si costruisce bene la scena 3D e solo dopo si pixela.
- Ordine nel post-process: prima colore e sfocatura tilt-shift, poi pixelatura e riduzione della palette.
- La palette del filtro va presa dal riferimento (arancio, pesca, beige, oliva, rosso, bronzo, blu-verde), così il pixel art resta caldo.
- La dimensione dei pixel deve restare piccola (2–3 px a 1080p): i dettagli piccoli e le sagome dei personaggi devono rimanere leggibili.
