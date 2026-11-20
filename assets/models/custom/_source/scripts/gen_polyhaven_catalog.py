"""Genera le tabelle del catalogo Poly Haven (polyhaven/CATALOGO.md) dal report della conversione
(polyhaven/_report.jsonl) e dalla mappa uso/livello qui sotto.

Uso: python3 gen_polyhaven_catalog.py
"""
import json, os, re, glob

CUSTOM = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
PH = os.path.join(CUSTOM, "polyhaven")

# regex sul nome della variante -> (uso consigliato, livello, slug Poly Haven per il credito)
USE = [
    (r"^boulder_01$", "Masso isolato: margini del campo, accanto a rovine e muretti", "1, 2", "boulder_01"),
    (r"^namaqualand_boulder_02$", "Lastra di roccia bassa e larga: bordi del diorama, riva", "1, 2", "namaqualand_boulder_02"),
    (r"^namaqualand_boulder_03$", "Grande masso verticale: sperone, scogliera, quinta di cresta", "1, 2", "namaqualand_boulder_03"),
    (r"^namaqualand_cliff_02$", "Parete di roccia (20 m): cresta e scogliera nord-ovest, bordo del blocco", "2 (1 solo per la cresta)", "namaqualand_cliff_02"),
    (r"^coast_land_rocks_04$", "Piattaforma rocciosa piana sul bagnasciuga: base per il cantiere e per le onde", "2", "coast_land_rocks_04"),
    (r"^coast_rocks_05$", "Gruppo di scogli: scogliera, relitto spaccato tra gli scogli, battigia", "2", "coast_rocks_05"),
    (r"^dead_tree_trunk_02$", "Tronco morto: legni portati dal mare (8 mucchi), punto di raccolta legna", "2 (1 sulla cresta)", "dead_tree_trunk_02"),
    (r"^fern_02_", "Felce: sottobosco ai piedi di rovine, abeti dello sperone", "1, 2", "fern_02"),
    (r"^grass_medium_01_tiny", "Ciuffo minuscolo: riempimento fitto, MultiMesh (poche decine di triangoli)", "1, 2", "grass_medium_01"),
    (r"^grass_medium_01_(tall|small|mid)", "Ciuffo d'erba medio: manto del prato, MultiMesh", "1, 2", "grass_medium_01"),
    (r"^grass_medium_01_large", "Ciuffo grande: macchie d'erba alta, bordi di muri", "1, 2", "grass_medium_01"),
    (r"^grass_medium_02_", "Cespo d'erba: alternativa a grass_medium_01 per variare il prato", "1, 2", "grass_medium_02"),
    (r"^periwinkle_plant_", "Pervinca viola: accenti di colore tra le pietre (STYLE.md: fiori viola)", "1", "periwinkle_plant"),
    (r"^celandine_01_", "Celidonia gialla: accenti di colore nel prato", "1, 2", "celandine_01"),
    (r"^dandelion_01_", "Tarassaco: accenti gialli e bianchi nel prato", "1, 2", "dandelion_01"),
    (r"^flower_heliophila_", "Eliofila (fiore blu): accenti sulle dune e ai bordi", "2 (1)", "flower_heliophila"),
    (r"^othonna_cerarioides_", "Cespuglio a fiori gialli: macchia sulle dune e sulla cresta", "1, 2", "othonna_cerarioides"),
    (r"^searsia_lucida_", "Arbusto verde scuro: macchia, siepi naturali, riparo per Sinone tra le dune", "2, 1", "searsia_lucida"),
    (r"^fir_sapling_medium_", "Abete giovane (6-9 m): abeti dello sperone nord-ovest da abbattere (raccolta legna)", "2", "fir_sapling_medium"),
    (r"^fir_tree_01_c$", "Abete adulto (14,5 m): sperone nord-ovest, quinta alta ai margini", "2", "fir_tree_01"),
    (r"^island_tree_01_", "Alberello da primo piano (4,5 m): macchia vicino alle rovine", "1, 2", "island_tree_01"),
    (r"^island_tree_02_", "Alberello da primo piano (3,7 m): alternativa al precedente", "1, 2", "island_tree_02"),
    (r"^street_rat$", "Ratto: dettaglio di vita al campo, sotto le casse e vicino alle navi", "1, 2", "street_rat"),
    (r"^treasure_chest$", "Forziere: interazione/ricompensa (Interazione dell'immagine di Ulisse)", "1, 2", "treasure_chest"),
    (r"^wooden_barrels_01_barrel", "Botte: accampamento (immagine di riferimento), cantiere, navi", "1, 2", "wooden_barrels_01"),
    (r"^wooden_bucket_02$", "Secchio: cantiere, tracce da bagnare (livello 2, fase 3)", "2 (1)", "wooden_bucket_02"),
    (r"^wooden_crate_01$", "Cassa: accampamento e cantiere", "1, 2", "wooden_crate_01"),
    (r"^wooden_ladder_02$", "Scala a pioli: impalcatura del cavallo", "2", "wooden_ladder_02"),
    (r"^wooden_stool_02$", "Sgabello: dentro e davanti alle tende", "1, 2", "wooden_stool_02"),
    (r"^wooden_axe$", "Ascia: carpentieri di Epeo, abbattimento degli abeti", "2", "wooden_axe"),
    (r"^wooden_hammer_01$", "Martello di legno (mazzuolo): impalcatura e cantiere", "2", "wooden_hammer_01"),
    (r"^cross_pein_hammer$", "Martello da carpentiere: cantiere", "2", "cross_pein_hammer"),
    (r"^hand_plane_no4$", "Pialla: cantiere (la pialla romana esisteva, la forma è moderna)", "2", "hand_plane_no4"),
    (r"^handsaw_wood$", "Sega a mano: smontare le navi e tagliare il legno", "2", "handsaw_wood"),
    (r"^rusted_spade_01$", "Vanga arrugginita: rastrellare le tracce, scavare", "2", "rusted_spade_01"),
    (r"^picke_dirty_01$", "Piccone: scavo del fossato, rocce", "1, 2", "picke_dirty_01"),
    (r"^vintage_hand_drill$", "Trapano a manovella: cantiere (forma moderna, usare con parsimonia)", "2", "vintage_hand_drill"),
    (r"^fish_knife$", "Coltello da pesce: FUORI EPOCA (moderno); solo per scene di mercato, meglio non usarlo", "-", "fish_knife"),
    (r"^flathead_screwdriver$", "Cacciavite: FUORI EPOCA, da non usare", "-", "flathead_screwdriver"),
    (r"^machete$", "Machete: FUORI EPOCA, da non usare", "-", "machete"),
    (r"^kite_shield$", "Scudo a goccia medievale: FUORI EPOCA, da non usare per Achei e Troiani", "-", "kite_shield"),
    (r"^dutch_ship_medium$", "Nave olandese del Seicento: FUORI EPOCA; al massimo sagoma lontanissima, sconsigliata", "-", "dutch_ship_medium"),
    (r"^modular_wooden_pier_planks$", "Tavolato del molo (impalcato)", "1, 2", "modular_wooden_pier"),
    (r"^modular_wooden_pier_poles$", "Pali del molo (fondazioni)", "1, 2", "modular_wooden_pier"),
    (r"^modular_wooden_pier_section_0[1-5]$", "Sezione modulare di molo (testata, curva, tratto, scala): banchina delle navi", "1, 2", "modular_wooden_pier"),
    (r"^modular_fort_01_tower", "Torre rotonda: candidata per una torre di Troia", "1, 2", "modular_fort_01"),
    (r"^modular_fort_01_wall_thin_gate", "Porta del forte: candidata per la porta di Troia (livello 2: percorso del cavallo)", "2, 1", "modular_fort_01"),
    (r"^modular_fort_01_", "Pezzo modulare di mura in pietra: mura di Troia, breccia nelle mura (livello 2)", "1, 2", "modular_fort_01"),
]

TIER = [(1000, "massa (MultiMesh)"), (5000, "standard"), (10**9, "primo piano")]


def tier(t):
    return next(n for lim, n in TIER if t <= lim)


rows = [json.loads(l) for l in open(os.path.join(PH, "_report.jsonl"))]
by_cat = {}
seen = set()
for r in rows:
    if "variant" not in r or r["file"] in seen:
        continue
    seen.add(r["file"])
    cat = r["file"].split("/")[1]
    by_cat.setdefault(cat, []).append(r)

order = ["rocce", "vegetazione", "alberi", "fauna", "oggetti", "attrezzi", "architettura", "attrezzi_fuori_epoca", "navi_fuori_epoca"]
titles = {
    "rocce": "Rocce, scogliere e tronchi", "vegetazione": "Erba, fiori e cespugli (alpha cards, MASK)",
    "alberi": "Alberi", "fauna": "Fauna", "oggetti": "Oggetti da campo e cantiere",
    "attrezzi": "Attrezzi (cantiere del cavallo)", "architettura": "Architettura modulare",
    "attrezzi_fuori_epoca": "Fuori epoca: attrezzi e scudo moderni/medievali (non usare per Troia)",
    "navi_fuori_epoca": "Fuori epoca: nave del Seicento (non usare per Troia)",
}
out = []
for cat in order:
    if cat not in by_cat:
        continue
    out.append(f"### {titles[cat]}\n")
    out.append("| File | Uso consigliato | Livello | Dimensioni L×P×A (m) | Triangoli | Tex | Budget |")
    out.append("|---|---|---|---|---|---|---|")
    for r in sorted(by_cat[cat], key=lambda r: r["file"]):
        v = r["variant"]
        uso, liv, slug = next(((u, l, s) for rx, u, l, s in USE if re.search(rx, v)), ("da definire", "-", ""))
        x, y, z = r["dim"]
        rel = r["file"].split("polyhaven/", 1)[-1]
        out.append(f"| [`{rel}`]({rel}) | {uso} | {liv} | {x:g} × {y:g} × {z:g} | {format(r['tris'], ',').replace(',', '.')} | {r['tex']} | {tier(r['tris'])} |")
    out.append("")
HEAD = """# Catalogo modelli Poly Haven

Elenco generato da `_source/scripts/gen_polyhaven_catalog.py` (dati: `_report.jsonl`). Dimensioni in metri **larghezza (X) x profondità (Z in Godot) x altezza (Y in Godot)**, origine al centro della base. Triangoli dopo la riduzione.
Budget: **massa** = fino a 1.000 triangoli, adatta al MultiMesh; **standard** = fino a 5.000; **primo piano** = oltre 5.000, pochi esemplari alla volta (su mobile e web meglio ridurre).
Tutti i modelli sono CC0 (Poly Haven): [polyhaven.com/license](https://polyhaven.com/license). Pagina originale di ogni modello: `https://polyhaven.com/a/<nome>`.

"""
open(os.path.join(PH, "CATALOGO.md"), "w").write(HEAD + "\n".join(out))
print("OK", sum(len(v) for v in by_cat.values()), "modelli,", {k: len(v) for k, v in by_cat.items()})
