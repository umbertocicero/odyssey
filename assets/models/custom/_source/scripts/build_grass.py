"""Ciuffi d'erba e piante selvatiche come alpha-cutout cards, per GPU instancing (MultiMesh in Godot).

Uso: blender -b --factory-startup -P build_grass.py
Uscita: terreno/erba_ciuffi.gltf (+ .bin, texture in terreno/textures/) (una mesh per variante, un solo materiale condiviso M_Erba_Cards).

Ogni card e' un quad diviso in 4 segmenti verticali, piegato e inclinato verso l'esterno.
COLOR_0 (per glTF moltiplica il colore base, quindi contiene solo dati che vanno bene come tinta):
  RGB = occlusione ambientale cotta (scura alla base del ciuffo), A = translucenza (alta in punta)
UV2 (TEXCOORD_1, in Godot UV2):
  x = peso del vento (0 alla base, 1 in punta, gia' curvato: la base resta ferma)
  y = fase casuale per card (le card dello stesso ciuffo non oscillano all'unisono)
Le normali puntano verso l'alto e in fuori dal centro del ciuffo: la luce resta morbida da ogni lato.
"""
import bpy, os, sys, math, random
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import okit

CUSTOM = os.path.abspath(os.path.join(HERE, "..", ".."))
TEX = os.path.join(CUSTOM, "terreno", "textures")
TILES = ["lush", "tips", "medium", "short", "dry", "weeds", "flowers", "seeds", "long", "long_dry"]
ROWS = 3
SEG = 4

# nome mesh: (tile o lista di tile, altezza m, numero di card, raggio di sparpagliamento m)
VARIANTS = {
    "Erba_Alta":        (["lush"], 0.55, 4, 0.04),
    "Erba_PunteSecche": (["tips"], 0.60, 4, 0.04),
    "Erba_Media":       (["medium"], 0.38, 4, 0.03),
    "Erba_Bassa":       (["short"], 0.18, 4, 0.03),
    "Erba_Secca":       (["dry"], 0.55, 4, 0.04),
    "Erbacce_Foglie":   (["weeds"], 0.40, 2, 0.02),
    "Fiori_Selvatici":  (["flowers"], 0.42, 2, 0.02),
    "Graminacee_Semi":  (["seeds"], 0.68, 4, 0.04),
    "Erba_Lunga":       (["long"], 0.95, 4, 0.04, True),
    "Erba_Lunga_Secca": (["long_dry"], 0.95, 4, 0.04, True),
    # zolle dense: piu' card di tile diversi su ~0,5 m, per riempire il prato senza vuoti
    "Prato_Denso_A":    (["lush", "tips", "medium", "medium", "short", "lush"], 0.5, 12, 0.32),
    "Prato_Denso_B":    (["tips", "dry", "medium", "short", "seeds", "lush", "flowers"], 0.5, 13, 0.34),
    # tappeto basso e fitto: riempie i vuoti tra i ciuffi alti
    "Prato_Denso_C":    (["medium", "short", "short", "lush", "medium", "tips"], 0.42, 12, 0.32),
    "Prato_Alto":       (["long", "long_dry", "long", "tips", "long", "lush"], 0.9, 14, 0.34, True),
}


def tile_uv(name):
    i = TILES.index(name)
    c, r = i % 4, i // 4
    u0, u1 = c / 4, (c + 1) / 4
    v0 = (ROWS - 1 - r) / ROWS  # prima riga dell'atlas = in alto
    return u0, u1, v0, v0 + 1 / ROWS


def build_variant(name, tiles, H, ncards, spread, seed, wind=False):
    rnd = random.Random(seed)
    verts, faces, uvs, cols, nors, uv2 = [], [], [], [], [], []
    for k in range(ncards):
        tile = tiles[k % len(tiles)]
        u0, u1, v0, v1 = tile_uv(tile)
        h = H * rnd.uniform(0.8, 1.15) * (0.55 if tile == "short" and len(tiles) > 1 else 1.0)
        w = h * 0.5
        ang = math.pi * k / ncards + rnd.uniform(-0.25, 0.25) if spread < 0.1 else rnd.uniform(0, math.pi)
        cx, cy = (0.0, 0.0) if spread < 0.1 else (rnd.uniform(-spread, spread), rnd.uniform(-spread, spread))
        cx += rnd.uniform(-0.01, 0.01); cy += rnd.uniform(-0.01, 0.01)
        along = Vector((math.cos(ang), math.sin(ang), 0))
        side = Vector((-along.y, along.x, 0))
        lean_dir = side * rnd.choice([-1, 1])
        lean = rnd.uniform(0.08, 0.2)
        bend = rnd.uniform(0.05, 0.16)
        if wind:  # erba lunga piegata dal vento: tutte le card inclinate verso +X con poca dispersione
            lean_dir = Vector((1.0, 0.3 + rnd.uniform(-0.25, 0.25), 0)).normalized()
            lean = rnd.uniform(0.18, 0.32)
            bend = rnd.uniform(0.22, 0.4)
        phase = rnd.random()
        base = len(verts)
        for j in range(SEG + 1):
            t = j / SEG
            z = h * t * (1 - 0.06 * t)
            off = lean_dir * (lean * h * t + bend * h * t * t)
            for e in (-0.5, 0.5):
                p = Vector((cx, cy, 0)) + along * (e * w * (1 - 0.15 * t)) + off + Vector((0, 0, z))
                verts.append(p)
                uvs.append((u0 + (e + 0.5) * (u1 - u0), v0 + t * (v1 - v0)))
                wind = t ** 1.6
                ao = 0.28 + 0.72 * min(1.0, t / 0.6) ** 0.8
                cols.append((ao, ao, ao, 0.35 + 0.65 * t))
                uv2.append((wind, phase))
                radial = Vector((p.x, p.y, 0))
                radial = radial.normalized() if radial.length > 1e-4 else lean_dir
                nors.append((Vector((0, 0, 1)) * 0.75 + radial * 0.45 + lean_dir * 0.2).normalized())
        for j in range(SEG):
            a = base + j * 2
            faces.append((a, a + 1, a + 3, a + 2))
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    uvl = me.uv_layers.new(name="UVMap")
    uvd = me.uv_layers.new(name="UVData")
    for li, l in enumerate(me.loops):
        uvl.data[li].uv = uvs[l.vertex_index]
        uvd.data[li].uv = uv2[l.vertex_index]
    me.uv_layers.active = uvl
    ca = me.color_attributes.new("Col", "BYTE_COLOR", "POINT")
    for i, c in enumerate(cols):
        ca.data[i].color = c
    me.color_attributes.active_color = ca
    for p in me.polygons:
        p.use_smooth = True
    me.normals_split_custom_set_from_vertices([tuple(n) for n in nors])
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def material():
    m = bpy.data.materials.new("M_Erba_Cards")
    m.use_nodes = True
    m.use_backface_culling = False
    try:
        m.surface_render_method = "DITHERED"
    except Exception:
        pass
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    def img(fn, noncolor=False):
        i = bpy.data.images.load(os.path.join(TEX, fn))
        if noncolor:
            i.colorspace_settings.name = "Non-Color"
        return i
    ta = nt.nodes.new("ShaderNodeTexImage"); ta.image = img("T_erba_cards_albedo_alpha.png"); ta.location = (-700, 300)
    vc = nt.nodes.new("ShaderNodeVertexColor"); vc.layer_name = "Col"; vc.location = (-700, 0)
    sep = nt.nodes.new("ShaderNodeSeparateColor"); sep.location = (-500, 0)
    nt.links.new(vc.outputs[0], sep.inputs[0])
    mul = nt.nodes.new("ShaderNodeMix"); mul.data_type = "RGBA"; mul.blend_type = "MULTIPLY"; mul.location = (-300, 300)
    mul.inputs[0].default_value = 1.0
    nt.links.new(ta.outputs[0], mul.inputs[6])
    nt.links.new(vc.outputs[0], mul.inputs[7])
    nt.links.new(mul.outputs[2], bsdf.inputs["Base Color"])
    rnd = nt.nodes.new("ShaderNodeMath"); rnd.operation = "ROUND"; rnd.location = (-300, 100)
    nt.links.new(ta.outputs[1], rnd.inputs[0])
    nt.links.new(rnd.outputs[0], bsdf.inputs["Alpha"])
    tn = nt.nodes.new("ShaderNodeTexImage"); tn.image = img("T_erba_cards_normal.png", True); tn.location = (-700, -300)
    nm = nt.nodes.new("ShaderNodeNormalMap"); nm.location = (-300, -300)
    nt.links.new(tn.outputs[0], nm.inputs["Color"])
    nt.links.new(nm.outputs[0], bsdf.inputs["Normal"])
    bsdf.inputs["Roughness"].default_value = 0.78
    bsdf.inputs["Specular IOR Level"].default_value = 0.2
    # translucenza per le anteprime in Blender (in Godot la fa lo shader con il canale A del vertex color)
    try:
        bsdf.inputs["Subsurface Weight"].default_value = 0.0
        tr = bsdf.inputs.get("Diffuse Transmission Weight") or bsdf.inputs.get("Transmission Weight")
    except Exception:
        tr = None
    return m


def main():
    okit.reset()
    mat = material()
    objs = []
    x = 0.0
    for i, (name, v) in enumerate(VARIANTS.items()):
        tiles, H, n, spread = v[:4]
        ob = build_variant(name, tiles, H, n, spread, 500 + i, len(v) > 4 and v[4])
        ob.data.materials.append(mat)
        ob.location.x = x  # affiancate solo nel .blend; nel .gltf ogni mesh ha l'origine alla base
        x += 0.9
        objs.append(ob)
        print(name, "tris", sum(len(p.vertices) - 2 for p in ob.data.polygons))
    okit.save_blend("terreno/erba_ciuffi.blend")
    for ob in objs:
        ob.location.x = 0
    p = os.path.join(CUSTOM, "terreno", "erba_ciuffi.gltf")
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(filepath=p, export_format="GLTF_SEPARATE", export_texture_dir="textures", use_selection=True, export_yup=True,
                              export_apply=True, export_texcoords=True, export_normals=True,
                              export_materials="EXPORT", export_image_format="AUTO",
                              export_vertex_color="ACTIVE", export_animations=False)
    print("glb", p)


main()
