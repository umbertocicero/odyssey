"""Gruppo 6: colonne doriche arcaiche in calcare ocra, come le mura (intera, spezzata con rocchi a terra, rocchio caduto).

Fusto con 20 scanalature a spigolo vivo, leggera rastremazione ed entasi; echino con anelli e abaco quadrato; base a gradino.
Uso (un solo Blender alla volta):  blender -b --factory-startup -P build_campo6.py -- [nome ...]
Modelli originali (modellati per il progetto): licenza del progetto. Proporzioni di riferimento: colonne doriche arcaiche
(diametro alla base ~0,9 m, altezza ~4,3 m, rapporto circa 4,7:1).
"""
import bpy, sys, os, math
from mathutils import Vector, Matrix
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import okit2
from okit2 import G, M, finish

V = Vector
MAT = "limestone"
R0, R1 = 0.43, 0.31            # raggio del fusto in basso e in alto


def fluted(g, mtx, ra, rb, z0, z1, rings=7, nfl=20, seg=4, depth=0.03, top_jag=None, bot_jag=None, caps=True, entasis=0.012):
    """Fusto scanalato: nfl scanalature da 'seg' segmenti, spigoli vivi (facce piatte), raggio da ra a rb con entasi."""
    n = nfl * seg
    rv = []
    for k in range(rings + 1):
        t = k / rings
        R = ra + (rb - ra) * t + entasis * math.sin(math.pi * t)
        z = z0 + (z1 - z0) * t
        ring = []
        for i in range(n):
            th = 2 * math.pi * i / n
            r = R - depth * math.sin(math.pi * ((i % seg) / seg))
            zz = z + (top_jag(th) if (k == rings and top_jag) else 0.0) + (bot_jag(th) if (k == 0 and bot_jag) else 0.0)
            ring.append((r * math.cos(th), r * math.sin(th), zz))
        rv.append(ring)
    verts = [v for r in rv for v in r]
    faces, uvs = [], []
    circ = 2 * math.pi * (ra + rb) / 2
    for k in range(rings):
        for i in range(n):
            j = (i + 1) % n
            faces.append([k * n + i, k * n + j, (k + 1) * n + j, (k + 1) * n + i])
            u0, u1 = i / n * circ, (i + 1) / n * circ
            v0, v1 = z0 + (z1 - z0) * k / rings, z0 + (z1 - z0) * (k + 1) / rings
            uvs.append([(u0, v0), (u1, v0), (u1, v1), (u0, v1)])
    g._add(verts, faces, MAT, mtx, uvs, False)
    if caps:
        for end, flip in ((0, True), (rings, False)):
            ring = rv[end]
            cz = sum(p[2] for p in ring) / n
            vs = list(ring) + [(0.0, 0.0, cz)]
            fan = [[i, (i + 1) % n, n] for i in range(n)]
            if flip:
                fan = [f[::-1] for f in fan]
            g._add(vs, fan, MAT, mtx, [[(p[0], p[1]) for p in (vs[a] for a in f)] for f in fan], False)


def capitello(g, mtx, z0):
    """Annuli, echino convesso e abaco quadrato; z0 = quota di attacco al fusto."""
    for k in range(3):
        g.cyl(R1 + 0.045 - 0.004 * k, R1 + 0.045 - 0.004 * k, 0.016, 28, mtx @ M((0, 0, z0 + 0.012 + 0.024 * k)), MAT, caps=True)
    eh = [(R1 + 0.02, 0.09), (R1 + 0.045, 0.105), (R1 + 0.085, 0.14), (R1 + 0.12, 0.185), (R1 + 0.155, 0.225), (R1 + 0.165, 0.262), (R1 + 0.16, 0.28)]
    g.lathe([(r, z) for r, z in eh], 40, mtx @ M((0, 0, z0)), MAT)
    g.box((0.98, 0.98, 0.2), mtx @ M((0, 0, z0 + 0.28 + 0.1)), MAT, tile=1.0)


def basamento(g):
    g.box((1.36, 1.36, 0.2), M((0, 0, 0.1)), MAT)
    g.box((1.12, 1.12, 0.14), M((0, 0, 0.27)), MAT)


def intera(name="colonna_dorica_intera", seed=131):
    g = G(seed)
    basamento(g)
    z0 = 0.34
    fluted(g, None, R0, R1, z0, z0 + 3.5, rings=7)
    capitello(g, M(), z0 + 3.5)
    return finish(g, name, "rovine")


def spezzata(name="colonna_dorica_spezzata", seed=132):
    g = G(seed)
    rnd = g.rnd
    basamento(g)
    z0 = 0.34
    ph = rnd.uniform(0, 6.28)
    jag = lambda th: 0.34 * math.cos(th - 0.9) + 0.07 * math.sin(5 * th + ph) + rnd.uniform(-0.025, 0.025)
    ztop = 2.05
    t = (ztop - z0) / 3.5
    rb = R0 + (R1 - R0) * t
    fluted(g, None, R0, rb, z0, ztop, rings=4, top_jag=jag)
    # rocchi caduti: sdraiati, con rastremazione e fluttuazione di posa
    rr = R0 + (R1 - R0) * 0.55
    for (x, y, yaw, tilt, L) in ((1.5, 0.75, 20, 3, 0.7), (2.4, -0.55, 105, -4, 0.62), (0.15, -1.55, 70, 5, 0.66)):
        rad = rr - 0.02 * rnd.random()
        m = M((x, y, rad * 0.98), (90 + tilt, 0, yaw)) @ M((0, 0, -L / 2))
        fluted(g, m, rad + 0.015, rad - 0.015, 0, L, rings=1, caps=True)
    # capitello caduto di lato, in parte interrato
    capitello(g, M((-1.65, 0.65, 0.5), (80, 0, 35)), 0.0)
    return finish(g, name, "rovine")


def rocchio(name="rocchio_colonna_caduto", seed=133):
    g = G(seed)
    rnd = g.rnd
    L = 1.15
    rad = R0 + (R1 - R0) * 0.3
    jag = lambda th: 0.05 * math.sin(3 * th + 1.0) + rnd.uniform(-0.012, 0.012)
    m = M((0, 0, rad * 0.97), (90 + 3, 0, 25)) @ M((0, 0, -L / 2))
    fluted(g, m, rad + 0.02, rad - 0.02, 0, L, rings=4, top_jag=jag)
    # frammento piu' piccolo accanto
    m2 = M((0.95, 0.55, 0.3), (84, 0, 115)) @ M((0, 0, -0.14))
    fluted(g, m2, rad - 0.02, rad - 0.04, 0, 0.28, rings=1, top_jag=lambda th: 0.09 * math.cos(th) + rnd.uniform(-0.015, 0.015))
    return finish(g, name, "rovine")


ALL = {
    "colonna_dorica_intera": lambda: intera(),
    "colonna_dorica_spezzata": lambda: spezzata(),
    "rocchio_colonna_caduto": lambda: rocchio(),
}

if __name__ == "__main__":
    names = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(ALL)
    for n in names:
        okit2.reset()
        ALL[n]()
