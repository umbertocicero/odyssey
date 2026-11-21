# Campo acheo: modelli originali (Età del bronzo)

Modelli **creati da zero in Blender** per il progetto, secondo `STYLE.md` sezione 5 (tende di tela e pelli con rami e pellicce, fuochi con calderoni su pietre, pithoi, panche, palizzate di pali appuntiti; palette terrosa smorzata, niente colori da circo).

**Licenza: originali, modellati per il progetto (proprietà di Umberto).** Nessun asset di terzi: geometria in `_source/scripts/okit2.py` e `build_campo1.py`, texture PBR procedurali in `_source/scripts/pbr_tex.py` (generate con Pillow, nessuna fonte esterna).

## Convenzioni

- `.gltf` + `.bin` + `textures/` in `campo/<categoria>/<modello>/`. Metri reali, origine al centro della base (y = 0), fronte verso +Y in Blender (-Z in Godot).
- Materiali PBR (base color JPEG, roughness e normal OpenGL, 1024 px; 512 per bronzo e carbone). `metallicFactor` esplicito a 0 (`fix_gltf_materials.py`); niente profilo ICC (`compress_textures.py`). Import in Godot verificato: 0 `valid=false`.
- **Foglie e fiamma**: `alphaMode MASK` con doppia faccia (cutoff 0,5 foglie, 0,3 fiamma); la fiamma e le braci hanno anche texture **emissiva**. Per un fuoco vivo servono comunque una `OmniLight3D` calda e particelle di scintille/fumo in Godot.
- **Tela e pelli**: doppia faccia (lastre sottili). Colori già smorzati; usare `GridProp.tint/desaturate` solo se serve.

## Import in Godot: VRAM compressed e mipmap

Le texture di `campo/` hanno nei `.import` `compress/mode=2` (VRAM compressed) e `mipmaps/generate=true` (le normal map anche `compress/normal_map=1`; le carte con alpha `process/fix_alpha_border=true`). Senza questo Godot le importa non compresse e senza mipmap: VRAM più che doppia e moiré sulle tende. Lo imposta `_source/scripts/tune_imports.py`, che legge i `.gltf` per sapere a cosa serve ogni file, e viene chiamato in automatico da `compress_textures.py campo` (con `NO_TUNE=1` si salta). **Dopo ogni nuovo gruppo**: `compress_textures.py campo` e `fix_gltf_materials.py`; lo stesso `tune_imports.py polyhaven` o `sketchfab` vale per le altre cartelle, se serve.

## Texture condivise e limite a 512

Le texture identiche tra modelli (corteccia, corda, assi, tela, pelle, argilla, bronzo...) sono **un solo file** in `campo/_tex/`, e i `.gltf` ci puntano con un percorso relativo (`../../_tex/bark_c.jpg`): Godot le carica una volta sola (in origine erano 363 copie per 81 contenuti diversi). Le texture uniche di un modello restano nella sua cartella `textures/`. Le texture usate solo da props secondari (panche, pithoi piccoli, torce, bracieri; in `polyhaven/` scale, sgabelli, secchi, casse, barili, attrezzi) e le famiglie corteccia, corda, zoccolo, cenere, carbone, bronzo e ferro hanno `process/size_limit=512` nel `.import`. Se un modello nuovo usa una texture già esistente, `compress_textures.py campo` la condivide da solo (lancia `share_textures.py` e poi `tune_imports.py`).

## Gruppo 1: tende, fuoco, giare, panche, difese

| Modello | Misure L × P × A (m) | Triangoli | Uso |
|---|---|---|---|
| [`tende/tenda_tela_rami`](campo/tende/tenda_tela_rami/tenda_tela_rami.gltf) | 5,9 × 6,0 × 3,2 con tiranti e picchetti (corpo ≈ 4,0 × 5,6) | 3.772 | tenda grande di tela e pelli con rami frondosi sul tetto, pali e due pellicce sul colmo; lembi d'ingresso legati |
| [`tende/tenda_pelli`](campo/tende/tenda_pelli/tenda_pelli.gltf) | 5,4 × 5,6 × 2,9 (corpo ≈ 3,5 × 4,9) | 3.672 | variante più piccola, per lo più di pelli, con più pellicce e meno rami |
| [`fuochi/focolare_calderone`](campo/fuochi/focolare_calderone/focolare_calderone.gltf) | 1,7 × 1,7 × 1,8 | 2.248 | anello di 9 pietre, tizzoni e braci, tre fiamme (carte emissive), treppiede di pali con catene e calderone di bronzo |
| [`giare_panche/pithos_grande`](campo/giare_panche/pithos_grande/pithos_grande.gltf) | 1,1 × 1,1 × 1,5 | 1.492 | pithos con bande dipinte, cordoni e quattro anse |
| [`giare_panche/pithos_medio_coperchio`](campo/giare_panche/pithos_medio_coperchio/pithos_medio_coperchio.gltf) | 0,7 × 0,7 × 1,1 | 1.536 | pithos più piccolo con coperchio di pietra appoggiato di traverso |
| [`giare_panche/panca_assi`](campo/giare_panche/panca_assi/panca_assi.gltf) | 2,2 × 0,5 × 0,55 | 124 | panca di assi su gambe divaricate |
| [`giare_panche/panca_ceppi`](campo/giare_panche/panca_ceppi/panca_ceppi.gltf) | 2,0 × 0,36 × 0,5 | 100 | panca di assi su due ceppi |
| [`difese/palizzata_sezione`](campo/difese/palizzata_sezione/palizzata_sezione.gltf) | 2,9 × 0,3 × 2,7 | 2.344 | tratto di palizzata: 12 pali appuntiti legati con travi e cordami; si affianca ripetendo ogni 2,76 m |
| [`difese/palizzata_angolo`](campo/difese/palizzata_angolo/palizzata_angolo.gltf) | 1,7 × 1,7 × 2,7 | 496 | angolo a 90° della palizzata |
| [`difese/barricata_cheval_de_frise`](campo/difese/barricata_cheval_de_frise/barricata_cheval_de_frise.gltf) | 2,6 × 1,9 × 2,5 | 1.516 | trave su cavalletti a X con 27 pali affilati incrociati (cheval-de-frise), legati con corde |

Budget: tutto sotto 4.000 triangoli. Per il MultiMesh: panche, pithoi, palizzate sono adatti a ripetizioni; le tende e il focolare a pochi esemplari.

Anteprima: `../_previews/campo1.png`.

## Gruppo 2: mura, torre, porta, piattaforma di guardia

Blocchi di calcare ocra veri (ogni blocco è una scatola con sporgenza e dimensioni diverse, corsi sfalsati), merli con cappello, zoccolo e cornice del camminamento. Pezzi modulari: l'altezza del corpo delle mura è 3,4 m, con i merli 4,5 m.

| Modello | Misure L × P × A (m) | Triangoli | Uso |
|---|---|---|---|
| [`mura/mura_tratto`](mura/mura_tratto/mura_tratto.gltf) | 4,1 × 1,2 × 4,5 | 1.056 | tratto di mura con 3 merli; si affianca ripetendo ogni 4,0 m |
| [`mura/torre_quadrata`](mura/torre_quadrata/torre_quadrata.gltf) | 4,5 × 4,5 × 8,2 | 3.936 | torre quadrata (base 3,6 m) con cantonali, feritoie, porticina di legno e coronamento aggettante merlato su tutti i lati |
| [`mura/porta_due_battenti`](mura/porta_due_battenti/porta_due_battenti.gltf) | 5,5 × 1,7 × 5,0 | 2.808 | tratto di mura con porta a due battenti di assi borchiate con fasce e anelli di ferro, cornice di pietra (stipiti a blocchi, architrave, cornice) e merli; apertura 2,4 × 3,0 m, battenti chiusi |
| [`mura/piattaforma_guardia_tegole`](mura/piattaforma_guardia_tegole/piattaforma_guardia_tegole.gltf) | 3,3 × 3,8 × 4,5 | 1.412 | piattaforma di guardia su quattro pali, a 2,1 m, con scala a pioli sul lato -Y, parapetti su tre lati e tetto a quattro falde di tegole di terracotta (doppia faccia) |

Anteprima: `../_previews/campo2.png`. **Fronte** di porta, torre e mura verso +Y in Blender (-Z in Godot); la scala della piattaforma sul lato -Y.

## Gruppo 3: cavalli e carro da guerra

I cavalli sono costruiti per sezioni lungo la spina dorsale (corpo e collo in un'unica forma continua, testa, quattro zampe articolate con ginocchio e garretto, masse di spalla, avambraccio e coscia, zoccoli, orecchie, occhi), con criniera e coda a ciocche (carte con alpha, `MASK`) e mantello di pelo corto con lucentezza. **Resa credibile ma stilizzata, non fotografica**: per un cavallo veramente realistico servirebbero scultura e bake da alta risoluzione, non ancora fatti.

| Modello | Misure L × P × A (m) | Triangoli | Uso |
|---|---|---|---|
| [`cavalli/cavallo_baio`](cavalli/cavallo_baio/cavallo_baio.gltf) | 0,6 × 2,9 × 2,05 (garrese 1,5 m) | 4.852 | cavallo baio con zampe e crini scuri; fronte verso +Y |
| [`cavalli/cavallo_grigio`](cavalli/cavallo_grigio/cavallo_grigio.gltf) | 0,6 × 2,9 × 2,05 | 4.852 | stessa forma, mantello grigio chiaro e crini chiari |
| [`carri/carro_da_guerra`](carri/carro_da_guerra/carro_da_guerra.gltf) | 1,6 × 3,0 × 1,3 | 2.516 | carro miceneo leggero: pianale di assi, fianco di cuoio con corrimano semicircolare, due ruote a quattro razze con cerchione e fascia di bronzo, asse di ferro, timone e giogo con anelli di bronzo; pronto per due cavalli (giogo a 1,0 m di larghezza) |

Anteprima: `../_previews/campo3.png`. I cavalli sono statici (nessuno scheletro né animazioni): per un'animazione di camminata servirebbe un rig, non incluso.

## Gruppo 4: equipaggiamento dell'oplita

| Modello | Misure L × P × A (m) | Triangoli | Uso |
|---|---|---|---|
| [`equipaggiamento/elmo_corinzio`](equipaggiamento/elmo_corinzio/elmo_corinzio.gltf) | 0,38 × 0,56 × 0,67 (cresta compresa) | 3.780 | elmo corinzio di bronzo a campana svasata con apertura del volto a T (occhi e bocca, paranaso al centro), sopracciglio sporgente, cresta di crine nero con fascia di bronzo che segue la calotta; doppia faccia (lamiera sottile) |
| [`equipaggiamento/corazza_bronzo`](equipaggiamento/corazza_bronzo/corazza_bronzo.gltf) | 0,42 × 0,34 × 0,74 | 1.912 | corazza di bronzo a torso con pettorali, linee degli addominali, volute a spirale sullo sterno e sulle spalle, spalline di cuoio e gonnellino di 16 pteruges di cuoio |
| [`equipaggiamento/hoplon_tridente`](equipaggiamento/hoplon_tridente/hoplon_tridente.gltf) | 0,93 × 0,19 × 0,93 | 5.188 | scudo hoplon Ø 0,9 m ammaccato (11 ammaccature vere nella geometria), campo rosso scuro con tridente dorato e bordo di bronzo; sul retro cuoio con bracciale e maniglia di corda |
| [`equipaggiamento/hoplon_chevron`](equipaggiamento/hoplon_chevron/hoplon_chevron.gltf) | 0,93 × 0,18 × 0,93 | 5.188 | stesso scudo con cinque chevron neri su bronzo e umbone dipinto |

**Onestà sulla qualità:** gli scudi sono i pezzi più riusciti (ammaccature, simboli leggibili, bronzo scrostato); **l'elmo e la corazza sono più semplici**: forme riconoscibili ma non rifinite (l'apertura del volto ha i bordi a gradini, la corazza è un torso liscio con rilievi aggiunti). Per un risultato da primo piano servirebbero scultura e bake. Scudi in piedi sul bordo, faccia verso +Y; elmo e corazza poggiati sulla base. Anteprima: `../_previews/campo4.png`.

## Gruppo 5: navi e vele

| Modello | Misure L × P × A (m) | Triangoli | Uso |
|---|---|---|---|
| [`navi/nave_scura_occhio`](navi/nave_scura_occhio/nave_scura_occhio.gltf) | 8,3 × 15,4 × 9,2 (con remi e timoni) | 4.948 | nave da guerra a remi di legno scuro catramato, fascia dipinta di ocra rossa lungo il capodibanda, poppa alta con aplustre, rostro di bronzo, **occhio dipinto** su entrambe le fiancate di prua (carta con alpha), 26 remi, due timoni, 13 panche, albero con vela quadra, imbrogli e sartiame |
| [`navi/vela_quadra_sartiame`](navi/vela_quadra_sartiame/vela_quadra_sartiame.gltf) | 6,5 × 3,1 × 9,0 | 1.288 | vela quadra di lino con teli cuciti e toppe su pennone e albero, imbrogli, ralinghe e quattro sartie a picchetti; per navi tirate in secca, relitti e cantieri (livello 2) |
| [`navi/barca_a_remi`](navi/barca_a_remi/barca_a_remi.gltf) | 4,7 × 5,9 × 1,4 | 1.208 | barca aperta di assi con fascia dipinta, tre panche, due remi nelle scalmiere, piccolo occhio dipinto a prua |

Stile dell'epoca: la forma è quella di una nave greca dell'Età del bronzo (fianchi bassi, poppa alta curva, rostro, vela quadra, nessuna sovrastruttura medievale). Le dimensioni sono a scala diorama: la nave è lunga 13 m (una vera pentecontera ne misura circa 35). **Fronte verso +Y**; scafo e albero poggiano sulla base (chiglia a z = 0), da affondare nell'acqua o da puntellare in secca. Anteprima: `../_previews/campo5.png`.

## Gruppo 6: colonne doriche in rovina (livello 1)

Colonna **dorica arcaica in calcare ocra**, dello stesso materiale delle mura (`limestone`, 1.024 px, `metallicFactor` 0). Fusto con **20 scanalature a spigolo vivo**, leggera rastremazione (raggio 0,43 m in basso, 0,31 m in alto) ed entasi, tre anelli sotto l'echino, **echino convesso** e **abaco quadrato** (0,98 m); base a due gradini. Proporzioni da colonne doriche arcaiche (circa 4,7 diametri di altezza).

| Modello | Misure L × P × A (m) | Triangoli | Uso |
|---|---|---|---|
| [`rovine/colonna_dorica_intera`](rovine/colonna_dorica_intera/colonna_dorica_intera.gltf) | 1,4 × 1,4 × 4,3 | 2.120 | colonna intera in piedi (portici, accessi, piazza davanti al tempio, livello 2) |
| [`rovine/colonna_dorica_spezzata`](rovine/colonna_dorica_spezzata/colonna_dorica_spezzata.gltf) | 4,7 × 3,2 × 2,5 | 2.600 | fusto spezzato a circa 2 m con bordo irregolare sulla base, tre rocchi a terra e il capitello caduto di lato |
| [`rovine/rocchio_colonna_caduto`](rovine/rocchio_colonna_caduto/rocchio_colonna_caduto.gltf) | 1,8 × 1,7 × 0,9 | 1.120 | rocchio caduto di 1,15 m con un frammento accanto, da sparpagliare nelle rovine |

Sostituiscono come colonne di Troia i vecchi modelli di primitive (lastre, cono, sfera). Anteprima: `../_previews/campo6.png`. Origine al centro della base. La colonna corinzia di `sketchfab/` è servita solo come riferimento di proporzioni (troppo pesante, e di ordine più tardo).

## Gruppo 7: macchine, luci, arco e colle (pianura di battaglia, acropoli)

| Modello | Misure L × P × A (m) | Triangoli | Uso |
|---|---|---|---|
| [`macchine/balista_telaio`](macchine/balista_telaio/balista_telaio.gltf) | 1,9 × 2,4 × 1,5 | 1.548 | balista a torsione su telaio di legno con due ruote a raggi e puntello: guide con slitta, due fasci di corde con anelli di bronzo, bracci tesi, corda, dardo con punta di ferro, argano |
| [`macchine/catapulta_contrappeso`](macchine/catapulta_contrappeso/catapulta_contrappeso.gltf) | 2,1 × 4,5 × 3,6 | 2.160 | catapulta a braccio con contrappeso (cassa di assi con pietre), cavalletti a A, quattro ruote, fionda con sacca e pietra a terra; armata (braccio lungo abbassato) |
| [`luci/torcia_a_muro`](luci/torcia_a_muro/torcia_a_muro.gltf) | 0,3 × 0,6 × 1,1 | 242 | torcia accesa su staffa di ferro; il muro è sul piano y = 0 (origine alla base della piastra) |
| [`luci/torcia_su_palo`](luci/torcia_su_palo/torcia_su_palo.gltf) | 0,5 × 0,5 × 2,6 | 636 | torcia accesa su palo con tre piedi, coppa di ferro e gabbia di bacchette |
| [`luci/braciere_bronzo_acceso`](luci/braciere_bronzo_acceso/braciere_bronzo_acceso.gltf) | 0,9 × 0,8 × 1,7 | 1.880 | braciere di bronzo su treppiede con carbone a braci emissive e tre fiamme |
| [`luci/braciere_bronzo_spento`](luci/braciere_bronzo_spento/braciere_bronzo_spento.gltf) | 0,9 × 0,8 × 1,2 | 1.874 | lo stesso braciere con carbone e cenere spenti, senza fiamme né emissiva |
| [`rovine/arco_pietra_rovina`](rovine/arco_pietra_rovina/arco_pietra_rovina.gltf) | 5,3 × 2,1 × 4,8 | 1.008 | arco di calcare ocra spezzato: due piloni a blocchi, conci dell'arco dal lato destro e blocchi caduti; sostituisce l'arco romano |
| [`terreno/colle_acropoli_modulare`](terreno/colle_acropoli_modulare/colle_acropoli_modulare.gltf) | 30,0 × 20,0 × 5,2 | 3.672 | colle basso a bassa risoluzione per l'acropoli: terra ocra con sassolini e fili d'erba, fianchi più ripidi in calcare, sei affioramenti rocciosi; bordi a quota zero per posarlo sul diorama (modulare) |

Le **fiamme** sono carte `MASK` doppia faccia con emissiva: in Godot servono una `OmniLight3D` calda e particelle di scintille e fumo. Fiamme e carbone acceso si spengono usando `braciere_bronzo_spento`; le torce sono solo accese. Tutti sotto 5.000 triangoli (colle sotto 8.000), texture 1.024 px, `metallicFactor` 0, VRAM compressed con mipmap. Anteprima: `../_previews/campo7.png`.

## Gruppo 8: carro rotto, cavalli bardati, serventi (pianura di battaglia)

| Modello | Misure L × P × A (m) | Triangoli | Uso |
|---|---|---|---|
| [`carri/carro_rotto`](carri/carro_rotto/carro_rotto.gltf) | 3,9 × 3,9 × 1,2 | 1.820 | carro da guerra ribaltato sul lato destro con la ruota staccata e sdraiata, mezzo asse a terra, timone spezzato e giogo caduto, schegge sparse; un unico oggetto da posare nella pianura |
| [`cavalli/cavallo_sellato`](cavalli/cavallo_sellato/cavallo_sellato.gltf) | 0,6 × 2,9 × 2,05 | 6.304 | cavallo baio con gualdrappa di tela, sella a cuscino di cuoio con arcioni e alette, sottopancia, pettorale con medaglioni di bronzo, briglia con frontale, nasiera, morso e redini |
| [`cavalli/cavallo_caduto`](cavalli/cavallo_caduto/cavallo_caduto.gltf) | 2,0 × 3,1 × 1,3 | 4.972 | cavallo scuro riverso sul fianco con tre frecce piantate; le zampe restano rigide |
| [`personaggi/auriga_carro`](personaggi/auriga_carro/auriga_carro.gltf) | 0,8 × 1,7 × 1,8 | 1.540 | auriga statico con tunica, braccia in avanti con le redini e un pungolo |
| [`personaggi/guerriero_carro`](personaggi/guerriero_carro/guerriero_carro.gltf) | 1,0 × 0,6 × 2,2 | 1.946 | guerriero statico con elmo a cresta, lancia, scudo tondo di bronzo e mantello di lana |

**Qualità:** i serventi sono **figure statiche e rigide, stilizzate** (testa e volto appena accennati, nessuna barba né rig); servono come comparse, non da primo piano. Elmo, scudo e corazza sono già in `equipaggiamento/` e restano modelli a parte. Il cavallo sellato e quello caduto riusano la stessa geometria del cavallo (`cavallo_baio`); il sellato ha la sella a cuscino perché nell'Età del bronzo non esistevano selle rigide. Anteprima: `../_previews/campo8.png`.

## Gruppo 9: masse di opliti da lontano (pianura di battaglia)

Unità economiche pensate per il **MultiMesh**, da piazzare a decine di metri dalla camera (file dense che si perdono nella foschia). Ogni blocco ha **8 opliti in 2 file da 4** con elmo a cresta, corazza e gambali di bronzo, gonnellino di lana, mantello e **scudo tondo rosso, blu o marrone smorzato** (a rotazione nel blocco) e lancia. Texture a 512 px condivise con il resto del campo (`campo/_tex/`).

| Modello | Misure L × P × A (m) | Triangoli | Uso |
|---|---|---|---|
| [`personaggi/masse/opliti_schieramento`](personaggi/masse/opliti_schieramento/opliti_schieramento.gltf) | 3,6 × 1,6 × 2,4 | 2.032 | blocco fermo in schieramento: lance quasi verticali, scudi in avanti |
| [`personaggi/masse/opliti_marcia`](personaggi/masse/opliti_marcia/opliti_marcia.gltf) | 3,6 × 2,1 × 2,3 | 2.032 | blocco in marcia: passo alternato e lance inclinate in avanti di circa 26° |

Consigli: origine al centro della base, fronte verso +Y (-Z in Godot); affiancare i blocchi ogni 3,8 m in larghezza e ogni 2,2 m in profondità per una fila continua; ruotare e variare scala di ±5% per rompere la ripetizione; nessun dettaglio utile sotto i 25 m. **Qualità:** figure minimali (volto appena accennato), pensate solo per la distanza, non da primo piano. Anteprima: `../_previews/campo9.png`.

## Rigenerare

```bash
python3 _source/scripts/pbr_tex.py                              # texture procedurali -> _source/textures/pbr/
blender -b --factory-startup -P _source/scripts/build_campo1.py -- tenda_tela_rami   # un modello alla volta
blender -b --factory-startup -P _source/scripts/build_campo2.py -- porta_due_battenti
blender -b --factory-startup -P _source/scripts/build_campo3.py -- cavallo_baio
blender -b --factory-startup -P _source/scripts/build_campo4.py -- hoplon_tridente
blender -b --factory-startup -P _source/scripts/build_campo5.py -- nave_scura_occhio
blender -b --factory-startup -P _source/scripts/build_campo6.py -- colonna_dorica_intera
blender -b --factory-startup -P _source/scripts/build_campo7.py -- balista_telaio
blender -b --factory-startup -P _source/scripts/build_campo8.py -- carro_rotto
blender -b --factory-startup -P _source/scripts/build_campo9.py -- opliti_schieramento
python3 _source/scripts/compress_textures.py campo              # PNG opachi -> JPEG, senza ICC
python3 _source/scripts/fix_gltf_materials.py                   # metallicFactor esplicito
```
Un solo Blender alla volta (render in parallelo hanno bloccato il PC). Altri modelli futuri andranno nelle stesse cartelle di `campo/`.
