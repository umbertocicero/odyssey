"""Gruppo 3: cavallo realistico (due mantelli) e carro da guerra miceneo.

Uso (un solo Blender alla volta):  blender -b --factory-startup -P build_campo3.py -- [nome ...]
Modelli originali (modellati per il progetto): licenza del progetto.
"""
import bpy, sys, os, math
from mathutils import Vector, Matrix
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import okit2
from okit2 import G, M, finish

V = Vector


def horse(name, coat="horse_bay", points="horse_dark", mane_mat="mane_dark", seed=81, scale=1.0):
    g = G(seed)
    rnd = g.rnd
    # corpo + collo (unica forma continua), poi testa
    body = [((0, -0.88, 1.28), 0.19, 0.19), ((0, -0.72, 1.31), 0.26, 0.30), ((0, -0.42, 1.22), 0.285, 0.335),
            ((0, -0.05, 1.17), 0.27, 0.335), ((0, 0.30, 1.16), 0.265, 0.345), ((0, 0.58, 1.22), 0.25, 0.355),
            ((0, 0.80, 1.34), 0.195, 0.31), ((0, 0.98, 1.51), 0.15, 0.275), ((0, 1.15, 1.69), 0.125, 0.23),
            ((0, 1.28, 1.80), 0.11, 0.195)]
    g.loft(body, 20, coat, dens=3)
    head = [((0, 1.24, 1.84), 0.095, 0.14), ((0, 1.34, 1.80), 0.112, 0.175), ((0, 1.45, 1.70), 0.10, 0.165),
            ((0, 1.55, 1.57), 0.076, 0.112), ((0, 1.63, 1.46), 0.067, 0.087), ((0, 1.675, 1.405), 0.062, 0.078)]
    g.loft(head, 16, coat, dens=3)
    for s in (-1, 1):                                    # masse muscolari: spalla, avambraccio, coscia
        g.blob((0.1, 0.2, 0.22), M((s * 0.15, 0.52, 1.22)), coat, 12, 8, 0.01)
        g.blob((0.085, 0.12, 0.2), M((s * 0.15, 0.52, 0.98)), coat, 10, 7, 0.01)
        g.blob((0.13, 0.22, 0.3), M((s * 0.17, -0.56, 1.12), (8, 0, 0)), coat, 12, 8, 0.01)
    fr = lambda s: [((s * 0.15, 0.50, 1.10), 0.115, 0.125), ((s * 0.145, 0.52, 0.82), 0.085, 0.095), ((s * 0.14, 0.52, 0.52), 0.064, 0.072),
                    ((s * 0.14, 0.51, 0.40), 0.05, 0.056), ((s * 0.14, 0.51, 0.14), 0.04, 0.045), ((s * 0.14, 0.52, 0.09), 0.052, 0.056)]
    hd = lambda s: [((s * 0.17, -0.55, 1.15), 0.135, 0.15), ((s * 0.16, -0.62, 0.86), 0.095, 0.125), ((s * 0.15, -0.76, 0.56), 0.065, 0.078),
                    ((s * 0.145, -0.70, 0.40), 0.048, 0.056), ((s * 0.145, -0.68, 0.14), 0.04, 0.045), ((s * 0.145, -0.67, 0.09), 0.052, 0.056)]
    for s in (-1, 1):
        for fn in (fr, hd):
            pts = fn(s)
            g.loft(pts[:3], 12, coat, dens=3)
            g.loft(pts[2:], 12, points, dens=3)
            g.cyl(0.066, 0.078, 0.09, 12, M((s * 0.142, pts[-1][0][1], 0.0)), "hoof")
    # orecchie, occhi, narici
    for s in (-1, 1):
        g.rod((s * 0.05, 1.27, 1.90), (s * 0.075, 1.285, 2.03), 0.026, 0.006, 6, coat)
        g.blob((0.012, 0.012, 0.012), M((s * 0.108, 1.39, 1.755)), "hoof", 6, 4, 0.0)
        g.blob((0.022, 0.016, 0.014), M((s * 0.04, 1.63, 1.465)), "hoof", 6, 4, 0.0)
    # criniera lungo il collo e ciuffo, coda con volume
    for k in range(18):
        t = k / 17
        base = V((0, 0.80 + 0.50 * t, 1.60 + 0.33 * t))
        side = 1 if k % 2 else -1
        g.quad(0.26, 0.44, M((side * 0.02, base.y - 0.02, base.z - 0.40), (0, side * 8, 90 + rnd.uniform(-8, 8))), mane_mat)
    g.quad(0.2, 0.26, M((0, 1.38, 1.80), (-15, 0, 0)), mane_mat)                      # ciuffo sulla fronte
    g.loft([((0, -0.88, 1.31), 0.06, 0.07), ((0, -0.98, 1.20), 0.075, 0.09), ((0, -1.03, 0.95), 0.08, 0.08), ((0, -1.0, 0.55), 0.055, 0.055), ((0, -0.97, 0.3), 0.025, 0.025)], 10, points, dens=3)
    for k in range(9):                                   # ciocche a stella intorno all'asse della coda: volume da ogni lato
        yaw = k * 20
        g.quad(0.34, 0.95, M((0.0, -1.0, 0.28), (7, 0, yaw)), mane_mat)
    return finish(g, name, "cavalli")


def ruota(g, cx, cy, cz, R=0.46):
    m = M((cx, cy, cz), (0, 90, 0))
    g.ring(R, 0.045, m, "bark", seg=24, tube=6)                                         # cerchione
    g.cyl(0.09, 0.075, 0.2, 10, M((cx - 0.1, cy, cz), (0, 90, 0)), "bark", z0=0.0)       # mozzo
    for k in range(4):                                                                   # quattro razze
        a = math.radians(45 + 90 * k)
        g.rod((cx, cy + 0.06 * math.cos(a), cz + 0.06 * math.sin(a)), (cx, cy + (R - 0.01) * math.cos(a), cz + (R - 0.01) * math.sin(a)), 0.034, 0.026, 6, "bark")
    g.ring(R + 0.012, 0.012, m, "bronze", seg=24, tube=4)                                # fascia di bronzo


def carro(name="carro_da_guerra", seed=91):
    g = G(seed)
    zf = 0.62
    R = 0.46
    for s in (-1, 1):
        ruota(g, s * 0.62, 0.0, R)
    g.rod((-0.78, 0.0, R), (0.78, 0.0, R), 0.045, 0.045, 8, "iron")                     # asse
    # pianale di assi e fianchi di cuoio con corrimano semicircolare
    for i in range(7):
        g.box((1.02, 0.12, 0.045), M((0, -0.28 + i * 0.125, zf)), "planks")
    for s in (-1, 1):
        g.rod((s * 0.45, -0.34, zf - 0.02), (s * 0.45, 0.55, zf - 0.02), 0.04, 0.04, 6, "bark")
    Rr = 0.46
    def P(u, v):
        ph = math.pi * u
        return (-Rr * math.cos(ph), 0.42 + Rr * 0.9 * math.sin(ph) - 0.06, zf + 0.03 + 0.58 * v)
    g.slab(P, 14, 4, 0.02, lambda i, j: "hide", tile=1.0)
    g.ring(Rr, 0.028, M((0, 0.36, zf + 0.62)), "bark", seg=18, tube=6, arc=math.pi)
    g.rod((-Rr, 0.36, zf + 0.62), (-Rr, -0.3, zf + 0.62), 0.028, 0.028, 6, "bark")
    g.rod((Rr, 0.36, zf + 0.62), (Rr, -0.3, zf + 0.62), 0.028, 0.028, 6, "bark")
    g.rod((-Rr, -0.3, zf + 0.62), (-Rr, -0.3, zf), 0.03, 0.03, 6, "bark")
    g.rod((Rr, -0.3, zf + 0.62), (Rr, -0.3, zf), 0.03, 0.03, 6, "bark")
    for s in (-1, 1):                                                                    # montanti del fianco
        g.rod((s * Rr * 0.99, 0.36, zf), (s * Rr * 0.99, 0.36, zf + 0.62), 0.03, 0.03, 6, "bark")
    # timone, giogo con selle, redini
    g.rod((0, 0.55, zf - 0.02), (0, 2.45, 0.92), 0.04, 0.032, 8, "bark")
    g.rod((-0.5, 2.45, 0.96), (0.5, 2.45, 0.96), 0.03, 0.03, 8, "bark")
    for s in (-1, 1):
        g.ring(0.07, 0.014, M((s * 0.5, 2.45, 0.96), (0, 90, 0)), "bronze", seg=12, tube=4)
        g.rod((s * 0.28, 2.45, 0.96), (s * 0.28, 2.45, 1.08), 0.02, 0.02, 5, "bark")
    g.rod((0, 0.0, 0.5), (0, 0.55, zf - 0.02), 0.035, 0.035, 6, "bark")
    for k in range(3):
        g.ring(0.045, 0.012, M((0, 0.8 + 0.5 * k, zf + 0.05 + 0.04 * k), (90, 0, 0)), "rope", seg=10, tube=4)
    return finish(g, name, "carri")


ALL = {
    "cavallo_baio": lambda: horse("cavallo_baio", "horse_bay", "horse_dark", "mane_dark", 81),
    "cavallo_grigio": lambda: horse("cavallo_grigio", "horse_grey", "horse_grey", "mane_light", 82),
    "carro_da_guerra": lambda: carro(),
}

if __name__ == "__main__":
    names = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(ALL)
    for n in names:
        okit2.reset()
        ALL[n]()
