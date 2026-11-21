"""Gruppo 8: carro rotto con ruota staccata, cavallo con sella e finimenti, cavallo caduto con frecce.

Uso (un solo Blender alla volta):  blender -b --factory-startup -P build_campo8.py -- [nome ...]
Modelli originali (modellati per il progetto): licenza del progetto.
"""
import bpy, sys, os, math
from mathutils import Vector, Matrix
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import okit2
from okit2 import G, M, finish
from build_campo3 import horse_geom

V = Vector


def wheelm(g, mtx, R=0.46, spokes=4):
    m = mtx @ M(rot=(0, 90, 0))
    g.ring(R, 0.045, m, "bark", seg=18, tube=5)
    g.ring(R + 0.012, 0.012, m, "bronze", seg=18, tube=4)
    g.cyl(0.09, 0.075, 0.2, 8, mtx @ M((-0.1, 0, 0), (0, 90, 0)), "bark")
    for k in range(spokes):
        a = math.radians(45 + 360 * k / spokes)
        g.rod(mtx @ V((0, 0.06 * math.cos(a), 0.06 * math.sin(a))), mtx @ V((0, (R - 0.01) * math.cos(a), (R - 0.01) * math.sin(a))), 0.034, 0.026, 5, "bark")


def carro_rotto(name="carro_rotto", seed=181):
    g = G(seed)
    rnd = g.rnd
    zf, Rw = 0.62, 0.46
    P0 = V((-0.62, 0.0, Rw))
    Tb = Matrix.Translation(P0) @ Matrix.Rotation(math.radians(17), 4, "Y") @ Matrix.Translation(-P0)   # il lato destro e' crollato
    T = lambda p: Tb @ V(p)
    wheelm(g, M((-0.62, 0, Rw)))                                                                            # ruota sinistra ancora montata
    wheelm(g, M((1.75, 0.55, 0.075), (6, -90, 0)))                                                          # ruota destra staccata, sdraiata
    g.rod(T((-0.8, 0, Rw)), T((0.12, 0, Rw)), 0.045, 0.04, 6, "iron")                                       # mezzo asse rimasto
    g.rod(V((2.3, -0.55, 0.05)), V((3.0, -0.25, 0.06)), 0.045, 0.04, 6, "iron")                            # mezzo asse a terra
    g.rod(V((2.95, -0.28, 0.06)), V((3.05, -0.22, 0.12)), 0.04, 0.01, 5, "iron")
    for i in range(7):                                                                                      # pianale
        g.box((1.02, 0.12, 0.045), Tb @ M((0, -0.28 + i * 0.125, zf)), "planks")
    g.box((0.03, 0.9, 0.04), Tb @ M((0.4, 0.1, zf - 0.04)), "bark")
    Rr = 0.46
    def P(u, v):
        ph = math.pi * u
        return (-Rr * math.cos(ph), 0.42 + Rr * 0.9 * math.sin(ph) - 0.06, zf + 0.03 + 0.58 * v * (1 - 0.35 * max(0, u - 0.55) * 1.8))
    g.slab(P, 14, 4, 0.02, lambda i, j: "hide", tile=1.0, mtx=Tb)                                          # fianco di cuoio, strappato a destra
    g.ring(Rr, 0.028, Tb @ M((0, 0.36, zf + 0.62)), "bark", seg=18, tube=6, arc=math.pi * 0.62)
    for sx in (-1, 1):
        g.rod(T((sx * Rr, -0.3, zf + 0.62)), T((sx * Rr, -0.3, zf)), 0.03, 0.03, 6, "bark")
    g.rod(T((-Rr, 0.36, zf)), T((-Rr, 0.36, zf + 0.62)), 0.03, 0.03, 6, "bark")
    g.rod(T((0, 0.55, zf - 0.02)), T((0.02, 1.15, 0.78)), 0.04, 0.034, 8, "bark")                           # timone spezzato
    g.rod(V((0.5, 1.85, 0.07)), V((0.2, 2.9, 0.1)), 0.036, 0.03, 8, "bark")                               # il resto a terra
    g.rod(T((0.02, 1.15, 0.78)), T((0.03, 1.25, 0.8)), 0.034, 0.012, 6, "bark")
    g.rod(V((-0.15, 3.3, 0.06)), V((0.85, 3.2, 0.07)), 0.03, 0.03, 8, "bark")                              # giogo caduto
    g.ring(0.07, 0.014, M((0.9, 3.2, 0.08), (0, 90, 0)), "bronze", seg=12, tube=4)
    for k in range(4):                                                                                      # schegge e raggi spezzati
        g.rod(V((1.4 + rnd.uniform(-0.4, 0.4), 0.2 + rnd.uniform(-0.5, 0.5), 0.04)), V((1.4 + rnd.uniform(-0.6, 0.6), 0.2 + rnd.uniform(-0.6, 0.6), 0.05)), 0.026, 0.02, 5, "bark")
    return finish(g, name, "carri")


def cavallo_sellato(name="cavallo_sellato", seed=182):
    g = G(seed)
    horse_geom(g, "horse_bay", "horse_dark", "mane_dark")
    # gualdrappa di tela sul dorso
    def B(u, v):
        x = (2 * u - 1) * 0.31
        y = -0.25 + 0.75 * v
        zc, rz, rx = 1.17, 0.34, 0.27 * 1.12
        return (x, y, zc + rz * math.sqrt(max(0.0, 1 - (x / rx) ** 2)) * 1.0 + 0.012)
    g.slab(B, 12, 6, 0.02, lambda i, j: "canvas", tile=0.8)
    g.box((0.30, 0.46, 0.05), M((0, 0.04, 1.545)), "leather")                                             # sella a cuscino
    g.box((0.26, 0.06, 0.13), M((0, 0.3, 1.6), (-8, 0, 0)), "leather")                                    # arcione anteriore
    g.box((0.28, 0.06, 0.15), M((0, -0.2, 1.6), (8, 0, 0)), "leather")                                    # arcione posteriore
    for sx in (-1, 1):
        g.box((0.04, 0.4, 0.24), M((sx * 0.28, 0.06, 1.4), (0, sx * 6, 0)), "leather")                    # alette
    def ellisse(y, zc, rx, rz, mat="leather", r=0.016, n=16, arc=1.0):
        pts = [V((rx * math.cos(2 * math.pi * k / n), y, zc + rz * math.sin(2 * math.pi * k / n))) for k in range(int(n * arc) + 1)]
        for a, b in zip(pts, pts[1:]):
            g.rod(a, b, r, r, 5, mat, caps=False)
    ellisse(0.12, 1.17, 0.282, 0.357)                                                                     # sottopancia
    ellisse(0.62, 1.22, 0.262, 0.372, r=0.02)                                                             # pettorale
    for sx in (-1, 1):
        g.ring(0.03, 0.007, M((sx * 0.27, 0.12, 1.12), (0, 90, 0)), "bronze", seg=8, tube=4)
        g.ring(0.045, 0.01, M((sx * 0.1, 0.72, 1.18 + 0.0), (90, 0, 0)), "bronze", seg=10, tube=4)
        g.rod(V((sx * 0.1, 0.64, 1.56)), V((sx * 0.1, 0.34, 1.62)), 0.012, 0.012, 4, "leather", caps=False)   # cinghia al garrese
    g.ring(0.055, 0.012, M((0, 0.74, 1.22), (90, 0, 0)), "bronze", seg=12, tube=4)
    # briglia: frontale, montanti, sottogola, morso e redini
    for sx in (-1, 1):
        g.rod(V((sx * 0.105, 1.34, 1.77)), V((sx * 0.077, 1.59, 1.46)), 0.009, 0.009, 4, "leather", caps=False)
        g.ring(0.022, 0.005, M((sx * 0.07, 1.6, 1.45), (0, 90, 0)), "bronze", seg=8, tube=4)
        g.rod(V((sx * 0.105, 1.34, 1.77)), V((sx * 0.085, 1.4, 1.64)), 0.009, 0.009, 4, "leather", caps=False)
        mid = V((sx * 0.14, 1.0, 1.62))
        g.rod(V((sx * 0.07, 1.6, 1.45)), mid, 0.007, 0.007, 4, "leather", caps=False)
        g.rod(mid, V((sx * 0.1, 0.34, 1.64)), 0.007, 0.007, 4, "leather", caps=False)
    g.rod(V((-0.105, 1.335, 1.78)), V((0.105, 1.335, 1.78)), 0.009, 0.009, 4, "leather", caps=False)
    q = V((0, 0, 1)).rotation_difference(V((0, 0.62, -0.78)).normalized())
    g.ring(0.083, 0.008, Matrix.Translation(V((0, 1.56, 1.545))) @ q.to_matrix().to_4x4(), "leather", seg=14, tube=4)   # nasiera
    return finish(g, name, "cavalli")


def cavallo_caduto(name="cavallo_caduto", seed=183):
    g = G(seed)
    g.root = M((0, 0, 0), (0, 90, 0)) @ M((0, 0, 0))
    g.root = Matrix.Rotation(math.radians(20), 4, "Z") @ Matrix.Rotation(math.radians(90), 4, "Y")
    horse_geom(g, "horse_dark", "horse_dark", "mane_dark")
    rnd = g.rnd
    for k in range(3):                                                                                     # frecce piantate nel fianco
        y, z = 0.05 + 0.3 * k - 0.2, 1.1 + 0.12 * (k % 2)
        a = V((-0.22, y, z))
        d = V((-0.55 - 0.1 * k, rnd.uniform(-0.12, 0.12), rnd.uniform(0.05, 0.25))).normalized()
        g.rod(a, a + d * 0.75, 0.01, 0.01, 5, "bark")
        for f in (0.62, 0.72):
            g.box((0.012, 0.045, 0.1), M(tuple(a + d * f), (0, 0, 20 * k)), "hide")
    return finish(g, name, "cavalli")


def figura(g, ruolo, tunic="wool"):
    """Figura umana statica, stilizzata (alta ~1,8 m): gambe, tunica, torso, braccia, testa. ruolo = 'auriga' | 'guerriero'."""
    rnd = g.rnd
    for sx in (-1, 1):                                                                    # gambe e sandali
        leg = [((sx * 0.11, 0.05, 0.09), 0.036, 0.05), ((sx * 0.11, 0.03, 0.27), 0.055, 0.06), ((sx * 0.11, 0.045, 0.48), 0.05, 0.057),
               ((sx * 0.105, 0.02, 0.7), 0.07, 0.075), ((sx * 0.1, 0.0, 0.92), 0.075, 0.085)]
        g.loft(leg, 9, "skin", dens=2)
        g.box((0.095, 0.25, 0.05), M((sx * 0.11, 0.1, 0.03)), "leather")
        g.rod(V((sx * 0.11, 0.0, 0.1)), V((sx * 0.11, 0.0, 0.27)), 0.052, 0.054, 8, "leather", caps=False)   # schinieri
    lean = 0.04 if ruolo == "auriga" else 0.0
    torso = [((0, 0, 0.93), 0.17, 0.1), ((0, 0.0, 1.06), 0.145, 0.095), ((0, 0.01 + lean, 1.27), 0.185, 0.115), ((0, 0.01 + lean, 1.43), 0.205, 0.095), ((0, 0.0 + lean, 1.51), 0.06, 0.06)]
    g.loft(torso, 12, tunic, dens=2)
    g.lathe([(0.17, 0.98), (0.2, 0.84), (0.23, 0.64), (0.235, 0.58)], 14, None, tunic)                      # gonnellino
    g.ring(0.17, 0.014, M((0, 0, 1.0), (0, 0, 0), (1, 0.65, 1)), "leather", seg=16, tube=4)                 # cintura
    g.loft([((0, 0.0 + lean, 1.5), 0.05, 0.05), ((0, 0.015 + lean, 1.6), 0.045, 0.048)], 8, "skin", dens=2)  # collo
    head = V((0, 0.02 + lean, 1.68))
    g.blob((0.085, 0.1, 0.11), M(tuple(head)), "skin", 10, 7, 0.0)
    g.blob((0.018, 0.022, 0.026), M((0, 0.1 + lean, 1.665)), "skin", 6, 4, 0.0)                              # naso
    for sx in (-1, 1):
        g.blob((0.011, 0.01, 0.01), M((sx * 0.035, 0.095 + lean, 1.7)), "hoof", 5, 4, 0.0)                    # occhi
    arms = ((-1, 1), (1, 1))
    for sx, _ in arms:
        sh = V((sx * 0.21, 0.0 + lean, 1.42))
        if ruolo == "auriga":                                                              # braccia in avanti con le redini
            el, wr = V((sx * 0.25, 0.1 + lean, 1.22)), V((sx * 0.2, 0.36 + lean, 1.2))
        elif sx > 0:                                                                       # braccio destro con la lancia
            el, wr = V((sx * 0.27, 0.06, 1.2)), V((sx * 0.3, 0.18, 1.16))
        else:                                                                              # braccio sinistro con lo scudo
            el, wr = V((sx * 0.3, 0.05, 1.18)), V((sx * 0.3, 0.22, 1.3))
        g.loft([(sh, 0.052, 0.05), (el, 0.042, 0.04), (wr, 0.034, 0.034)], 8, "skin", dens=3)
        g.blob((0.04, 0.045, 0.04), M(tuple(wr)), "skin", 7, 5, 0.0)
    if ruolo == "auriga":
        g.blob((0.092, 0.11, 0.085), M((0, 0.015 + lean, 1.735)), "horse_dark", 10, 6, 0.1)                 # capelli
        g.rod(V((-0.2, 0.37 + lean, 1.2)), V((-0.22, 1.5, 0.95)), 0.008, 0.008, 4, "leather", caps=False)   # redini
        g.rod(V((0.2, 0.37 + lean, 1.2)), V((0.22, 1.5, 0.95)), 0.008, 0.008, 4, "leather", caps=False)
        g.rod(V((0.22, 0.34, 1.19)), V((0.5, 0.6, 1.5)), 0.012, 0.012, 5, "bark")                           # pungolo
    else:
        g.blob((0.098, 0.115, 0.1), M((0, 0.02, 1.72)), "bronze", 11, 7, 0.02)                              # elmo
        g.box((0.016, 0.02, 0.06), M((0, 0.115, 1.69)), "bronze")
        g.loft([((0, 0.08, 1.78), 0.014, 0.025), ((0, 0.0, 1.84), 0.014, 0.075), ((0, -0.1, 1.76), 0.014, 0.06), ((0, -0.15, 1.66), 0.012, 0.02)], 7, "horse_dark", dens=3)
        g.rod(V((0.3, 0.18, 0.0)), V((0.3, 0.2, 2.05)), 0.014, 0.012, 6, "bark")                           # lancia
        g.rod(V((0.3, 0.2, 2.0)), V((0.3, 0.2, 2.2)), 0.03, 0.002, 6, "iron")
        g.cyl(0.33, 0.33, 0.035, 18, M((-0.3, 0.27, 1.12), (90, 0, -12)), "bronze")                         # scudo tondo
        g.ring(0.33, 0.016, M((-0.3, 0.27, 1.12), (90, 0, -12)), "bronze", seg=18, tube=4)
        g.quad(0.3, 0.55, M((0, -0.085, 0.95), (6, 0, 0)), "wool")                                                    # mantello


def auriga(name="auriga_carro", seed=191):
    g = G(seed)
    figura(g, "auriga")
    return finish(g, name, "personaggi")


def guerriero(name="guerriero_carro", seed=192):
    g = G(seed)
    figura(g, "guerriero")
    return finish(g, name, "personaggi")


ALL = {
    "carro_rotto": lambda: carro_rotto(),
    "cavallo_sellato": lambda: cavallo_sellato(),
    "cavallo_caduto": lambda: cavallo_caduto(),
    "auriga_carro": lambda: auriga(),
    "guerriero_carro": lambda: guerriero(),
}

if __name__ == "__main__":
    names = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(ALL)
    for n in names:
        okit2.reset()
        ALL[n]()
