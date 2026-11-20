"""Importa i modelli Poly Haven (CC0, .blend 2K) scaricati in ~/Scaricati e li prepara per il gioco.

Per ogni .blend:
  - sceglie i LOD bassi (mai LOD0 da milioni di triangoli), valuta i geometry nodes dove serve;
  - decima fino al budget indicato (collapse, UV conservate);
  - ricostruisce un materiale PBR pulito (base color, roughness, normal, alpha) con texture
    ridimensionate: l'esporter glTF non gestisce i mix shader Translucent dei file originali;
  - porta la base a z = 0 e il centro in x/y = 0, metri;
  - esporta glTF separato (.gltf + .bin + textures/), come in terreno/ (l'editor Godot
    duplica le texture incorporate dei .glb).

Uso (una sola istanza alla volta!):
  blender -b <cartella estratta>/<nome>.blend --factory-startup -P import_polyhaven.py -- <nome> <cartella_out> [<nome> ...]
La configurazione sta in CONFIG qui sotto, i risultati vanno in <out>/_report.jsonl.
"""
import bpy, bmesh, sys, os, re, json, math
from mathutils import Vector

CUSTOM = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT_ROOT = os.path.join(CUSTOM, "polyhaven")

# nome blend -> categoria, regex di inclusione/esclusione, LOD ('max' = il piu' basso, oppure numero),
# cap = triangoli massimi per variante (oltre: decimazione), tex = lato texture
CONFIG = {
    "boulder_01_2k": dict(cat="rocce", inc=r"^boulder_01_LOD\d$", lod="max", cap=3500, tex=2048),
    "namaqualand_boulder_02_2k": dict(cat="rocce", inc=r"_LOD\d$", lod="max", cap=4000, tex=2048),
    "namaqualand_boulder_03_2k": dict(cat="rocce", inc=r"_LOD\d$", lod="max", cap=3500, tex=2048),
    "namaqualand_cliff_02_2k": dict(cat="rocce", inc=r"_LOD\d$", lod="max", cap=9000, tex=2048),
    "dead_tree_trunk_02_2k": dict(cat="rocce", inc=r"_LOD\d$", lod="max", cap=4500, tex=2048),
    "fern_02_2k": dict(cat="vegetazione", inc=r"^fern_02_[a-d]$", lod=None, cap=2600, tex=1024),
    "grass_medium_01_2k": dict(cat="vegetazione", inc=r"^grass_medium_01_(large_b|mid_b|small_b|tall_a|tall_c|tiny_a)_LOD\d$", lod=2, cap=1100, tex=1024),
    "grass_medium_02_2k": dict(cat="vegetazione", inc=r"^grass_medium_02_[a-e]$", lod=None, cap=2600, tex=1024),
    "celandine_01_2k": dict(cat="vegetazione", inc=r"^celandine_01_[a-d]_LOD\d$", lod="max", cap=1500, tex=1024),
    "dandelion_01_2k": dict(cat="vegetazione", inc=r"^dandelion_01_[a-c]_LOD\d$", lod="max", cap=1500, tex=1024),
    "flower_heliophila_2k": dict(cat="vegetazione", inc=r"^flower_heliophila_(small|medium)_LOD\d$", lod="max", cap=4500, tex=1024),
    "othonna_cerarioides_2k": dict(cat="vegetazione", inc=r"^othonna_cerarioides_[a-c]_LOD\d$", lod="max", cap=5000, tex=1024),
    "periwinkle_plant_2k": dict(cat="vegetazione", inc=r"^periwinkle_plant_0[12]_LOD\d$", lod=4, cap=700, tex=1024),
    "searsia_lucida_2k": dict(cat="vegetazione", inc=r"^searsia_lucida_[a-d]_LOD\d$", lod="max", cap=14000, tex=1024),
    "fir_sapling_medium_2k": dict(cat="alberi", inc=r"^fir_sapling_medium_[a-c]_LOD\d$", lod="max", cap=9000, tex=1024),
    "fir_tree_01_2k": dict(cat="alberi", inc=r"^fir_tree_01_c_LOD\d$", lod="max", cap=24000, tex=1024),
    # alberi procedurali (geometry nodes): foglie/rami LOD1 e densita' ridotta fino al budget
    "island_tree_01_2k": dict(cat="alberi", inc=r"^island_tree_01_geometry_nodes$", lod=None, cap=60000, tex=1024, gn=True),
    "island_tree_02_2k": dict(cat="alberi", inc=r"^island_tree_02_geometry_nodes$", lod=None, cap=45000, tex=1024, gn=True),
    "street_rat_2k": dict(cat="fauna", inc=r"^street_rat$", lod=None, cap=4000, tex=1024, no_mods=True),
    # --- collezione Namaqualand / costa (livello 2) ---
    "coast_land_rocks_04_2k": dict(cat="rocce", inc=r"_LOD\d$", lod="max", cap=9000, tex=2048),
    "coast_rocks_05_2k": dict(cat="rocce", inc=r"_LOD\d$", lod="max", cap=6000, tex=2048),
    "treasure_chest_2k": dict(cat="oggetti", join={"treasure_chest": r"^treasure_chest_"}, cap=9000, tex=1024),
    "wooden_barrels_01_2k": dict(cat="oggetti", inc=r"^wooden_barrels_01_barrel0\d$", lod=None, cap=3500, tex=1024),
    "wooden_bucket_02_2k": dict(cat="oggetti", join={"wooden_bucket_02": r"^wooden_bucket_02$"}, cap=3000, tex=1024),
    "wooden_crate_01_2k": dict(cat="oggetti", join={"wooden_crate_01": r"^wooden_crate_01$"}, cap=3500, tex=1024),
    "wooden_ladder_02_2k": dict(cat="oggetti", inc=r"^wooden_ladder_02$", lod=None, cap=3500, tex=1024),
    "wooden_stool_02_2k": dict(cat="oggetti", inc=r"^wooden_stool_02$", lod=None, cap=3000, tex=1024),
    "wooden_axe_2k": dict(cat="attrezzi", inc=r"^wooden_axe$", lod=None, cap=3000, tex=1024),
    "wooden_hammer_01_2k": dict(cat="attrezzi", inc=r"^wooden_hammer_01$", lod=None, cap=3000, tex=1024),
    "cross_pein_hammer_2k": dict(cat="attrezzi", inc=r"^cross_pein_hammer$", lod=None, cap=2500, tex=1024),
    "hand_plane_no4_2k": dict(cat="attrezzi", inc=r"^hand_plane_no4$", lod=None, cap=4000, tex=1024),
    "handsaw_wood_2k": dict(cat="attrezzi", inc=r"^handsaw_wood$", lod=None, cap=2500, tex=1024),
    "rusted_spade_01_2k": dict(cat="attrezzi", inc=r"^rusted_spade_01$", lod=None, cap=3500, tex=1024),
    "picke_dirty_01_2k": dict(cat="attrezzi", inc=r"^picke_dirty_01$", lod=None, cap=3500, tex=1024),
    "vintage_hand_drill_2k": dict(cat="attrezzi", join={"vintage_hand_drill": r"^vintage_hand_drill(_cog\d|_crank|_head)?$"}, cap=4500, tex=1024),
    "fish_knife_2k": dict(cat="attrezzi_fuori_epoca", join={"fish_knife": r"^fish_knife_"}, cap=2800, tex=1024),
    "flathead_screwdriver_2k": dict(cat="attrezzi_fuori_epoca", inc=r"^flathead_screwdriver$", lod=None, cap=2300, tex=1024),
    "machete_2k": dict(cat="attrezzi_fuori_epoca", inc=r"^machete$", lod=None, cap=3000, tex=1024),
    "kite_shield_2k": dict(cat="attrezzi_fuori_epoca", join={"kite_shield": r"^kite_shield_"}, cap=6000, tex=1024),
    "modular_wooden_pier_2k": dict(cat="architettura", inc=r"^modular_wooden_pier_(planks|poles|section_0\d)$", lod=None, cap=7000, tex=1024),
    "modular_fort_01_2k": dict(cat="architettura", inc=r"^modular_fort_01_", lod=None, cap=4000, tex=1024),
    "dutch_ship_medium_2k": dict(cat="navi_fuori_epoca", join={"dutch_ship_medium": r"^dutch_ship_medium_"}, cap=22000, tex=1024),
}


def log(**kw):
    print("JOB", json.dumps(kw, ensure_ascii=False))
    with open(os.path.join(OUT_ROOT, "_report.jsonl"), "a") as f:
        f.write(json.dumps(kw, ensure_ascii=False) + "\n")


def pick_variants(cfg):
    if cfg.get("join"):   # (nome, [oggetti]) uniti in un'unica mesh, in coordinate mondo
        return [(nm, [o for o in bpy.data.objects if o.type == "MESH" and re.search(rx, o.name)])
                for nm, rx in cfg["join"].items()]
    inc = re.compile(cfg["inc"])
    groups = {}
    for o in bpy.data.objects:
        if o.type != "MESH" or not inc.search(o.name):
            continue
        m = re.match(r"^(.*)_LOD(\d+)$", o.name)
        base, lod = (m.group(1), int(m.group(2))) if m else (o.name, None)
        groups.setdefault(base, {})[lod] = o
    chosen = []
    for base, lods in sorted(groups.items()):
        want = cfg["lod"]
        if want is None or None in lods:
            ob = lods.get(None) or lods[min(lods)]
        elif want == "max":
            ob = lods[max(lods)]
        else:
            ob = lods.get(want) or lods[max(k for k in lods if k <= want) if any(k <= want for k in lods) else max(lods)]
        chosen.append((base, [ob]))
    return chosen


def tris_of(me):
    return sum(len(p.vertices) - 2 for p in me.polygons)


def build_material(src, size, outname):
    """Materiale pulito da quello Poly Haven: cerca le immagini per etichetta del nodo."""
    imgs = {}
    for n in src.node_tree.nodes:
        if n.type == "TEX_IMAGE" and n.image:
            lab = (n.label or n.name).lower()
            key = None
            if "base" in lab or "diff" in lab: key = "color"
            elif "rough" in lab: key = "rough"
            elif "normal" in lab or "nor" in lab: key = "normal"
            elif "alpha" in lab or "opacity" in lab: key = "alpha"
            elif "metal" in lab: key = "metal"
            if key and key not in imgs:
                imgs[key] = n.image
    m = bpy.data.materials.new(outname)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]

    has_alpha = "alpha" in imgs

    def tex(key, cs, y):
        im = imgs[key].copy()
        im.name = f"{outname}_{key}"
        im.colorspace_settings.name = cs
        # colore e alpha alla risoluzione piena richiesta, roughness e normal a meta' (min 1024):
        # le normal PNG a 2K pesano ~20 MB l'una
        lim = size if key in ("color", "alpha") else max(1024, size // 2)
        if key == "color" and not has_alpha:
            im.file_format = "JPEG"          # il colore opaco in JPEG: le diffuse PNG a 2K pesano 20 MB
            im.scale(min(lim, max(im.size)), min(lim, max(im.size)))   # forza la ricodifica anche a pari risoluzione
        elif max(im.size) > lim:
            im.scale(lim, lim)
        n = nt.nodes.new("ShaderNodeTexImage"); n.image = im; n.location = (-600, y)
        return n
    if "color" in imgs:
        nt.links.new(tex("color", "sRGB", 300).outputs["Color"], bsdf.inputs["Base Color"])
    if "rough" in imgs:
        nt.links.new(tex("rough", "Non-Color", 0).outputs["Color"], bsdf.inputs["Roughness"])
    if "metal" in imgs:
        nt.links.new(tex("metal", "Non-Color", -150).outputs["Color"], bsdf.inputs["Metallic"])
    if "normal" in imgs:
        nm = nt.nodes.new("ShaderNodeNormalMap"); nm.location = (-300, -300)
        nt.links.new(tex("normal", "Non-Color", -300).outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    if has_alpha:
        a = tex("alpha", "Non-Color", -600)
        nt.links.new(a.outputs["Color"], bsdf.inputs["Alpha"])
        m.blend_method = "CLIP"
        m.alpha_threshold = 0.5
        m.use_backface_culling = False
    return m, has_alpha


def fix_gltf(path, alpha_mats):
    """Alpha a maschera (cutout, niente sorting) e singola faccia per i materiali opachi."""
    g = json.load(open(path))
    for m in g.get("materials", []):
        if m.get("name") in alpha_mats:
            m["alphaMode"] = "MASK"; m["alphaCutoff"] = 0.5; m["doubleSided"] = True
        else:
            m.pop("alphaMode", None); m["doubleSided"] = False
    json.dump(g, open(path, "w"), indent=1)


def fit_geonodes(ob, cap):
    """Foglie/rami LOD1 e densita' ridotta finche' i triangoli valutati stanno nel budget."""
    mod = next(m for m in ob.modifiers if m.type == "NODES" and m.node_group)
    for n in mod.node_group.nodes:
        if n.type == "COLLECTION_INFO":
            col = n.inputs["Collection"].default_value
            if col and col.name.endswith("_LOD0") and col.name[:-1] + "1" in bpy.data.collections:
                n.inputs["Collection"].default_value = bpy.data.collections[col.name[:-1] + "1"]
    g = mod.node_group
    mults = []
    for n in g.nodes:
        if n.type == "DISTRIBUTE_POINTS_ON_FACES":
            sock = n.inputs["Density Factor"] if n.distribute_method == "POISSON" else n.inputs["Density"]
            if sock.is_linked:   # moltiplicatore inserito sul collegamento esistente
                src = sock.links[0].from_socket
                mul = g.nodes.new("ShaderNodeMath"); mul.operation = "MULTIPLY"
                g.links.new(src, mul.inputs[0]); g.links.new(mul.outputs[0], sock)
            else:
                mul = g.nodes.new("ShaderNodeMath"); mul.operation = "MULTIPLY"
                mul.inputs[0].default_value = sock.default_value; g.links.new(mul.outputs[0], sock)
            mults.append(mul)
    # le foglie sono carte instanziate sui rami: se ne tolgo, ingrandisco quelle rimaste per coprire la chioma
    leaf_inst = [n for n in g.nodes if n.type == "INSTANCE_ON_POINTS" and n.inputs["Points"].is_linked
                 and n.inputs["Points"].links[0].from_node.type == "DISTRIBUTE_POINTS_ON_FACES"
                 and n.inputs["Points"].links[0].from_node.distribute_method == "RANDOM"]
    leaf_scale = []
    for n in leaf_inst:
        sock = n.inputs["Scale"]
        vm = g.nodes.new("ShaderNodeVectorMath"); vm.operation = "SCALE"
        if sock.is_linked:
            g.links.new(sock.links[0].from_socket, vm.inputs[0])
        else:
            vm.inputs[0].default_value = sock.default_value
        g.links.new(vm.outputs["Vector"], sock)
        leaf_scale.append(vm)
    f = 1.0
    for it in range(8):
        for mul in mults:
            mul.inputs[1].default_value = f
        for vm in leaf_scale:
            vm.inputs["Scale"].default_value = min(3.2, 1.0 / math.sqrt(max(f, 0.05)))
        ob.update_tag(); bpy.context.view_layer.update()
        dg = bpy.context.evaluated_depsgraph_get()
        me = ob.evaluated_get(dg).to_mesh()
        t = tris_of(me); ob.evaluated_get(dg).to_mesh_clear()
        print("GNFIT", it, "f=%.3f" % f, "tris", t)
        if t <= cap:
            break
        f *= max(0.05, cap / t * 0.9)
    return f


def process(name, cfg):
    cat_dir = os.path.join(OUT_ROOT, cfg["cat"], name.replace("_2k", ""))
    os.makedirs(cat_dir, exist_ok=True)
    chosen = pick_variants(cfg)
    if not chosen:
        log(asset=name, error="nessuna variante trovata")
        return
    dg = bpy.context.evaluated_depsgraph_get()
    matcache = {}
    results = []
    for base, members in chosen:
        ob = members[0]
        clean = base.replace("_2k", "")
        if cfg.get("gn"):
            fit_geonodes(ob, cfg["cap"])
            dg = bpy.context.evaluated_depsgraph_get()
        temps = []
        for k, mb in enumerate(members):
            me = bpy.data.meshes.new_from_object(mb.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg) \
                if not cfg.get("no_mods") else mb.data.copy()
            t = bpy.data.objects.new(f"{clean}__m{k}", me)
            bpy.context.scene.collection.objects.link(t)
            if len(members) > 1:
                t.matrix_world = mb.matrix_world   # parti unite nella loro posizione relativa
            for i, slot in enumerate(t.data.materials):
                if slot is None:
                    continue
                key = (slot.name, cfg["tex"])
                if key not in matcache:
                    matcache[key] = build_material(slot, cfg["tex"], "PH_" + slot.name)
                t.data.materials[i] = matcache[key][0]
            temps.append(t)
        bpy.ops.object.select_all(action="DESELECT")
        for t in temps:
            t.select_set(True)
        new = temps[0]
        bpy.context.view_layer.objects.active = new
        if len(temps) > 1:
            bpy.ops.object.join()
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        me = new.data
        orig_tris = tris_of(me)
        # decimazione
        if orig_tris > cfg["cap"]:
            mod = new.modifiers.new("dec", "DECIMATE")
            mod.ratio = max(0.02, cfg["cap"] / orig_tris)
            bpy.ops.object.modifier_apply(modifier=mod.name)
        # base a z = 0, centro xy = 0
        vs = [v.co for v in new.data.vertices]
        mn = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
        mx = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
        off = Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))
        for v in new.data.vertices:
            v.co -= off
        new.data.update()
        # normali: smooth di base (le normal map fanno il resto)
        for p in new.data.polygons:
            p.use_smooth = True
        final_tris = tris_of(new.data)
        dims = mx - mn
        new.name = clean + "__x"
        out = os.path.join(cat_dir, clean + ".gltf")
        bpy.ops.object.select_all(action="DESELECT")
        new.select_set(True)
        bpy.ops.export_scene.gltf(
            filepath=out, export_format="GLTF_SEPARATE", use_selection=True, export_yup=True, export_apply=False,
            export_materials="EXPORT", export_image_format="AUTO", export_texture_dir="textures",
            export_texcoords=True, export_normals=True, export_animations=False, export_skins=False,
            export_cameras=False, export_lights=False)
        fix_gltf(out, {matcache[k][0].name for k in matcache if matcache[k][1]})
        results.append((clean, orig_tris, final_tris, dims))
        log(asset=name, variant=clean, src=ob.name, tris_src=orig_tris, tris=final_tris,
            dim=[round(d, 2) for d in dims], tex=cfg["tex"], file=os.path.relpath(out, CUSTOM))
        bpy.data.objects.remove(new)
    return results


if __name__ == "__main__":
    names = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    os.makedirs(OUT_ROOT, exist_ok=True)
    for n in names:
        if n not in CONFIG:
            print("SKIP", n, "(nessuna configurazione)")
            continue
        process(n, CONFIG[n])
