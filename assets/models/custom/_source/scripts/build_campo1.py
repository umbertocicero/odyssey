"""Gruppo 1 del campo acheo (Età del bronzo): tende di tela e pelli, calderone con fuoco, pithoi, panche, difese.

Uso (un solo Blender alla volta):  blender -b --factory-startup -P build_campo1.py -- [nome ...]
Modelli originali (modellati per il progetto): licenza del progetto.
"""
import bpy, sys, os, math
from mathutils import Vector, Matrix
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import okit2
from okit2 import G, M, seg_m, finish


# ------------------------------------------------------------------ tende
def tent(seed, name, L=4.8, W=1.9, H=2.6, hide_from=0.62, branches=16, extra_hides=0):
    g = G(seed)
    rnd = g.rnd
    # pali: due forcelle ai capi del colmo, colmo, puntelli laterali
    for y in (-L / 2, L / 2):
        g.cyl(0.075, 0.06, H + 0.12, 8, M((0, y, 0)), "bark")
    g.rod((0, -L / 2 - 0.4, H + 0.02), (0, L / 2 + 0.4, H + 0.02), 0.06, 0.055, 8, "bark")
    for y in (-1.45, 0, 1.45):
        for s in (-1, 1):
            g.rod((s * (W * 1.12), y, 0.0), (s * (W * 0.78), y, 1.15), 0.045, 0.04, 6, "bark")

    def roof_p(s):
        def P(u, v):
            y = -L / 2 + L * u
            x = s * W * 1.05 * v
            z = H - (H - 0.05) * v ** 1.6
            z -= 0.11 * math.sin(math.pi * u) * math.sin(math.pi * min(1, v * 1.1)) * 0.9      # cedimento tra i pali
            z += 0.018 * math.sin(u * 38 + v * 5 + s) * v                                          # pieghe
            return (x, y + 0.03 * math.sin(v * 7 + s), z)
        return P
    NU, NV = 22, 8
    matfn = lambda i, j: "hide" if (j + 0.5) / NV >= hide_from else "canvas"
    for s in (-1, 1):
        g.slab(roof_p(s), NU, NV, 0.025, matfn, tile=1.0)
    # timpano posteriore chiuso e anteriore con due lembi legati ai lati
    def gable(yg, side):
        def P(u, v):
            return ((2 * u - 1) * W * 1.05 * (1 - v), yg, 0.05 + (H - 0.05) * v)
        return P
    g.slab(gable(-L / 2, -1), 10, 7, 0.025, lambda i, j: "canvas")
    apex = Vector((0, L / 2, H * 0.97))
    for s in (-1, 1):
        B = Vector((s * W * 1.05, L / 2, 0.05))
        C = Vector((s * 0.55, L / 2 + 0.35, 0.05))
        def P(u, v, B=B, C=C):
            base = B + (C - B) * u
            p = base * (1 - v) + apex * v
            return (p.x, p.y + 0.05 * math.sin(u * 3) * (1 - v), p.z)
        g.slab(P, 8, 7, 0.025, lambda i, j: "canvas")
        g.rod((s * 0.55, L / 2 + 0.35, 0.05), (s * 0.55, L / 2 + 0.35, 0.9), 0.03, 0.03, 5, "rope")
    # pavimento di pelli e puntelli all'ingresso
    g.box((W * 1.7, L * 0.8, 0.025), M((0, 0, 0.012)), "hide", long_u=False)
    for s in (-1, 1):
        g.rod((s * 0.95, L / 2 + 0.75, 0.0), (s * 0.12, L / 2 + 0.3, H - 0.15), 0.05, 0.045, 7, "bark")
    # rami frondosi sul tetto: stelo + due schede incrociate
    P_roof = {s: roof_p(s) for s in (-1, 1)}
    for k in range(branches):
        s = -1 if k % 2 else 1
        u, v = rnd.uniform(0.08, 0.92), rnd.uniform(0.12, 0.8)
        p0, pu, pv = Vector(P_roof[s](u, v)), Vector(P_roof[s](u + 0.01, v)), Vector(P_roof[s](u, v + 0.01))
        t = (pv - p0).normalized()                   # in discesa lungo la falda
        b = (pu - p0).normalized()
        n = t.cross(b).normalized()
        if n.z < 0:
            n = -n
        yaw = math.radians(rnd.uniform(-35, 35))
        t2 = (t * math.cos(yaw) + b * math.sin(yaw)).normalized()
        b2 = t2.cross(n).normalized()
        L_b = rnd.uniform(1.15, 1.6)
        base = p0 + n * 0.03
        g.rod(base, base + t2 * L_b, 0.012, 0.008, 5, "bark")
        for tilt in (0.0, 0.32):
            up = (t2 * math.cos(tilt) + n * math.sin(tilt)).normalized()
            # scheda: z lungo 'up' (verso il basso della falda), x lungo la larghezza, y = normale
            rot = Matrix((b2, up.cross(b2), up)).transposed().to_4x4()
            g.quad(L_b * 0.78, L_b * 0.98, Matrix.Translation(base + n * (0.02 if tilt > 0 else 0.0)) @ rot, "leaves")
    for k in range(extra_hides):                       # pellicce buttate sul colmo
        s = -1 if k % 2 else 1
        u, v = rnd.uniform(0.15, 0.85), rnd.uniform(0.04, 0.18)
        p = Vector(P_roof[s](u, v))
        g.blob((0.5, 0.36, 0.05), M(tuple(p + Vector((0, 0, 0.05))), (0, s * 22, rnd.uniform(0, 180))), "hide", 10, 5, 0.12)
    # tiranti e picchetti
    for y in (-1.8, -0.6, 0.6, 1.8):
        for s in (-1, 1):
            pe = Vector(P_roof[s](0.5 + y / L, 0.97))
            gp = Vector((s * (W * 1.05 + 0.85), pe.y, 0.0))
            g.rod(pe, gp + Vector((0, 0, 0.12)), 0.011, 0.011, 4, "rope", caps=False)
            g.rod(gp + Vector((s * 0.1, 0, 0.0)), gp + Vector((-s * 0.04, 0, 0.3)), 0.028, 0.025, 5, "bark")
    return finish(g, name, "tende")


# ------------------------------------------------------------------ focolare con calderone
def focolare(seed=21, name="focolare_calderone"):
    g = G(seed)
    rnd = g.rnd
    n = 9
    for i in range(n):                               # anello di pietre
        a = 2 * math.pi * i / n + rnd.uniform(-0.1, 0.1)
        r = 0.52 + rnd.uniform(-0.04, 0.05)
        g.blob((rnd.uniform(0.17, 0.25), rnd.uniform(0.15, 0.2), rnd.uniform(0.11, 0.16)),
               M((r * math.cos(a), r * math.sin(a), 0.1), (rnd.uniform(-8, 8), rnd.uniform(-8, 8), rnd.uniform(0, 180))), "stone", 9, 6, 0.2)
    g.cyl(0.42, 0.40, 0.05, 14, M((0, 0, 0.0)), "charcoal", caps=True)            # braci a terra
    for i in range(6):                               # tizzoni incrociati
        a = math.radians(i * 60 + rnd.uniform(-10, 10))
        g.rod((0.32 * math.cos(a), 0.32 * math.sin(a), 0.05), (-0.32 * math.cos(a), -0.32 * math.sin(a), 0.16 + 0.05 * (i % 3)), 0.05, 0.043, 7, "charcoal")
    for k in range(3):                               # fiamme: tre schede incrociate
        g.quad(0.62, 0.7 + 0.1 * (k % 2), M((0, 0, 0.1), (0, 0, 60 * k + 15)), "flame")
    # treppiede e calderone appeso
    top = Vector((0, 0, 1.62))
    for i in range(3):
        a = math.radians(120 * i + 20)
        g.rod((0.95 * math.cos(a), 0.95 * math.sin(a), 0.0), top + Vector((0.03 * math.cos(a + 1), 0.03 * math.sin(a + 1), 0.04 * i)), 0.04, 0.032, 7, "bark")
    g.cyl(0.065, 0.065, 0.16, 8, M((0, 0, 1.52)), "rope")
    for i in range(3):                               # tre catene di maglie dal vertice al bordo
        a = math.radians(120 * i + 80)
        bot = Vector((0.27 * math.cos(a), 0.27 * math.sin(a), 0.99))
        for k in range(8):
            p0 = top.lerp(bot, k / 8)
            p1 = top.lerp(bot, (k + 0.6) / 8)
            g.rod(p0, p1, 0.011, 0.011, 4, "bronze")
    bowl = [(0.0, 0.0), (0.1, 0.012), (0.2, 0.07), (0.27, 0.17), (0.3, 0.29), (0.3, 0.34), (0.285, 0.36), (0.27, 0.345), (0.27, 0.3), (0.255, 0.18), (0.19, 0.09), (0.1, 0.035), (0.0, 0.03)]
    g.lathe(bowl, 18, M((0, 0, 0.62)), "bronze", uv_norm=False, tile=0.6)
    g.ring(0.3, 0.018, M((0, 0, 0.965)), "bronze", seg=18, tube=6)
    for s in (-1, 1):
        g.ring(0.085, 0.018, M((s * 0.31, 0, 0.93), (90, 0, 0)), "bronze", seg=10, tube=5)
    return finish(g, name, "fuochi")


# ------------------------------------------------------------------ pithoi
def pithos(name, scale=1.0, lid=False, seed=31):
    g = G(seed)
    prof = [(0.0, 0.0), (0.27, 0.0), (0.40, 0.07), (0.50, 0.28), (0.54, 0.58), (0.51, 0.93), (0.40, 1.16), (0.31, 1.29), (0.30, 1.33),
            (0.355, 1.375), (0.36, 1.43), (0.30, 1.455), (0.27, 1.43), (0.27, 1.33), (0.25, 1.28)]
    prof = [(r * scale, z * scale) for r, z in prof]
    g.lathe(prof, 20, None, "clay", uv_norm=True)
    for z in (0.52, 0.86):                           # cordoni a rilievo
        g.ring(0.54 * scale if z < 0.7 else 0.52 * scale, 0.02 * scale, M((0, 0, z * scale)), "clay", seg=20, tube=6)
    for k in range(4):                               # anse a nastro sulla spalla
        a = math.radians(90 * k + 45)
        rr = 0.47 * scale
        g.ring(0.11 * scale, 0.026 * scale, M((rr * math.cos(a), rr * math.sin(a), 1.02 * scale), (90, 0, math.degrees(a) + 90)), "clay", seg=10, tube=5, arc=math.pi)
    g.cyl(0.245 * scale, 0.245 * scale, 0.02, 14, M((0, 0, 1.285 * scale)), "bark", caps=True)    # bocca scura
    if lid:
        g.cyl(0.42 * scale, 0.40 * scale, 0.07 * scale, 12, M((0.12 * scale, 0.05 * scale, 1.43 * scale), (14, -10, 20)), "stone")
    return finish(g, name, "giare_panche")


# ------------------------------------------------------------------ panche
def panca_assi(name="panca_assi", L=2.2, seed=41):
    g = G(seed)
    rnd = g.rnd
    g.box((L, 0.34, 0.07), M((0, 0, 0.5)), "planks")
    g.box((L, 0.03, 0.06), M((0, -0.15, 0.435)), "planks")
    g.box((L, 0.03, 0.06), M((0, 0.15, 0.435)), "planks")
    for x in (-L * 0.38, L * 0.38):
        for s in (-1, 1):
            g.rod((x + 0.05 * s, s * 0.22, 0.0), (x, s * 0.1, 0.47), 0.04, 0.035, 5, "bark")
        g.box((0.05, 0.3, 0.05), M((x, 0, 0.22)), "planks", long_u=False)
    return finish(g, name, "giare_panche")


def panca_ceppi(name="panca_ceppi", L=2.0, seed=42):
    g = G(seed)
    rnd = g.rnd
    g.box((L, 0.36, 0.1), M((0, 0, 0.45)), "planks")
    for x in (-L * 0.36, L * 0.36):
        g.cyl(0.15, 0.13, 0.4, 9, M((x, rnd.uniform(-0.02, 0.02), 0.0)), "bark")
    for x in (-L * 0.36, L * 0.36):
        g.rod((x - 0.06, -0.1, 0.35), (x - 0.06, 0.1, 0.5), 0.02, 0.02, 4, "rope")
    return finish(g, name, "giare_panche")


# ------------------------------------------------------------------ difese
def palizzata(name="palizzata_sezione", n=12, seed=51, corner=False):
    g = G(seed)
    rnd = g.rnd
    sp = 0.235
    logs = []
    if not corner:
        for i in range(n):
            logs.append((i * sp - (n - 1) * sp / 2, 0.0, 0.0))
    else:
        m = n // 2
        for i in range(m + 1):
            logs.append((i * sp, 0.0, 0.0))
        for i in range(1, m + 1):
            logs.append((0.0, i * sp, 90.0))
    for (x, y, rot) in logs:
        h = 2.35 + rnd.uniform(-0.18, 0.2)
        r = 0.11 + rnd.uniform(-0.01, 0.012)
        lean = rnd.uniform(-1.8, 1.8)
        a = Vector((x + rnd.uniform(-0.012, 0.012), y + rnd.uniform(-0.015, 0.015), -0.15))
        b = a + Vector((math.sin(math.radians(lean)) * h, math.sin(math.radians(lean * 0.6)) * h * 0.4, h + 0.15))
        g.stake(a, b, r, tip=0.34 + rnd.uniform(-0.04, 0.05), seg=8)
    # travi di legatura e cordami
    if not corner:
        x0, x1 = logs[0][0] - 0.15, logs[-1][0] + 0.15
        for z in (0.72, 1.58):
            g.rod((x0, -0.14, z), (x1, -0.14, z + 0.03), 0.055, 0.05, 6, "bark")
        for (x, y, rot) in logs:
            for z in (0.72, 1.58):
                g.ring(0.115, 0.012, M((x, 0, z + 0.015), (0, 0, 0)), "rope", seg=10, tube=4)
    else:
        for z in (0.72, 1.58):
            g.rod((-0.15, -0.14, z), (1.45, -0.14, z + 0.03), 0.055, 0.05, 6, "bark")
            g.rod((-0.14, -0.15, z), (-0.14, 1.45, z + 0.03), 0.055, 0.05, 6, "bark")
    return finish(g, name, "difese")


def cheval(name="barricata_cheval_de_frise", L=2.6, seed=61):
    g = G(seed)
    rnd = g.rnd
    z = 0.62
    g.rod((-L / 2, 0, z), (L / 2, 0, z), 0.085, 0.08, 8, "bark")
    for x in (-L * 0.4, 0, L * 0.4):                   # cavalletti a X
        for s in (-1, 1):
            g.rod((x + 0.0, s * 0.62, 0.0), (x, -s * 0.18, 1.05), 0.055, 0.05, 6, "bark")
    nx = 9
    for i in range(nx):                                # pali affilati che attraversano la trave
        x = -L / 2 + 0.18 + i * (L - 0.36) / (nx - 1)
        for a_deg in ((38 if i % 2 else -38), (142 if i % 2 else 218), 90 if i % 3 == 0 else 270):
            a = math.radians(a_deg)
            d = Vector((0, math.cos(a), math.sin(a)))
            c = Vector((x, 0, z))
            g.stake(c - d * 0.25, c + d * (1.15 + rnd.uniform(-0.1, 0.1)), 0.036, tip=0.32, seg=6)
    for i in range(nx):
        x = -L / 2 + 0.18 + i * (L - 0.36) / (nx - 1)
        g.ring(0.09, 0.012, M((x, 0, z), (0, 90, 0)), "rope", seg=10, tube=4)
    return finish(g, name, "difese")


ALL = {
    "tenda_tela_rami": lambda: tent(11, "tenda_tela_rami", L=4.8, W=1.9, H=2.6, hide_from=0.62, branches=28, extra_hides=2),
    "tenda_pelli": lambda: tent(12, "tenda_pelli", L=4.1, W=1.65, H=2.25, hide_from=0.28, branches=11, extra_hides=5),
    "focolare_calderone": lambda: focolare(),
    "pithos_grande": lambda: pithos("pithos_grande", 1.0, False, 31),
    "pithos_medio_coperchio": lambda: pithos("pithos_medio_coperchio", 0.66, True, 32),
    "panca_assi": lambda: panca_assi(),
    "panca_ceppi": lambda: panca_ceppi(),
    "palizzata_sezione": lambda: palizzata("palizzata_sezione", 12),
    "palizzata_angolo": lambda: palizzata("palizzata_angolo", 12, 52, True),
    "barricata_cheval_de_frise": lambda: cheval(),
}

if __name__ == "__main__":
    names = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(ALL)
    for n in names:
        okit2.reset()
        ALL[n]()
