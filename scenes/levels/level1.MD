ODISSEA – Livello 1: L'ultima notte di Troia
La scelta comporta una precisazione narrativa: il racconto dell'Odissea inizia dopo la caduta di Troia. Quindi questo livello sarà un prologo ambientato alla fine della guerra, che introduce Ulisse e mostra gli eventi che precedono il suo viaggio di ritorno.

Non vogliamo riscrivere Omero: possiamo aggiungere missioni e combattimenti originali, purché non contraddicano gli eventi principali del poema.
1. Identità del livello
Elemento	Definizione
Nome	L'ultima notte di Troia
Protagonista	Ulisse
Ambientazione	Accampamento acheo, mura e strade di Troia
Periodo	Ultima notte della guerra
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