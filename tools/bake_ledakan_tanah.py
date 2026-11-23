"""Bake volume Blender ke flipbook benturan Recoil.

Jalankan Blender dengan --background --python tools/bake_ledakan_tanah.py.
Tambahkan -- baja untuk bake benturan baja dari demo Medium Tank vs Destroyer.
Pillow dari Python sistem dipakai untuk mengemas PNG hasil render.
"""
from pathlib import Path
import math
import shutil
import subprocess
import sys
import tempfile

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
ASSET = ROOT.parent / "blender-assets/efek/ledakan-tanah/ledakan-tanah.blend"
OUTPUT = ROOT / "game/RTSPC.sdd/bitmaps/fx/ledakan-tanah.png"
BAJA = ROOT.parent / "blender-assets/fraksi-1/efek/medium-vs-destroyer/demo-hit-v2/medium-tank-vs-destroyer.blend"
TILE = 256


def main():
    python = shutil.which("python")
    if python is None:
        raise RuntimeError("Python dengan Pillow diperlukan untuk mengemas atlas.")

    baja = "--" in sys.argv and "baja" in sys.argv[sys.argv.index("--")+1:]
    bpy.ops.wm.open_mainfile(filepath=str(BAJA if baja else ASSET))
    scene = bpy.context.scene
    cols, rows = (4, 4) if baja else (8, 4)
    start, duration = (28, 30) if baja else (10, 49)
    output = OUTPUT.with_name("benturan-baja.png") if baja else OUTPUT
    if baja:
        core = bpy.data.objects["FX_Kena_metal_Inti_00"]
        keep = set(core.users_collection[0].all_objects)
        scene.frame_set(start)
        origin = core.location.copy()
    else:
        keep = set(bpy.data.collections["Ledakan Tanah 3D"].all_objects)
        origin = Vector((0, 0, 0))
    for obj in scene.objects:
        if obj.type == "MESH" and (obj not in keep or not obj.get("volume_kena_meriam")):
            obj.animation_data_clear()
            obj.hide_render = True

    # Titik benturan berada di bawah tengah kotak. Offset +2 m pada bidang
    # gambar dipakai juga oleh definisi efek Recoil.
    camera_data = bpy.data.cameras.new("Kamera bake benturan")
    camera = bpy.data.objects.new(camera_data.name, camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    if scene.timeline_markers:
        scene.timeline_markers.clear()
    toward = Vector((0, -1, 1.19175359)).normalized()  # 50 derajat ke bawah
    up = Vector((0, toward.z, -toward.y))
    target = origin + up * (0.55 if baja else 2)
    camera.location = target + toward * 20
    camera.rotation_euler = (-toward).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 10 if baja else 12
    scene.render.film_transparent = True
    scene.render.resolution_x = scene.render.resolution_y = TILE
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"

    with tempfile.TemporaryDirectory(prefix="rts-bake-tanah-") as folder:
        for i in range(cols * rows):
            time = start + duration * i / (cols * rows - 1)
            scene.frame_set(math.floor(time), subframe=time % 1)
            scene.render.filepath = str(Path(folder) / f"{i:02}.png")
            bpy.ops.render.render(write_still=True)
        output.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run([python, "-c", """
from pathlib import Path
import sys
from PIL import Image

folder, output = map(Path, sys.argv[1:3])
cols, rows, tile, fade_frames = map(int, sys.argv[3:])
atlas = Image.new('RGBA', (cols * tile, rows * tile))
for i in range(cols * rows):
    with Image.open(folder / f'{i:02}.png') as frame:
        alpha = frame.getchannel('A')
        bounds = alpha.point(lambda a: 255 if a >= 12 else 0).getbbox()
        if bounds and any(edge in (0, tile) for edge in bounds):
            raise ValueError(f'Frame {i} terpotong: {bounds}')
        # Kepadatan volume masih terlihat hingga akhir animasi sumber.
        remaining = min(1, (cols * rows - 1 - i) / fade_frames)
        fade = remaining * remaining * (3 - 2 * remaining)
        frame.putalpha(alpha.point(lambda a: round(a * fade)))
        atlas.paste(frame, ((i % cols) * tile, (i // cols) * tile))
atlas.save(output, optimize=True)
""", folder, str(output), str(cols), str(rows), str(TILE), "5" if baja else "9"], check=True)
    print(f"BAKE_SELESAI {output}", flush=True)


if __name__ == "__main__":
    main()
