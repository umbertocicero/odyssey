"""Materiali PBR Poly Haven (non mesh) -> texture tileable ridotte per il terreno.

Uso: blender -b --factory-startup -P convert_materials.py -- <cartella_estratta> <nome> [<nome> ...]
Legge <cartella_estratta>/<nome>/textures/*, scrive polyhaven/terreno_costa/<nome>/
  <nome>_diff.jpg (2048), <nome>_nor_gl.png (1024, OpenGL come Godot), <nome>_rough.png (1024, grigio),
  <nome>_disp.png (1024, height/parallax).
Poi un passaggio PIL porta roughness e displacement a un solo canale.
"""
import bpy, sys, os, glob

CUSTOM = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(CUSTOM, "polyhaven", "terreno_costa")

argv = sys.argv[sys.argv.index("--") + 1:]
root, names = argv[0], argv[1:]
for n in names:
    src = os.path.join(root, n, "textures")
    dst = os.path.join(OUT, n)
    os.makedirs(dst, exist_ok=True)
    for kind, pat, size, fmt, cs in (("diff", "*_diff_*", 2048, "JPEG", "sRGB"),
                                      ("nor_gl", "*_nor_gl_*", 1024, "PNG", "Non-Color"),
                                      ("rough", "*_rough_*", 1024, "PNG", "Non-Color"),
                                      ("disp", "*_disp_*", 1024, "PNG", "Non-Color")):
        files = glob.glob(os.path.join(src, pat))
        if not files:
            continue
        im = bpy.data.images.load(files[0])
        im.colorspace_settings.name = cs
        im.scale(size, size)
        im.file_format = fmt
        out = os.path.join(dst, f"{n}_{kind}.{'jpg' if fmt == 'JPEG' else 'png'}")
        im.filepath_raw = out
        scene = bpy.context.scene
        scene.render.image_settings.file_format = fmt
        scene.render.image_settings.quality = 90
        scene.render.image_settings.color_mode = "RGB"
        im.save_render(out, scene=scene) if cs == "sRGB" else im.save()
        print("MAT", out, os.path.getsize(out))
