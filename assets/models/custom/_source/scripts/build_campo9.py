"""Gruppo 9: unita' economiche di opliti per la pianura di battaglia (da istanziare con MultiMesh a distanza).

Blocco di 8 figure in 2 file da 4 (circa 3,4 x 1,9 m), con elmo a cresta, corazza di bronzo, gambali, scudo tondo (rosso, blu o
marrone smorzato) e lancia; 2 varianti: in schieramento (lance quasi verticali) e in marcia (passo e lance inclinate in avanti).
Texture a 512 px condivise con il resto del campo. Esporta in campo/personaggi/masse/.

Uso (un solo Blender alla volta):  blender -b --factory-startup -P build_campo9.py -- [nome ...]
Modelli originali (modellati per il progetto): licenza del progetto.
"""
import bpy, sys, os, math
from mathutils import Vector, Matrix
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import okit2
from okit2 import G, M, finish

V = Vector
CLOAKS = ("cloak_red", "cloak_blue", "cloak_brown")


def oplita(g, x, y, yaw, cloak, stride, spear_tilt, h=1.0):
    """Una figura minimale (~250 triangoli), nella posa data."""
    g.root = M((x, y, 0), (0, 0, yaw)) @ M(scale=(h, h, h))
    for sx in (-1, 1):                                                                   # gambe con gambale di bronzo
        foot = V((sx * 0.09, -sx * stride * 0.22, 0.04))
        hip = V((sx * 0.09, 0.0, 0.92))
        g.rod(foot, hip, 0.045, 0.06, 5, "skin", caps=False)
        g.rod(foot + V((0, 0, 0.04)), foot.lerp(hip, 0.42), 0.05, 0.052, 5, "bronze", caps=False)
    g.cyl(0.17, 0.22, 0.36, 8, M((0, 0, 0.62)), "wool", caps=False)                       # gonnellino
    g.cyl(0.17, 0.2, 0.5, 8, M((0, 0, 0.95)), "bronze")                                   # corazza
    g.blob((0.075, 0.085, 0.09), M((0, 0.01, 1.58)), "skin", 6, 4, 0.0)                    # testa
    g.blob((0.095, 0.105, 0.085), M((0, 0.01, 1.64)), "bronze", 6, 3, 0.0)                 # elmo
    g.box((0.03, 0.22, 0.07), M((0, 0.0, 1.74)), "horse_dark")                            # cresta
    g.quad(0.34, 0.8, M((0, -0.17, 0.72)), cloak)                                          # mantello sulle spalle
    sh = V((-0.2, 0.0, 1.42))
    g.rod(sh, V((-0.3, 0.2, 1.2)), 0.04, 0.035, 5, "skin", caps=False)                    # braccio dello scudo
    g.cyl(0.33, 0.33, 0.04, 8, M((-0.3, 0.27, 1.12), (90, 0, -8)), cloak)                  # scudo tondo
    g.cyl(0.345, 0.345, 0.025, 8, M((-0.3, 0.245, 1.12), (90, 0, -8)), "bronze")           # bordo di bronzo
    hand = V((0.27, 0.17, 1.2))
    g.rod(V((0.2, 0.0, 1.42)), hand, 0.04, 0.035, 5, "skin", caps=False)                  # braccio della lancia
    d = V((0, math.sin(math.radians(spear_tilt)), math.cos(math.radians(spear_tilt))))   # lancia inclinata in avanti di spear_tilt gradi
    g.rod(hand - d * 1.05, hand + d * 1.0, 0.014, 0.012, 4, "bark", caps=False)
    g.rod(hand + d * 0.98, hand + d * 1.22, 0.026, 0.002, 4, "iron")
    g.root = None


def unita(name, marcia, seed):
    g = G(seed)
    rnd = g.rnd
    cols, rows = 4, 2
    k = 0
    for r in range(rows):
        for c in range(cols):
            x = (c - (cols - 1) / 2) * 0.88 + rnd.uniform(-0.04, 0.04)
            y = -r * 1.0 + rnd.uniform(-0.05, 0.05)
            if marcia:
                oplita(g, x, y, rnd.uniform(-5, 5), CLOAKS[(c + r) % 3], 1 if (c + r) % 2 else -1, 26 + rnd.uniform(-3, 3), 1.0 + rnd.uniform(-0.03, 0.03))
            else:
                oplita(g, x, y, rnd.uniform(-4, 4), CLOAKS[(c + 2 * r) % 3], 0, -4 + rnd.uniform(-2, 2), 1.0 + rnd.uniform(-0.03, 0.03))
            k += 1
    return finish(g, name, "personaggi/masse")


ALL = {
    "opliti_schieramento": lambda: unita("opliti_schieramento", False, 201),
    "opliti_marcia": lambda: unita("opliti_marcia", True, 202),
}

if __name__ == "__main__":
    names = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(ALL)
    for n in names:
        okit2.reset()
        ALL[n]()
