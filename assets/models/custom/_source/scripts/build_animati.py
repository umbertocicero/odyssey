"""Importa i personaggi animati (Meshy + rig Mixamo, ~/Scaricati/MODELLI_ANIMATI) in assets/models/custom/personaggi_animati/<nome>/<nome>.gltf.

- Rinomina i file Meshy con i nomi dei personaggi originali (abbinamento certo: la texture base color coincide con quella di personaggi_nuovi/<nome>/Image_0.jpg).
- Texture a 1024 px, JPEG (stessa pipeline di personaggi_nuovi), scala 0,8 (altezza ~1,4-1,5 m come le figurine di personaggi_nuovi).
- Agamennone: lo scudo e' fuso nella mesh unica e i pesi Mixamo lo spargevano su coscia/pollice/avambraccio, quindi nelle animazioni si piegava.
  Qui i suoi vertici (disco intorno a mixamorig:LeftForeArm, escluso il braccio e il mantello) vengono legati al 100% all'osso LeftForeArm: scudo rigido.
Uso (un Blender alla volta): blender -b --factory-startup -P build_animati.py -- <cartella_sorgente> <cartella_destinazione> [nome ...]
"""
import bpy, sys, os, numpy as np

MAP = {  # nome gioco -> file Meshy (prefisso del nome file, con eventuale ' (1)')
    "agamennone": "agamennone (1).glb",
    "perimede": "Meshy_AI_Bronze_Sentinel_of_Perimede_20261127_animated_mixamo_All_animation.glb",
    "troiano_1": "Meshy_AI_Deiphobus_Trojan_Warrior_20261127_animated_mixamo_All_animation (1).glb",
    "troiano_2": "Meshy_AI_Deiphobus_Trojan_Warrior_20261127_animated_mixamo_All_animation.glb",
    "euribate": "Meshy_AI_Eurybates_Character_Study_20261127_animated_mixamo_All_animation.glb",
    "euriloco": "Meshy_AI_Eurylochus_Character_Concept_20261127_animated_mixamo_All_animation.glb",
    "menelao": "Meshy_AI_Menelaus_Character_Concept_Art_20261127_animated_mixamo_All_animation.glb",
    "troiano_arciere": "Meshy_AI_Pandarus_the_Trojan_Archer_20261127_animated_mixamo_All_animation.glb",
    "elpenore": "Meshy_AI_The_One_Eyed_Legionary_20261127_animated_mixamo_All_animation.glb",
    "troiano_capitano": "Meshy_AI_Trojan_Captain_Concept_Sheet_20261127_animated_mixamo_All_animation.glb",
    "troiano_fanteria": "Meshy_AI_Trojan_Foot_Soldier_Concept_Art_20261127_animated_mixamo_All_animation.glb",
    "filotete_no_elmo": "Meshy_AI_Wounded_Hoplite_Character_Study_20261127_animated_mixamo_All_animation (1).glb",
    "filotete": "Meshy_AI_Wounded_Hoplite_Character_Study_20261127_animated_mixamo_All_animation.glb",
    "polite": "Meshy_AI_Wounded_Legionary_Concept_Art_20261127_animated_mixamo_All_animation.glb",
    "ulisse": "ulisse.glb",
}
SCALE = 0.8
TEX = 1024


def fix_shield(ob, arm):
    me = ob.data
    b = arm.data.bones["mixamorig:LeftForeArm"]
    h = np.array(b.head_local); t = np.array(b.tail_local); u = (t - h) / np.linalg.norm(t - h)
    co = np.array([v.co[:] for v in me.vertices]); p = co - h
    r = np.linalg.norm(p - np.outer(p @ u, u), axis=1)
    names = {g.index: g.name for g in ob.vertex_groups}
    fa = ob.vertex_groups["mixamorig:LeftForeArm"]
    dom = []; wf = np.zeros(len(co))
    for v in me.vertices:
        w = {}
        for g in v.groups:
            w[names[g.group]] = w.get(names[g.group], 0) + g.weight
            if g.group == fa.index: wf[v.index] = g.weight
        dom.append(max(w, key=w.get) if w else "")
    dom = np.array(dom)
    ok = np.isin(dom, ["mixamorig:LeftForeArm", "mixamorig:LeftUpLeg", "mixamorig:LeftHandThumb3",
                       "mixamorig:LeftHandThumb1", "mixamorig:LeftHandPinky3", "mixamorig:LeftHand"])
    # disco dello scudo (centro ~(0.36, 0, 0.835), raggio ~0.33, piano YZ) nella posa di bind
    inreg = (co[:, 0] > 0.19) & (np.hypot(co[:, 1], co[:, 2] - 0.835) < 0.34) & (co[:, 2] > 0.5) & (co[:, 2] < 1.17)
    sel = np.where(inreg & (r > 0.115) & ok & ((wf > 0.3) | (co[:, 0] > 0.28)))[0]
    for i in sel:
        for gi in [g.group for g in me.vertices[i].groups]:
            ob.vertex_groups[gi].remove([int(i)])
        fa.add([int(i)], 1.0, "REPLACE")
    print("scudo rigido:", len(sel), "vertici")


def main():
    a = sys.argv[sys.argv.index("--") + 1:]
    src, dst, only = a[0], a[1], a[2:]
    for name, fn in MAP.items():
        if only and name not in only: continue
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=os.path.join(src, fn))
        ob = max([o for o in bpy.data.objects if o.type == "MESH"], key=lambda o: len(o.data.vertices))
        arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
        for o in [o for o in bpy.data.objects if o.type == "MESH" and o is not ob]: bpy.data.objects.remove(o)  # forme dei bone widget
        for im in bpy.data.images:
            if im.size[0] > TEX: im.scale(TEX, TEX)
        arm.scale = (SCALE,) * 3
        arm.animation_data.action = None
        out = os.path.join(dst, name); os.makedirs(out, exist_ok=True)
        bpy.ops.export_scene.gltf(filepath=os.path.join(out, name + ".gltf"), export_format="GLTF_SEPARATE", export_animations=True,
                                  export_skins=True, export_image_format="JPEG", export_jpeg_quality=88, export_yup=True)
        print("OK", name, [x.name for x in bpy.data.actions])


main()
