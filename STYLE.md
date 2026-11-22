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

## 5. Accampamento e stile Età del bronzo (richiesta di Umberto, vale per tutto il gioco)

Riferimento: foto `ispirazione/accampamento_riferimento.jpg` (**non ancora salvata**: il file non è arrivato al computer, va rimandato). Regole estratte dalla descrizione:
- **Epoca**: Età del bronzo greca. Niente tendoni da circo, niente colori vivaci o piatti.
- **Luce**: tramonto dorato cinematografico, foschia e colonne di fumo. Ambiente smorzato (saturazione globale 0,8 in `Environment`), foschia calda più densa.
- **Palette**: terrosa e smorzata: sabbia, ocra, oliva, legno consumato, bronzo opaco, rosso/marrone spento per mantelli e stendardi.
- **Tende**: grandi, di tela e pelli consumate, con rami frondosi e pellicce sopra, pali e corde. In scena: modelli a tenda scuri, desaturati (`GridProp.tint` e `desaturate`).
- **Campo**: denso, irregolare, vissuto: fuochi con calderoni su pietre, pithoi, botti, panche, rastrelliere con lance, scudi rotondi appoggiati, palizzate di pali appuntiti, cumuli di terra, casse sparse, file di tende che si perdono in lontananza. Terra e sabbia con impronte e ciuffi d'erba secca, pini, colline sullo sfondo. Niente piazzale a lastre nel campo.
- **Navi**: legno scuro, scafo curvo, sartiame, vela quadra, tirate in secca con schiuma.
- **Personaggi**: tuniche semplici, mantelli rosso/marrone spenti, corazza ed elmo di bronzo. Presenti i cavalli.
- **Mancano** (non inventati): panche, calderoni, pithoi, tende con pelli e rami, cavalli (esiste solo `sketchfab/animali/cavallo_lowpoly_marrone`, licenza da verificare, non inserito), vele quadre con sartiame dettagliato.

## 6. Sentiero verso Troia e Troia sullo sfondo (riferimento `ispirazione/sentiero_troia_riferimento.jpg`, non ancora salvato)
- Steppa secca ocra dorata; strada di terra larga e curva con solchi profondi di ruote e impronte; palizzate di pali appuntiti e staccionate basse lungo il sentiero; cumuli di pietre e barricate di pali; ciuffi di erba gialla secca e cespugli; pochi alberi tondi; capanne e fuochi lontani; colonne di fumo sulla piana.
- Troia sullo sfondo: cittadella massiccia di arenaria chiara su una collina bassa all'orizzonte, mura merlate con torri quadrate, porta centrale, molti edifici con tetti di terracotta, fumo.
- Soldati con elmo a cresta rossa, corazza di bronzo, mantello rosso scuro, lance; un carro con cavalli in lontananza.
- Luce morbida con foschia, cielo nuvoloso, sole caldo del pomeriggio con ombre lunghe.

## 7. Mura e porta di Troia da vicino (`ispirazione/mura_porta_troia_riferimento.jpg`, non ancora salvato)
- Mura di blocchi di calcare ocra tagliati grezzamente con giunti di malta, muschio e usura; grandi torri quadrate merlate ai lati di una porta centrale a due battenti di legno scuro con borchie e rinforzi di metallo, incorniciata di pietra.
- In cima palizzata di legno, piattaforme di guardia coperte con tetto di tegole, scale di legno addossate, bracieri fumanti sulle torri, bandiere scure e dorate su pali, difensori con scudi rotondi ed elmi a cresta.
- Davanti alla porta barricate di pali appuntiti e cumuli di pietre, strada polverosa con solchi, cespugli secchi in primo piano.

## 8. Pianura di battaglia (`ispirazione/battaglia_pianura_riferimento.jpg`, non ancora salvato)
- Battaglia fitta su pianura sabbiosa calpestata sotto le mura; luce dorata con foschia, colonne di fumo scuro, frecce infuocate nel cielo.
- Opliti greci con corazza di bronzo, elmi a cresta (rossi, blu, semplici), scudi rotondi di bronzo, mantelli blu/rossi/marroni; cavalli, un carro da guerra.
- Troiani sulle mura: arcieri su merli e torri, bandiere, bracieri; davanti catapulte di legno (braccio con contrappeso) e baliste su telai con ruote, con serventi e piccoli fuochi; barricate di pali, detriti, frecce conficcate a terra, fango e impronte; campo greco e navi in lontananza a sinistra.

## 9. Ulisse e i soldati achei da vicino (`ispirazione/achei_ulisse_riferimento.jpg`, non ancora salvato)
- Bronzo consumato da battaglia, opaco e invecchiato (non lucido, non giallo piatto): roughness alta, metallico moderato, graffi.
- Elmi corinzi con incisioni e paraguance, alte creste di crine nero (più grande sul capo); corazza muscolata con volute incise e spalline a strati; cinghie e cinturoni di cuoio, bracciali; scudi rotondi (hoplon) di bronzo martellato con ammaccature e simboli (tridente, chevron); tunica scura.
- Volti ruvidi e barbuti, capelli scuri, cicatrici, sporco; sfondo con file di opliti e lance, polvere e fumo, luce diffusa morbida.

## 10. Mare, riva e navi (riferimento solo testuale; `mare_riva_navi_riferimento.jpg` assente)
- Mare blu-verde scuro mosso con onde bianche che si rompono sulla sabbia bagnata (`assets/shaders/sea.gdshader`, rifatto da un altro agente: non toccarlo), luce coperta di crepuscolo, fumo e fuochi sulla spiaggia.
- Grandi navi scure con occhio dipinto e vela quadra all'ancora al largo, navi medie più vicine, piccole barche a remi che fanno la spola, alcune tirate in secca spinte in acqua da soldati; tende scure sulla spiaggia.
- Nel livello 1 il mare è una striscia di 4,4 m sul lato ovest del blocco: oggi ci sono 2 triremi e 2 pentecontere. Mancano barche a remi, navi con occhio dipinto, soldati in acqua.

## 11. Cielo e luce (riferimento solo testuale; `cielo_luce_riferimento.jpg` assente)
- Tramonto drammatico: sole basso arancione-oro dietro colline lontane, grandi cumuli stratificati grigio-viola con bordi arancio/rosa/oro, foschia dorata e polvere sul terreno, ombre lunghe e morbide, colonne di fumo scuro, terreno in controluce caldo, mare con riflessi caldi, mura con torri fumanti in controluce.
- Contrasto caldo-freddo: arancio e oro contro blu ardesia e viola (sole oro-arancio, riempimento viola ardesia).
- Implementazione: `assets/shaders/sky_dusk.gdshader` (cielo con sole, gradiente e nuvole procedurali; ottave 2/3/5 per qualità), sole a 22° (`LevelAtmosphere.sun_elevation_degrees`), `fog_sun_scatter` 0,55, luce di riempimento viola. Il Compatibility non ha nebbia volumetrica né raggi di luce: la foschia è quella per distanza; i raggi volumetrici restano da fare (cards o post-process) se il profilo regge.

## 12. Stato di applicazione (novembre 2026)
Applicato nel livello 1: stile Età del bronzo (sezione 5) con accampamento, tende, focolare, pithoi, panche e palizzate; sentiero e Troia (6) con strada di terra, steppa secca ocra, mura, torri, porta e colle; battaglia (8) con carri, cavalli, polvere, fumo e frecce infuocate; mare e cielo (10-11) con cielo procedurale, sole basso e foschia; achei (9) con elmo corinzio e hoplon su Ulisse. HUD: cornici di bronzo con greca, ritratti e icone di `assets/ui/hud/`, pergamena per minimappa e obiettivo. Foto di riferimento non ricevute (solo descrizioni): sentiero, mura e porta, battaglia, achei, mare, cielo, HUD, accampamento.
Ancora da fare: luce reale sui bracieri, vele e navi in secca, volti e corazze dettagliate sul rig, atmosfera dinamica (`todo.md`).

## 13. Notte
Riferimento solo testuale (`ispirazione/notte_torce_luna_riferimento.jpg` non arrivata): notte con luna piena fredda tra le nuvole, poca visibilità, soldati con torce calde, fuochi lontani e fumo sulla piana, mura di Troia illuminate da luci calde, strada in penombra blu-ardesia.
Implementazione (`NightCycle`, `LevelClock`): il tempo scorre in modo continuo dalle 17:30 alle 23:30 (nessuno stage visibile); sole che scende sotto l'orizzonte e si arrossa, luna fredda e fioca (`DirectionalLight3D` blu, senza ombre a low/medium, con ombre a high), cielo con stelle e luna in `sky_dusk.gdshader`, ambiente e nebbia blu-ardesia, fuochi che crescono fino a +90 %, torce calde sui soldati vicini al giocatore (luci puntiformi: low 1, medium 5, high 9), luci calde sui bracieri delle mura (0/3/5). Pioggia casuale (`WeatherFx`): overlay 2D a costo fisso, terreno ed erba più scuri, pozze riflettenti che svaniscono in circa un minuto; non influisce sul gameplay. Vento variabile sull'erba, foglie dagli alberi (0/40/90 particelle) e polline (0/40/100).
