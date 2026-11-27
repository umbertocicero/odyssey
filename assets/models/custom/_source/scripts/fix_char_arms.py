"""Braccia solide per i personaggi di personaggi_nuovi (pn_<nome>.blend, gia' decimati e riggati da build_char_hires.py).

Problema: lo scheletro usa giunti fissi uguali per tutti (build_char_hires.J), quindi nelle braccia scolpite le ossa
passano qualche centimetro fuori dalla mesh e lo skinning automatico dava all'avambraccio pochissimi vertici (il resto
diviso tra braccio e mano): piegando il gomito l'avambraccio si stirava come gomma, sottile e molle.

Correzione (solo braccia, scheletro e animazioni invariati, cosi' HumanoidAnims resta valido per tutti):
  1. ricentra la mesh del braccio sulla catena spalla-gomito-polso (sposta le sezioni del braccio sulla linea delle ossa,
     con raccordo morbido verso la spalla);
  2. irrobustisce braccio e avambraccio (sezioni allargate attorno all'asse: bicipite/deltoide e avambraccio piu' pieni,
     polso e mano invariati);
  3. rifa' i pesi per segmenti rigidi con raccordi corti a spalla, gomito e polso (niente effetto gomma).

Uso: blender -b --factory-startup _source/blend/pn_<nome>.blend -P fix_char_arms.py -- <nome> [--out DIR] [--render PREFIX]
Esporta il glTF come build_char_hires.export (in personaggi_nuovi/<nome>/, o in DIR) tenendo le texture gia' ridotte.
Il .blend non viene salvato (lanciarlo due volte non irrobustisce due volte).
"""
import bpy, sys, os, math
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
CUSTOM = os.path.abspath(os.path.join(HERE, "..", ".."))

THICKEN_UPPER = 1.16     # braccio (bicipite/deltoide)
THICKEN_FORE = 1.14      # avambraccio
SHOULDER_BLEND = 0.05    # m: raccordo spalla-busto
ELBOW_BLEND = 0.035      # m: mezzo raccordo al gomito
WRIST_BLEND = 0.02       # m: mezzo raccordo al polso
BINS = 24


def chain(arm, side):
    names = [f"upperarm.{side}", f"forearm.{side}", f"hand.{side}"]
    b = [arm.data.bones[n] for n in names]
    mw = arm.matrix_world
    pts = [mw @ b[0].head_local, mw @ b[1].head_local, mw @ b[2].head_local, mw @ b[2].tail_local]
    return names, pts


def project(p, pts):
    """Parametro lungo la polilinea (metri dalla spalla), punto proiettato e indice del segmento."""
    best = None
    acc = 0.0
    for i in range(3):
        a, c = pts[i], pts[i + 1]
        ab = c - a
        L = ab.length
        t = max(0.0, min(1.0, (p - a).dot(ab) / (L * L)))
        q = a + ab * t
        d = (p - q).length
        if best is None or d < best[0]:
            best = (d, acc + t * L, q, i, ab / L)
        acc += L
    return best


def smoothstep(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def fix_side(ob, arm, side):
    me = ob.data
    names, pts = chain(arm, side)
    seg = [(pts[i + 1] - pts[i]).length for i in range(3)]
    s_elbow, s_wrist, s_end = seg[0], seg[0] + seg[1], sum(seg)
    gi = {vg.index: vg.name for vg in ob.vertex_groups}
    mw = ob.matrix_world
    imw = mw.inverted()
    # 1. vertici del braccio: quelli che lo skinning automatico dava gia' soprattutto al braccio
    verts = []
    for v in me.vertices:
        ws = {gi[g.group]: g.weight for g in v.groups if g.group in gi}
        aw = sum(ws.get(n, 0.0) for n in names)
        if aw > 0.5:
            p = mw @ v.co
            d, s, q, i, ax = project(p, pts)
            if d < 0.16:   # oltre: scudo o mantello agganciati al braccio, lasciati rigidi
                verts.append((v, p, d, s, q, ax))
    if not verts:
        return 0
    # 2. centro della sezione per fasce lungo il braccio
    sums = [[Vector(), 0] for _ in range(BINS)]
    for v, p, d, s, q, ax in verts:
        if d > 0.09:
            continue
        k = min(BINS - 1, int(s / s_end * BINS))
        off = p - q
        off -= ax * off.dot(ax)
        sums[k][0] += off
        sums[k][1] += 1
    offs = [(sv / n) if n else None for sv, n in sums]
    # riempie i buchi e smussa
    for k in range(BINS):
        if offs[k] is None:
            near = [offs[j] for j in range(BINS) if offs[j] is not None]
            offs[k] = min(near, key=lambda o: 0) if near else Vector()
    sm = []
    for k in range(BINS):
        acc = Vector(); w = 0.0
        for j in range(max(0, k - 2), min(BINS, k + 3)):
            acc += offs[j] * (3 - abs(j - k)); w += 3 - abs(j - k)
        sm.append(acc / w)

    def offset_at(s):
        x = s / s_end * BINS - 0.5
        k0 = max(0, min(BINS - 1, int(math.floor(x))))
        k1 = min(BINS - 1, k0 + 1)
        f = max(0.0, min(1.0, x - k0))
        return sm[k0].lerp(sm[k1], f)

    for v, p, d, s, q, ax in verts:
        # ricentra (raccordo verso la spalla; al polso torna a zero: la mano resta dov'era, HandFist ne misura la posa)
        blend = smoothstep(0.0, SHOULDER_BLEND * 1.6, s) * (1.0 - smoothstep(s_wrist - 0.07, s_wrist - 0.01, s))
        off = offset_at(s)
        off -= ax * off.dot(ax)
        p2 = p - off * blend
        # irrobustisce: sezione allargata attorno all'asse delle ossa
        radial = p2 - q
        radial -= ax * radial.dot(ax)
        if d < 0.11:
            if s < s_elbow:
                f = 1.0 + (THICKEN_UPPER - 1.0) * smoothstep(0.0, SHOULDER_BLEND * 1.6, s) * (0.75 + 0.25 * math.sin(math.pi * min(1.0, s / s_elbow)))
            elif s < s_wrist:
                u = (s - s_elbow) / max(seg[1], 1e-4)
                f = 1.0 + (THICKEN_FORE - 1.0) * (1.0 - smoothstep(0.55, 1.0, u))
            else:
                f = 1.0
            p2 = p2 + radial * (f - 1.0)
        v.co = imw @ p2
        # 3. pesi per segmenti rigidi con raccordi corti
        w_up = 1.0 - smoothstep(s_elbow - ELBOW_BLEND, s_elbow + ELBOW_BLEND, s)
        w_hand = smoothstep(s_wrist - WRIST_BLEND, s_wrist + WRIST_BLEND, s)
        w_fore = max(0.0, 1.0 - w_up - w_hand)
        w_spine = (1.0 - smoothstep(0.0, SHOULDER_BLEND, s)) * 0.5
        ws = {names[0]: w_up * (1.0 - w_spine), names[1]: w_fore, names[2]: w_hand, "spine": w_up * w_spine}
        for g in list(v.groups):
            ob.vertex_groups[g.group].remove([v.index])
        for n, w in ws.items():
            if w > 0.001:
                (ob.vertex_groups.get(n) or ob.vertex_groups.new(name=n)).add([v.index], w, "REPLACE")
    return len(verts)


def render(arm, ob, prefix):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x = 900
    sc.render.resolution_y = 600
    cd = bpy.data.cameras.new("cam_fix")
    cam = bpy.data.objects.new("cam_fix", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    if arm.animation_data:
        arm.animation_data.action = None
    sh = arm.matrix_world @ arm.data.bones["upperarm.R"].head_local
    poses = [("rest", {}), ("bent", {"forearm.R": (math.radians(-100), 0, 0), "upperarm.R": (math.radians(-45), 0, math.radians(15)),
                                     "forearm.L": (math.radians(-100), 0, 0), "upperarm.L": (math.radians(-45), 0, math.radians(-15))})]
    for name, rots in poses:
        for pb in arm.pose.bones:
            pb.rotation_mode = "XYZ"
            pb.rotation_euler = rots.get(pb.name, (0, 0, 0))
        bpy.context.view_layer.update()
        for view, loc in (("front", Vector((-0.2, -1.5, 0.0))), ("side", Vector((1.4, -0.4, 0.0)))):
            cam.location = sh + loc + Vector((0, 0, -0.1))
            d = (sh + Vector((-0.2, 0, -0.2))) - cam.location
            cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
            sc.render.filepath = f"{prefix}_{name}_{view}.png"
            bpy.ops.render.render(write_still=True)
    for pb in arm.pose.bones:
        pb.rotation_euler = (0, 0, 0)


def export(name, arm, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    # Le texture nel .blend sono a 2K: si tengono quelle gia' ridotte (shrink_char_tex.py) della cartella.
    keep = {}
    for f in os.listdir(out_dir):
        if f.lower().endswith((".jpg", ".jpeg", ".png")):
            with open(os.path.join(out_dir, f), "rb") as fh:
                keep[f] = fh.read()
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    for c in arm.children_recursive:
        c.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, name + ".gltf"), export_format="GLTF_SEPARATE", use_selection=True,
                              export_yup=True, export_apply=False, export_texcoords=True, export_normals=True,
                              export_materials="EXPORT", export_image_format="AUTO", export_extras=False,
                              export_animations=True, export_animation_mode="ACTIONS", export_skins=True,
                              export_def_bones=False, export_anim_single_armature=True, export_force_sampling=True,
                              export_frame_range=False)
    for f, data in keep.items():
        with open(os.path.join(out_dir, f), "wb") as fh:
            fh.write(data)


if __name__ == "__main__":
    a = sys.argv[sys.argv.index("--") + 1:]
    name = a[0]
    out_dir = a[a.index("--out") + 1] if "--out" in a else os.path.join(CUSTOM, "personaggi_nuovi", name)
    prefix = a[a.index("--render") + 1] if "--render" in a else ""
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    ob = next(o for o in bpy.data.objects if o.type == "MESH" and o.parent == arm)
    if prefix:
        render(arm, ob, prefix + "_before")
    n = [fix_side(ob, arm, s) for s in ("R", "L")]
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.vertex_group_limit_total(limit=4)
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    if prefix:
        render(arm, ob, prefix + "_after")
    export(name, arm, out_dir)   # il .blend non si salva: resta la sorgente, la correzione si riapplica a ogni export
    print(f"FIXED {name}: vertici braccio R/L {n} -> {out_dir}")
