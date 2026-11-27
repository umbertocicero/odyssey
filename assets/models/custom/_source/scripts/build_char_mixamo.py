"""Personaggi animati Meshy (rig Mixamo, ~/Scaricati/MODELLI_ANIMATI) -> rig a 17 ossa del gioco (personaggi_nuovi/).

Perche': il gioco (HumanoidAnims, duello in prima persona, UnitGear, remo, torcia, trasporto feriti...) legge le 17 ossa
hips/spine/neck/head/upperarm.L/... Le nuove mesh Meshy hanno uno skinning Mixamo molto migliore del vecchio skinning automatico,
ma sono in posa di corsa e con 66 ossa. Questo script:
  1. decima la mesh (~25k tri) mentre e' ancora nella posa originale (pesi Mixamo interpolati);
  2. porta lo scheletro Mixamo nella A-pose del gioco (direzioni di busto, braccia e gambe come build_char_hires.J) e "cuoce"
     la mesh in quella posa;
  3. misura i giunti dei 17 ossa sul personaggio stesso (niente piu' ossa fuori dalla mesh) e costruisce lo scheletro con
     build_char_hires.armature (stesse orientazioni, quindi le animazioni procedurali restano valide);
  4. collassa i pesi Mixamo sulle 17 ossa (dita -> mano, piede+punta -> piede, spalla 50% busto 50% braccio); i vertici legati
     alle ossa extra Meshy (mantello, ecc.) prendono un mix morbido delle ossa vicine come in build_char_hires.skin;
  5. Agamennone: lo scudo (fuso nella mesh) e' legato al 100% a forearm.R (rigido);
  6. animazioni procedurali di build_characters (idle_loop, walk_loop, attack, hit, death), texture 1K, export glTF e versione _lod
     (~6,5k tri, texture 512).
Uso (un Blender alla volta):
  blender -b --factory-startup -P build_char_mixamo.py -- <cartella_sorgente> [nome ...] [--debug]
Fronte verso -Y in Blender (= +Z in Godot, come i vecchi personaggi), ossa R a +X (= sinistra anatomica: scudo su forearm.R, arma su
hand.L), piedi a z=0, altezza ~1,52 m, origine tra le caviglie. Come i vecchi rig: osso del piede verso +Y e mano/pugno calibrati
sulle costanti di HandFist (le dita puntano avanti-giu', polso scelto in modo che il baricentro della mano sia a HandFist.CENTER).
"""
import bpy, sys, os, math, shutil
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_char_hires as BCH
import build_characters as BC

CUSTOM = BCH.CUSTOM
SCALE = BCH.SCALE
HEIGHT = 1.52
TRIS, TRIS_LOD = 25000, 6500
SHIELD_IN_MESH = set()   # personaggi con lo scudo fuso nella mesh (nessuno dopo la nuova mesh di Agamennone)

MAP = {  # nome gioco -> (file Meshy, attacco)
    "agamennone": ("agamennone (1).glb", "slash"),   # versione senza scudo nella mesh (27/11/2026, ore 14): lo scudo e' quello del gioco, su forearm.R
    "perimede": ("Meshy_AI_Bronze_Sentinel_of_Perimede_20261127_animated_mixamo_All_animation.glb", "slash"),
    "troiano_1": ("Meshy_AI_Deiphobus_Trojan_Warrior_20261127_animated_mixamo_All_animation (1).glb", "thrust"),
    "troiano_2": ("Meshy_AI_Deiphobus_Trojan_Warrior_20261127_animated_mixamo_All_animation.glb", "thrust"),
    "euribate": ("Meshy_AI_Eurybates_Character_Study_20261127_animated_mixamo_All_animation.glb", "slash"),
    "euriloco": ("Meshy_AI_Eurylochus_Character_Concept_20261127_animated_mixamo_All_animation.glb", "slash"),
    "menelao": ("Meshy_AI_Menelaus_Character_Concept_Art_20261127_animated_mixamo_All_animation.glb", "slash"),
    "troiano_arciere": ("Meshy_AI_Pandarus_the_Trojan_Archer_20261127_animated_mixamo_All_animation.glb", "shoot"),
    "elpenore": ("Meshy_AI_The_One_Eyed_Legionary_20261127_animated_mixamo_All_animation.glb", "slash"),
    "troiano_capitano": ("Meshy_AI_Trojan_Captain_Concept_Sheet_20261127_animated_mixamo_All_animation.glb", "slash"),
    "troiano_fanteria": ("Meshy_AI_Trojan_Foot_Soldier_Concept_Art_20261127_animated_mixamo_All_animation.glb", "thrust"),
    "filotete_no_elmo": ("Meshy_AI_Wounded_Hoplite_Character_Study_20261127_animated_mixamo_All_animation (1).glb", "slash"),
    "filotete": ("Meshy_AI_Wounded_Hoplite_Character_Study_20261127_animated_mixamo_All_animation.glb", "slash"),
    "polite": ("Meshy_AI_Wounded_Legionary_Concept_Art_20261127_animated_mixamo_All_animation.glb", "slash"),
    "ulisse": ("ulisse.glb", "slash"),
}

MX = "mixamorig:"

# direzioni A-pose nel riferimento FINALE (fronte +Y, destra anatomica +X), lato destro; il sinistro e' lo specchio in x.
# Ricavate da build_char_hires.J (spalla->gomito->polso->mano, anca->ginocchio->caviglia).
A_DIR = dict(
    shoulder=(1.0, 0.0, 0.12), arm=(0.11, 0, -0.18), fore=(0.16, 0, -0.17), hand=(0.07, 0, -0.15),
    thigh=(0.01, 0, -0.41), shin=(0.0, 0, -0.38), foot=(0.0, 1.0, -0.45), toe=(0.0, 1.0, -0.1),
)


def to_mx(v, side):
    """Direzione della tabella A_DIR (lato +X, fronte +Y) -> riferimento Mixamo (fronte -Y; 'Left' sta a +X)."""
    x, y, z = v
    if side == "Right": x = -x
    return Vector((x, -y, z)).normalized()


# ------------------------------------------------------------------ posa
def upd():
    bpy.context.view_layer.update()


def rot_about(pb, q_mat3, pivot):
    M = Matrix.Translation(pivot) @ q_mat3.to_4x4() @ Matrix.Translation(-pivot)
    pb.matrix = M @ pb.matrix
    upd()


def aim(arm, bone, to_pt, tgt):
    pb = arm.pose.bones[MX + bone]
    h = pb.head.copy()
    cur = (to_pt() - h).normalized()
    rot_about(pb, cur.rotation_difference(tgt.normalized()).to_matrix(), h)


def yaw_to(arm, bone, vec_fn, target_xy):
    pb = arm.pose.bones[MX + bone]
    v = vec_fn(); a = math.atan2(v.y, v.x) - math.atan2(target_xy[1], target_xy[0])
    rot_about(pb, Matrix.Rotation(-a, 3, "Z"), pb.head.copy())


def a_pose(arm):
    P = lambda n: arm.pose.bones[n if n == "headfront" else MX + n]
    H = lambda n: (lambda: P(n).head.copy())
    up = Vector((0, 0, 1))
    chain = ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head"]
    nxt = {"Hips": "Spine", "Spine": "Spine1", "Spine1": "Spine2", "Spine2": "Neck", "Neck": "Head", "Head": "HeadTop_End"}
    for b in chain:
        aim(arm, b, H(nxt[b]), up)
        if b == "Hips":   # linea delle anche orizzontale: Left a +X (riferimento Mixamo)
            yaw_to(arm, "Hips", lambda: P("LeftUpLeg").head - P("RightUpLeg").head, (1, 0))
        if b == "Spine":
            yaw_to(arm, "Spine", lambda: P("LeftArm").head - P("RightArm").head, (1, 0))
        if b == "Head":   # il viso guarda -Y
            yaw_to(arm, "Head", lambda: P("headfront").head - P("Head").head, (0, -1))
    for side in ("Left", "Right"):
        s = side
        aim(arm, s + "Shoulder", H(s + "Arm"), to_mx(A_DIR["shoulder"], s))
        aim(arm, s + "Arm", H(s + "ForeArm"), to_mx(A_DIR["arm"], s))
        aim(arm, s + "ForeArm", H(s + "Hand"), to_mx(A_DIR["fore"], s))
        aim(arm, s + "Hand", lambda s=s: P(s + "Hand").tail.copy(), to_mx(A_DIR["hand"], s))
        aim(arm, s + "UpLeg", H(s + "Leg"), to_mx(A_DIR["thigh"], s))
        aim(arm, s + "Leg", H(s + "Foot"), to_mx(A_DIR["shin"], s))
        aim(arm, s + "Foot", H(s + "ToeBase"), to_mx(A_DIR["foot"], s))
        aim(arm, s + "ToeBase", H(s + "Toe_End"), to_mx(A_DIR["toe"], s))


# ------------------------------------------------------------------ mani (calibrazione di HandFist, in riferimento Blender)
# HandFist (Godot, mano a +X): dita (0.22,-0.79,0.58), normale del palmo (-0.91,-0.38,-0.16), baricentro dal polso (0.027,-0.072,0.106).
# Godot (x,y,z) -> Blender (x,-z,y).
HAND_F = Vector((0.22, -0.58, -0.79))
HAND_N = Vector((-0.91, 0.16, -0.38))
CENTER_B = Vector((0.027, -0.106, -0.072))


def hand_vertices(ob, mx, exclude):
    """Indici dei vertici della mano per lato (dominante Mixamo '<Lato>Hand*', entro 14 cm dal polso, scudo escluso)."""
    import numpy as np
    me = ob.data; names = {g.index: g.name for g in ob.vertex_groups}
    out = {}
    for side in ("Left", "Right"):
        w = np.array(mx.pose.bones[MX + side + "Hand"].head)
        idx = []
        for v in me.vertices:
            if v.index in exclude or not v.groups: continue
            acc = {}
            for g in v.groups: acc[names[g.group]] = acc.get(names[g.group], 0) + g.weight
            if max(acc, key=acc.get).startswith(MX + side + "Hand") and np.linalg.norm(np.array(v.co[:]) - w) < 0.14 * 1.6:
                idx.append(v.index)
        out[side] = np.array(idx, dtype=int)
    return out


def evaluated_coords(ob):
    import numpy as np
    upd()
    ev = ob.evaluated_get(bpy.context.evaluated_depsgraph_get()); m = ev.to_mesh()
    co = np.array([v.co[:] for v in m.vertices]); ev.to_mesh_clear()
    return co


def align_hands(ob, mx, hand_idx):
    """Ruota ogni osso Mano attorno al polso finche' dita e palmo coincidono con HandFist; ritorna i baricentri delle mani."""
    import numpy as np
    cent = {}
    for side in ("Left", "Right"):
        sx = 1.0 if side == "Left" else -1.0
        pb = mx.pose.bones[MX + side + "Hand"]
        co = evaluated_coords(ob)
        if len(hand_idx[side]) < 60:   # mano fusa con lo scudo (Agamennone): solo la direzione delle dita
            F = Vector((HAND_F.x * sx, HAND_F.y, HAND_F.z)).normalized()
            cur = (pb.tail - pb.head).normalized()
            rot_about(pb, cur.rotation_difference(F).to_matrix(), pb.head.copy())
            cent[side] = pb.head.copy(); print("MANO", side, "poche vertici", len(hand_idx[side])); continue
        P = co[hand_idx[side]]; c = P.mean(0)
        U, Sg, Vt = np.linalg.svd(P - c, full_matrices=False)
        f = Vector(Vt[0]); n = Vector(Vt[2])
        if f.dot(Vector(c) - pb.head) < 0: f = -f
        if n.x * sx > 0: n = -n                                    # palmo verso il corpo
        F = Vector((HAND_F.x * sx, HAND_F.y, HAND_F.z)).normalized()
        N = Vector((HAND_N.x * sx, HAND_N.y, HAND_N.z))
        n = (n - f * n.dot(f)).normalized(); N = (N - F * N.dot(F)).normalized()
        A = Matrix((f, n, f.cross(n))).transposed(); B = Matrix((F, N, F.cross(N))).transposed()
        rot_about(pb, B @ A.inverted(), pb.head.copy())
        cent[side] = Vector(evaluated_coords(ob)[hand_idx[side]].mean(0))
        print("MANO", side, "dita", tuple(round(x, 2) for x in (Vector(Vt[0]))), "-> centro", tuple(round(x, 3) for x in cent[side]))
    return cent


def armature_sided(name, J, JR, JL):
    """Come build_char_hires.armature ma con i giunti reali di ogni lato (le mesh Meshy non sono simmetriche al centimetro:
    con giunti specchiati le ossa uscivano di qualche cm dal braccio). Coordinate gia' in metri finali."""
    d = bpy.data.armatures.new(name)
    a = bpy.data.objects.new(name, d)
    bpy.context.scene.collection.objects.link(a)
    bpy.context.view_layer.objects.active = a
    bpy.ops.object.mode_set(mode="EDIT")
    eb = {}

    def add(n, h, t, p, conn=False):
        b = d.edit_bones.new(n); b.head, b.tail = Vector(h), Vector(t); b.roll = 0
        if p:
            b.parent = eb[p]; b.use_connect = conn
        eb[n] = b
    add("root", (0, 0, 0), (0, 0, 0.2 * SCALE), None)
    add("hips", J["hips"], J["spine"], "root")
    add("spine", J["spine"], J["chest"], "hips", True)
    add("neck", J["chest"], J["neck"], "spine", True)
    add("head", J["neck"], J["head_top"], "neck", True)
    for sd, K in (("R", JR), ("L", JL)):
        # ossa di supporto, pilotate a runtime da ArmHelpers (scripts/units/arm_helpers.gd): clavicola (segue in parte il braccio) e twist
        # dell'avambraccio (segue in parte la rotazione della mano). Non fanno parte della catena delle animazioni.
        add(f"clavicle.{sd}", K["clav"], K["shoulder"], "spine")
        add(f"upperarm.{sd}", K["shoulder"], K["elbow"], "spine")
        add(f"forearm.{sd}", K["elbow"], K["wrist"], f"upperarm.{sd}", True)
        add(f"forearm_twist.{sd}", (K["elbow"] + K["wrist"]) * 0.5, K["wrist"], f"forearm.{sd}")
        add(f"hand.{sd}", K["wrist"], K["hand_end"], f"forearm.{sd}", True)
        add(f"thigh.{sd}", K["hip"], K["knee"], "hips")
        add(f"shin.{sd}", K["knee"], K["ankle"], f"thigh.{sd}", True)
        add(f"foot.{sd}", K["ankle"], K["toe"], f"shin.{sd}", True)
    bpy.ops.object.mode_set(mode="OBJECT")
    d.display_type = "STICK"
    for pb in a.pose.bones:
        pb.rotation_mode = "XYZ"
    return a


# ------------------------------------------------------------------ mesh
def decimate(ob, arm, target):
    """Decima ob (figlio di arm con modificatore Armature) mantenendo i pesi (interpolati sul collasso)."""
    for m in list(ob.modifiers):
        if m.type == "ARMATURE": ob.modifiers.remove(m)
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    m = ob.modifiers.new("dec", "DECIMATE")
    m.decimate_type = "COLLAPSE"; m.ratio = min(1.0, target / tris); m.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True)
    bpy.ops.object.modifier_apply(modifier=m.name)
    if arm is not None:
        am = ob.modifiers.new("Armature", "ARMATURE"); am.object = arm
    for p in ob.data.polygons: p.use_smooth = True
    return tris


def shield_vertices(ob, arm):
    """Indici dei vertici dello scudo di Agamennone (disco intorno all'avambraccio sinistro Mixamo, posa di bind)."""
    import numpy as np
    me = ob.data
    b = arm.data.bones[MX + "LeftForeArm"]
    h = np.array(b.head_local); t = np.array(b.tail_local); u = (t - h) / np.linalg.norm(t - h)
    co = np.array([v.co[:] for v in me.vertices]); p = co - h
    r = np.linalg.norm(p - np.outer(p @ u, u), axis=1)
    names = {g.index: g.name for g in ob.vertex_groups}
    fa = ob.vertex_groups[MX + "LeftForeArm"].index
    dom, wf = [], np.zeros(len(co))
    for v in me.vertices:
        w = {}
        for g in v.groups:
            w[names[g.group]] = w.get(names[g.group], 0) + g.weight
            if g.group == fa: wf[v.index] = g.weight
        dom.append(max(w, key=w.get) if w else "")
    ok = np.isin(np.array(dom), [MX + n for n in ("LeftForeArm", "LeftUpLeg", "LeftHandThumb3", "LeftHandThumb1", "LeftHandPinky3", "LeftHand")])
    inreg = (co[:, 0] > 0.19) & (np.hypot(co[:, 1], co[:, 2] - 0.835) < 0.34) & (co[:, 2] > 0.5) & (co[:, 2] < 1.17)
    return [int(i) for i in np.where(inreg & (r > 0.115) & ok & ((wf > 0.3) | (co[:, 0] > 0.28)))[0]]


# ------------------------------------------------------------------ pesi
def game_group(mx_name):
    """Nome osso Mixamo (senza prefisso) -> [(osso del gioco, frazione)] oppure None se non mappato (osso extra Meshy)."""
    n = mx_name
    if n.startswith(MX): n = n[len(MX):]
    if n == "Hips": return [("hips", 1.0)]
    if n in ("Spine", "Spine1", "Spine2"): return [("spine", 1.0)]
    if n == "Neck": return [("neck", 1.0)]
    if n.startswith("Head") or n == "headfront" or "Eye" in n: return [("head", 1.0)]
    for side, gs in (("Left", "R"), ("Right", "L")):
        if not n.startswith(side): continue
        k = n[len(side):]
        if k == "Shoulder": return [(f"clavicle.{gs}", 1.0)]
        if k == "Arm": return [(f"upperarm.{gs}", 1.0)]
        if k == "ForeArm": return [(f"forearm.{gs}", 1.0)]
        if k.startswith("Hand"): return [(f"hand.{gs}", 1.0)]
        if k == "UpLeg": return [(f"thigh.{gs}", 1.0)]
        if k == "Leg": return [(f"shin.{gs}", 1.0)]
        if k.startswith("Foot") or k.startswith("Toe"): return [(f"foot.{gs}", 1.0)]
    return None


def smoothstep(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def seg_param(p, a, b):
    ab = b - a; t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared)); return (p - (a + ab * t)).length, t * ab.length


def collapse_weights(ob, arm, shield, xs=0.19, zs=1.12, joints=None):
    me = ob.data
    old = {g.index: g.name for g in ob.vertex_groups}
    bones = {b.name: (arm.matrix_world @ b.head_local, arm.matrix_world @ b.tail_local) for b in arm.data.bones}
    gnames = [b.name for b in arm.data.bones if b.name != "root"]

    def dist(p, a, b):
        ab = b - a; t = max(0, min(1, (p - a).dot(ab) / ab.length_squared)); return (p - (a + ab * t)).length

    new = {}
    extra_verts = 0
    for v in me.vertices:
        acc, ext = {}, 0.0
        for g in v.groups:
            m = game_group(old[g.group])
            if m is None: ext += g.weight; continue
            for bn, f in m: acc[bn] = acc.get(bn, 0) + g.weight * f
        tot = sum(acc.values()) + ext
        if tot < 1e-6: ext, tot, acc = 1.0, 1.0, {}
        if ext > 1e-4:   # osso extra (mantello...): fusione morbida delle 3 ossa piu' vicine
            extra_verts += 1
            ds = sorted((dist(v.co, *bones[n]), n) for n in gnames)[:3]
            ws = [1.0 / (d + 0.03) ** 4 for d, _ in ds]; s = sum(ws)
            for (d, bn), w in zip(ds, ws): acc[bn] = acc.get(bn, 0) + ext * w / s
        # le ossa Mixamo di spalla/clavicola non ci sono: a braccio alzato la parte interna del busto (collo, petto, cinghie della corazza,
        # mantello) seguirebbe il braccio. L'influenza del braccio si attenua verso il centro (|x| < spalla) e va al busto.
        m = smoothstep(xs - 0.06, xs + 0.01, abs(v.co.x))
        # e la parte alta della spalla (pauldron, trapezio) segue il braccio solo in parte: senza clavicola salirebbe tutta con lui
        m *= 1.0 - 0.35 * smoothstep(0.0, 0.08, v.co.z - zs)
        if m < 1.0:
            for k in [k for k in acc if k.startswith("upperarm.")]:
                moved = acc[k] * (1 - m); acc[k] -= moved; cv = "clavicle." + k.split(".")[1]; acc[cv] = acc.get(cv, 0) + moved
        # gomito: lo skinning Mixamo sfuma braccio/avambraccio su ~11 cm (gomma sottile e storta quando si piega): transizione stretta (+-3 cm)
        if joints:
            sd = "R" if v.co.x > 0 else "L"
            K = joints[0] if sd == "R" else joints[1]
            ka, kf = f"upperarm.{sd}", f"forearm.{sd}"
            T = acc.get(ka, 0.0) + acc.get(kf, 0.0)
            if T > 0.3:
                d1, s1 = seg_param(v.co, K["shoulder"], K["elbow"]); d2, s2 = seg_param(v.co, K["elbow"], K["wrist"])
                L1 = (K["elbow"] - K["shoulder"]).length
                if min(d1, d2) < 0.08:
                    ss = s1 if d1 < d2 else L1 + s2
                    f = smoothstep(L1 - 0.03, L1 + 0.03, ss)
                    acc[ka] = T * (1 - f); acc[kf] = T * f
                    L2 = (K["wrist"] - K["elbow"]).length
                    u = (ss - L1) / max(L2, 1e-6)
                    wt = acc[kf] * 0.75 * smoothstep(0.25, 0.95, u)       # twist dell'avambraccio: cresce verso il polso
                    if wt > 0.0:
                        acc[kf] -= wt; acc["forearm_twist." + sd] = wt
        s = sum(acc.values())
        new[v.index] = {k: x / s for k, x in acc.items()}
    if shield:
        for i in shield: new[i] = {"forearm.R": 1.0}
    for vg in list(ob.vertex_groups): ob.vertex_groups.remove(vg)
    groups = {n: ob.vertex_groups.new(name=n) for n in gnames}
    for i, w in new.items():
        for bn, x in w.items():
            if x > 0.002: groups[bn].add([i], x, "REPLACE")
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.vertex_group_limit_total(limit=4)
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    return extra_verts



# ------------------------------------------------------------------ retarget dei clip Mixamo sul rig a 17 ossa
GAME_FROM_MX = {  # osso del gioco -> osso Mixamo la cui orientazione globale viene trasferita (Left Mixamo = lato +X = ".R")
    "hips": "Hips", "spine": "Spine1", "neck": "Neck", "head": "Head",
    "upperarm.R": "LeftArm", "forearm.R": "LeftForeArm", "hand.R": "LeftHand",
    "upperarm.L": "RightArm", "forearm.L": "RightForeArm", "hand.L": "RightHand",
    "thigh.R": "LeftUpLeg", "shin.R": "LeftLeg", "foot.R": "LeftFoot",
    "thigh.L": "RightUpLeg", "shin.L": "RightLeg", "foot.L": "RightFoot",
}
ORDER = ["hips", "spine", "neck", "head", "upperarm.R", "forearm.R", "hand.R", "upperarm.L", "forearm.L", "hand.L",
         "thigh.R", "shin.R", "foot.R", "thigh.L", "shin.L", "foot.L"]
PARENT = {"hips": None, "spine": "hips", "neck": "spine", "head": "neck", "upperarm.R": "spine", "forearm.R": "upperarm.R",
          "hand.R": "forearm.R", "upperarm.L": "spine", "forearm.L": "upperarm.L", "hand.L": "forearm.L",
          "thigh.R": "hips", "shin.R": "thigh.R", "foot.R": "shin.R", "thigh.L": "hips", "shin.L": "thigh.L", "foot.L": "shin.L"}
ATTACK_WORDS = ("Attack", "Slash", "Combo", "Archery", "Sword")
DEATH_NAMES = ("Dead", "Fall_Dead_from_Abdominal_Injury", "dying_backwards")


def pick_clips():
    """Nome clip Mixamo -> nome base dell'azione nel gioco."""
    names = [a.name for a in bpy.data.actions]
    out = {}
    if "Walking" in names: out["Walking"] = "mx_walk"
    if "Running" in names: out["Running"] = "mx_run"
    for i, n in enumerate([n for n in DEATH_NAMES if n in names]): out[n] = f"mx_death_{i}"
    atk = [n for n in names if any(w in n for w in ATTACK_WORDS)][:4]
    for i, n in enumerate(atk): out[n] = f"mx_attack_{i}"
    return out


def sample_clips(mx, picks):
    """Per ogni clip scelto: matrici globali (3x3) delle ossa Mixamo mappate, testa dell'anca e quota del piede, a ogni fotogramma intero."""
    out = {}
    mx.animation_data_create()
    sc = bpy.context.scene
    for cname in picks:
        act = bpy.data.actions[cname]
        mx.animation_data.action = act
        f0, f1 = int(round(act.frame_range[0])), int(round(act.frame_range[1]))
        rec = {"f0": f0, "f1": f1, "rot": [], "hips": [], "footz": [], "feet": [], "dur": (f1 - f0) / sc.render.fps}
        for f in range(f0, f1 + 1):
            sc.frame_set(f); upd()
            rec["rot"].append({m: mx.pose.bones[MX + m].matrix.to_3x3().normalized() for m in set(GAME_FROM_MX.values())})
            rec["hips"].append(mx.pose.bones[MX + "Hips"].head.copy())
            rec["feet"].append((mx.pose.bones[MX + "LeftFoot"].head.copy(), mx.pose.bones[MX + "RightFoot"].head.copy()))
            rec["footz"].append(min(mx.pose.bones[MX + "LeftFoot"].head.z, mx.pose.bones[MX + "RightFoot"].head.z))
        out[cname] = rec
    mx.animation_data.action = None
    return out


def make_mx_actions(arm, clips, picks, a_rot, hips_a, ankle_h, scale, tf):
    """Crea sul rig a 17 ossa le azioni mx_* trasferendo le rotazioni globali Mixamo (relative alla A-pose) sulle ossa del gioco."""
    from mathutils import Euler
    bones = arm.data.bones
    rest = {n: bones[n].matrix_local.copy() for n in ORDER}
    rest_local = {n: (rest[PARENT[n]].inverted() @ rest[n]) if PARENT[n] else rest[n] for n in ORDER}
    rest_rot = {n: rest[n].to_3x3() for n in ORDER}
    # quota del terreno nello spazio Mixamo: dal passo (Walking) o dalla corsa
    ground = None
    for ref in ("Walking", "Running"):
        if ref in clips:
            ground = min(clips[ref]["footz"]) - ankle_h; break
    if ground is None:
        ground = hips_a.z - 0.9
    ad = arm.animation_data_create()
    made = []
    for cname, base in picks.items():
        rec = clips[cname]; n = len(rec["hips"])
        loop = base in ("mx_walk", "mx_run")
        if loop and n > 2:       # l'ultimo fotogramma ripete il primo
            n -= 1
        hip = [rec["hips"][k] for k in range(n)]
        dur = rec["dur"] if not loop else rec["dur"] * n / max(len(rec["hips"]) - 1, 1)
        # moto in avanti: tolto nei cicli di andatura (si cammina sul posto), tenuto negli altri clip
        if loop:
            d = hip[-1] - hip[0]; travel = Vector((d.x, d.y, 0)) * n / max(n - 1, 1)
            hip = [hip[k] - travel * (k / n) for k in range(n)]
            mean = Vector((sum(h.x for h in hip) / n, sum(h.y for h in hip) / n, 0))
            hip = [Vector((h.x - mean.x + hips_a.x, h.y - mean.y + hips_a.y, h.z)) for h in hip]
            speed = travel.length / max(dur, 1e-6) * scale
            if speed < 0.3:   # clip sul posto: velocita' dal piede d'appoggio (si muove all'indietro rispetto al bacino)
                vs = []
                zmin = min(min(f[0].z, f[1].z) for f in rec["feet"][:n])
                for side in (0, 1):
                    for k in range(n):
                        a, b = rec["feet"][(k - 1) % n][side], rec["feet"][(k + 1) % n][side]
                        ha, hb = rec["hips"][(k - 1) % n], rec["hips"][(k + 1) % n]
                        if rec["feet"][k][side].z < zmin + 0.04:
                            vs.append(-(((a.y - ha.y) - (b.y - hb.y)) * -1.0) / (2.0 / 24.0) * -1.0)
                vs = sorted(abs(v) for v in vs)
                speed = (vs[len(vs) // 2] if vs else 0.0) * scale
            name = f"{base}_v{speed:.2f}".replace(".", "p")
        else:
            h0 = hip[0]
            hip = [Vector((h.x - h0.x + hips_a.x, h.y - h0.y + hips_a.y, h.z)) for h in hip]
            name = base
        act = bpy.data.actions.new(name); act.use_fake_user = True
        ad.action = act
        prev = {b: Euler((0, 0, 0)) for b in ORDER}
        for k in range(n):
            gl = {}
            for b in ORDER:
                m = GAME_FROM_MX[b]
                delta = rec["rot"][k][m] @ a_rot[m].inverted()
                g_rot = delta @ rest_rot[b]
                if PARENT[b]:
                    pg = gl[PARENT[b]]
                    basis_rot = (pg.to_3x3() @ rest_local[b].to_3x3()).inverted() @ g_rot
                    pglob = pg @ rest_local[b]
                else:
                    basis_rot = rest_rot[b].inverted() @ g_rot
                    pglob = rest[b]
                loc = Vector((0, 0, 0))
                if b == "hips":
                    target = Vector(((hip[k].x - tf[0]) * scale, (hip[k].y - tf[1]) * scale, (hip[k].z - ground) * scale))
                    loc = rest_rot["hips"].inverted() @ (target - rest["hips"].translation)
                    pglob = pglob @ Matrix.Translation(loc)
                gm = pglob @ basis_rot.to_4x4()
                gl[b] = gm
                pb = arm.pose.bones[b]
                e = basis_rot.to_euler("XYZ", prev[b]); prev[b] = e
                pb.rotation_euler = e
                pb.keyframe_insert("rotation_euler", frame=1 + k, group=b)
                if b == "hips":
                    pb.location = loc
                    pb.keyframe_insert("location", frame=1 + k, group=b)
        tr = ad.nla_tracks.new(); tr.name = name
        tr.strips.new(name, 1, act); tr.mute = True
        made.append((name, n, dur))
    ad.action = None
    for pb in arm.pose.bones: pb.rotation_euler = (0, 0, 0); pb.location = (0, 0, 0)
    keep = {"idle_loop", "walk_loop", "attack", "hit", "death"} | {m[0] for m in made}
    for a in list(bpy.data.actions):   # via le azioni Mixamo originali (canali delle 66 ossa)
        if a.name not in keep: bpy.data.actions.remove(a)
    return made


# ------------------------------------------------------------------ texture ed export
def tex_size(px):
    """Immagini a px (i glb Meshy sono 2048: le dimensioni di quelle impacchettate non sono note finche' non si caricano)."""
    for im in bpy.data.images:
        if im.name == "normal": im.name = "Image_2"          # stessi nomi di build_char_hires: Image_0 base, Image_1 ORM, Image_2 normale
        im.alpha_mode = "NONE" if im.name == "Image_0" else im.alpha_mode
        im.pixels[0]                                           # forza il caricamento
        if im.size[0] != px: im.scale(px, px)


def export(name, ob, arm):
    d = os.path.join(CUSTOM, "personaggi_nuovi", name)
    shutil.rmtree(d, ignore_errors=True); os.makedirs(d, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    for c in arm.children_recursive: c.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(filepath=os.path.join(d, name + ".gltf"), export_format="GLTF_SEPARATE", use_selection=True,
                              export_yup=True, export_apply=False, export_texcoords=True, export_normals=True,
                              export_materials="EXPORT", export_image_format="JPEG", export_jpeg_quality=88, export_extras=False,
                              export_animations=True, export_animation_mode="ACTIONS", export_skins=True,
                              export_def_bones=False, export_anim_single_armature=True, export_force_sampling=True,
                              export_frame_range=False)
    return d


# ------------------------------------------------------------------ principale
def build(src, name, fn, attack, debug=False):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(src, fn))
    ob = max([o for o in bpy.data.objects if o.type == "MESH"], key=lambda o: len(o.data.vertices))
    mx = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    for o in [o for o in bpy.data.objects if o.type == "MESH" and o is not ob]: bpy.data.objects.remove(o)
    mx.animation_data.action = None
    for pb in mx.pose.bones:
        pb.rotation_mode = "QUATERNION"; pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0); pb.scale = (1, 1, 1)
    upd()
    shield = shield_vertices(ob, mx) if name in SHIELD_IN_MESH else []   # indici nella mesh originale
    # 1. decimazione nella posa originale: porta con se' i pesi, ma gli indici dello scudo cambiano -> marcali con un gruppo
    if shield:
        tmp = ob.vertex_groups.new(name="shield_tmp"); tmp.add(shield, 1.0, "REPLACE")
    n0 = decimate(ob, mx, TRIS)
    if shield:
        tmp = ob.vertex_groups["shield_tmp"]; tidx = tmp.index
        shield = [v.index for v in ob.data.vertices if any(g.group == tidx and g.weight > 0.5 for g in v.groups)]
        ob.vertex_groups.remove(tmp)
    # 2. A-pose, mani orientate come quelle dei vecchi modelli (HandFist) e cottura
    a_pose(mx)
    hand_idx = hand_vertices(ob, mx, set(shield))
    hand_c = align_hands(ob, mx, hand_idx)
    pose = {b.name[len(MX):]: (b.head.copy(), b.tail.copy()) for b in mx.pose.bones if b.name.startswith(MX)}
    a_rot = {m: mx.pose.bones[MX + m].matrix.to_3x3().normalized() for m in set(GAME_FROM_MX.values())}
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True)
    bpy.ops.object.modifier_apply(modifier="Armature")
    ob.parent = None
    picks = pick_clips()
    clips = sample_clips(mx, picks)
    bpy.data.objects.remove(mx)
    # 3. riferimento finale: fronte -Y (come i vecchi modelli: +Z in Godot), piedi a z=0, altezza HEIGHT, origine tra le caviglie
    zs = [v.co.z for v in ob.data.vertices]
    h = max(zs) - min(zs); s = HEIGHT / h; z0 = min(zs)
    ankle_mx_z = (pose["LeftFoot"][0].z + pose["RightFoot"][0].z) / 2; z0_mx = z0; hips_a = pose["Hips"][0].copy()
    cx = (pose["LeftUpLeg"][0].x + pose["RightUpLeg"][0].x) / 2
    cy = (pose["LeftFoot"][0].y + pose["RightFoot"][0].y) / 2
    T = lambda p: Vector(((p.x - cx) * s, (p.y - cy) * s, (p.z - z0) * s))
    for v in ob.data.vertices: v.co = T(v.co)
    pose = {k: (T(a), T(b)) for k, (a, b) in pose.items()}
    hand_c = {k: T(v) for k, v in hand_c.items()}
    me = ob.data
    me.update()
    # 4. giunti misurati (destra a +X: Right Mixamo dopo la rotazione) e scheletro a 17 ossa
    def side_joints(sd):
        """Giunti del lato Mixamo `sd` ('Left' = lato +X = '.R'); polso vero, mano fino alle nocche."""
        P = lambda n, e=0: pose[sd + n][e]
        knuckle = pose[sd + "HandMiddle1"][0] if (sd + "HandMiddle1") in pose else P("Hand", 1)
        ankle = Vector((P("Foot").x, P("Foot").y, 0.105))   # quota fissa uguale per tutti: HumanoidAnims.ANKLE_H (la media misurata sui 15 modelli e' 0,105)
        wrist = P("Hand")     # polso anatomico; HandFist.CENTER e' il baricentro della mano rispetto a questo punto (vedi HANDC)
        d = hand_c[sd] - wrist
        print("HANDC", name, sd, round(abs(d.x), 4), round(d.z, 4), round(-d.y, 4), "(x, y, z Godot, mano +X)")
        return dict(clav=P("Shoulder"), shoulder=P("Arm"), elbow=P("ForeArm"), wrist=wrist, hand_end=knuckle,
                    hip=P("UpLeg"), knee=P("Leg"), ankle=ankle, toe=ankle + Vector((0.0, 0.12, -0.048)))   # osso del piede verso +Y come nei vecchi rig
    JR, JL = side_joints("Left"), side_joints("Right")
    J = dict(hips=Vector((0, pose["Hips"][0].y, pose["Hips"][0].z)), spine=Vector((0, pose["Spine"][0].y, pose["Spine"][0].z)),
             chest=Vector((0, pose["Neck"][0].y, pose["Neck"][0].z)), neck=Vector((0, pose["Head"][0].y, pose["Head"][0].z)),
             head_top=Vector((0, pose["HeadTop_End"][0].y, pose["HeadTop_End"][0].z)), shoulder=JR["shoulder"], elbow=JR["elbow"],
             wrist=JR["wrist"], ankle=JR["ankle"])
    arm = armature_sided("RIG_" + name, J, JR, JL)
    # 5. pesi e skinning
    ob.name = "SM_" + name
    ob.vertex_groups.clear() if False else None
    # i pesi Mixamo sono ancora nei gruppi 'mixamorig:*' (modificatore applicato, gruppi intatti)
    extra = collapse_weights(ob, arm, shield, J["shoulder"].x, J["shoulder"].z, (JR, JL))
    ob.parent = arm
    am = ob.modifiers.new("Armature", "ARMATURE"); am.object = arm
    ob.matrix_parent_inverse = arm.matrix_world.inverted()
    tex_size(1024)
    acts = BC.make_actions(arm, {"attack": attack}, name)
    ankle_h = pose["LeftFoot"][0].z * 0 + (ankle_mx_z - z0_mx)    # quota caviglia sopra la suola, in unita' Mixamo
    made = make_mx_actions(arm, clips, picks, a_rot, hips_a, ankle_h, s, (cx, cy))
    print("MX", name, [(m[0], m[1], round(m[2], 2)) for m in made])
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    nov = sum(1 for v in me.vertices if not v.groups)
    print(f"RESULT {name}: {n0} -> {tris} tris, vertici senza peso {nov}, vertici con ossa extra {extra}, scudo {len(shield)}, "
          f"giunti spalla {tuple(round(x, 3) for x in J['shoulder'])} gomito {tuple(round(x, 3) for x in J['elbow'])} "
          f"polso {tuple(round(x, 3) for x in J['wrist'])} caviglia {tuple(round(x, 3) for x in J['ankle'])}")
    tmp = os.environ.get("SCRATCH", "/tmp")
    if debug:
        BCH.render_debug(ob, arm, os.path.join(tmp, "mxdbg_" + name),
                         [(None, 1, 0), (None, 1, 90), ("walk_loop", 7, 0), ("attack", 10, 30), ("death", 20, 40)])
        return
    d = export(name, ob, arm)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(CUSTOM, "_source", "blend", f"pn_{name}.blend"), compress=True)
    print("EXPORT", d)
    # 6. versione leggera
    decimate(ob, arm, TRIS_LOD)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.vertex_group_limit_total(limit=4)
    tex_size(512)
    ob.name = "SM_" + name + "_lod"
    d = export(name + "_lod", ob, arm)
    print("EXPORT", d, sum(len(p.vertices) - 2 for p in ob.data.polygons), "tris")


if __name__ == "__main__":
    a = sys.argv[sys.argv.index("--") + 1:]
    debug = "--debug" in a
    a = [x for x in a if x != "--debug"]
    src, only = a[0], a[1:]
    for name, (fn, attack) in MAP.items():
        if only and name not in only: continue
        build(src, name, fn, attack, debug)
