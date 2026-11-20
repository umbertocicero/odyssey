# ODISSEA – Livello 2: Il dono del mare

Il livello 1 porta Ulisse fino alle mura di Troia e ne indebolisce le difese. Il livello 2 racconta lo stratagemma vero e proprio: gli Achei costruiscono il cavallo con il legno delle navi e della costa, lo lasciano sulla spiaggia come se l'avesse portato il mare, ci si chiudono dentro e aspettano che siano i Troiani stessi a trascinarlo dentro le mura.

Come nel livello 1, non riscriviamo Omero. La trama segue la tradizione: Epeo costruisce il cavallo (*Odissea* VIII), gli Achei bruciano le tende e salpano, Sinone resta indietro, i Troiani discutono sul da farsi e alla fine portano il cavallo in città. Quello che non è nei poemi è indicato come **Proposta**.

> **Nota sulle fonti.** Alcuni episodi famosi (la lancia di Laocoonte, il cavallo che si ferma quattro volte sulla soglia, la breccia nelle mura) vengono dall'*Eneide* di Virgilio, non da Omero. Non contraddicono l'*Odissea*, ma sono segnalati perché la scelta di usarli resta a Umberto.

## 1. Identità del livello

| Elemento | Definizione |
|---|---|
| Nome | Il dono del mare |
| Protagonista | Ulisse |
| Ambientazione | Spiaggia achea, navi tirate in secca, pianura e mura di Troia |
| Periodo | Gli ultimi giorni della guerra: dalla costruzione del cavallo alla sua entrata in città |
| Durata | 20–25 minuti |
| Visuale | Isometrica 2.5D, camera fissa |
| Gameplay | Raccolta e costruzione, poi furtività e tensione. Pochissimo combattimento. |
| Obiettivo | Costruire il cavallo, nascondercisi dentro e farlo portare dai Troiani tra le mura senza essere scoperti |

### Premessa narrativa

Dopo dieci anni di assedio le navi achee cadono a pezzi: il legno è marcito e le funi sono allentate (lo dice già Agamennone nell'*Iliade*, II 135). Ulisse trasforma questo problema nell'arma finale. Le navi più vecchie vengono smontate e, insieme al legno che il mare ha portato sulla costa, diventano un enorme cavallo.

Il cavallo deve sembrare arrivato dal mare, un dono degli dèi o un'offerta lasciata dagli Achei in fuga. Poi i guerrieri scelti ci entrano, la flotta brucia l'accampamento e salpa, e sulla spiaggia resta solo il cavallo. Il resto lo faranno i Troiani.

## 2. Mappa e struttura delle missioni

### Il diorama

Un **diorama nuovo**, pensato per questo livello, nello stesso formato del livello 1: un blocco quadrato di 52×52 m con la griglia giocabile di 40×40 caselle da 1 m. Il mare occupa i lati ovest e sud, in una baia a L; le mura di Troia stanno a nord, con la porta spostata verso il centro. Così il cavallo ha un percorso diritto dalla spiaggia alla porta e il giocatore lo vede attraversare tutto il diorama.

Il livello 1 e il livello 2 non condividono la scena: stessa pianura e stesse mura come aspetto, ma il layout è rifatto (si può riusare lo script di generazione del livello 1 con una mappa diversa). Le difese distrutte nel livello 1 qui sono già in rovina.

Schema indicativo (nord in alto, ogni carattere vale circa 4 caselle):

```
x→   0   4   8   12  16  20  24  28  32  36
y 0  ~   R   M   M   M   P   M   M   M   M     M = mura   P = porta
y 4  ~   R   a   .   .   s   .   .   .   c     R = scogliera con relitto
y 8  ~   r   a   .   x   .   .   x   .   c     a = abeti sullo sperone   c = cresta
y12  ~   .   .   .   .   .   .   .   .   c     x = carri da guerra distrutti
y16  ~   .   .   .   F   v   F   .   .   .     F = fossato acheo   v = varco
y20  ~   b   n   .   F   v   F   K   K   .     n = navi tirate in secca
y24  ~   b   n   .   .   .   .   K   T   T     K = palizzata   T = tende dell'accampamento
y28  ~   b   n   d   d   H   .   .   .   .     d = dune   H = cantiere del cavallo
y32  ~   b   b   b   b   b   b   b   b   .     b = spiaggia   . = pianura
y36  ~   ~   ~   ~   ~   ~   ~   ~   ~   ~     ~ = mare
```

- **Il percorso del cavallo** va da H (cantiere) a nord, per il varco `v` del fossato, fino alla porta `P`: una linea quasi dritta di circa 28 caselle, larga 3 per l'impronta del cavallo.
- **Il cantiere** sta sul bagnasciuga a sud, nascosto dalle dune e dalle navi: dalle mura non si vede (si usa la linea di vista già esistente, `DioramaGrid.has_line_of_fire`). Quando le navi salpano e le dune restano, il cavallo diventa visibile dalla pianura.
- **Le navi** sono allineate lungo la spiaggia ovest. Tre sono vecchie e si smontano, le altre si preparano a salpare.
- **Il fossato e la palizzata** dell'accampamento sono quelli costruiti dagli Achei nell'*Iliade*. Il fossato ha un solo varco `v`, che servirà ai Troiani per trascinare il cavallo.
- **Le mura** sono lontane: dal cantiere si è fuori dalla gittata delle difese, come all'accampamento del livello 1.

### Le cinque fasi del livello

#### FASE 1 – Gli ordini e la raccolta della legna

Obiettivo: raccogliere abbastanza legno per il cavallo.

- Consiglio nella tenda di Agamennone: Ulisse espone il piano, Epeo mostra il progetto.
- Il giocatore riceve i suoi soldati (i sopravvissuti del livello 1, più rinforzi: i dieci nominati nel cavallo si uniscono a loro) e i carpentieri di Epeo.
- Raccolta nei punti segnati sotto, trasporto al cantiere.
- **Astuzia** (sbloccata alla fine del livello 1) rivela per qualche secondo i punti di raccolta e gli esploratori troiani.

**Punti di raccolta della legna** (in "fasci"; un fascio è quello che porta un uomo):

| Punto | Dove | Legna | Come si raccoglie | Rischio |
|---|---|---|---|---|
| Tre navi vecchie | Spiaggia ovest | 3 × 10 = 30 | Ulisse e 2 soldati smontano la nave (circa 10 s). Resta un mucchio sul posto. | Nessuno |
| Legni portati dal mare | Lungo tutta la spiaggia | 8 mucchi × 1 = 8 | Si raccolgono con E | Nessuno |
| Relitto sulla scogliera | Scogliera nord-ovest | 6 | Si arriva saltando tra gli scogli (rilievo livelli 1–2) | Le onde: una casella bagnata fa cadere il fascio in mare |
| Palizzata vecchia | Bordo dell'accampamento | 6 | Si smonta un tratto; apre una scorciatoia | Nessuno |
| Carri da guerra distrutti | Pianura | 3 × 2 = 6 | Si smontano | Esploratori troiani |
| Abeti dello sperone | Sperone nord-ovest | 4 × 2 = 8 | Si abbattono | Vicini alle mura: esploratori, a difficoltà alta anche frecce |
| **Totale disponibile** | | **64** | | |

Servono 50 fasci per il cavallo. I 14 in più sono il margine per gli imprevisti della fase 2 (l'incursione notturna può distruggerne una parte). **Nota canonica:** nell'*Eneide* il cavallo è fatto di abete; l'idea delle navi e della costa è di Umberto e non contraddice niente.

**Trasporto:**
- Ulisse porta un fascio alla volta. Mentre porta non può attaccare né parare e si muove un po' più lento.
- Un soldato a cui si dà l'ordine "porta al cantiere" fa la spola da solo tra un mucchio e il cantiere.
- Il carro (modello già scaricato) porta 5 fasci e va spinto da 2 soldati.

#### FASE 2 – La costruzione del cavallo

Obiettivo: costruire il cavallo sul bagnasciuga, a fasi.

| Fase | Legna | Cosa si vede | Note |
|---|---|---|---|
| 1. Base | 10 | Una piattaforma di travi sulla sabbia | Sbloccata subito |
| 2. Zampe | 8 | Quattro zampe e l'impalcatura | |
| 3. Ventre | 16 | Il corpo cavo con le costole delle navi | Il pezzo più lungo da costruire |
| 4. Collo e testa | 10 | Il collo alto, la testa che guarda la città | |
| 5. Rifinitura e botola | 6 | Coda, criniera, la botola nascosta nel fianco, la dedica | Dopo questa fase il cavallo è finito |

- Ogni fase si avvia portando la legna e poi interagendo con Epeo. I carpentieri lavorano da soli; Ulisse e i soldati possono aiutare per accorciare i tempi.
- La dedica incisa, secondo la tradizione: "Per il ritorno in patria, gli Achei offrono ad Atena".

**Proposta: l'incursione notturna.** Durante la fase 3 un piccolo gruppo di incursori troiani con le torce scende dalla pianura per bruciare le navi, senza sapere del cavallo. È l'unico vero combattimento del livello (nessun mini-boss, solo incursori comuni): va respinto prima che il fuoco arrivi al cantiere o ai mucchi di legna (le caselle in fiamme usano `burning_cell.gd`). Se un incursore vede il cantiere e scappa verso le mura, la Credibilità del cavallo scende (vedi fase 3).

**Esploratori troiani.** Per tutta la fase 1 e 2 un paio di esploratori girano sulla cresta e nella pianura. Non attaccano: guardano. Se uno di loro ha la linea di vista sul cantiere per qualche secondo, scappa verso la porta. Il giocatore può fermarlo (combattimento) o evitarlo (restare fuori vista, lavorare quando passa oltre).

#### FASE 3 – Il dono del mare

Obiettivo: far sembrare che il cavallo sia arrivato dal mare, poi far partire la flotta.

- **Cancellare le tracce:** smontare l'impalcatura e riportare gli attrezzi alle navi, rastrellare le orme e i solchi nella sabbia (caselle segnate), coprire la base con alghe e conchiglie, bagnare il legno.
- Ogni traccia lasciata abbassa la **Credibilità** del cavallo (da 0 a 100). Più è bassa, più i Troiani saranno sospettosi nella fase 4.
- **Sinone:** dialogo con Ulisse, che gli fa ripetere la storia da raccontare ai Troiani. Sinone resta nascosto tra le dune (tradizione).
- **Bruciare l'accampamento:** Ulisse accende i fuochi sulle tende (canonico: gli Achei bruciano le tende prima di partire). La flotta prende il largo verso Tenedo.

#### FASE 4 – Dentro il cavallo

Obiettivo: chiudersi nel cavallo e resistere fino all'arrivo dei Troiani, senza farsi scoprire.

**Chi entra e come si dispone.** Il ventre del cavallo è un piccolo diorama nel diorama: si vede in sezione, come un modellino tagliato, e ha una griglia interna di 2×5 posti.

- Entrano 10 guerrieri, tutti con un nome della tradizione. Le fonti antiche danno numeri molto diversi (da una dozzina a cinquanta): 10 è una scelta di gioco, i nomi sono quelli degli elenchi antichi.

| Guerriero | Fonte | Tratto |
|---|---|---|
| Ulisse | Omero | Il giocatore. Calma gli altri |
| Menelao | *Odissea* IV | Calmo, il più anziano |
| Diomede | *Odissea* IV | Calmo, saldo |
| Anticlo | *Odissea* IV | Nervoso: vorrebbe rispondere alle voci, e infatti lo si deve trattenere nel livello 3 |
| Neottolemo | *Odissea* XI | Nervoso e impaziente, il più giovane. Nei poemi è l'unico a non piangere né tremare nel cavallo |
| Epeo | *Odissea* VIII, XI | Pesante: ha costruito il cavallo, conosce ogni scricchiolio. Fa da guida ai rumori |
| Stenelo | Tradizione | Calmo, compagno di Diomede |
| Toante | Tradizione | Pesante, forte, goffo |
| Macaone | Tradizione | Il guaritore: può curare un ferito (ripristina la vita dal livello 1) |
| Merione | Tradizione | Nervoso, soffre il caldo |

Menelao e i guerrieri dell'*Odissea* IV sono quelli che Elena minaccia nel livello 3.
- Prima di chiudere la botola il giocatore sceglie dove mettere ciascuno. Ogni posto ha un difetto: vicino alla botola si sente di più fuori, sopra le zampe il legno scricchiola, in fondo fa più caldo e i Nervi salgono più in fretta.
- Ogni guerriero ha un tratto: calmo, nervoso, pesante, ferito (dal livello 1). Mettere un nervoso accanto a un calmo fa salire meno i suoi Nervi.

**I tre indicatori:**

| Indicatore | Cosa misura | Come sale | Come scende |
|---|---|---|---|
| Nervi (per guerriero) | La paura di ognuno | Tempo, caldo, eventi, colpi sul legno | Ulisse gli si mette accanto e lo calma (E) |
| Rumore | Quanto rumore fa il cavallo in quel momento | Un guerriero con Nervi al massimo, armi che urtano, movimenti di Ulisse | Da solo, in pochi secondi, se tutti stanno fermi |
| Sospetto dei Troiani | Quanto i Troiani là fuori dubitano | Rumore mentre un troiano è vicino, Credibilità bassa | Lentamente, quando nessuno sente niente |

Se il Sospetto arriva a 100 il cavallo è scoperto.

**L'attesa: cosa succede fuori.** La camera resta fissa sul diorama. Il cavallo si vede in sezione: dentro i guerrieri, fuori i Troiani. Con Astuzia (Q) Ulisse "sente" la posizione dei Troiani anche quando sono nascosti dietro il cavallo.

1. **L'alba.** La spiaggia è vuota, il fumo dell'accampamento sale ancora. Lunga attesa con eventi minori.
2. **Le prime pattuglie.** Pochi soldati troiani escono dalla porta, attraversano il fossato, girano intorno al cavallo, lo toccano, guardano sotto la base. Ogni volta che uno è adiacente, il Rumore pesa di più.
3. **La folla e la discussione.** Arriva la gente di Troia. I Troiani discutono se bruciarlo, gettarlo dalle rupi o tenerlo come offerta: è canonico (*Odissea* VIII 505–510). Durante la discussione le voci fuori fanno salire i Nervi.
4. **La lancia di Laocoonte** (*Eneide*). Una lancia si pianta nel fianco del cavallo, accanto a un guerriero: il legno risuona. Il giocatore ha un attimo per tenerlo fermo (azione a tempo). Se il Rumore è basso, il colpo suona vuoto e passa.
5. **Sinone.** I pastori trascinano Sinone davanti a Priamo; lui racconta la sua storia. Se la Credibilità è alta, il Sospetto scende molto.

**Eventi casuali** (estratti durante l'attesa, più frequenti a difficoltà alta):

| Evento | Effetto |
|---|---|
| Un gabbiano si posa sulla testa del cavallo | Un troiano si avvicina a guardare |
| Un'onda colpisce la base | Il legno scricchiola: piccolo Rumore |
| Crampo di un guerriero | I suoi Nervi salgono; bisogna raggiungerlo |
| Uno scudo scivola | Rumore forte se nessuno lo ferma in tempo |
| Un bambino troiano bussa sul legno | Il Sospetto sale solo se qualcuno reagisce |
| Il sole scalda il legno | I Nervi salgono più in fretta nei posti in fondo |
| Un guerriero vuole uscire | Ulisse deve trattenerlo prima che apra la botola |

**Scelte del giocatore** (piccole decisioni con conseguenze):

- Chi calmare per primo quando due guerrieri sono al limite.
- Durante la lancia di Laocoonte, spostare il guerriero colpito (rischio di rumore) o lasciarlo dov'è (rischio che gridi).
- Usare Astuzia ora o tenerla per dopo (si ricarica lentamente).

**Controlli dentro il cavallo:**

| Comando | Azione |
|---|---|
| WASD | Ulisse si sposta di un posto nella griglia interna (fa un po' di rumore) |
| E | Calmare il guerriero accanto, fermare un oggetto che cade, tappare la bocca |
| Mouse destro (tenuto) | "Fermi tutti": per qualche secondo il Rumore non sale, ma i Nervi sì |
| Q | Astuzia: mostra i Troiani intorno al cavallo |

Su mobile: tocco sul posto per spostarsi, tocco sul guerriero per calmarlo, pressione lunga per "Fermi tutti".

#### FASE 5 – Il trasporto tra le mura

Obiettivo: resistere fino all'interno di Troia.

- I Troiani mettono rulli sotto la base e funi al collo e trascinano il cavallo. La camera segue il cavallo attraverso il varco del fossato, la pianura (i resti del livello 1) e la rampa fino alla porta.
- Il giocatore non guida niente: gestisce l'interno. Ogni sobbalzo (una pietra, la rampa, il fossato) fa sbattere le armi e alza i Nervi.
- **Le quattro soste sulla soglia** (*Eneide*): sulla porta il cavallo si incaglia quattro volte e ogni volta le armi dentro risuonano. Sono quattro momenti di tensione in cui bisogna tenere fermi tutti. Per farlo passare, i Troiani allargano la porta abbattendo un tratto di mura (*Eneide*).
- Il cavallo arriva nella piazza davanti al tempio sull'acropoli. Festa, canti, poi la notte.

**Finale.** Troia si addormenta. Dentro il cavallo è buio e silenzio. Ulisse sussurra: "Ora aspettiamo Sinone." Schermo nero. Il livello 3 si apre con **Elena** che, di notte, gira intorno al cavallo e chiama i capi imitando le voci delle loro mogli (*Odissea* IV 271–289); poi Sinone toglie i chiavistelli.

## 3. Nemici e minacce

In questo livello i Troiani non sono quasi mai avversari da combattere: sono occhi e orecchie.

| Chi | Fase | Comportamento | Si combatte? |
|---|---|---|---|
| Esploratori troiani | 1–2 | Girano su cresta e pianura; se vedono il cantiere scappano verso la porta | Sì, si possono fermare |
| Incursori con le torce (**Proposta**) | 2 | Attaccano le navi di notte, appiccano fuoco | Sì, unico combattimento vero |
| Difese sulle mura | 1–2 | Come nel livello 1, ma il cantiere è fuori gittata. Tirano solo su chi va agli abeti dello sperone (difficoltà alta). Quelle distrutte nel livello 1 restano distrutte (**Proposta**) | No, si evitano |
| Pattuglie che ispezionano | 4 | Girano intorno al cavallo, ascoltano, toccano | No |
| Folla, Laocoonte, Priamo | 4–5 | Eventi a copione | No |

**Sulla "tregua".** Nella tradizione non c'è una tregua: i Troiani credono che gli Achei se ne siano andati davvero. Per questo nelle fasi 4 e 5 nessuno tira e nessuno combatte. Prima della partenza della flotta, invece, la guerra è ancora in corso e le difese sulle mura funzionano come nel livello 1.

## 4. Condizioni di vittoria e sconfitta

**Vittoria:** il cavallo arriva sull'acropoli e Troia si addormenta senza che il Sospetto sia mai arrivato a 100.

**Sconfitta:**
- Il Sospetto arriva a 100 nelle fasi 4 o 5: i Troiani aprono il cavallo (breve scena) e si riparte dall'inizio della fase in corso.
- Il fuoco degli incursori distrugge il cantiere (fase 2): si riparte dall'inizio della fase 2.
- Se cade Ulisse (fasi 1–2) si riparte dal cantiere, come nel livello 1 si ripartiva dall'accampamento. Se i soldati cadono, arrivano rinforzi dall'accampamento dopo qualche secondo: non si resta mai senza braccia per portare legna.

**Valutazione finale (Proposta):** Credibilità del cavallo, Rumore massimo raggiunto, soldati del livello 1 sopravvissuti, legna avanzata. Serve per esperienza e dracme.

## 5. Difficoltà

| Parametro | Facile | Normale | Difficile |
|---|---|---|---|
| Legna richiesta | 40 | 50 | 56 |
| Esploratori | 1 | 2 | 3, più veloci |
| Incursori | 3 | 5 | 7 + frecce dalle mura sugli abeti |
| Salita dei Nervi | lenta | media | rapida |
| Eventi casuali durante l'attesa | pochi | medi | molti |
| Finestra per l'azione a tempo (lancia, soste sulla soglia) | 1,5 s | 1 s | 0,6 s |
| Calo del Sospetto per Credibilità alta | forte | medio | debole |

## 6. Personaggi

| Personaggio | Ruolo | Fonte |
|---|---|---|
| Ulisse | Protagonista, ideatore dello stratagemma | Omero |
| Agamennone | Approva il piano, guida la flotta verso Tenedo | Omero |
| Epeo | Costruttore del cavallo, guida il cantiere | *Odissea* VIII |
| Sinone | Resta indietro e inganna i Troiani | Tradizione, *Eneide* |
| Menelao, Diomede, Anticlo, Stenelo, Toante, Macaone, Merione | Nel cavallo con Ulisse (vedi la tabella della fase 4) | *Odissea* IV, tradizione |
| Neottolemo | Nel cavallo, il più impaziente di combattere | *Odissea* XI |
| Laocoonte | Lancia l'asta contro il cavallo | *Eneide* |
| Priamo | Ascolta Sinone e decide di portare il cavallo in città | *Eneide* |
| Elena | Compare solo all'inizio del livello 3 | *Odissea* IV |

Ettore resta solo evocato nei dialoghi, come nel livello 1.

## 7. Testi e dialoghi

> **Regola:** tutti i testi che il giocatore vede o sente nel gioco sono in **inglese**, anche se questo documento è in italiano. Le traduzioni qui sotto sono le stringhe di riferimento da implementare. Per i nomi degli indicatori in gioco si usano **Nerves**, **Noise** e **Suspicion**.

- **Council in the tent.** Agamennone: "Ten years, Odysseus. The ships are rotting and the men want to go home." Ulisse: "Then let the ships carry us into Troy."
- **Epeo**, at each phase: "The belly must be hollow, but it must not sound hollow. Bring me solid beams, not rotten planks."
- **Soldiers** during gathering: short lines about home, the sea, and how tired they are of the war.
- **Sinone** in phase 3: Odysseus makes him repeat the story; Sinone stumbles on a word and Odysseus corrects him.
- **Inside the horse:** whispers between the warriors, one line per trait (the nervous one, the calm one, Neoptolemus impatient). Odysseus: "Breathe. The wood hears everything."
- **Trojan voices outside:** "Burn it!", "It is an offering to Athena!", "Throw it off the cliffs!", "Do not trust the Greeks, not even when they bring gifts" (Laocoön, *Aeneid*).
- **On-screen text:** short phase objectives, the inscription on the horse, the final message. Example labels: "Gather wood", "Build the horse", "Cover the tracks", "Get inside", "Wait", "Haul to the walls".
- **Hold still** (control hint, mouse right held): "Hold still".
- **Defeat:** one line per cause. "A scout reached the walls." / "The wood spoke."
- **Final line:** "Now we wait for Sinon." (Odysseus, whisper, then black screen.)

## 8. Oggetti e modelli

### Già disponibili in `assets/models/`

| Uso | Modello |
|---|---|
| Navi in secca | `custom/navi/trireme.glb` (navi intere e in partenza) |
| Accampamento | `custom/accampamento/` (tende, carro coperto, rastrelliera), `troia/accampamento/` (tende, falò, torce, palizzate, torri di guardia) |
| Legna e attrezzi da campo | `troia/oggetti/` (casse, barili, sacchi, anfore, carro, carro rotto) |
| Carri da guerra distrutti | `troia/oggetti/broken_cart_*`, `wagon_*` |
| Abeti, rocce, cespugli | `troia/vegetazione/` (cipressi, alberi, rocce) |
| Mura, porta, tempio | `troia/architettura/` |
| Soldati e stendardi | `custom/personaggi/`, `custom/stendardi/` |

Le navi `troia/navi/` (drakkar e barca vichinga) hanno uno stile nordico che stona: meglio usarle solo come relitto lontano o non usarle.

### Da creare in Blender

| Oggetto | Note |
|---|---|
| Cavallo in 5 stadi | Base, zampe, ventre, collo e testa, finito. Stesso modello con i pezzi che si aggiungono. Impronta 3×5 caselle, alto circa 6 m |
| Cavallo in sezione | Interno cavo con le costole delle navi, la griglia 2×5 dei posti, la botola |
| Trireme smontata | 3 stadi: intera, a metà, solo chiglia |
| Relitto sulla scogliera | Scafo spaccato tra gli scogli |
| Legni spiaggiati e fascio di legna | Mucchi piccoli; il fascio si vede in spalla a chi lo porta |
| Impalcatura e attrezzi | Scale, cavalletti, asce, funi, rastrello |
| Alghe, conchiglie, sabbia smossa | Per le tracce da cancellare |
| Rulli e funi dei Troiani | Per il trasporto |
| Breccia nelle mura | Variante del tratto di mura vicino alla porta |
| Personaggi | Epeo, Sinone, Menelao, Diomede, Anticlo, Neottolemo, Stenelo, Toante, Macaone, Merione, Laocoonte, Priamo, popolani troiani, esploratore, incursore con torcia |

## 9. Specifiche tecniche per Godot

| Componente | Implementazione |
|---|---|
| Diorama | Scena nuova `level2.tscn` con lo stesso script di layout del livello 1 e una mappa diversa (mare su due lati) |
| Griglia, rilievo, oggetti | `DioramaGrid`, `TerrainRelief`, `GridProp`, `PropScatter` già esistenti |
| Vista degli esploratori | `DioramaGrid.has_line_of_fire` già esistente |
| Fuoco degli incursori | `burning_cell.gd` già esistente |
| Difese sulle mura | `WallShooter` con `auto_fire` spento dopo la partenza della flotta |
| Punti di legna | Nuovo: `WoodSource` (quantità, tempo, quanti uomini servono) |
| Trasporto | Nuovo: stato "porta fascio" su `GridUnit`, ordine "porta al cantiere" per gli alleati |
| Cantiere | Nuovo: `ConstructionSite` con le fasi in una risorsa (come `AttackProfile`), scambio di mesh per stadio |
| Tracce | Nuovo: `TraceMarker` sulle caselle, calcolo della Credibilità |
| Interno del cavallo | Nuovo: `HorseInterior`, una piccola `DioramaGrid` 2×5 con i guerrieri |
| Nervi, Rumore, Sospetto | Nuovo: nodo del livello con i tre valori e i parametri di difficoltà in una risorsa |
| Eventi | Nuovo: `EventDirector`, eventi a copione e casuali con pesi per difficoltà |
| Trasporto dei Troiani | Percorso a copione (`Path3D`) con soste e sobbalzi |

**Test da aggiungere:** che la legna disponibile basti sempre a ogni difficoltà anche dopo l'incursione; che il cantiere non sia visibile dalle mura; che il percorso del cavallo (impronta 3×5) dalla spiaggia alla porta sia libero; che il Sospetto non possa arrivare a 100 se il giocatore non fa errori.

## 10. Cosa sviluppare per primo

**Proposta:** come vertical slice, la fase 4 (l'attesa dentro il cavallo) con le quattro soste sulla soglia. È la parte più nuova e quella che decide se il livello funziona. La raccolta della legna e la costruzione riusano in gran parte quello che c'è già (griglia, alleati, oggetti) e si possono fare dopo.
