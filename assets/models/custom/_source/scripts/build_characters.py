"""Personaggi riggati: oplita acheo, Ulisse oplita, arciere troiano, ufficiale troiano.

Uso: blender -b --factory-startup -P build_characters.py [-- nome ...]
Figurine alte ~1.5 m (testa ed elmo grandi, come da STYLE.md), fronte verso +Y in Blender
(= -Z in Godot), piedi a z = 0. Skinning rigido per parte (ogni parte segue un osso),
adatto a figurine low-poly e leggero su mobile.

Animazioni (nomi delle action, Godot mette in loop quelle che finiscono con "_loop"):
  idle_loop (2 s), walk_loop (1 s), attack, hit, death
"""
import bpy, sys, os, math
from mathutils import Vector
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import okit
from okit import Builder, M, look_m

# ------------------------------------------------------------------ scheletro
# (nome, testa, coda, genitore)
BONES = [
    ("root", (0, 0, 0), (0, 0, 0.18), None),
    ("hips", (0, 0, 0.64), (0, 0, 0.78), "root"),
    ("spine", (0, 0, 0.78), (0, 0, 0.98), "hips"),
    ("neck", (0, 0, 0.98), (0, 0, 1.07), "spine"),
    ("head", (0, 0, 1.07), (0, 0, 1.38), "neck"),
    ("cape", (0, -0.13, 0.99), (0, -0.20, 0.55), "spine"),
]
for s, x in (("R", 1), ("L", -1)):
    BONES += [
        (f"upperarm.{s}", (0.19 * x, 0, 0.96), (0.22 * x, -0.02, 0.78), "spine"),
        (f"forearm.{s}", (0.22 * x, -0.02, 0.78), (0.22 * x, 0.16, 0.72), f"upperarm.{s}"),
        (f"hand.{s}", (0.22 * x, 0.16, 0.72), (0.22 * x, 0.24, 0.71), f"forearm.{s}"),
        (f"thigh.{s}", (0.09 * x, 0, 0.66), (0.09 * x, 0.0, 0.36), "hips"),
        (f"shin.{s}", (0.09 * x, 0.0, 0.36), (0.09 * x, 0, 0.07), f"thigh.{s}"),
        (f"foot.{s}", (0.09 * x, 0, 0.07), (0.09 * x, 0.13, 0.03), f"shin.{s}"),
    ]


def build_armature(name):
    arm_data = bpy.data.armatures.new(name)
    arm = bpy.data.objects.new(name, arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = {}
    for n, h, t, p in BONES:
        b = arm_data.edit_bones.new(n)
        b.head, b.tail = h, t
        b.roll = 0
        if p:
            b.parent = eb[p]
            b.use_connect = Vector(h) == Vector(eb[p].tail) and n not in ("cape",)
        eb[n] = b
    bpy.ops.object.mode_set(mode="OBJECT")
    arm_data.display_type = "STICK"
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
    return arm


# ------------------------------------------------------------------ corpo
def body(b, v):
    """Corpo comune. v = dizionario con colori e accessori della variante."""
    for s, x in (("R", 1), ("L", -1)):
        # piedi e sandali
        b.box((0.10, 0.17, 0.06), M((0.09 * x, 0.035, 0.03)), v["shoe"], f"foot.{s}", bevel=0.012)
        b.box((0.105, 0.05, 0.02), M((0.09 * x, 0.03, 0.065)), "leather_dark", f"foot.{s}")
        # gambe
        b.cyl(0.046, 0.056, 0.30, 8, M((0.09 * x, 0, 0.06)), v["shin"], f"shin.{s}")
        if v.get("greaves"):
            b.cyl(0.060, 0.066, 0.22, 8, M((0.09 * x, 0.004, 0.13)), v["greaves"], f"shin.{s}")
        b.sphere(0.056, M((0.09 * x, 0.004, 0.36)), v["knee"], f"shin.{s}", seg=8, rings=5)
        b.cyl(0.058, 0.07, 0.31, 8, M((0.09 * x, 0, 0.36)), v["thigh"], f"thigh.{s}")
        # braccia
        b.sphere(0.065, M((0.19 * x, 0, 0.955)), v["shoulder"], f"upperarm.{s}", seg=8, rings=5)
        b.rod((0.19 * x, 0, 0.96), (0.22 * x, -0.02, 0.78), 0.046, 8, v["arm"], f"upperarm.{s}", r2=0.042)
        b.sphere(0.045, M((0.22 * x, -0.02, 0.78)), v["arm"], f"forearm.{s}", seg=8, rings=5)
        b.rod((0.22 * x, -0.02, 0.78), (0.22 * x, 0.15, 0.725), 0.043, 8, v["arm"], f"forearm.{s}", r2=0.038)
        b.rod((0.22 * x, 0.04, 0.765), (0.22 * x, 0.14, 0.728), 0.048, 8, v["bracer"], f"forearm.{s}")
        b.sphere(0.052, M((0.22 * x, 0.19, 0.715)), "skin", f"hand.{s}", seg=8, rings=5, scale=(0.9, 1.1, 1))
    # bacino, gonnellino, busto
    b.cyl(0.13, 0.14, 0.14, 10, M((0, 0, 0.60), scale=(1, 0.8, 1)), v["pelvis"], "hips")
    skirt = v["skirt"]
    b.cyl(0.20, 0.15, 0.20, 12, M((0, 0, 0.50), scale=(1, 0.85, 1)),
          (lambda fi, f: skirt[fi % len(skirt)]) if isinstance(skirt, list) else skirt, "hips", smooth=False)
    b.cyl(0.152, 0.152, 0.05, 10, M((0, 0, 0.69), scale=(1, 0.82, 1)), v["belt"], "hips")
    b.cyl(0.145, 0.185, 0.24, 10, M((0, 0, 0.72), scale=(1, 0.78, 1)), v["torso"], "spine")
    b.cyl(0.185, 0.10, 0.07, 10, M((0, 0, 0.96), scale=(1, 0.78, 1)), v["torso"], "spine")
    if v.get("torso_detail"):
        v["torso_detail"](b)
    # collo e testa
    b.cyl(0.05, 0.048, 0.11, 8, M((0, 0, 0.98)), "skin", "neck")
    b.sphere(0.15, M((0, 0, 1.2)), "skin", "head", seg=10, rings=7, scale=(0.95, 1.0, 1.08))
    b.box((0.03, 0.04, 0.05), M((0, 0.15, 1.19), rot=(15, 0, 0)), "skin_dark", "head")  # naso
    for x in (1, -1):
        b.box((0.032, 0.02, 0.035), M((0.052 * x, 0.137, 1.225)), "eye", "head")
        b.box((0.05, 0.02, 0.014), M((0.052 * x, 0.138, 1.258)), v.get("brow", "hair"), "head")
    # mantello
    if v.get("cape"):
        c = v["cape"]

        def cape(u, vv):
            phi = -math.pi * (0.06 + 0.88 * u)
            r = 0.165 + 0.13 * vv + 0.018 * math.sin(u * math.pi * 6) * vv
            return (r * math.cos(phi) * 1.05, r * math.sin(phi) * 0.75 - 0.03 - 0.06 * vv, 1.0 - 0.56 * vv)
        b.slab(cape, 10, 3, 0.016, c, "cape")
        b.sphere(0.03, M((0.15, 0.06, 0.985)), "gold", "spine", seg=8, rings=4, scale=(1, 0.5, 1))
        b.sphere(0.03, M((-0.15, 0.06, 0.985)), "gold", "spine", seg=8, rings=4, scale=(1, 0.5, 1))


# ------------------------------------------------------------------ accessori
def corinthian_helmet(b, plume="plume", metal="bronze"):
    b.hemi(0.172, M((0, 0.005, 1.215)), metal, "head", seg=12, rings=4, cut=-0.05, scale=(1, 1.06, 1.08))
    for x in (1, -1):  # paraguance
        b.box((0.035, 0.12, 0.16), M((0.125 * x, 0.055, 1.13), rot=(0, 0, -12 * x)), metal, "head", bevel=0.01)
    b.box((0.25, 0.06, 0.13), M((0, -0.125, 1.15), rot=(-12, 0, 0)), metal, "head", bevel=0.01)  # paranuca
    b.box((0.03, 0.025, 0.07), M((0, 0.17, 1.2)), metal, "head")  # paranaso
    b.box((0.36, 0.03, 0.03), M((0, 0.17, 1.27)), "bronze_dark", "head")  # fascia sopracciglia
    b.rod((0, 0.02, 1.38), (0, 0.02, 1.43), 0.02, 6, metal, "head")
    b.rod((0, -0.15, 1.35), (0, -0.2, 1.39), 0.018, 6, metal, "head")

    def crest(u, v):
        y = 0.16 - 0.46 * u
        base = 1.405 + 0.035 * math.sin(math.pi * min(u * 1.3, 1)) - 0.08 * max(0, u - 0.75) * 4
        top = 1.50 + 0.07 * math.sin(math.pi * (0.1 + 0.75 * u)) - 0.12 * max(0, u - 0.8) * 5
        return (0, y, base + (top - base) * v)
    b.slab(crest, 8, 2, 0.055, plume, "head", smooth=True)


def phrygian_cap(b):
    b.hemi(0.168, M((0, -0.005, 1.205)), "ochre", "head", seg=12, rings=4, cut=-0.15, scale=(1, 1.05, 1.08))
    b.rod((0, -0.02, 1.33), (0, 0.06, 1.47), 0.10, 10, "ochre", "head", r2=0.035)
    b.sphere(0.04, M((0, 0.09, 1.46)), "ochre", "head", seg=8, rings=5)
    b.cyl(0.172, 0.172, 0.04, 12, M((0, -0.005, 1.20), scale=(1, 1.05, 1)), "troy_blue", "head", smooth=True)
    for x in (1, -1):  # bandelle laterali
        b.box((0.03, 0.08, 0.17), M((0.15 * x, 0.0, 1.10), rot=(0, 0, 0)), "ochre", "head", bevel=0.008)
    b.box((0.25, 0.04, 0.14), M((0, -0.14, 1.12)), "ochre_dark", "head", bevel=0.01)


def hair_and_beard(b):
    b.hemi(0.163, M((0, -0.012, 1.215), rot=(-18, 0, 0)), "hair", "head", seg=12, rings=4, cut=-0.1, scale=(1.03, 1.05, 1.1))
    for (x, y, z, r) in ((0.12, -0.06, 1.17, 0.06), (-0.12, -0.06, 1.17, 0.06), (0, -0.13, 1.16, 0.08),
                         (0.08, -0.12, 1.09, 0.06), (-0.08, -0.12, 1.09, 0.06), (0.1, 0.06, 1.33, 0.05),
                         (-0.06, 0.08, 1.35, 0.055), (0.03, 0.10, 1.34, 0.05)):
        b.sphere(r, M((x, y, z)), "hair", "head", seg=6, rings=4)
    b.sphere(0.152, M((0, -0.045, 1.17)), "hair", "head", seg=10, rings=6, scale=(1.0, 0.85, 1.0))  # nuca
    b.sphere(0.115, M((0, 0.065, 1.105)), "hair", "head", seg=10, rings=6, scale=(1.05, 0.72, 0.85))
    b.box((0.10, 0.03, 0.025), M((0, 0.147, 1.16)), "hair", "head")  # baffi


def round_shield(b, field, emblem, emblem_sw, rim="bronze", bone="forearm.L", loc=(-0.13, 0.28, 0.80), yaw=18, r=0.27):
    m = M(loc, rot=(-90, 0, yaw))
    b.cyl(r + 0.012, r + 0.012, 0.03, 18, m, rim, bone, smooth=False)
    b.cyl(r - 0.02, r - 0.05, 0.035, 18, m @ M((0, 0, 0.03)), field, bone, smooth=False)
    figurative = emblem is okit.HORSE_HEAD or emblem is okit.OWL
    if not figurative:  # umbone centrale solo con emblemi geometrici
        b.cyl(r * 0.18, r * 0.12, 0.02, 10, m @ M((0, 0, 0.065)), rim, bone)
    if emblem:
        em = m @ M((0, 0, 0.064), rot=(90, 0, 0))
        b.poly_extrude(okit.scaled(emblem, r * 1.05), 0.012, em, emblem_sw, bone)
        if emblem is okit.OWL:  # occhi del gufo
            for x in (1, -1):
                b.cyl(r * 0.11, r * 0.11, 0.008, 10, m @ M((x * 0.13 * r, -0.18 * r, 0.075)), "cream", bone, smooth=False)
                b.cyl(r * 0.05, r * 0.05, 0.008, 8, m @ M((x * 0.13 * r, -0.18 * r, 0.081)), "black", bone, smooth=False)
        if emblem is okit.HORSE_HEAD:  # occhio del cavallo
            b.cyl(r * 0.045, r * 0.045, 0.008, 8, m @ M((0.24 * r, -0.29 * r, 0.075)), "black", bone, smooth=False)
    # impugnatura dietro
    b.box((0.04, 0.04, 0.2), m @ M((0, 0, -0.03)), "leather", bone)


def spear(b, bone="hand.R", x=0.22):
    b.rod((x, 0.195, 0.05), (x, 0.205, 1.86), 0.017, 6, "wood", bone)
    b.rod((x, 0.205, 1.86), (x, 0.207, 2.04), 0.032, 6, "bronze", bone, r2=0.0)
    b.rod((x, 0.195, 0.05), (x, 0.195, -0.02), 0.022, 6, "bronze", bone, r2=0.004)
    b.rod((x, 0.199, 0.66), (x, 0.199, 0.78), 0.022, 6, "leather_dark", bone)


def sword(b, bone="hand.R", x=0.22):
    b.rod((x, 0.19, 0.66), (x, 0.205, 0.77), 0.016, 6, "leather_dark", bone)
    b.box((0.13, 0.03, 0.025), M((x, 0.205, 0.775)), "bronze", bone, bevel=0.006)
    b.rod((x, 0.205, 0.78), (x, 0.235, 1.20), 0.032, 4, "blade", bone, r2=0.006)
    b.sphere(0.022, M((x, 0.188, 0.655)), "bronze", bone, seg=6, rings=4)


def bow(b, bone="hand.L", x=-0.22):
    import math as m_
    pts = []
    for i in range(9):
        t = i / 8
        y = 0.19 - 0.11 * (1 - math.sin(math.pi * t)) + 0.03 * (abs(t - 0.5) > 0.42)
        z = 0.715 + (t - 0.5) * 0.95
        pts.append((x, y, z))
    for a, c in zip(pts, pts[1:]):
        b.rod(a, c, 0.016, 6, "wood_dark", bone)
    b.rod((x, 0.19, 0.67), (x, 0.19, 0.76), 0.024, 6, "leather", bone)
    b.rod(pts[0], pts[-1], 0.004, 4, "cream", bone, caps=False)


def quiver(b):
    a, c = (0.10, -0.17, 0.62), (-0.08, -0.19, 1.12)
    b.rod(a, c, 0.06, 8, "leather", "spine", r2=0.07)
    b.rod((0.09, -0.172, 0.66), (0.075, -0.174, 0.70), 0.064, 8, "ochre", "spine")
    for dx, dy in ((0.0, 0.0), (0.03, 0.02), (-0.025, 0.015), (0.01, -0.025)):
        tip = Vector(c) + Vector((dx, dy, 0)) + (Vector(c) - Vector(a)).normalized() * 0.12
        b.rod(Vector(c) + Vector((dx, dy, -0.02)), tip, 0.006, 4, "wood_light", "spine")
        b.box((1, 1, 1), look_m(tip - (Vector(c) - Vector(a)).normalized() * 0.07, tip, (0.008, 0.035)) @ M((0, 0, 0.5)), "feather", "spine")
    b.rod((0.17, 0.08, 0.98), (-0.15, -0.12, 0.66), 0.012, 4, "leather_dark", "spine")


def cuirass_detail(b, metal="bronze", trim="bronze_dark"):
    b.cyl(0.158, 0.192, 0.24, 10, M((0, 0, 0.725), scale=(1, 0.8, 1)), metal, "spine")
    b.cyl(0.192, 0.11, 0.075, 10, M((0, 0, 0.962), scale=(1, 0.8, 1)), metal, "spine")
    for x in (1, -1):  # pettorali e spallacci
        b.sphere(0.07, M((0.07 * x, 0.12, 0.90)), metal, "spine", seg=8, rings=5, scale=(1, 0.45, 0.8))
        b.box((0.09, 0.2, 0.025), M((0.12 * x, 0.0, 1.01), rot=(0, 10 * x, 0)), trim, "spine", bevel=0.006)
    b.cyl(0.162, 0.162, 0.03, 10, M((0, 0, 0.725), scale=(1, 0.81, 1)), trim, "spine")


def ulisse_detail(b):
    b.box((0.045, 0.02, 0.42), M((0.0, 0.135, 0.85), rot=(0, 38, 0)), "leather", "spine", bevel=0.005)
    b.box((0.045, 0.02, 0.42), M((0.0, -0.135, 0.85), rot=(0, -38, 0)), "leather", "spine", bevel=0.005)
    b.box((0.05, 0.02, 0.05), M((0.0, 0.142, 0.85)), "gold", "spine")


VARIANTS = {
    "oplita_acheo": dict(
        shoe="leather", shin="skin", greaves="bronze", knee="bronze", thigh="skin", shoulder="bronze",
        arm="skin", bracer="leather", pelvis="tunic", skirt=["tunic", "leather", "tunic", "red_dark"],
        belt="leather_dark", torso="tunic", torso_detail=cuirass_detail, cape="red",
        extra=lambda b: (corinthian_helmet(b), round_shield(b, "red", okit.star_points(0.42, 0.17, 8), "bronze"), spear(b)),
        attack="thrust"),
    "ulisse_oplita": dict(
        shoe="leather", shin="skin", greaves="leather", knee="skin", thigh="skin", shoulder="tunic",
        arm="skin", bracer="leather", pelvis="tunic", skirt="tunic", belt="leather", torso="tunic",
        torso_detail=ulisse_detail, cape="red",
        extra=lambda b: (hair_and_beard(b), round_shield(b, "bronze", okit.OWL, "gold", rim="bronze_dark"), sword(b)),
        attack="slash"),
    "arciere_troiano": dict(
        shoe="leather_dark", shin=None, knee="troy_blue_dark", thigh=None, shoulder="troy_blue",
        arm="skin", bracer="leather", pelvis="troy_blue", skirt=["troy_blue", "troy_blue", "ochre"], belt="ochre",
        torso="troy_blue", cape=None, brow="black",
        extra=lambda b: (phrygian_cap(b), bow(b), quiver(b)),
        attack="shoot"),
    "ufficiale_troiano": dict(
        shoe="leather", shin="skin", greaves="bronze", knee="bronze", thigh="skin", shoulder="gold",
        arm="skin", bracer="bronze", pelvis="troy_blue", skirt=["troy_blue", "ochre", "troy_blue", "ochre_dark"],
        belt="gold", torso="troy_blue", torso_detail=lambda b: cuirass_detail(b, "bronze", "gold"), cape="troy_blue",
        brow="black",
        extra=lambda b: (corinthian_helmet(b, plume="feather"), round_shield(b, "troy_blue", okit.HORSE_HEAD, "ochre", rim="gold"), sword(b)),
        attack="slash"),
}


def trousers_fix(v):
    # l'arciere porta brache a righe (anassiridi)
    if v["shin"] is None:
        stripes = lambda fi, f: ("ochre", "troy_blue_dark")[fi % 2]
        v["shin"] = stripes; v["thigh"] = stripes
    return v


# ------------------------------------------------------------------ animazione
class Poser:
    """Imposta rotazioni con nomi semantici, calibrando il segno sugli assi locali reali."""

    def __init__(self, arm):
        self.arm = arm
        self.sign = {}
        vl = bpy.context.view_layer
        for pb in arm.pose.bones:
            s = {}
            rest_tail = pb.tail.copy()
            d = (pb.bone.tail_local - pb.bone.head_local).normalized()
            horizontal = abs(d.z) < 0.7
            for ax in range(3):
                pb.rotation_euler = (0, 0, 0)
                e = [0, 0, 0]; e[ax] = math.radians(15)
                pb.rotation_euler = e
                vl.update()
                delta = pb.tail - rest_tail
                if ax == 0:
                    s["x"] = (1 if (delta.z if horizontal else delta.y) > 0 else -1)
                elif ax == 2:
                    side = 1 if pb.bone.head_local.x >= 0 else -1
                    if abs(pb.bone.head_local.x) < 1e-4:
                        side = 1
                    comp = delta.x * side if not horizontal else delta.x * side
                    s["z"] = 1 if comp > 0 else -1
                else:
                    # torsione: un punto a +X del bone deve andare verso -Y (girarsi a destra)
                    pb.rotation_euler = (0, 0, 0); vl.update()
                    m0 = pb.matrix.copy()
                    local = m0.inverted() @ (pb.head + Vector((0.1, 0, 0)))
                    pb.rotation_euler = e; vl.update()
                    p1 = pb.matrix @ local
                    s["y"] = 1 if p1.y < (pb.head.y) else -1
                pb.rotation_euler = (0, 0, 0)
            vl.update()
            self.sign[pb.name] = s

    def apply(self, spec):
        for pb in self.arm.pose.bones:
            sp = spec.get(pb.name, {})
            s = self.sign[pb.name]
            pb.rotation_euler = (math.radians(sp.get("x", 0)) * s["x"],
                                 math.radians(sp.get("tw", 0)) * s["y"],
                                 math.radians(sp.get("z", 0)) * s["z"])
            pb.location = (0, sp.get("up", 0), sp.get("fw", 0) * 0)
            if pb.name == "root":
                pb.location = (0, sp.get("up", 0), 0)


def mirror(spec):
    out = {}
    for k, v in spec.items():
        nk = k.replace(".R", ".TMP").replace(".L", ".R").replace(".TMP", ".L")
        nv = dict(v)
        if "tw" in nv:
            nv["tw"] = -nv["tw"]
        if "z" in nv and nk in ("spine", "hips", "neck", "head", "root"):
            nv["z"] = -nv["z"]
        out[nk] = nv
    return out


def walk_keys(v):
    contact = {
        "thigh.R": {"x": 26}, "shin.R": {"x": -6}, "foot.R": {"x": 14},
        "thigh.L": {"x": -22}, "shin.L": {"x": -28}, "foot.L": {"x": -10},
        "upperarm.R": {"x": -14}, "upperarm.L": {"x": 10},
        "hips": {"tw": -5, "up": -0.012}, "spine": {"tw": 7, "x": 4}, "cape": {"x": -10},
        "head": {"tw": -2},
    }
    passing = {
        "thigh.R": {"x": 2}, "shin.R": {"x": -4},
        "thigh.L": {"x": 8}, "shin.L": {"x": -48}, "foot.L": {"x": 12},
        "hips": {"up": 0.022}, "spine": {"x": 3}, "cape": {"x": -16},
    }
    return {0: contact, 6: passing, 12: mirror(contact), 18: mirror(passing), 24: contact}


def idle_keys(v):
    a = {}
    b = {"spine": {"x": 2.5}, "head": {"x": -2, "tw": 3}, "hips": {"up": -0.008},
         "upperarm.R": {"z": 2.5}, "upperarm.L": {"z": 2.5}, "cape": {"x": -4}, "neck": {"x": -1}}
    return {0: a, 24: b, 48: a}


def attack_keys(kind):
    if kind == "thrust":
        wind = {"upperarm.R": {"x": -35, "z": 10}, "forearm.R": {"x": 30}, "hand.R": {"x": -50},
                "spine": {"tw": 22}, "thigh.R": {"x": -10}, "thigh.L": {"x": 12}, "shin.L": {"x": -8},
                "upperarm.L": {"x": 10}, "hips": {"up": -0.02}, "cape": {"x": -8}}
        hit = {"upperarm.R": {"x": 50, "z": 4}, "forearm.R": {"x": -15}, "hand.R": {"x": -88},
               "spine": {"tw": -18, "x": 10}, "thigh.L": {"x": 32}, "shin.L": {"x": -12}, "thigh.R": {"x": -18},
               "shin.R": {"x": -10}, "hips": {"up": -0.05, "tw": -8}, "upperarm.L": {"x": 20}, "cape": {"x": -22}}
        return {0: {}, 6: wind, 10: hit, 14: hit, 22: {}}
    if kind == "slash":
        wind = {"upperarm.R": {"x": 40, "z": 55}, "forearm.R": {"x": 55}, "hand.R": {"x": 20},
                "spine": {"tw": 25, "x": -4}, "thigh.L": {"x": 10}, "upperarm.L": {"x": 15}, "cape": {"x": -6}}
        hit = {"upperarm.R": {"x": 55, "z": -5}, "forearm.R": {"x": -10}, "hand.R": {"x": -40},
               "spine": {"tw": -25, "x": 12}, "thigh.L": {"x": 28}, "shin.L": {"x": -10}, "thigh.R": {"x": -15},
               "hips": {"up": -0.04, "tw": -10}, "upperarm.L": {"x": 25}, "cape": {"x": -20}}
        return {0: {}, 6: wind, 10: hit, 14: hit, 22: {}}
    # shoot: arco
    draw = {"upperarm.L": {"x": 85, "z": 4}, "forearm.L": {"x": -55}, "hand.L": {"x": -30},
            "upperarm.R": {"x": 80, "z": 18}, "forearm.R": {"x": 95}, "hand.R": {"x": 10},
            "spine": {"tw": 28}, "head": {"tw": -24}, "thigh.L": {"x": 10}, "thigh.R": {"x": -6}}
    release = dict(draw); release["forearm.R"] = {"x": 120}; release["upperarm.R"] = {"x": 70, "z": 40}
    return {0: {}, 8: draw, 18: draw, 20: release, 24: release, 32: {}}


def hit_keys():
    h = {"spine": {"x": -16, "tw": 6}, "head": {"x": -12}, "hips": {"up": -0.02},
         "upperarm.R": {"z": 12}, "upperarm.L": {"z": 12}, "cape": {"x": 10}}
    return {0: {}, 3: h, 12: {}}


def death_keys():
    a = {"spine": {"x": -20}, "head": {"x": -15}, "thigh.R": {"x": 25}, "thigh.L": {"x": 10},
         "shin.R": {"x": -40}, "shin.L": {"x": -25}, "hips": {"up": -0.08}, "upperarm.R": {"z": 25}, "upperarm.L": {"z": 25}}
    b = {"root": {"x": -86}, "spine": {"x": -6}, "head": {"x": 10, "tw": 25}, "thigh.R": {"x": 15},
         "shin.R": {"x": -20}, "upperarm.R": {"z": 70}, "upperarm.L": {"z": 60}, "forearm.R": {"x": -30},
         "cape": {"x": 30}}
    return {0: {}, 8: a, 20: b, 30: b}


def make_actions(arm, v, prefix):
    poser = Poser(arm)
    ad = arm.animation_data_create()
    sets = [("idle_loop", idle_keys(v)), ("walk_loop", walk_keys(v)), ("attack", attack_keys(v["attack"])),
            ("hit", hit_keys()), ("death", death_keys())]
    acts = []
    for name, keys in sets:
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        ad.action = act
        for f, spec in sorted(keys.items()):
            poser.apply(spec)
            for pb in arm.pose.bones:
                pb.keyframe_insert("rotation_euler", frame=f, group=pb.name)
                pb.keyframe_insert("location", frame=f, group=pb.name)
        acts.append(act)
    ad.action = None
    for act in acts:
        tr = ad.nla_tracks.new(); tr.name = act.name
        st = tr.strips.new(act.name, int(act.frame_range[0]), act)
        tr.mute = True
    poser.apply({})
    return acts


# ------------------------------------------------------------------ main
def build(name):
    okit.reset()
    v = trousers_fix(dict(VARIANTS[name]))
    arm = build_armature(f"RIG_{name}")
    b = Builder()
    body(b, v)
    v["extra"](b)
    ob = b.build(f"SM_{name}")
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE"); mod.object = arm
    acts = make_actions(arm, v, name)
    tris = okit.tri_count(ob)
    okit.save_blend(f"personaggi/{name}.blend")
    p = okit.export_glb([arm], f"personaggi/{name}.glb", animations=True)
    print(f"OK {name} tris={tris} actions={[a.name for a in acts]} -> {p}")


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for n in (argv or list(VARIANTS)):
        build(n)
