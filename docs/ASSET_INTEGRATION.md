# Integrazione degli asset: cosa è usato dove (livello 1)

Stato a novembre 2026. Percorsi in `assets/models/custom/` salvo diversa indicazione. Il livello è `scenes/levels/level1/level1.tscn`.

| Area (nodi) | Asset | Note |
|---|---|---|
| Terreno (`TerrenoFotorealistico`, `StradaTerra`, `ErbaFotorealistica`) | `terreno/terreno_pianura(.mobile).gltf`, `erba_ciuffi.gltf`, `campo/terreno/colle_acropoli_modulare` (Acropoli) | PhotoTerrain, DirtRoad, GrassCards; budget 3k/10k/30k ciuffi |
| Accampamento (`Scenario/Accampamento`) | `campo/tende` (tela_rami, pelli), `sketchfab/tende/tenda_gajk_pelli_rami` (Tenda2/3), `campo/fuochi/focolare_calderone` (Falo), `campo/giare_panche` (pithoi, panche), Poly Haven secchi, sgabelli, scale, barili, casse, forziere | tenda Gajk solo a high |
| Difese (`PaliSezione*`, `Staccionata*`, `Cheval*`) | `campo/difese` (palizzata_sezione, cheval_de_frise) | Palizzata/Recinto/Barricata sono GridProp senza modello (collisioni) |
| Mura e Troia (`MuraDiTroia`) | `campo/mura` (mura_tratto, torre_quadrata, porta_due_battenti), Quaternius Citta e tempio (tinta ocra) | TorreDiGuardia/Vedetta usano torre_quadrata |
| Rovine | `campo/rovine` (colonna_dorica_intera/spezzata, rocchio, arco_pietra_rovina) | collisioni sul fusto/piloni |
| Luci | `campo/luci` (torcia_su_palo, braciere_bronzo_acceso/spento) | fiamme emissive, luci da LevelAtmosphere |
| Pianura di battaglia | `campo/carri`, `campo/cavalli` (baio, grigio, sellato, caduto), `campo/personaggi` (auriga, guerriero, masse opliti), `campo/macchine` (balista, catapulta) | non bloccanti, min_quality, lazy |
| Navi | `campo/navi/nave_scura_occhio`, `barca_a_remi` (FerrySystem), `navi/trireme` (low) | nomi Nave1/2 e Drakkar1/2 usati da FerrySystem |
| Personaggi | `personaggi/*.glb` (ulisse_oplita, oplita_acheo, ufficiale_troiano, arciere_troiano), `campo/equipaggiamento` (hoplon, elmo su Ulisse via UnitGear) | CharacterModel |
| Alberi e piante | Poly Haven (island_tree, fir_sapling, fir_tree, othonna, heliophila, felci, fiori, rocce) | CC0; FoliageTint |
| HUD | `assets/ui/hud/` (ritratti, icone, pergamena) | LevelHud |

## Modelli senza licenza verificata (prototipo)
Sketchfab senza metadati: `sketchfab/architettura/*`, `sketchfab/rovine/rovina_arco_muschio`, `testa_statua_barbuta`, `animali/cavallo_lowpoly_marrone`, `fuori_epoca/nave_asiatica_torri` (non usati nel livello 1). Quaternius/Kenney/altri in `assets/models/troia/` (crediti in `assets/models/troia/CREDITS.md`).

## Crediti CC-BY
- "Tent" di Gajk.Mv (Sketchfab, CC-BY-4.0): `sketchfab/tende/`; testo in `sketchfab/CREDITI.md`.
- Pentecontera (Thales) e rilievo del tempio (ScanForgeFAB): CC-BY-4.0, nello stesso file CREDITI.md (non nel livello 1).
Da mostrare nei crediti in-game quando ci saranno.

## Qualità
Low usa mesh mobile del terreno, modelli leggeri, niente comparse; medium + cavalli, masse, polvere; high tutto. VRAM misurata: 163 / 197 / 272 MB.

## Personaggi nuovi (`personaggi_nuovi/`, 13 + LOD)
Ulisse (ulisse.tscn), alleati Elpenore/Euriloco (soldato_acheo.tscn + UnitFactory, alternati), troiani 1 e 2 (soldato_troiano.tscn), arcieri troiani (arciere_mura/arciere_fuoco via IdleFigure). Comparse ferme del campo (`IdleFigure`, da qualità media, non bloccanti): Agamennone (-13.6, 7.2), Menelao (-11.7, 7.0), Polite (-15.7, 7.6), Filottete con elmo (-9.2, 15.2) e senza (-17.4, 8.2), Euribate (-8.4, 8.0), Perimede (-15, 15.2). A low/medium si usano i `_lod`; i ritratti HUD sono in `assets/ui/hud/` (tabella PORTRAITS in level_hud.gd).
