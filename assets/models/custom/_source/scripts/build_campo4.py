"""Gruppo 4: equipaggiamento dell'oplita: elmo corinzio con cresta di crine nero, corazza di bronzo con volute,
scudi hoplon ammaccati con tridente e chevron.

Uso (un solo Blender alla volta):  blender -b --factory-startup -P build_campo4.py -- [nome ...]
Modelli originali (modellati per il progetto): licenza del progetto.
"""
import bpy, sys, os, math, random
from mathutils import Vector, Matrix
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import okit2
from okit2 import G, M, finish

V = Vector


def lathe_arc(g, profile, a0, a1, seg, mtx, mat, tile=0.5):
    """Superficie di rotazione limitata a un arco di angoli (gradi); angolo 90 = fronte (+Y)."""
    verts, faces, uvs = [], [], []
    n = len(profile)
    for (r, z) in profile:
        for i in range(seg + 1):
            th = math.radians(a0 + (a1 - a0) * i / seg)
            verts.append((r * math.cos(th), r * math.sin(th), z))
    for k in range(n - 1):
        for i in range(seg):
            a, b, c, d = k * (seg + 1) + i, k * (seg + 1) + i + 1, (k + 1) * (seg + 1) + i + 1, (k + 1) * (seg + 1) + i
            faces.append([a, b, c, d])
            r_ = profile[k][0]
            arc = math.radians(a1 - a0) * r_
            uvs.append([(i / seg * arc / tile, profile[k][1] / tile), ((i + 1) / seg * arc / tile, profile[k][1] / tile),
                        ((i + 1) / seg * arc / tile, profile[k + 1][1] / tile), (i / seg * arc / tile, profile[k + 1][1] / tile)])
    g._add(verts, faces, mat, mtx, uvs, True, tile)


def elmo(name="elmo_corinzio", seed=101):
    g = G(seed)
    rnd = g.rnd
    ys = 1.2                                              # la testa e' piu' lunga che larga
    seg = 44
    zs = [-0.05 + 0.0125 * k for k in range(0, 29)]       # da -0.05 (paranuca) a 0.31 (calotta)

    def rz(z):
        if z < 0.0:
            return 0.14 + (0.0 - z) * 1.0                 # paranuca che si allarga verso il basso
        if z < 0.13:
            return 0.118 + (0.143 - 0.118) * (z / 0.13)   # corpo: leggero restringimento verso il mento
        t = (z - 0.13) / 0.18
        return 0.147 * math.sqrt(max(0.0, 1 - t * t)) + 0.0
    rings = []
    for z in zs:
        r = rz(z)
        rings.append([(r * math.cos(2 * math.pi * i / seg), ys * r * math.sin(2 * math.pi * i / seg), z) for i in range(seg)])
    verts = [v for r in rings for v in r]
    faces, uvs = [], []
    for k in range(len(rings) - 1):
        for i in range(seg):
            j = (i + 1) % seg
            f = [k * seg + i, k * seg + j, (k + 1) * seg + j, (k + 1) * seg + i]
            cx = sum(verts[q][0] for q in f) / 4
            cy = sum(verts[q][1] for q in f) / 4
            cz = sum(verts[q][2] for q in f) / 4
            if cy > 0.02 and cz < 0.138:                 # apertura del volto: occhi larghi, bocca stretta, paranaso al centro
                half = 0.088 if cz > 0.075 else 0.046
                if abs(cx) < half and abs(cx) > 0.0165:
                    continue
                if abs(cx) <= 0.0165 and cz < 0.075:
                    continue
            if cz < 0.0 and cy < 0 and abs(cx) < 0.0 : continue
            faces.append(f)
            u0, u1 = i / seg * 0.9, (i + 1) / seg * 0.9
            uvs.append([(u0, zs[k] * 2), (u1, zs[k] * 2), (u1, zs[k + 1] * 2), (u0, zs[k + 1] * 2)])
    g._add(verts, faces, "bronze", None, uvs, True)
    # paranaso, sopracciglio
    g.box((0.034, 0.022, 0.13), M((0, ys * 0.143 + 0.008, 0.075)), "bronze")
    g.ring(0.152, 0.007, M((0, 0, 0.138), (0, 0, 0), (1, ys, 1)), "bronze", seg=40, tube=4)
    # cresta: segue la superficie della calotta; fascia di bronzo alla base e pennacchio di crine nero ad arco
    def dome_z(y):
        q = min(1.0, abs(y) / (ys * 0.147))
        return 0.13 + 0.18 * math.sqrt(max(0.0, 1 - q * q))
    N = 11
    strip, plume = [], []
    for i in range(N):
        t = i / (N - 1)
        y = 0.215 - t * 0.43
        base = max(dome_z(y), 0.20) + 0.004
        strip.append(((0.0, y, base + 0.006), 0.02, 0.01))
        h = 0.045 + 0.11 * math.sin(math.pi * (0.06 + 0.94 * t)) ** 0.8 + 0.04 * t
        plume.append(((0.0, y - 0.03 * t, base + 0.012 + h * 0.5), 0.016, h * 0.55))
    g.loft(strip, 8, "bronze", dens=3)
    g.loft(plume, 10, "horse_dark", dens=3, tile=0.3)
    for k in range(26):                                   # frangia di crini sul bordo alto
        t = (k + 0.5) / 26
        y = 0.215 - t * 0.43
        base = max(dome_z(y), 0.20) + 0.004
        h = 0.045 + 0.11 * math.sin(math.pi * (0.06 + 0.94 * t)) ** 0.8 + 0.04 * t
        hh = h * rnd.uniform(0.55, 0.95)
        g.quad(0.12, hh * 1.25, M((rnd.uniform(-0.012, 0.012), y - 0.03 * t, base + 0.012 + h * 0.62), (rnd.uniform(-10, 10), 0, 90 + rnd.uniform(-30, 30))), "mane_dark")
    return finish(g, name, "equipaggiamento", double=("bronze",))


def corazza(name="corazza_bronzo", seed=102):
    g = G(seed)
    rnd = g.rnd
    prof = [(0.195, 0.0), (0.178, 0.07), (0.186, 0.21), (0.205, 0.34), (0.2, 0.43), (0.176, 0.5), (0.12, 0.535), (0.088, 0.555)]
    ys = 0.78
    g.lathe(prof, 28, M(scale=(1.0, ys, 1.0)), "bronze")

    def rz(z):                                           # raggio del profilo all'altezza z
        for (r0, z0), (r1, z1) in zip(prof, prof[1:]):
            if z0 <= z <= z1:
                return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
        return prof[-1][0]

    def front_y(x, z):
        r = rz(z)
        return ys * r * math.sqrt(max(0.0, 1 - min(1.0, (x / r) ** 2)))
    for s in (-1, 1):                                    # pettorali e addominali in rilievo
        g.blob((0.075, 0.03, 0.06), M((s * 0.085, front_y(s * 0.085, 0.37) - 0.008, 0.37)), "bronze", 10, 6, 0.0)
        g.blob((0.03, 0.012, 0.012), M((s * 0.088, front_y(s * 0.088, 0.355) + 0.012, 0.355)), "bronze", 6, 4, 0.0)
    g.rod((0, front_y(0, 0.46), 0.46), (0, front_y(0, 0.12) + 0.004, 0.12), 0.007, 0.007, 4, "bronze")
    for z in (0.31, 0.24, 0.17):
        g.rod((-0.07, front_y(-0.07, z) + 0.003, z), (0.07, front_y(0.07, z) + 0.003, z), 0.0065, 0.0065, 4, "bronze")
    # volute ai lati dello sterno e sulle spalle: spirali di bastoncini
    def spirale(cx, cz, r0, turns, side):
        pts = []
        for k in range(19):
            t = k / 18
            ang = side * (t * turns * 2 * math.pi)
            r = r0 * (1 - 0.85 * t)
            x, z = cx + r * math.cos(ang), cz + r * math.sin(ang)
            pts.append(V((x, front_y(x, z) + 0.006, z)))
        for a, b in zip(pts, pts[1:]):
            g.rod(a, b, 0.0075, 0.0075, 4, "bronze", caps=False)
    for s in (-1, 1):
        spirale(s * 0.115, 0.455, 0.045, 1.4, s)
        spirale(s * 0.065, 0.31, 0.03, 1.1, -s)
    # spalline e cinghie di cuoio, pteruges attorno al bacino
    for s in (-1, 1):
        g.blob((0.055, 0.1, 0.012), M((s * 0.14, -0.01, 0.54), (0, s * -28, 0)), "bronze", 8, 5, 0.0)
        g.box((0.05, 0.02, 0.1), M((s * 0.14, 0.0, 0.5), (0, s * 20, 0)), "hide")
    for k in range(16):
        th = 2 * math.pi * k / 16
        x, y = 0.2 * math.cos(th), 0.2 * ys * math.sin(th)
        g.box((0.095, 0.012, 0.21), M((x, y, -0.07), (0, 0, math.degrees(th) - 90 + 0)), "hide")
    g.ring(0.2, 0.012, M((0, 0, 0.0), (0, 0, 0), (1, ys, 1)), "bronze", seg=28, tube=5)
    return finish(g, name, "equipaggiamento")


def hoplon(name, tex, seed, R=0.45, depth=0.1):
    g = G(seed)
    rnd = g.rnd
    ROT = M(rot=(-90, 0, 0))                          # la faccia guarda +Y e lo scudo sta in piedi
    dents = [(rnd.uniform(-0.75, 0.75) * R, rnd.uniform(-0.75, 0.75) * R, rnd.uniform(0.035, 0.09), rnd.uniform(0.008, 0.022)) for _ in range(11)]
    rim_r = 0.88 * R
    NR, NS = 22, 52

    def zf(x, y):
        rr = math.hypot(x, y)
        t = min(rr / rim_r, 1.0)
        z = depth * (1 - t * t)                        # bombatura: il centro e' il punto piu' alto
        if rr > rim_r:
            z = 0.012 * math.sin(min(1.0, (rr - rim_r) / (R - rim_r)) * math.pi)
        for cx, cy, sg, amp in dents:                  # ammaccature
            z -= amp * math.exp(-((x - cx) ** 2 + (y - cy) ** 2) / (2 * sg * sg)) * (0.4 if rr > rim_r else 1.0)
        return z
    for face, offz, mat in (("front", 0.0, tex), ("back", -0.028, "hide")):
        verts = []
        for k in range(NR + 1):
            rr = R * k / NR
            for i in range(NS if k else 1):
                th = 2 * math.pi * i / NS
                x, y = rr * math.cos(th), rr * math.sin(th)
                verts.append((x, y, zf(x, y) + offz))

        def idx(k, i):
            return 0 if k == 0 else 1 + (k - 1) * NS + (i % NS)
        faces = [[0, idx(1, i), idx(1, i + 1)] for i in range(NS)]
        for k in range(1, NR):
            for i in range(NS):
                faces.append([idx(k, i), idx(k + 1, i), idx(k + 1, i + 1), idx(k, i + 1)])
        if face == "back":
            faces = [f[::-1] for f in faces]
        uvs = [[(0.5 + verts[j][0] / (2 * R), 0.5 - verts[j][1] / (2 * R)) for j in f] for f in faces]   # v invertita: la rotazione porta +y verso il basso
        g._add(verts, faces, mat, ROT, uvs, True)
    g.ring(R - 0.004, 0.018, ROT @ M((0, 0, -0.012)), "bronze", seg=44, tube=6)             # bordo
    g.ring(0.075, 0.013, ROT @ M((0, 0, -0.07), (90, 0, 0)), "bronze", seg=14, tube=5, arc=math.pi)   # bracciale (porpax)
    g.rod(ROT @ V((0.27, -0.03, -0.045)), ROT @ V((0.27, 0.03, -0.045)), 0.012, 0.012, 5, "rope")     # maniglia di corda
    for sg in (-1, 1):
        g.rod(ROT @ V((0.065 * sg, 0.0, -0.045)), ROT @ V((0.065 * sg, 0.0, -0.1)), 0.012, 0.012, 5, "bronze")
    return finish(g, name, "equipaggiamento", double=("bronze",))


ALL = {
    "elmo_corinzio": lambda: elmo(),
    "corazza_bronzo": lambda: corazza(),
    "hoplon_tridente": lambda: hoplon("hoplon_tridente", "hoplon_tridente", 111),
    "hoplon_chevron": lambda: hoplon("hoplon_chevron", "hoplon_chevron", 112),
}

if __name__ == "__main__":
    names = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(ALL)
    for n in names:
        okit2.reset()
        ALL[n]()
