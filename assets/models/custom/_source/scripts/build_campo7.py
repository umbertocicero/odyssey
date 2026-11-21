"""Gruppo 7 (pianura di battaglia e bracieri): balista, catapulta, torce, bracieri, arco di pietra in rovina, colle dell'acropoli.

Uso (un solo Blender alla volta):  blender -b --factory-startup -P build_campo7.py -- [nome ...]
Modelli originali (modellati per il progetto): licenza del progetto.
"""
import bpy, sys, os, math
from mathutils import Vector, Matrix
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import okit2
from okit2 import G, M, finish
from build_campo2 import stone_region

V = Vector


def wheel(g, cx, cy, cz, R=0.4, spokes=6, seg=18):
    """Ruota a raggi con asse lungo X (cerchione, mozzo, raggi)."""
    m = M((cx, cy, cz), (0, 90, 0))
    g.ring(R, 0.04, m, "bark", seg=seg, tube=5)
    g.cyl(0.075, 0.07, 0.17, 8, M((cx - 0.085, cy, cz), (0, 90, 0)), "bark")
    for k in range(spokes):
        a = math.radians(360 * k / spokes + 15)
        g.rod(V((cx, cy + 0.05 * math.cos(a), cz + 0.05 * math.sin(a))), V((cx, cy + (R - 0.01) * math.cos(a), cz + (R - 0.01) * math.sin(a))), 0.03, 0.024, 5, "bark")


def balista(name="balista_telaio", seed=141):
    g = G(seed)
    rnd = g.rnd
    zr = 0.95
    for sx in (-1, 1):                                        # guide dello scorrevole
        g.box((0.09, 2.15, 0.1), M((sx * 0.075, 0.05, zr)), "planks")
    g.box((0.14, 1.0, 0.07), M((0, -0.15, zr + 0.085)), "bark")                      # slitta
    for sx in (-1, 1):                                        # telaio inferiore con montanti
        g.box((0.1, 1.9, 0.1), M((sx * 0.4, 0.0, 0.47)), "planks")
        for y in (-0.7, 0.7):
            g.rod(V((sx * 0.4, y, 0.5)), V((sx * 0.09, y, zr - 0.04)), 0.045, 0.04, 6, "bark")
    for y in (-0.7, 0.7):
        g.box((0.82, 0.09, 0.09), M((0, y, 0.5)), "planks")
    g.rod(V((-0.72, 0.15, 0.38)), V((0.72, 0.15, 0.38)), 0.04, 0.04, 6, "iron")               # asse e ruote
    for sx in (-1, 1):
        wheel(g, sx * 0.66, 0.15, 0.38, 0.38)
    g.rod(V((0, -0.85, 0.5)), V((0, -1.25, 0.04)), 0.05, 0.045, 6, "bark")                  # puntello posteriore
    for sx in (-1, 1):                                        # telai di torsione a fascio di corde
        c = V((sx * 0.43, 0.72, 1.25))
        g.box((0.36, 0.38, 0.045), M((c.x, c.y, c.z - 0.2)), "planks")
        g.box((0.36, 0.38, 0.045), M((c.x, c.y, c.z + 0.22)), "planks")
        g.cyl(0.085, 0.085, 0.4, 10, M((c.x, c.y, c.z - 0.2)), "rope")
        for z in (-0.05, 0.1):
            g.ring(0.09, 0.012, M((c.x, c.y, c.z + z)), "bronze", seg=14, tube=4)
        end = V((sx * 0.95, 0.46, 1.27))                       # bracci tesi all'indietro (arma carica)
        g.rod(c, end, 0.04, 0.026, 6, "bark")
    g.rod(V((-0.95, 0.46, 1.27)), V((0, -0.42, zr + 0.18)), 0.011, 0.011, 4, "rope", caps=False)      # corda dell'arco
    g.rod(V((0.95, 0.46, 1.27)), V((0, -0.42, zr + 0.18)), 0.011, 0.011, 4, "rope", caps=False)
    g.rod(V((0, -0.4, zr + 0.17)), V((0, 0.95, zr + 0.17)), 0.016, 0.014, 5, "bark")                 # dardo
    g.rod(V((0, 0.9, zr + 0.17)), V((0, 1.14, zr + 0.17)), 0.034, 0.003, 6, "iron")
    for sx in (-1, 1):
        g.box((0.005, 0.14, 0.05), M((sx * 0.015, -0.33, zr + 0.17)), "hide")
    g.cyl(0.07, 0.07, 0.56, 8, M((0, -0.92, zr - 0.02), (0, 90, 0)), "bark", z0=-0.28)               # argano posteriore
    for sg in (-1, 1):
        g.rod(V((sg * 0.28, -0.92, zr - 0.02)), V((sg * 0.28, -0.92 + 0.0, zr + 0.28)), 0.02, 0.02, 4, "bark")
    return finish(g, name, "macchine")


def catapulta(name="catapulta_contrappeso", seed=142):
    g = G(seed)
    rnd = g.rnd
    for sx in (-1, 1):                                        # travi di base
        g.box((0.16, 3.5, 0.16), M((sx * 0.7, 0.0, 0.5)), "planks")
    for y in (-1.5, -0.55, 0.55, 1.5):
        g.box((1.6, 0.14, 0.12), M((0, y, 0.5)), "planks")
    for y in (-1.15, 1.15):                                   # assi e ruote
        g.rod(V((-1.05, y, 0.4)), V((1.05, y, 0.4)), 0.045, 0.045, 6, "iron")
        for sx in (-1, 1):
            wheel(g, sx * 0.98, y, 0.4, 0.4, spokes=6, seg=16)
    top = V((0, 0.0, 2.75))
    for sx in (-1, 1):                                        # cavalletti a A
        for y in (-0.7, 0.7):
            g.rod(V((sx * 0.7, y, 0.56)), V((sx * 0.7, 0.0, 2.75)), 0.085, 0.07, 7, "bark")
        g.rod(V((sx * 0.7, -0.35, 1.55)), V((sx * 0.7, 0.35, 1.55)), 0.05, 0.05, 6, "bark")
    g.rod(V((-0.85, 0, 2.75)), V((0.85, 0, 2.75)), 0.075, 0.075, 8, "iron")                  # perno del braccio
    Lend = V((0, -1.85, 0.95))
    d = (top - Lend).normalized()
    Send = top + d * 1.15
    g.rod(Lend, Send, 0.1, 0.07, 9, "bark")                                                       # braccio
    g.rod(Lend, top, 0.1, 0.085, 9, "bark")
    # contrappeso: cassa di assi con pietre, appesa a due ganci
    cw = Send + V((0, 0.0, -0.78))
    g.box((1.1, 0.7, 0.8), M(tuple(cw)), "planks")
    for i in range(7):
        g.blob((0.17, 0.17, 0.12), M((cw.x + rnd.uniform(-0.4, 0.4), cw.y + rnd.uniform(-0.22, 0.22), cw.z + 0.42)), "stone", 8, 5, 0.2)
    for sx in (-1, 1):
        g.rod(Send + V((sx * 0.35, 0, 0.02)), cw + V((sx * 0.35, 0, 0.3)), 0.025, 0.025, 5, "iron")
    # fionda: due funi e sacca di cuoio con la pietra a terra
    pouch = V((0.0, -2.45, 0.12))
    for sx in (-1, 1):
        g.rod(Lend, pouch + V((sx * 0.12, 0, 0.0)), 0.014, 0.014, 4, "rope", caps=False)
    g.blob((0.2, 0.26, 0.07), M(tuple(pouch)), "hide", 8, 5, 0.08)
    g.blob((0.12, 0.12, 0.12), M((pouch.x, pouch.y, pouch.z + 0.1)), "stone", 8, 6, 0.1)
    for y in (-0.8, 0.8):                                     # tiranti di controvento
        g.rod(V((-0.7, y, 0.55)), V((0.7, y, 1.7)), 0.02, 0.02, 4, "rope", caps=False)
        g.rod(V((0.7, y, 0.55)), V((-0.7, y, 1.7)), 0.02, 0.02, 4, "rope", caps=False)
    return finish(g, name, "macchine")


def torcia_muro(name="torcia_a_muro", seed=151):
    g = G(seed)
    g.box((0.14, 0.03, 0.26), M((0, 0.015, 0.13)), "iron")                                     # piastra a muro
    g.rod(V((0, 0.02, 0.12)), V((0, 0.3, 0.14)), 0.016, 0.014, 5, "iron")                      # braccio
    g.rod(V((0, 0.1, 0.03)), V((0, 0.26, 0.12)), 0.012, 0.012, 4, "iron")
    g.ring(0.05, 0.011, M((0, 0.31, 0.14), (90, 0, 0)), "iron", seg=14, tube=4)                # anello portatorcia
    base, tip = V((0, 0.2, -0.02)), V((0, 0.45, 0.5))
    g.rod(base, tip, 0.026, 0.024, 7, "bark")                                                  # fusto
    g.rod(tip - (tip - base).normalized() * 0.12, tip + (tip - base).normalized() * 0.14, 0.055, 0.05, 9, "canvas")       # straccio imbevuto
    g.rod(tip + (tip - base).normalized() * 0.1, tip + (tip - base).normalized() * 0.2, 0.05, 0.03, 8, "ash")             # punta carbonizzata
    for k in range(3):
        g.quad(0.3, 0.46, M((tip.x, tip.y, tip.z + 0.08), (0, 0, 60 * k + 10)), "flame")
    return finish(g, name, "luci", center_xy=False)


def torcia_palo(name="torcia_su_palo", seed=152):
    g = G(seed)
    for k in range(3):                                                                         # tre piedi a treppiede
        a = math.radians(120 * k + 30)
        g.rod(V((0.28 * math.cos(a), 0.28 * math.sin(a), 0.0)), V((0.025 * math.cos(a), 0.025 * math.sin(a), 0.3)), 0.025, 0.02, 5, "bark")
    g.rod(V((0, 0, 0.0)), V((0, 0, 1.75)), 0.04, 0.032, 8, "bark")                              # palo
    g.ring(0.05, 0.012, M((0, 0, 0.32)), "rope", seg=12, tube=4)
    cup = [(0.0, 0.0), (0.06, 0.01), (0.12, 0.06), (0.16, 0.14), (0.17, 0.17), (0.15, 0.17), (0.14, 0.12), (0.1, 0.06), (0.0, 0.04)]
    g.lathe(cup, 16, M((0, 0, 1.72)), "iron")                                                  # coppa di ferro
    for k in range(4):                                                                         # gabbia di bacchette
        a = math.radians(90 * k + 45)
        g.rod(V((0.04 * math.cos(a), 0.04 * math.sin(a), 1.7)), V((0.17 * math.cos(a), 0.17 * math.sin(a), 1.9)), 0.011, 0.01, 4, "iron")
    g.blob((0.11, 0.11, 0.13), M((0, 0, 1.9)), "canvas", 9, 6, 0.12)                             # fascio di stracci
    g.blob((0.08, 0.08, 0.05), M((0, 0, 2.0)), "ash", 8, 5, 0.1)
    for k in range(3):
        g.quad(0.42, 0.62, M((0, 0, 1.94), (0, 0, 60 * k + 5)), "flame")
    return finish(g, name, "luci")


def braciere(name="braciere_bronzo_acceso", lit=True, seed=153):
    g = G(seed)
    rnd = g.rnd
    for k in range(3):                                                                         # treppiede di bronzo con piedi ricurvi
        a = math.radians(120 * k + 15)
        g.rod(V((0.42 * math.cos(a), 0.42 * math.sin(a), 0.0)), V((0.2 * math.cos(a), 0.2 * math.sin(a), 0.8)), 0.03, 0.024, 6, "bronze")
        g.blob((0.045, 0.06, 0.03), M((0.42 * math.cos(a), 0.42 * math.sin(a), 0.03), (0, 0, math.degrees(a))), "bronze", 7, 5, 0.0)
    g.ring(0.21, 0.02, M((0, 0, 0.8)), "bronze", seg=20, tube=5)
    bowl = [(0.0, 0.0), (0.1, 0.012), (0.2, 0.06), (0.29, 0.14), (0.34, 0.24), (0.355, 0.3), (0.34, 0.32), (0.325, 0.3), (0.32, 0.26), (0.27, 0.16), (0.18, 0.08), (0.08, 0.04), (0.0, 0.035)]
    g.lathe(bowl, 24, M((0, 0, 0.78)), "bronze")
    g.ring(0.35, 0.02, M((0, 0, 1.08)), "bronze", seg=26, tube=5)
    g.ring(0.2, 0.012, M((0, 0, 0.9)), "bronze", seg=20, tube=4)                              # fascia decorativa
    for sx in (-1, 1):
        g.ring(0.07, 0.015, M((sx * 0.37, 0, 1.0), (90, 0, 0)), "bronze", seg=10, tube=4)
    coal = "charcoal" if lit else "ash"
    g.blob((0.27, 0.27, 0.11), M((0, 0, 1.04)), coal, 11, 6, 0.18)
    for i in range(5):
        g.blob((0.07, 0.06, 0.05), M((rnd.uniform(-0.18, 0.18), rnd.uniform(-0.18, 0.18), 1.12)), coal, 6, 4, 0.2)
    if lit:
        for k in range(3):
            g.quad(0.55, 0.62, M((0, 0, 1.08), (0, 0, 60 * k + 20)), "flame")
    return finish(g, name, "luci", double=("bronze",))


def arco_rovina(name="arco_pietra_rovina", seed=161):
    g = G(seed)
    rnd = g.rnd
    T, H = 1.0, 3.1
    for sx in (-1, 1):                                                                         # piloni a blocchi di calcare
        g.box((1.0, T, H), M((sx * 1.55, 0, H / 2)), "limestone")
        mtx = M((sx * 1.55, T / 2, 0))
        stone_region(g, -0.5, 0.5, 0.0, H, mtx, depth=0.11, bh=(0.3, 0.46), bw=(0.45, 0.8))
        mtx2 = M((sx * 1.55, -T / 2, 0), (0, 0, 180))
        stone_region(g, -0.5, 0.5, 0.0, H, mtx2, depth=0.11, bh=(0.3, 0.46), bw=(0.45, 0.8))
    g.box((1.12, T + 0.1, 0.16), M((-1.55, 0, H + 0.08)), "limestone")                           # imposta del lato integro
    cy, R_in, R_out = H + 0.1, 1.05, 1.6                                                       # conci dell'arco: lato sinistro quasi completo, destro crollato
    n = 9
    for i in range(n):
        a0, a1 = math.pi * i / n, math.pi * (i + 1) / n
        am = (a0 + a1) / 2
        if i >= 6:                                                                              # concio mancante (crollo)
            continue
        rm = (R_in + R_out) / 2
        pos = V((-rm * math.cos(am), 0, cy + rm * math.sin(am) - 0.05))
        g.box((R_out - R_in, T * 0.96, 2 * math.pi * rm / n * 0.95), M(tuple(pos), (0, 180 + math.degrees(am), 0)), "limestone")
    for k in range(5):                                                                          # blocchi caduti
        x, y = rnd.uniform(0.2, 2.8), rnd.uniform(-1.1, 1.1)
        g.box((rnd.uniform(0.55, 0.9), rnd.uniform(0.4, 0.6), rnd.uniform(0.3, 0.46)), M((x, y, 0.22), (rnd.uniform(-8, 8), rnd.uniform(-8, 8), rnd.uniform(0, 90))), "limestone")
    return finish(g, name, "rovine")


def colle(name="colle_acropoli_modulare", seed=171):
    g = G(seed)
    rnd = g.rnd
    NX, NY = 48, 32
    SX, SY = 30.0, 20.0
    ph = [rnd.uniform(0, 6.28) for _ in range(6)]

    def sm(a, b, x):
        t = max(0.0, min(1.0, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)

    def hz(x, y):
        r = math.hypot(x / (SX / 2), y / (SY / 2))
        base = 4.2 * (1 - sm(0.38, 0.97, r))
        wob = 0.55 * math.sin(x * 0.32 + ph[0]) * math.sin(y * 0.42 + ph[1]) + 0.3 * math.sin(x * 0.7 + y * 0.55 + ph[2])
        edge = 1 - sm(0.8, 1.0, r)
        terr = 0.18 * sm(0.45, 0.62, r) * (1 - sm(0.62, 0.8, r)) * math.sin(r * 12 + ph[4])
        return max(0.0, base + (wob * 0.9 + terr) * edge * (0.35 + base / 4.2))
    verts = []
    for j in range(NY + 1):
        for i in range(NX + 1):
            x, y = -SX / 2 + SX * i / NX, -SY / 2 + SY * j / NY
            verts.append((x, y, hz(x, y)))
    faces_e, faces_r = [], []
    for j in range(NY):
        for i in range(NX):
            a, b, c, d = j * (NX + 1) + i, j * (NX + 1) + i + 1, (j + 1) * (NX + 1) + i + 1, (j + 1) * (NX + 1) + i
            f = [a, b, c, d]
            nrm = (V(verts[b]) - V(verts[a])).cross(V(verts[d]) - V(verts[a])).normalized()
            (faces_e if nrm.z > 0.74 else faces_r).append(f)
    g._add(verts, faces_e, "earth", None, None, True, 4.0, False)
    g._add(verts, faces_r, "limestone", None, None, True, 2.5, False)
    for k in range(6):                                                                          # affioramenti rocciosi interrati sui fianchi
        a = rnd.uniform(0, 6.28)
        r = rnd.uniform(0.52, 0.72)
        x, y = r * (SX / 2) * math.cos(a), r * (SY / 2) * math.sin(a)
        g.blob((rnd.uniform(0.8, 1.3), rnd.uniform(0.7, 1.1), rnd.uniform(0.5, 0.85)), M((x, y, hz(x, y) - 0.05), (0, 0, rnd.uniform(0, 180))), "limestone", 10, 6, 0.12, tile=2.0)
    return finish(g, name, "terreno")


ALL = {
    "balista_telaio": lambda: balista(),
    "catapulta_contrappeso": lambda: catapulta(),
    "torcia_a_muro": lambda: torcia_muro(),
    "torcia_su_palo": lambda: torcia_palo(),
    "braciere_bronzo_acceso": lambda: braciere("braciere_bronzo_acceso", True),
    "braciere_bronzo_spento": lambda: braciere("braciere_bronzo_spento", False, 154),
    "arco_pietra_rovina": lambda: arco_rovina(),
    "colle_acropoli_modulare": lambda: colle(),
}

if __name__ == "__main__":
    names = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(ALL)
    for n in names:
        okit2.reset()
        ALL[n]()
