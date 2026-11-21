# Asset HUD (stile: bronzo opaco e pergamena, palette smorzata)

Tutti PNG con alpha. Generati da script: ritratti con `_source/scripts/hud_portraits.py` dalle foto in `ispirazione/characters/` (i primi render Blender non si usano piu'); icone e texture con `hud_assets.py` (Pillow, nessuna dipendenza esterna).

| File | Dimensione | Note |
|---|---|---|
| `portrait_*.png` (ulisse, euriloco, elpenore, euribate, filotete, polite, pandaro, deifobo, pandaro_arciere; alias dei nomi vecchi: oplita_acheo = euriloco, ufficiale_troiano = deifobo, arciere_troiano = pandaro_arciere) | 128x128 | volto ritagliato in tondo dalle schede personaggio in `ispirazione/characters/` (foto di riferimento), anello di bronzo, fuori dal cerchio trasparente. Script `hud_portraits.py` |
| `icon_spada_itaca.png`, `icon_hoplon.png`, `icon_lancia.png`, `icon_pozione.png`, `icon_borsa.png` | 64x64 | cornice rotonda di bronzo con borchie, fondo cuoio scuro, alpha fuori dal cerchio |
| `icon_*_2x.png` | 128x128 | stesse icone per schermi HiDPI |
| `tex_pergamena.png` | 512x512 | pergamena invecchiata, ripetibile (tileable) |
| `tex_bronzo_greca.png` | 512x512 | bronzo opaco con greca a meandro, ripetibile; motivo a celle da 64 px |

Uso in Godot: icone e ritratti in `TextureRect` / `TextureButton`; texture in `StyleBoxTexture` o `TextureRect` con `stretch_mode = Tile`. Per i ritratti e le icone tenere il filtro lineare con mipmap; `_anteprima.png` e' solo una scheda di confronto.
