"""Gruppo 2 del campo/Troia: mura di calcare ocra con merli, torre quadrata merlata, porta a due battenti, piattaforma di guardia.

Uso (un solo Blender alla volta):  blender -b --factory-startup -P build_campo2.py -- [nome ...]
Modelli originali (modellati per il progetto): licenza del progetto.
"""
import bpy, sys, os, math
from mathutils import Vector, Matrix
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import okit2
from okit2 import G, M, finish


def stone_region(g, x0, x1, z0, z1, mtx, depth=0.12, bh=(0.34, 0.5), bw=(0.55, 1.0), mat="limestone"):
    """Blocchi di calcare a corsi sfalsati su un rettangolo di parete (piano locale XZ, sporgono lungo +Y)."""
    rnd = g.rnd
    z, row = z0, 0
    while z < z1 - 0.05:
        h = min(rnd.uniform(*bh), z1 - z)
        if z1 - (z + h) < 0.2:
            h = z1 - z
        x = x0 - (rnd.uniform(0.1, 0.5) if row % 2 else 0.0)
        while x < x1 - 0.02:
            w = rnd.uniform(*bw)
            xa, xb = max(x, x0), min(x + w, x1)
            if xb - xa > 0.1:
                d = depth + rnd.uniform(-0.03, 0.02)
                g.box((xb - xa - 0.03, d, h - 0.03), mtx @ M(((xa + xb) / 2, d / 2, z + h / 2)), mat)
            x += w
        z += h
        row += 1


def merli(g, xs, y, z, w=0.8, t=0.9, h=0.8):
    for x in xs:
        g.box((w, t, h), M((x, y, z + h / 2)), "limestone")
        g.box((w + 0.1, t + 0.05, 0.09), M((x, y, z + h + 0.045)), "limestone", long_u=True)


def mura_tratto(name="mura_tratto", L=4.0, T=0.9, Hb=3.4, seed=71):
    g = G(seed)
    g.box((L, T, Hb), M((0, 0, Hb / 2)), "limestone")
    g.box((L + 0.06, T + 0.16, 0.3), M((0, 0, 0.15)), "limestone")             # zoccolo
    for s in (1, -1):
        mtx = M((0, s * T / 2, 0), (0, 0, 0 if s == 1 else 180))
        stone_region(g, -L / 2, L / 2, 0.3, Hb, mtx)
    g.box((L + 0.04, T + 0.14, 0.18), M((0, 0, Hb + 0.09)), "limestone")           # cornice del camminamento
    n = int(L / 1.35) + 1
    merli(g, [-(n - 1) / 2 * 1.35 + i * 1.35 for i in range(n)], 0, Hb + 0.18, t=T)
    return finish(g, name, "mura")


def torre(name="torre_quadrata", B=3.6, Hb=7.0, seed=72):
    g = G(seed)
    g.box((B, B, Hb), M((0, 0, Hb / 2)), "limestone")
    g.box((B + 0.24, B + 0.24, 0.35), M((0, 0, 0.175)), "limestone")
    for k in range(4):
        mtx = M((0, 0, 0), (0, 0, 90 * k)) @ M((0, B / 2, 0))
        stone_region(g, -B / 2 + 0.02, B / 2 - 0.02, 0.35, Hb, mtx, depth=0.11, bh=(0.4, 0.55), bw=(0.6, 1.05))
    for sx in (-1, 1):                                # cantonali
        for sy in (-1, 1):
            g.box((0.46, 0.46, Hb), M((sx * B / 2, sy * B / 2, Hb / 2)), "limestone", tile=0.6)
    # feritoie e porta
    for k in range(4):
        rot = M((0, 0, 0), (0, 0, 90 * k))
        g.box((0.13, 0.16, 0.9), rot @ M((0, B / 2 + 0.01, 4.6)), "bark")
        if k:
            g.box((0.13, 0.16, 0.9), rot @ M((0, B / 2 + 0.01, 2.6)), "bark")
    g.box((1.15, 0.12, 1.95), M((0, B / 2 + 0.06, 1.0 + 0.0)), "planks")
    g.box((1.6, 0.26, 0.3), M((0, B / 2 + 0.1, 2.12)), "limestone")
    for s in (-1, 1):
        g.box((0.22, 0.26, 2.0), M((s * 0.68, B / 2 + 0.1, 1.0)), "limestone")
    for z in (0.5, 1.5):
        g.box((1.1, 0.03, 0.1), M((0, B / 2 + 0.14, z)), "iron")
    # coronamento aggettante con merli
    ov = 0.3
    g.box((B + 2 * ov, B + 2 * ov, 0.3), M((0, 0, Hb + 0.15)), "limestone")
    zc = Hb + 0.3
    P = B / 2 + ov - 0.22
    for k in range(4):
        rot = M((0, 0, 0), (0, 0, 90 * k))
        for xo in (-1.2, 0.0, 1.2):
            g.box((0.8, 0.44, 0.8), rot @ M((xo, P, zc + 0.4)), "limestone")
            g.box((0.9, 0.5, 0.09), rot @ M((xo, P, zc + 0.845)), "limestone")
        g.box((0.7, 0.7, 0.8), rot @ M((-P + 0.22 - 0.22, P, zc + 0.4)), "limestone") if False else None
    for sx in (-1, 1):
        for sy in (-1, 1):
            g.box((0.62, 0.62, 0.8), M((sx * P, sy * P, zc + 0.4)), "limestone")
            g.box((0.72, 0.72, 0.09), M((sx * P, sy * P, zc + 0.845)), "limestone")
    return finish(g, name, "mura")


def porta(name="porta_due_battenti", Wt=5.4, T=1.0, Hb=3.9, ow=2.4, oh=3.0, seed=73):
    g = G(seed)
    xl, xr = -ow / 2, ow / 2
    lint = oh + 0.55
    # corpo della parete: due fianchi e architrave
    side_w = (Wt - ow) / 2
    for s in (-1, 1):
        g.box((side_w, T, Hb), M((s * (ow / 2 + side_w / 2), 0, Hb / 2)), "limestone")
    g.box((ow + 0.02, T, Hb - lint), M((0, 0, lint + (Hb - lint) / 2)), "limestone")
    g.box((Wt + 0.06, T + 0.16, 0.3), M((0, 0, 0.15)), "limestone")
    for s in (1, -1):
        mtx = M((0, s * T / 2, 0), (0, 0, 0 if s == 1 else 180))
        stone_region(g, -Wt / 2, xl - 0.45, 0.3, Hb, mtx)
        stone_region(g, xr + 0.45, Wt / 2, 0.3, Hb, mtx)
        stone_region(g, xl - 0.45, xr + 0.45, lint + 0.02, Hb, mtx)
        # cornice di pietra: stipiti a blocchi e architrave monolitico
        zz = 0.3
        i = 0
        while zz < oh:
            h = 0.52 if oh - zz > 0.55 else oh - zz
            for sx in (-1, 1):
                g.box((0.5, 0.16, h - 0.03), mtx @ M((sx * (ow / 2 + 0.25), 0.08 + 0.04 * (i % 2), zz + h / 2)), "limestone", tile=0.7)
            zz += h; i += 1
        g.box((ow + 1.1, 0.26, 0.55), mtx @ M((0, 0.13, oh + 0.275)), "limestone", tile=0.8)
        g.box((ow + 1.3, 0.34, 0.14), mtx @ M((0, 0.17, oh + 0.62)), "limestone", tile=0.8)
    g.box((Wt + 0.04, T + 0.14, 0.18), M((0, 0, Hb + 0.09)), "limestone")
    merli(g, [-2.0, -0.65, 0.7, 2.05], 0, Hb + 0.18, t=T)
    # battenti: assi verticali, fasce di ferro, borchie, anelli
    yd = -0.1
    for s in (-1, 1):
        x0 = s * (ow / 2) - s * 0.02
        lw = ow / 2 - 0.03
        nb = 5
        bw = lw / nb
        for b in range(nb):
            xc = x0 - s * (b + 0.5) * bw
            g.box((bw - 0.015, 0.09, oh - 0.04), M((xc, yd + 0.0, (oh - 0.04) / 2 + 0.02 + (b % 2) * 0.01)), "planks")
        for z in (0.45, 1.5, 2.5):
            g.box((lw, 0.035, 0.13), M((x0 - s * lw / 2, yd + 0.06, z)), "iron")
            for k in range(5):
                g.cyl(0.036, 0.03, 0.04, 6, M((x0 - s * (0.12 + k * (lw - 0.2) / 4), yd + 0.085, z - 0.0), (-90, 0, 0)), "iron")
        for z in (0.95, 1.5 + 0.5, 2.0 + 0.5 - 0.5):
            for k in range(3):
                g.cyl(0.032, 0.026, 0.035, 6, M((x0 - s * (0.28 + k * 0.38), yd + 0.075, z + 0.28), (-90, 0, 0)), "iron")
        g.ring(0.085, 0.013, M((s * 0.2, yd + 0.1, 1.45), (90, 0, 0)), "iron", seg=12, tube=5)
    return finish(g, name, "mura")


def piattaforma(name="piattaforma_guardia_tegole", S=2.4, seed=74):
    g = G(seed)
    rnd = g.rnd
    zf = 2.1
    for sx in (-1, 1):
        for sy in (-1, 1):
            g.rod((sx * S / 2, sy * S / 2, 0.0), (sx * S / 2 + rnd.uniform(-0.03, 0.03), sy * S / 2, 3.45), 0.1, 0.085, 8, "bark")
    for z in (0.9, 1.5):                                   # travi di controvento
        for a, b in (((-S / 2, -S / 2), (S / 2, -S / 2)), ((-S / 2, S / 2), (S / 2, S / 2)), ((-S / 2, -S / 2), (-S / 2, S / 2)), ((S / 2, -S / 2), (S / 2, S / 2))):
            g.rod((a[0], a[1], z), (b[0], b[1], z + 0.02), 0.04, 0.04, 5, "bark")
    for sx in (-S / 3, 0, S / 3):
        g.rod((sx, -S / 2 - 0.1, zf - 0.1), (sx, S / 2 + 0.1, zf - 0.1), 0.06, 0.06, 6, "bark")
    nb = 9
    for i in range(nb):
        y = -S / 2 - 0.1 + i * (S + 0.2) / (nb - 1)
        g.box((S + 0.3, 0.255, 0.07), M((0, y, zf)), "planks")
    for side in (-1, 1, 2):                                # parapetto su tre lati (il quarto ha la scala)
        for z in (zf + 0.45, zf + 0.95):
            if side == 2:
                g.rod((-S / 2, S / 2, z), (S / 2, S / 2, z), 0.035, 0.035, 5, "bark")
            else:
                g.rod((side * S / 2, -S / 2, z), (side * S / 2, S / 2, z), 0.035, 0.035, 5, "bark")
    # scala a pioli sul lato -Y
    for sx in (-0.28, 0.28):
        g.rod((sx, -S / 2 - 0.9, 0.0), (sx, -S / 2 - 0.15, zf + 0.75), 0.04, 0.035, 6, "bark")
    for k in range(9):
        t = (k + 0.7) / 9.6
        y = -S / 2 - 0.9 + t * 0.75
        g.rod((-0.3, y, t * (zf + 0.75)), (0.3, y, t * (zf + 0.75)), 0.025, 0.025, 5, "bark")
    # tetto a quattro falde di tegole
    ov = S / 2 + 0.45
    zr, za = 3.05, 4.25
    corners = [(-ov, -ov), (ov, -ov), (ov, ov), (-ov, ov)]
    for k in range(4):
        a, b = corners[k], corners[(k + 1) % 4]
        def P(u, v, a=a, b=b):
            ex, ey = a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u
            return (ex * (1 - v), ey * (1 - v), zr + (za - zr) * v - 0.04 * math.sin(math.pi * u) * (1 - v))
        g.slab(P, 8, 4, 0.07, lambda i, j: "tile", tile=1.0)
    g.rod((0, 0, za - 0.1), (0, 0, za + 0.25), 0.04, 0.02, 6, "bark")
    return finish(g, name, "mura")


ALL = {
    "mura_tratto": lambda: mura_tratto(),
    "torre_quadrata": lambda: torre(),
    "porta_due_battenti": lambda: porta(),
    "piattaforma_guardia_tegole": lambda: piattaforma(),
}

if __name__ == "__main__":
    names = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(ALL)
    for n in names:
        okit2.reset()
        ALL[n]()
