ODISSEA – Livello 1: Verso le mura di Troia
La scelta comporta una precisazione narrativa: il racconto dell'Odissea inizia dopo la caduta di Troia. Quindi questo livello sarà un prologo ambientato alla fine della guerra, che introduce Ulisse e mostra gli eventi che precedono il suo viaggio di ritorno.

Non vogliamo riscrivere Omero: possiamo aggiungere missioni e combattimenti originali, purché non contraddicano gli eventi principali del poema.
1. Identità del livello
Elemento	Definizione
Nome	Verso le mura di Troia
Protagonista	Ulisse
Ambientazione	Accampamento acheo, mura e strade di Troia
Periodo	Gli ultimi giorni dell'assedio
Durata	15–20 minuti
Visuale	Isometrica 2.5D
Combattimento	Action RPG in tempo reale
Obiettivo	Preparare e portare a termine lo stratagemma del cavallo

Premessa narrativa

Dopo dieci anni di assedio, gli Achei sono pronti a porre fine alla guerra. Ulisse, ideatore dello stratagemma del cavallo, deve assicurarsi che il piano riesca.

La missione si svolge durante le ore che precedono l'ingresso del cavallo a Troia e la caduta della città.

2. Mappa e struttura delle missioni
Immagino una mappa compatta, suddivisa in cinque aree collegate. Non un mondo aperto: un livello lineare con piccoli spazi esplorabili e percorsi alternativi.
AREA 1 – L'accampamento acheo
Obiettivo: ricevere gli ordini e prepararsi alla missione.
- Dialogo con Agamennone.
- Incontro con alcuni soldati achei.
- Recupero di spada e scudo.
- Tutorial di movimento, interazione e attacco.
- Partenza verso le mura di Troia.
Qui il giocatore impara a controllare Ulisse.


AREA 2 – La pianura di Troia
Obiettivo: raggiungere il punto d'accesso alla città.
- Resti del campo di battaglia.
- Pattuglia troiana.
- Primo combattimento reale.
- Introduzione alla schivata e alla parata.
- Possibilità di raccogliere materiali e oggetti.
Il giocatore affronta i primi nemici senza ancora incontrare un boss.


AREA 3 – Le mura di Troia
Obiettivo: individuare e neutralizzare le difese che potrebbero compromettere il piano.
- Percorso tra rovine e postazioni militari.
- Due tipologie di nemici: soldato e arciere.
- Piccola sezione di esplorazione.
- Incontro con un ufficiale troiano.
L'ufficiale è un mini-boss originale, non un personaggio canonico dell'Iliade.


AREA 4 – Il cavallo di Troia
Obiettivo: completare lo stratagemma.
- Sequenza narrativa con Sinone e il cavallo.
- Ulisse si nasconde all'interno del cavallo con gli altri guerrieri.
- Breve sequenza giocabile di attesa e tensione.
- Il cavallo viene introdotto dentro le mura.
Niente combattimento in questa fase: il silenzio e la tensione sono parte dell'esperienza.


AREA 5 – La caduta di Troia
Obiettivo: raggiungere il punto di raccolta degli Achei.
- Apertura delle porte dall'interno.
- Sequenza di combattimento contro pochi difensori.
- Strade illuminate dagli incendi.
- Ricongiungimento con i compagni.
- Sequenza cinematografica della caduta della città.
Il livello termina con Ulisse che guarda Troia in fiamme.


3. Sistema di combattimento
Il combattimento deve essere immediato, leggibile e basato sull'abilità del giocatore.
Controlli iniziali
Comando	Azione
WASD	Movimento
Mouse sinistro	Attacco
Mouse destro	Parata
Spazio	Schivata
E	Interazione
Q	Abilità speciale

Armi iniziali
- Spada: bilanciata, attacchi veloci.
- Scudo: parata e riduzione dei danni.
- Lancia: arma secondaria da introdurre successivamente.
Non aggiungerei subito un sistema complesso di combo, stamina e crafting. Prima dobbiamo verificare che movimento e combattimento siano divertenti.
4. Personaggi










Ulisse

Protagonista. Intelligente, strategico, abile nel combattimento. Il personaggio controllato dal giocatore.












Agamennone

Comandante degli Achei. Introduce la missione e il contesto della guerra.












Sinone

Figura centrale nell'inganno del cavallo. Secondo la tradizione, convince i Troiani a introdurlo in città.












Ettore

Non compare come personaggio vivo: è già morto prima degli eventi finali della guerra. Può essere evocato nei dialoghi e nei riferimenti alla guerra.



5. Progressione e ricompense
Il primo livello deve introdurre anche il sistema di progressione, senza sovraccaricarlo.
Ricompensa	Utilizzo
Esperienza	Sbloccare abilità
Dracme	Valuta del gioco
Materiali	Potenziamenti futuri
Equipaggiamento	Miglioramento di armi e armature

Al termine del livello Ulisse sblocca una prima abilità: Astuzia, che consente di individuare temporaneamente i nemici vicini e i punti di interesse.
7. Specifiche tecniche per Godot
Per evitare di costruire subito un progetto troppo grande, dividerei il lavoro in moduli.
Componente	Implementazione
Engine	Godot 4
Rendering	3D low-poly + pixel art
Camera	Isometrica prospettica fissa
Mappa	Scene modulari 3D
Personaggi	Sprite 2D o modelli 3D pixelizzati
Movimento	CharacterBody3D
Nemici	State Machine
Combattimento	Hitbox / Hurtbox
Dialoghi	Sistema a eventi
Salvataggi	JSON o Resource

1. Cosa sviluppare per primo
Non realizzerei tutte e cinque le aree contemporaneamente. Costruirei un vertical slice: una porzione giocabile che rappresenti la qualità finale del progetto.
Primo prototipo: la pianura di Troia


9. Gameplay del prototipo: "Resistere fino alla ritirata"
Questa sezione descrive il primo livello giocabile (la pianura di Troia). Non cambia la storia: il cavallo di Troia resta nei livelli successivi.

Obiettivo
Sopravvivere fino al segnale di ritirata mentre si salvano i compagni feriti sparsi sulla pianura, portandoli all'accampamento.

Tempo e ondate
- Il livello dura 180 secondi (parametro `duration`). Un conto alla rovescia in alto mostra il tempo alla ritirata.
- Dopo 8 secondi parte la prima ondata, poi una nuova ondata ogni 25 secondi.
- Ogni ondata è più forte della precedente: più soldati troiani (da 2, +1 a ondata, fino a 8), più vita, più danno, passo più veloce.
- Anche le difese sulle mura si intensificano: a ogni ondata arcieri, baliste e catapulte tirano più spesso (+12%) e fanno più danno (+8%).
- Non ci sono più di 14 troiani vivi insieme, per tenere leggero il gioco su mobile.

Feriti
- 6 compagni feriti giacciono a terra in punti diversi della pianura, alcuni vicino alle mura e quindi sotto il fuoco.
- Quando Ulisse arriva accanto a un ferito, questo si rialza e lo segue. Va scortato fino all'area dell'accampamento: lì è in salvo.
- Un ferito può essere colpito da frecce e dai soldati troiani. Se muore è perso.
- I troiani attaccano l'acheo più vicino, quindi anche i feriti a terra: tenere i nemici lontani fa parte del gioco.

Combattimento
- Ulisse attacca con il tasto sinistro del mouse: colpisce il nemico nella casella davanti (o accanto) con la spada.
- I soldati achei alleati combattono da soli i troiani che arrivano accanto.

Punteggio
- 100 punti per ogni ferito salvato, 10 per ogni troiano sconfitto, 200 di bonus se si salvano tutti.
- Ritirata ordinata se si salva almeno metà dei feriti, altrimenti ritirata disperata.

Finale (sconfitta narrativa)
Allo scadere del tempo suonano i corni della ritirata: gli Achei non espugnano Troia con le armi. Compare una schermata con esito, feriti salvati, troiani sconfitti, ondate superate e punteggio; il pulsante conduce al livello 2, dove Ulisse cercherà un'altra strada.

Parametri
Tutti i valori si regolano da `data/level1/rules.tres` (resource LevelRules): durata, ritmo delle ondate, numero e forza dei troiani, intensificazione delle difese, numero e posizione dei feriti, area dell'accampamento e punteggio.

