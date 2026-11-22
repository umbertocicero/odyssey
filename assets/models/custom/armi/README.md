# Armi separate (xiphos, lancia, arco)

Per attaccarle a `hand.R` del rig a 17 ossa dei personaggi (`personaggi_nuovi/`). Originali, modellate per il progetto con `_source/scripts/build_armi.py` (un Blender alla volta) e texture procedurali PBR (`pbr_tex.py armi_set`).

| Arma | File (normale / leggera) | Tri | Lunghezza | Note |
|---|---|---|---|---|
| Xiphos (spada corta) | `xiphos/xiphos.gltf` / `xiphos_lod.gltf` | 1264 / 368 | 0,49 m | lama a foglia di bronzo con nervatura, parafilo, impugnatura di cuoio con cordino, pomolo |
| Lancia | `lancia/lancia.gltf` / `lancia_lod.gltf` | 1220 / 316 | 1,84 m | asta di frassino, presa di cuoio, cuspide a foglia di bronzo con cannone, puntale con spuntone |
| Arco con corda | `arco/arco.gltf` / `arco_lod.gltf` | 1244 / 412 | 0,80 m | arco ricurvo scuro, riser in cuoio, puntali di bronzo, corda di lino con serving centrale (non incoccata) |

- Scala dei personaggi (0,8 x reale). **Origine = centro della presa**: basta metterle sotto un `BoneAttachment3D` su `hand.R`.
- Asse lungo = +Y in Godot (punta/estremita' superiore verso l'alto), lama e arco nel piano X-Y; nell'arco la corda sta verso -Z (il lato del tiratore). Se la presa nella mano non e' allineata, ruotare il nodo figlio (tipico: -90/90 gradi attorno a X o Z).
- 1 materiale per parte (bronzo `metallicFactor 0,92`), texture 512 JPEG, VRAM compressed + mipmap (`tune_imports.py armi`); le due versioni dello stesso oggetto condividono `textures/`.
