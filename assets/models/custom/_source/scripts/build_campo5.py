"""Gruppo 5: vela quadra con sartiame, nave scura con occhio dipinto, barca a remi dell'epoca.

Uso (un solo Blender alla volta):  blender -b --factory-startup -P build_campo5.py -- [nome ...]
Modelli originali (modellati per il progetto): licenza del progetto.
"""
import bpy, sys, os, math
from mathutils import Vector, Matrix
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import okit2
from okit2 import G, M, finish

V = Vector


def hull_fns(L, b, top0, stern_rise, bow_rise, keel_stern, keel_bow, wexp=0.62):
    w = lambda s: b * math.sin(math.pi * s) ** wexp + 0.04
    top = lambda s: top0 + stern_rise * (max(0, 0.15 - s) / 0.15) ** 2 + bow_rise * (max(0, s - 0.88) / 0.12) ** 2
    keel = lambda s: 0.06 + keel_stern * (max(0, 0.12 - s) / 0.12) ** 1.5 + keel_bow * (max(0, s - 0.9) / 0.1) ** 1.5

    def P(u, v):
        s = 0.012 + 0.976 * u
        y = -L / 2 + L * s
        t, k = top(s), keel(s)
        h = 1 - abs(2 * v - 1)
        x = (-1 if v < 0.5 else 1) * w(s) * max(0.0, 1 - h ** 2.2) ** 0.5
        z = t - (t - k) * h
        return (x, y, z)
    return w, top, keel, P


def sail_set(g, mast_y, zy, W=5.8, H=4.9, belly=0.55, ground=None, top_mast=None):
    """Vela quadra su pennone, con vele di rinforzo, imbrogli e sartie. Ritorna la quota della cima dell'albero."""
    g.rod((-W / 2 - 0.35, mast_y, zy), (W / 2 + 0.35, mast_y, zy), 0.085, 0.07, 8, "bark")      # pennone
    def S(u, v):
        return (-W / 2 + W * u, mast_y + 0.18 + belly * math.sin(math.pi * u) ** 0.9 * math.sin(math.pi * (0.04 + 0.96 * v)) ** 0.8, zy - 0.06 - H * v)
    g.slab(S, 14, 10, 0.014, lambda i, j: "sail", tile=1.2)
    for u in (0.12, 0.31, 0.5, 0.69, 0.88):                                                   # imbrogli lungo la vela
        pts = [V(S(u, k / 8)) + V((0, 0.03, 0)) for k in range(9)]
        for a, b2 in zip(pts, pts[1:]):
            g.rod(a, b2, 0.011, 0.011, 4, "rope", caps=False)
    for u in (0.0, 1.0):                                                                       # ralinghe laterali
        pts = [V(S(u, k / 8)) for k in range(9)]
        for a, b2 in zip(pts, pts[1:]):
            g.rod(a, b2, 0.016, 0.016, 4, "rope", caps=False)
    g.rod(V(S(0, 1)), V(S(1, 1)), 0.02, 0.02, 4, "rope")
    return zy


def rigging(g, mast_y, z_top, pts_ground):
    for p in pts_ground:
        g.rod(V((0, mast_y, z_top)), V(p), 0.013, 0.013, 4, "rope", caps=False)


def nave(name="nave_scura_occhio", seed=121):
    g = G(seed)
    rnd = g.rnd
    L = 13.0
    w, top, keel, P = hull_fns(L, 1.5, 1.85, 1.35, 0.55, 0.8, 0.5)
    NV = 12
    g.slab(P, 28, NV, 0.07, lambda i, j: "hull_band" if j in (0, 1, NV - 2, NV - 1) else "hull_dark", tile=1.0)
    deck = lambda s: top(s) - 0.42
    # ponte, panche dei rematori, corrimano
    def D(u, v):
        s = 0.07 + 0.88 * u
        return ((2 * v - 1) * w(s) * 0.93, -L / 2 + L * s, deck(s))
    g.slab(D, 16, 3, 0.05, lambda i, j: "planks", tile=1.0)
    for k in range(13):
        s = 0.17 + k * 0.058
        y = -L / 2 + L * s
        g.box((2 * w(s) * 0.9, 0.24, 0.07), M((0, y, deck(s) + 0.5)), "planks")
    for sg in (-1, 1):
        prev = None
        for k in range(15):
            s = 0.02 + k * 0.068
            p = V((sg * w(s), -L / 2 + L * s, top(s) + 0.02))
            if prev is not None:
                g.rod(prev, p, 0.05, 0.05, 5, "hull_band" if False else "bark")
            prev = p
    # remi: 13 per lato, pale larghe
    for sg in (-1, 1):
        for k in range(13):
            s = 0.2 + k * 0.05
            y = -L / 2 + L * s
            zin = top(s) - 0.05
            a = V((sg * 0.55, y + 0.2, zin + 0.1))
            b2 = V((sg * (w(s) + 2.55), y - 0.45, 0.35 + 0.05 * (k % 3)))
            g.rod(a, b2, 0.032, 0.03, 6, "planks")
            d = (b2 - a).normalized()
            g.rod(b2 - d * 0.95, b2 + d * 0.05, 0.075, 0.06, 4, "planks")
            g.rod(V((sg * w(s), y, top(s) + 0.05)), a + d * 0.4, 0.02, 0.02, 4, "rope", caps=False)
    # timoni di poppa e aplustre
    for sg in (-1, 1):
        g.rod(V((sg * 0.7, -L / 2 + 0.2, 2.3)), V((sg * 1.0, -L / 2 - 1.2, 0.25)), 0.06, 0.05, 6, "planks")
        g.rod(V((sg * 1.0, -L / 2 - 1.05, 0.6)), V((sg * 1.02, -L / 2 - 1.35, 0.1)), 0.14, 0.1, 4, "planks")
    g.loft([((0, -L / 2 + 0.1, top(0.02) - 0.1), 0.06, 0.4), ((0, -L / 2 - 0.15, top(0.0) + 0.3), 0.05, 0.38), ((0, -L / 2 - 0.35, top(0.0) + 0.9), 0.04, 0.3),
            ((0, -L / 2 - 0.1, top(0.0) + 1.4), 0.035, 0.18)], 8, "hull_band", dens=3)
    # rostro di bronzo e dritto di prua
    g.rod(V((0, L / 2 - 0.9, 0.38)), V((0, L / 2 + 1.0, 0.3)), 0.2, 0.04, 8, "bronze")
    g.box((0.6, 0.12, 0.08), M((0, L / 2 + 0.55, 0.34)), "bronze")
    g.rod(V((0, L / 2 - 0.2, top(0.99) - 0.2)), V((0, L / 2 + 0.25, top(0.99) + 0.8)), 0.09, 0.05, 6, "bark")
    # occhi dipinti sulle fiancate di prua
    for sg, rz in ((1, 90), (-1, -90)):
        s = 0.84
        p = V(P(s, 0.17 if sg < 0 else 0.83))
        g.quad(1.55, 0.88, M((p.x + sg * 0.07, p.y, p.z - 0.5), (0, 0, rz)), "eye")
    # albero, vela quadra, sartiame
    my = 0.4
    g.rod(V((0, my, deck(0.5) - 0.2)), V((0, my, 9.2)), 0.12, 0.07, 10, "bark")
    sail_set(g, my, 8.4, 5.9, 5.0)
    for sg in (-1, 1):
        for y in (-1.6, 0.6, 2.8):
            s = (y + L / 2) / L
            g.rod(V((0, my, 8.9)), V((sg * w(s) * 0.98, y, top(s))), 0.013, 0.013, 4, "rope", caps=False)
    g.rod(V((0, my, 9.1)), V((0, L / 2 + 0.2, top(0.99) + 0.7)), 0.015, 0.015, 4, "rope", caps=False)
    g.rod(V((0, my, 9.1)), V((0, -L / 2, top(0.0) + 1.2)), 0.015, 0.015, 4, "rope", caps=False)
    return finish(g, name, "navi")


def vela(name="vela_quadra_sartiame", seed=122):
    g = G(seed)
    g.box((1.3, 1.3, 0.28), M((0, 0, 0.14)), "planks")
    g.rod(V((0, 0, 0.2)), V((0, 0, 9.0)), 0.12, 0.07, 10, "bark")
    sail_set(g, 0.0, 8.2, 5.8, 4.9)
    for ang in (35, 145, 215, 325):                                  # sartie a quattro picchetti
        a = math.radians(ang)
        gp = V((2.6 * math.cos(a), 2.6 * math.sin(a), 0.0))
        g.rod(V((0, 0, 8.7)), gp + V((0, 0, 0.1)), 0.013, 0.013, 4, "rope", caps=False)
        g.rod(gp, gp + V((0.0, 0.0, 0.35)), 0.04, 0.035, 5, "bark")
    return finish(g, name, "navi")


def barca(name="barca_a_remi", seed=123):
    g = G(seed)
    L = 5.6
    w, top, keel, P = hull_fns(L, 0.88, 0.85, 0.55, 0.5, 0.25, 0.3, wexp=0.7)
    NV = 10
    g.slab(P, 22, NV, 0.045, lambda i, j: "hull_band" if j in (0, NV - 1) else "planks", tile=1.0)
    g.box((1.2, L * 0.7, 0.04), M((0, 0, keel(0.5) + 0.12)), "planks")                 # fondo
    for k in range(3):
        s = 0.3 + 0.2 * k
        y = -L / 2 + L * s
        g.box((2 * w(s) * 0.97, 0.26, 0.05), M((0, y, top(s) - 0.28)), "planks")
    for sg in (-1, 1):
        for s in (0.38, 0.62):
            y = -L / 2 + L * s
            g.rod(V((sg * w(s), y, top(s) + 0.02)), V((sg * w(s), y, top(s) + 0.2)), 0.02, 0.02, 4, "bark")        # scalmi
        a = V((sg * 0.08, -L / 2 + 0.15, top(0.4) + 0.05))
        b2 = V((sg * (w(0.55) + 1.15), -L / 2 + 3.0, top(0.55) + 0.1))
        g.rod(a, b2, 0.028, 0.026, 6, "planks")
        g.rod(b2 - (b2 - a).normalized() * 0.7, b2 + (b2 - a).normalized() * 0.4, 0.07, 0.055, 4, "planks")
    sp = 0.93
    p = V(P(sp, 0.25))
    g.quad(0.5, 0.3, M((-w(sp) + 0.02 - 0.02, p.y, p.z - 0.1), (0, 0, -90)), "eye")
    p2 = V(P(sp, 0.75))
    g.quad(0.5, 0.3, M((w(sp) - 0.02 + 0.02, p2.y, p2.z - 0.1), (0, 0, 90)), "eye")
    g.rod(V((0, L / 2 - 0.1, keel(0.99))), V((0, L / 2 + 0.28, top(0.99) + 0.2)), 0.06, 0.03, 6, "bark")
    g.rod(V((0, L / 2 - 0.3, 0.12)), V((0, L / 2 + 0.2, 0.18)), 0.05, 0.02, 5, "rope")
    return finish(g, name, "navi")


ALL = {
    "nave_scura_occhio": lambda: nave(),
    "vela_quadra_sartiame": lambda: vela(),
    "barca_a_remi": lambda: barca(),
}

if __name__ == "__main__":
    names = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(ALL)
    for n in names:
        okit2.reset()
        ALL[n]()
