"""Oggetti di scena: tende a padiglione, rastrelliera per lance, carro coperto, trireme,
scudi e stendardi achei e troiani.

Uso: blender -b --factory-startup -P build_props.py [-- nome ...]
Metri, origine alla base (z = 0), fronte verso +Y in Blender (= -Z in Godot).
"""
import bpy, sys, os, math
from mathutils import Vector
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import okit
from okit import Builder, M, look_m
from build_characters import round_shield

STRIPE = ("red", "cream")


# ------------------------------------------------------------------ tende
def tenda(R=1.3, seg=16, wall=1.1, roof=1.15):
    b = Builder()
    stripe = lambda fi, f: STRIPE[fi % 2]
    b.cyl(R, R, wall, seg, M(rot=(0, 0, 180 / seg)), stripe, smooth=False, caps=False)
    b.cyl(R * 0.99, R * 0.99, 0.02, seg, M(rot=(0, 0, 180 / seg)), "canvas_dark", smooth=False)  # pavimento
    # tetto a cono con leggera curvatura, strisce alterne
    def roof_p(u, v):
        a = 2 * math.pi * u + math.pi / seg
        r = R * 1.07 * (1 - v * 0.97)
        z = wall + roof * v - 0.10 * math.sin(math.pi * v)
        return (r * math.cos(a), r * math.sin(a), z)
    b.slab(roof_p, seg, 3, 0.03, lambda i, j: STRIPE[i % 2], smooth=False)
    # balza smerlata sotto la gronda
    for k in range(seg):
        a = 2 * math.pi * (k + 0.5) / seg + math.pi / seg - math.pi / seg
        c = Vector((math.cos(a), math.sin(a), 0)) * (R * 1.075)
        tri = [(-math.pi * R / seg, 0.0), (math.pi * R / seg, 0.0), (0.0, -0.17)]
        b.poly_extrude(tri, 0.02, M((c.x, c.y, wall + 0.005), rot=(0, 0, math.degrees(a) - 90)),
                       ("cream", "red")[k % 2])
    b.cyl(R * 1.075, R * 1.075, 0.05, seg, M((0, 0, wall - 0.02), rot=(0, 0, 180 / seg)), "gold", smooth=False, caps=False)
    # ingresso (+Y): apertura scura e lembi ripiegati
    b.box((0.62, 0.04, 0.95), M((0, R * 0.985, 0.47)), "pitch")
    for x in (1, -1):
        b.poly_extrude([(0, 0), (0.36 * x, 0), (0, 0.95)], 0.025, M((0.31 * x, R * 0.99 + 0.005, 0.0), rot=(0, 0, 0)), "red_dark")
    # palo, pinnacolo e pennone
    top = wall + roof
    b.rod((0, 0, top - 0.1), (0, 0, top + 0.45), 0.035, 6, "wood_dark")
    b.sphere(0.06, M((0, 0, top + 0.47)), "gold", seg=8, rings=5)
    b.slab(lambda u, v: (0.04 + 0.45 * u, 0.04 * math.sin(u * 5), top + 0.40 - 0.18 * v * (1 - 0.6 * u) - 0.0),
           6, 1, 0.012, "red")
    # tiranti e picchetti
    for k in range(6):
        a = 2 * math.pi * (k + 0.5) / 6
        d = Vector((math.cos(a), math.sin(a), 0))
        if d.y > 0.85:
            continue
        p0 = d * R * 1.06 + Vector((0, 0, wall + 0.02))
        p1 = d * R * 1.75
        b.rod(p0, p1 + Vector((0, 0, 0.12)), 0.008, 4, "rope", caps=False)
        b.rod(p1 - Vector((0, 0, 0.05)), p1 + Vector((0, 0, 0.16)), 0.022, 5, "wood")
    return b


# ------------------------------------------------------------------ rastrelliera
def rastrelliera():
    b = Builder()
    W = 1.5
    for x in (W / 2, -W / 2):
        b.box((0.08, 0.08, 1.3), M((x, 0, 0.65)), "wood", bevel=0.01)
        b.box((0.1, 0.7, 0.08), M((x, 0, 0.04)), "wood_dark", bevel=0.01)
        b.box((0.06, 0.06, 0.55), M((x, 0.17, 0.25), rot=(32, 0, 0)), "wood_dark", bevel=0.008)
        b.box((0.06, 0.06, 0.55), M((x, -0.17, 0.25), rot=(-32, 0, 0)), "wood_dark", bevel=0.008)
        b.box((0.12, 0.12, 0.05), M((x, 0, 1.31)), "wood_dark", bevel=0.01)
    b.box((W + 0.14, 0.09, 0.07), M((0, 0, 1.15)), "wood", bevel=0.01)       # traversa alta
    b.box((W + 0.1, 0.32, 0.06), M((0, 0, 0.22)), "wood_light", bevel=0.01)  # piano basso
    b.box((W + 0.1, 0.03, 0.10), M((0, 0.15, 0.28)), "wood", bevel=0.005)
    b.box((W + 0.1, 0.03, 0.10), M((0, -0.15, 0.28)), "wood", bevel=0.005)
    b.box((W * 0.98, 0.02, 0.03), M((0, 0, 1.12)), "rope")                     # legatura
    n = 7
    for k in range(n):
        x = -W / 2 + 0.17 + k * (W - 0.34) / (n - 1)
        lean = 0.06 if k % 2 else -0.04
        top = 2.05 + (0.1 if k % 3 == 0 else 0)
        a = Vector((x, lean * 0.3, 0.25)); c = Vector((x + (0.03 if k % 2 else -0.02), lean * 2.4, top))
        b.rod(a, c, 0.017, 6, "wood")
        d = (c - a).normalized()
        b.rod(c, c + d * 0.17, 0.032, 6, "bronze" if k % 2 else "iron", r2=0.0)
        b.rod(c - d * 0.9, c - d * 0.78, 0.021, 6, "leather_dark")
        b.box((0.03, 0.03, 0.03), M(tuple(a + d * 0.9)), "wood_dark")
    # pioli sulla traversa
    for k in range(n):
        x = -W / 2 + 0.17 + k * (W - 0.34) / (n - 1)
        for y in (0.06, -0.06):
            b.rod((x - 0.07 if y > 0 else x + 0.07, y, 1.15), (x - 0.07 if y > 0 else x + 0.07, y * 2.2, 1.21), 0.012, 4, "wood_dark")
    # scudo appoggiato
    round_shield(b, "red", okit.star_points(0.42, 0.17, 8), "bronze", bone=None, loc=(0.45, 0.30, 0.28), yaw=8, r=0.27)
    return b


# ------------------------------------------------------------------ carro coperto
def wheel(b, c, r=0.42, side=1):
    m = M(c, rot=(0, 90, 0))
    n = 14
    for k in range(n):
        a0, a1 = 2 * math.pi * k / n, 2 * math.pi * (k + 1) / n
        p0 = Vector((math.cos(a0) * r, math.sin(a0) * r, 0)); p1 = Vector((math.cos(a1) * r, math.sin(a1) * r, 0))
        mid = (p0 + p1) / 2; L = (p1 - p0).length
        b.box((L * 1.08, 0.07, 0.07), m @ M(tuple(mid), rot=(0, 0, math.degrees((a0 + a1) / 2) + 90)), "wood_dark")
    b.cyl(0.08, 0.08, 0.14, 8, m @ M((0, 0, -0.07)), "wood", smooth=False)
    b.cyl(0.05, 0.05, 0.18, 8, m @ M((0, 0, -0.04)), "iron", smooth=False)
    for k in range(6):
        a = 2 * math.pi * k / 6
        b.rod(m @ Vector((math.cos(a) * 0.07, math.sin(a) * 0.07, 0)), m @ Vector((math.cos(a) * (r - 0.03), math.sin(a) * (r - 0.03), 0)), 0.02, 4, "wood")


def carro():
    b = Builder()
    zc = 0.456
    for x in (0.66, -0.66):
        for y in (0.62, -0.62):
            wheel(b, (x, y, zc), 0.42)
    for y in (0.62, -0.62):
        b.rod((-0.78, y, zc), (0.78, y, zc), 0.035, 6, "wood_dark")
    b.box((1.1, 2.0, 0.12), M((0, 0, 0.62)), "wood", bevel=0.015)
    for x in (0.53, -0.53):  # sponde
        b.box((0.05, 2.0, 0.26), M((x, 0, 0.80)), "wood_light", bevel=0.01)
        for y in (-0.9, -0.3, 0.3, 0.9):
            b.box((0.07, 0.06, 0.32), M((x * 1.02, y, 0.79)), "wood_dark")
    b.box((1.1, 0.05, 0.26), M((0, -0.98, 0.80)), "wood_light", bevel=0.01)
    b.box((1.1, 0.05, 0.18), M((0, 0.98, 0.76)), "wood_light", bevel=0.01)
    # telone su archi
    zc2, rr = 0.88, 0.60
    def cover(u, v):
        a = math.pi * u
        y = -0.92 + 1.84 * v
        r = rr + 0.025 * math.sin(v * math.pi * 7) * math.sin(a)
        return (math.cos(a) * r, y, zc2 + math.sin(a) * r * 1.05)
    b.slab(cover, 8, 7, 0.025, lambda i, j: "canvas" if j % 2 else "canvas_dark", smooth=True)
    for y in (-0.9, -0.3, 0.3, 0.9):
        pts = [(math.cos(math.pi * k / 8) * (rr + 0.04), y, zc2 + math.sin(math.pi * k / 8) * (rr + 0.04) * 1.05) for k in range(9)]
        for a, c in zip(pts, pts[1:]):
            b.rod(a, c, 0.018, 4, "rope")
    # apertura anteriore scura (niente sacchi: le sfere grezze dentro il carro erano mal disegnate)
    semi = [(math.cos(math.pi * k / 8) * (rr - 0.04), math.sin(math.pi * k / 8) * (rr - 0.04) * 1.05) for k in range(9)]
    b.poly_extrude(semi, 0.02, M((0, 0.90, zc2)), "pitch")
    # timone e giogo
    b.rod((0, 0.95, 0.55), (0, 2.0, 0.48), 0.04, 6, "wood")
    b.rod((-0.4, 1.95, 0.5), (0.4, 1.95, 0.5), 0.035, 6, "wood_dark")
    for x in (-0.3, 0.3):
        b.rod((x, 1.95, 0.5), (x, 1.98, 0.3), 0.02, 4, "wood_dark")
    return b


# ------------------------------------------------------------------ trireme
def trireme():
    b = Builder()
    L = 10.0

    def w(s):
        return 1.15 * math.sin(math.pi * s) ** 0.6 + 0.05

    def top(s):
        return 1.25 + 0.75 * (max(0, 0.16 - s) / 0.16) ** 2 + 0.35 * (max(0, s - 0.86) / 0.14) ** 2

    def keel(s):
        return 0.0 + 0.55 * (max(0, 0.12 - s) / 0.12) ** 1.5 + 0.25 * (max(0, s - 0.9) / 0.1) ** 1.5

    def hull(u, v):
        s = 0.01 + 0.98 * u
        y = -L / 2 + L * s
        t, k = top(s), keel(s)
        h = 1 - abs(2 * v - 1)          # 0 al bordo superiore, 1 sulla chiglia
        x = (-1 if v < 0.5 else 1) * w(s) * max(0.0, 1 - h ** 2.2) ** 0.5
        z = t - (t - k) * h
        return (x, y, z)

    def hull_sw(i, j):
        nv = 10
        kk = min(j, nv - 1 - j)
        return ("red", "hull", "hull_dark", "pitch", "pitch")[min(kk, 4)]
    b.slab(hull, 22, 10, 0.07, hull_sw, smooth=True)
    # ponte
    b.slab(lambda u, v: (w(0.06 + 0.88 * u) * 0.92 * (2 * v - 1), -L / 2 + L * (0.06 + 0.88 * u), top(0.06 + 0.88 * u) - 0.12),
           16, 2, 0.05, lambda i, j: "wood_light" if i % 2 else "wood", smooth=False)
    # postazione dei rematori (parexeiresia) e scudi lungo la murata
    for sd in (1, -1):
        b.slab(lambda u, v, sd=sd: (sd * (w(0.18 + 0.64 * u) + 0.10), -L / 2 + L * (0.18 + 0.64 * u),
                                    top(0.18 + 0.64 * u) - 0.28 + 0.2 * v), 10, 1, 0.06, "teal_paint", smooth=True)
        for k in range(8):
            s = 0.24 + k * 0.074
            y = -L / 2 + L * s
            m = M((sd * (w(s) + 0.14), y, top(s) - 0.05), rot=(0, 90 * sd, 0))
            b.cyl(0.19, 0.17, 0.04, 12, m, "bronze_dark", smooth=False)
            b.cyl(0.16, 0.13, 0.03, 12, m @ M((0, 0, 0.03)), ("red", "bronze")[k % 2], smooth=False)
        # remi su due file
        for row in range(2):
            for k in range(11):
                s = 0.2 + k * 0.058 + row * 0.025
                y = -L / 2 + L * s
                x0 = sd * (w(s) + 0.12)
                z0 = top(s) - 0.22 - 0.22 * row
                p0 = Vector((x0, y, z0))
                p1 = Vector((sd * (w(s) + 2.0 + 0.3 * row), y - 0.25, 0.25 - 0.08 * row))
                b.rod(p0 - (p1 - p0).normalized() * 0.4, p1, 0.022, 4, "wood_light")
                d = (p1 - p0).normalized()
                b.box((1, 1, 1), look_m(p1 - d * 0.1, p1 + d * 0.35, (0.03, 0.15)) @ M((0, 0, 0.5)), "wood")
        # occhio apotropaico a prua
        s = 0.9
        y = -L / 2 + L * s
        pe = Vector((sd * (w(s) + 0.035), y, top(s) - 0.33))
        b.cyl(0.13, 0.13, 0.02, 12, M(tuple(pe), rot=(0, 90 * sd, 0)), "white_paint", smooth=False)
        b.cyl(0.065, 0.065, 0.02, 10, M(tuple(pe + Vector((sd * 0.012, 0.02, 0))), rot=(0, 90 * sd, 0)), "black", smooth=False)
        # remo-timone a poppa
        sp = 0.07; ys = -L / 2 + L * sp
        a = Vector((sd * (w(sp) + 0.1), ys + 0.2, top(sp) + 0.1)); c = Vector((sd * (w(sp) + 0.55), ys - 1.0, 0.05))
        b.rod(a, c, 0.04, 6, "wood_dark")
        d = (c - a).normalized()
        b.box((1, 1, 1), look_m(c - d * 0.75, c + d * 0.05, (0.06, 0.3)) @ M((0, 0, 0.5)), "wood_dark")
    # rostro di bronzo
    yb = L / 2
    b.rod((0, yb - 0.6, 0.42), (0, yb + 0.85, 0.32), 0.2, 6, "bronze", r2=0.03)
    b.box((0.55, 0.12, 0.08), M((0, yb + 0.55, 0.36)), "bronze", bevel=0.02)
    # aplustre di poppa (ricciolo) e ornamento di prua
    def stern(u, v):
        t = u
        ang = math.pi * 0.25 + math.pi * 0.95 * t
        r = 1.2 - 0.6 * t
        return (0, -L / 2 + 0.6 - r * math.cos(ang) * 0.9 + 0.2 * t, top(0.0) - 0.4 + r * math.sin(ang) + 0.9 * t + 0.0 * v)
    b.slab(lambda u, v: (-0.11 + 0.22 * v, *stern(u, 0)[1:]), 10, 1, 0.08, "hull_dark", smooth=True)
    b.slab(lambda u, v: (0, L / 2 - 0.5 + 0.55 * u + 0.15 * u * u, top(1.0) - 0.25 + 0.6 * u * u + 0.2 * v * (1 - u)), 5, 1, 0.1, "hull_dark")
    # albero, pennone e vela rossa
    ym = 0.6
    b.rod((0, ym, top(0.56) - 0.2), (0, ym, 7.1), 0.09, 8, "wood", r2=0.06)
    b.rod((-2.7, ym + 0.12, 6.6), (2.7, ym + 0.12, 6.6), 0.06, 6, "wood_dark")
    def sail(u, v):
        x = -2.55 + 5.1 * u
        z = 6.52 - 3.3 * v
        y = ym + 0.2 + 0.55 * math.sin(math.pi * u) * math.sin(math.pi * (0.15 + 0.85 * v)) ** 0.8
        return (x, y, z)
    b.slab(sail, 10, 5, 0.03, lambda i, j: "red_dark" if i in (0, 9) or j == 4 else ("sail_red" if (i // 2) % 2 == 0 else "red"), smooth=True)
    # sartiame
    for p0, p1 in (((0, ym, 7.0), (0, L / 2 - 0.4, top(1.0) - 0.1)), ((0, ym, 7.0), (0, -L / 2 + 0.9, top(0.06))),
                   ((2.6, ym + 0.12, 6.6), (1.0, -1.8, top(0.3))), ((-2.6, ym + 0.12, 6.6), (-1.0, -1.8, top(0.3))),
                   ((2.4, ym + 0.6, 3.25), (1.05, 2.8, top(0.78))), ((-2.4, ym + 0.6, 3.25), (-1.05, 2.8, top(0.78)))):
        b.rod(p0, p1, 0.012, 4, "rope", caps=False)
    # cabina/seduta del timoniere
    b.box((0.9, 0.7, 0.35), M((0, -L / 2 + 1.6, top(0.16) - 0.0)), "wood_dark", bevel=0.03)
    return b


# ------------------------------------------------------------------ scudi e stendardi
SHIELDS = {
    "scudo_acheo": ("red", okit.star_points(0.42, 0.17, 8), "bronze", "bronze"),
    "scudo_ulisse": ("bronze", okit.OWL, "gold", "bronze_dark"),
    "scudo_troiano": ("troy_blue", okit.HORSE_HEAD, "ochre", "gold"),
}


def scudo(name):
    field, emb, esw, rim = SHIELDS[name]
    b = Builder()
    r = 0.42  # scudo hoplon reale, circa 0,85-0,9 m di diametro
    round_shield(b, field, emb, esw, rim=rim, bone=None, loc=(0, -0.03, r + 0.012), yaw=0, r=r)
    return b


def stendardo(team):
    field, dark, emb, esw, trim = (("red", "red_dark", okit.star_points(0.5, 0.2, 8), "gold", "gold") if team == "acheo"
                                    else ("troy_blue", "troy_blue_dark", okit.HORSE_HEAD, "ochre", "ochre"))
    b = Builder()
    b.box((0.36, 0.36, 0.18), M((0, 0, 0.09)), "stone", bevel=0.03)
    b.box((0.26, 0.26, 0.08), M((0, 0, 0.21)), "stone", bevel=0.02)
    b.rod((0, 0, 0.2), (0, 0, 2.75), 0.035, 6, "wood_dark")
    b.rod((-0.42, 0.04, 2.45), (0.42, 0.04, 2.45), 0.025, 6, "wood_dark")
    for x in (-0.42, 0.42):
        b.sphere(0.035, M((x, 0.04, 2.45)), "gold", seg=6, rings=4)
    b.rod((0, 0, 2.75), (0, 0, 2.95), 0.045, 6, "bronze", r2=0.0)
    b.sphere(0.05, M((0, 0, 2.75)), "gold", seg=8, rings=5)
    W, H = 0.74, 1.15

    def cloth(u, v):
        x = -W / 2 + W * u
        bottom = H + 0.16 * (abs(2 * u - 1)) - 0.0
        z = 2.43 - bottom * v
        y = 0.06 + 0.018 * math.sin(u * 6.0 + v * 2.0) * v
        return (x, y, z)
    b.slab(cloth, 8, 6, 0.018, lambda i, j: trim if i in (0, 7) else (dark if j == 5 else field), smooth=True)
    b.poly_extrude(okit.scaled(emb, 0.42), 0.01, M((0, 0.074, 1.8)), esw)
    for x in (-0.25, 0.25):  # nappe
        b.rod((x, 0.06, 2.43 - H - 0.16 * abs(2 * (x / W + 0.5) - 1)), (x, 0.06, 2.43 - H - 0.3), 0.012, 4, trim)
    return b


def drappo(team):
    field, dark, emb, esw, trim = (("red", "red_dark", okit.star_points(0.5, 0.2, 8), "gold", "gold") if team == "acheo"
                                    else ("troy_blue", "troy_blue_dark", okit.HORSE_HEAD, "ochre", "ochre"))
    b = Builder()
    W, H = 0.8, 1.55
    b.rod((-W / 2 - 0.08, 0.05, H + 0.02), (W / 2 + 0.08, 0.05, H + 0.02), 0.025, 6, "wood_dark")
    for x in (-W / 2 - 0.08, W / 2 + 0.08):
        b.sphere(0.04, M((x, 0.05, H + 0.02)), "gold", seg=6, rings=4)

    def cloth(u, v):
        x = -W / 2 + W * u
        z = H - (H - 0.22 * (1 - abs(2 * u - 1))) * v  # punta a V verso il basso
        y = 0.05 + 0.012 * math.sin(u * 7 + 1.0) * v
        return (x, y, z)
    b.slab(cloth, 8, 6, 0.016, lambda i, j: trim if (i in (0, 7) or j == 0) else field, smooth=True)
    b.poly_extrude(okit.scaled(emb, 0.46), 0.01, M((0, 0.063, H - 0.6)), esw)
    return b


ASSETS = {
    "tenda_padiglione": ("accampamento", lambda: tenda()),
    "tenda_padiglione_piccola": ("accampamento", lambda: tenda(R=0.85, seg=12, wall=0.95, roof=0.9)),
    "rastrelliera_lance": ("accampamento", rastrelliera),
    "carro_coperto": ("accampamento", carro),
    "trireme": ("navi", trireme),
    "scudo_acheo": ("stendardi", lambda: scudo("scudo_acheo")),
    "scudo_ulisse": ("stendardi", lambda: scudo("scudo_ulisse")),
    "scudo_troiano": ("stendardi", lambda: scudo("scudo_troiano")),
    "stendardo_acheo": ("stendardi", lambda: stendardo("acheo")),
    "stendardo_troiano": ("stendardi", lambda: stendardo("troiano")),
    "drappo_muro_acheo": ("stendardi", lambda: drappo("acheo")),
    "drappo_muro_troiano": ("stendardi", lambda: drappo("troiano")),
}


def build(name):
    okit.reset()
    cat, fn = ASSETS[name]
    ob = fn().build(f"SM_{name}")
    tris = okit.tri_count(ob)
    d = ob.dimensions
    okit.save_blend(f"{cat}/{name}.blend")
    p = okit.export_glb([ob], f"{cat}/{name}.glb")
    print(f"OK {name} tris={tris} dim=({d.x:.2f},{d.y:.2f},{d.z:.2f}) minz={min((ob.matrix_world @ v.co).z for v in ob.data.vertices):.3f} -> {p}")


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for n in (argv or list(ASSETS)):
        build(n)
