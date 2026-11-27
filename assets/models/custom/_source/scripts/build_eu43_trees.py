"""Alberi a foglia larga (castagno/quercia) generati proceduralmente con le texture del pacchetto EU43_FORESTPACK.

Il pacchetto contiene solo .max (non importabili): usiamo solo le texture (foglia singola con alpha, cortecce con normal map)
e costruiamo qui rami rastremati e foglie singole (quad alpha-cutout, doppia faccia).
Avvio: blender -b --factory-startup -P build_eu43_trees.py
Esce in ../../eu43/alberi/<nome>/<nome>.gltf (+ textures/). Origine alla base del tronco, altezza ~ 6 m, Y su in glTF.
"""
import bpy, bmesh, math, os, random, shutil
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
TEX = os.path.join(HERE, "..", "textures", "eu43")
OUT = os.path.abspath(os.path.join(HERE, "..", "..", "eu43", "alberi"))

# nome, seed, corteccia, altezza, ramificazioni, foglie per rametto, scala foglia, forma chioma (larghezza/altezza), lean
VARIANTS = [
    ("castagno_a", 3, "bark_brown", 6.0, 3, 12, 1.0, 0.95, 0.04),
    ("castagno_b", 11, "bark_grey", 5.2, 3, 12, 1.0, 1.15, 0.10),
    ("castagno_c", 27, "bark_brown", 4.4, 3, 12, 1.1, 1.25, 0.16),
    # versioni leggere per qualità bassa/media: meno foglie, più grandi
    ("castagno_a_lod", 3, "bark_brown", 6.0, 3, 4, 1.7, 0.95, 0.04),
    ("castagno_b_lod", 11, "bark_grey", 5.2, 3, 4, 1.7, 1.15, 0.10),
    ("castagno_c_lod", 27, "bark_brown", 4.4, 3, 4, 1.8, 1.25, 0.16),
]


def mat_bark(name):
    m = bpy.data.materials.new("M_" + name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = bpy.data.images.load(os.path.join(TEX, name + "_diff.jpg"))
    nt.links.new(t.outputs[0], b.inputs["Base Color"])
    n = nt.nodes.new("ShaderNodeTexImage")
    n.image = bpy.data.images.load(os.path.join(TEX, name + "_nor.jpg"))
    n.image.colorspace_settings.name = "Non-Color"
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(n.outputs[0], nm.inputs["Color"])
    nt.links.new(nm.outputs[0], b.inputs["Normal"])
    b.inputs["Roughness"].default_value = 0.9
    b.inputs["Metallic"].default_value = 0.0
    return m


def mat_leaf():
    m = bpy.data.materials.new("M_foglia_castagno")
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = bpy.data.images.load(os.path.join(TEX, "leaf_chestnut_color_alpha.png"))
    nt.links.new(t.outputs[0], b.inputs["Base Color"])
    r = nt.nodes.new("ShaderNodeMath"); r.operation = "ROUND"
    nt.links.new(t.outputs[1], r.inputs[0])
    nt.links.new(r.outputs[0], b.inputs["Alpha"])
    n = nt.nodes.new("ShaderNodeTexImage")
    n.image = bpy.data.images.load(os.path.join(TEX, "leaf_chestnut_normal.png"))
    n.image.colorspace_settings.name = "Non-Color"
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(n.outputs[0], nm.inputs["Color"])
    nt.links.new(nm.outputs[0], b.inputs["Normal"])
    b.inputs["Roughness"].default_value = 0.6
    m.use_backface_culling = False
    return m


class Builder:
    def __init__(self, seed, height, depth, leaves_per, leaf_scale, aspect, lean):
        self.r = random.Random(seed)
        self.h = height
        self.depth = depth
        self.leaves_per = leaves_per
        self.ls = leaf_scale
        self.aspect = aspect
        self.lean = lean
        self.bark = bmesh.new()
        self.leaf = bmesh.new()
        self.bl = self.bark.loops.layers.uv.new("UVMap")
        self.ll = self.leaf.loops.layers.uv.new("UVMap")
        self.vcol = self.leaf.loops.layers.color.new("Col")
        self.tips = []

    # -- ramo come tubo rastremato lungo una spline (punti), raggio r0 -> r1
    def tube(self, pts, r0, r1, sides=6, v0=0.0):
        rings = []
        up = Vector((0, 0, 1))
        for i, p in enumerate(pts):
            t = i / (len(pts) - 1)
            d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
            a = d.cross(up)
            if a.length < 1e-3:
                a = d.cross(Vector((1, 0, 0)))
            a.normalize()
            b = d.cross(a).normalized()
            rad = r0 + (r1 - r0) * t
            ring = []
            for s in range(sides + 1):
                ang = 2 * math.pi * s / sides
                ring.append(self.bark.verts.new(p + (a * math.cos(ang) + b * math.sin(ang)) * rad))
            rings.append(ring)
        vlen = sum((pts[i + 1] - pts[i]).length for i in range(len(pts) - 1))
        acc = 0.0
        vs = [v0]
        for i in range(len(pts) - 1):
            acc += (pts[i + 1] - pts[i]).length
            vs.append(v0 + acc / 1.2)
        for i in range(len(rings) - 1):
            for s in range(sides):
                f = self.bark.faces.new((rings[i][s], rings[i][s + 1], rings[i + 1][s + 1], rings[i + 1][s]))
                uv = [(s / sides, vs[i]), ((s + 1) / sides, vs[i]), ((s + 1) / sides, vs[i + 1]), (s / sides, vs[i + 1])]
                for lp, (u, v) in zip(f.loops, uv):
                    lp[self.bl].uv = (u * 1.0, v)
        # tappo finale rimosso: i rami finiscono sotto le foglie

    def branch(self, start, direction, length, radius, level):
        r = self.r
        n = 6 if level == 0 else 5
        pts = [start]
        d = direction.copy()
        p = start.copy()
        step = length / n
        for i in range(n):
            # leggera curvatura e gravità sui rami laterali
            d = (d + Vector((r.uniform(-1, 1), r.uniform(-1, 1), r.uniform(-0.3, 0.6) if level == 0 else r.uniform(-0.5, 0.5))) * (0.10 if level == 0 else 0.22))
            if level > 0:
                d.z -= 0.04
            d.normalize()
            p = p + d * step
            pts.append(p.copy())
        r1 = radius * (0.35 if level == 0 else 0.25)
        self.tube(pts, radius, max(r1, 0.006), sides=8 if level == 0 else 5, v0=r.random())
        if level >= self.depth:
            self.tips.append((pts, d))
            return
        # rami figli
        kids = {0: 8, 1: 5, 2: 4}.get(level, 3)
        golden = r.uniform(0, 6.28)
        for k in range(kids):
            t = (0.38 + 0.62 * (k + r.random() * 0.6) / kids) if level == 0 else (0.35 + 0.65 * (k + r.random() * 0.5) / kids)
            idx = min(int(t * n), n - 1)
            base = pts[idx] + (pts[idx + 1] - pts[idx]) * (t * n - idx)
            golden += 2.4
            par = (pts[min(idx + 1, n)] - pts[idx]).normalized()
            ax = par.cross(Vector((0, 0, 1)))
            if ax.length < 1e-3:
                ax = Vector((1, 0, 0))
            ax.normalize()
            ay = par.cross(ax)
            spread = r.uniform(0.9, 1.25) if level == 0 else r.uniform(0.7, 1.1)
            nd = (par * math.cos(spread * 0.7) + (ax * math.cos(golden) + ay * math.sin(golden)) * math.sin(spread * 0.7))
            nd.z += 0.15 if level == 0 else 0.05
            nd.normalize()
            clen = length * (r.uniform(0.55, 0.8) if level == 0 else r.uniform(0.5, 0.75))
            # chioma più larga che alta: i rami bassi più lunghi
            clen *= self.aspect ** 0.5
            self.branch(base, nd, clen, radius * (0.45 if level == 0 else 0.5), level + 1)
        # prolungamento
        if level == 0:
            pass

    def add_leaf(self, pos, normal_hint, size):
        r = self.r
        # asse lungo della foglia: lungo il ramo con variazione, pendente
        axis = (normal_hint + Vector((r.uniform(-1, 1), r.uniform(-1, 1), r.uniform(-1.2, 0.3))) * 0.9).normalized()
        axis.z -= 0.15
        axis.normalize()
        side = axis.cross(Vector((r.uniform(-0.4, 0.4), r.uniform(-0.4, 0.4), 1))).normalized()
        L = size * r.uniform(0.85, 1.2)
        W = L * 0.454
        # il picciolo (v=0) sta in pos; la foglia si estende lungo axis
        c = [pos - side * (W / 2), pos + side * (W / 2), pos + side * (W / 2) + axis * L, pos - side * (W / 2) + axis * L]
        vs = [self.leaf.verts.new(x) for x in c]
        f = self.leaf.faces.new(vs)
        for lp, uv in zip(f.loops, [(0, 0), (1, 0), (1, 1), (0, 1)]):
            lp[self.ll].uv = uv
        tint = r.uniform(0.75, 1.15)
        col = (tint * r.uniform(0.95, 1.05), tint, tint * r.uniform(0.8, 0.95), 1.0)
        for lp in f.loops:
            lp[self.vcol] = col

    def leaves(self):
        r = self.r
        for pts, d in self.tips:
            n = len(pts)
            for i in range(1, n):
                for k in range(self.leaves_per // 2 + 1):
                    t = r.random()
                    pos = pts[i - 1] + (pts[i] - pts[i - 1]) * t
                    hint = (pts[i] - pts[i - 1]).normalized()
                    self.add_leaf(pos, hint, 0.30 * self.ls)
            # ciuffo in punta
            for k in range(self.leaves_per):
                self.add_leaf(pts[-1], d, 0.30 * self.ls)

    def build(self):
        h = self.h
        lean = Vector((self.r.uniform(-1, 1), self.r.uniform(-1, 1), 0)).normalized() * self.lean
        trunk_len = h * 0.55
        self.branch(Vector((0, 0, 0)), (Vector((0, 0, 1)) + lean).normalized(), trunk_len, 0.21 * h / 6, 0)
        self.leaves()


def to_object(bm, name, mat, collection):
    me = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(me)
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    collection.objects.link(ob)
    return ob


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    leaf_m = mat_leaf()
    mats = {}
    for name, seed, bark, h, depth, lp, ls, aspect, lean in VARIANTS:
        for o in list(bpy.data.objects):
            bpy.data.objects.remove(o)
        bld = Builder(seed, h, depth, lp, ls, aspect, lean)
        bld.build()
        if bark not in mats:
            mats[bark] = mat_bark(bark)
        col = bpy.context.scene.collection
        tr = to_object(bld.bark, name + "_rami", mats[bark], col)
        lf = to_object(bld.leaf, name + "_foglie", leaf_m, col)
        # normali delle foglie verso l'alto (illuminazione morbida, come le carte vegetali)
        d = os.path.join(OUT, name)
        os.makedirs(d, exist_ok=True)
        p = os.path.join(d, name + ".gltf")
        bpy.ops.object.select_all(action="DESELECT")
        for o in (tr, lf):
            o.select_set(True)
        bpy.context.view_layer.objects.active = tr
        bpy.ops.export_scene.gltf(filepath=p, export_format="GLTF_SEPARATE", export_texture_dir="textures", use_selection=True,
                                  export_yup=True, export_apply=True, export_texcoords=True, export_normals=True,
                                  export_materials="EXPORT", export_image_format="AUTO", export_vertex_color="ACTIVE",
                                  export_animations=False)
        print(name, "tris", len(bld.bark.faces) * 8 // 1, len(bld.leaf.faces) * 2, "bark+leaf")


main()
