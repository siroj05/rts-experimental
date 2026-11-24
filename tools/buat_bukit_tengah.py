"""Buat dan pasang peta Recoil Bukit Tengah 1v1 dari medan prosedural orisinal."""
from collections import deque
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess

from grading_medan import grade
from zipfile import ZIP_DEFLATED, ZipFile

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
MAP = "bukit-tengah-1v1"
SIZE = 2048
MAX_HEIGHT = 256
STARTS = ((336, 1024), (1712, 1024))
METAL = (
    (240, 880), (240, 1168), (452, 1024),
    (1808, 880), (1808, 1168), (1596, 1024),
    (800, 368), (1248, 368), (800, 1680), (1248, 1680),
)


def smooth(t):
    t = np.clip(t, 0, 1)
    return t * t * (3 - 2 * t)


def radius(x, z):
    dx, dz = x - 1024, z - 1024
    shoulder = 270 + 20 * np.cos(dz / 106) + 9 * np.cos(dz / 38)
    return np.hypot(dx / shoulder, dz / 560)


def height(x, z):
    r = radius(x, z)
    dx, dz = x - 1024, z - 1024
    low = 23 + 4 * np.cos(dx / 165) * np.cos(dz / 210) + 1.6 * np.cos(dx / 77) * np.cos(dz / 114)
    for bx, bz in STARTS:
        blend = smooth((np.hypot(x - bx, z - bz) - 124) / 100)
        low = 23 * (1 - blend) + low * blend
    ridge = smooth((1.15 - r) / .68)
    return low + ridge * (186 + 14 * np.cos(dz / 111) + 7 * np.cos(dx / 61) * np.cos(dz / 48))


def noise(rng, cells, size):
    samples = Image.fromarray(rng.standard_normal((cells, cells), dtype=np.float32))
    out = np.asarray(samples.resize((size, size), Image.Resampling.BICUBIC))
    return np.clip(out, -2, 2)


def color_map():
    rng = np.random.default_rng(20261122)
    z, x = np.ogrid[0:SIZE, 0:SIZE]
    r = radius(x, z)
    actual_height = height(x, z)
    gradient_z, gradient_x = np.gradient(actual_height)
    slope = np.hypot(gradient_x, gradient_z)
    broad, middle, fine = (noise(rng, cells, SIZE) for cells in (14, 58, 360))
    grit = rng.uniform(-1, 1, (SIZE, SIZE)).astype(np.float32)

    scrub = smooth((.82 - r + .09 * broad) / .35)
    rock = smooth((slope - .13 + .06 * middle) / .31) * (r < 1.21)
    rock = np.maximum(rock, .55 * scrub)
    road_axis = 260 + 340 * (np.abs(x - 1024) / 1024) ** 2
    road_distance = np.minimum(np.abs(z - road_axis), np.abs(z - (SIZE - road_axis)))
    road = smooth((46 - road_distance + middle * 7) / 38) * (1 - rock)
    # Bare areas and small changes of vegetation density break up the plain.
    dry = smooth((broad * 0.36 + middle * 0.15 + .23) / .94) * .55
    dry = np.maximum(dry, road * .74)
    grass = np.array([87, 110, 68], dtype=np.float32)
    earth = np.array([143, 119, 82], dtype=np.float32)
    stone = np.array([121, 112, 102], dtype=np.float32)
    color = grass + (earth - grass) * dry[..., None]
    color += (stone - color) * rock[..., None]
    # Relief is subtle in the baked albedo; Recoil lights the physical slope as well.
    veins = np.cos(actual_height * .34 + middle * 2.1) * (2.5 + rock * 4.9)
    detail = broad * 6 + middle * 4.9 + fine * 4 + grit * 3.3 + veins * rock
    relief = np.clip(gradient_x * 11 + gradient_z * 6, -12, 12) * .5
    color += (detail + relief)[..., None]

    for px, pz in METAL:
        dist = np.hypot(x - px, z - pz)
        edge = smooth((29 + 2 * middle - dist) / 17)
        color += (np.array([138, 104, 82]) - color) * (edge * .70)[..., None]
        grains = (dist < 15 + fine * 2) & (grit > .65)
        color[grains] += np.array([35, 27, 22])
    return Image.fromarray(np.clip(color, 0, 255).astype(np.uint8), "RGB")


def verify_corridors(blocked):
    west, east = [(z // 16, x // 16) for x, z in STARTS]
    assert not blocked[west] and not blocked[east]
    assert blocked[west[0], blocked.shape[1] // 2]
    for north in (True, False):
        seen = {west}
        queue = deque([west])
        while queue:
            z, x = queue.popleft()
            for probe in ((z - 1, x), (z + 1, x), (z, x - 1), (z, x + 1)):
                pz, px = probe
                if pz != west[0] and (pz < west[0]) != north:
                    continue
                if 0 <= pz < blocked.shape[0] and 0 <= px < blocked.shape[1] and not blocked[probe] and probe not in seen:
                    seen.add(probe)
                    queue.append(probe)
        assert east in seen, f"Koridor {'utara' if north else 'selatan'} terputus."


def rgb_mask(data):
    return Image.fromarray(np.repeat(data[..., None], 3, axis=2), "RGB")


def main():
    lock = json.loads((ROOT / "dependencies.windows.json").read_text(encoding="utf-8"))
    installed = {p["nama"]: ROOT / ".deps" / p["folder"] for p in lock}
    engine, compiler = installed["Recoil Engine"], installed["PyMapConv"]
    work = ROOT / ".cache" / MAP
    (work / "resources").mkdir(parents=True, exist_ok=True)
    for source in ("nvdxt.exe", "resources/geovent.bmp"):
        shutil.copy2(compiler / source, work / source)

    terrain = grade(color_map())  # grading medan bersama (tahap 5)
    terrain.save(work / "warna.bmp")
    z, x = np.ogrid[0:SIZE + 1:8, 0:SIZE + 1:8]
    np.rint(height(x, z) * (65535 / MAX_HEIGHT)).astype("<u2").tofile(work / "tinggi.raw")
    z, x = np.ogrid[8:SIZE:16, 8:SIZE:16]
    blocked = radius(x, z) < 1.04
    verify_corridors(blocked)
    rgb_mask(blocked.astype(np.uint8)).save(work / "tipe.bmp")
    metal = np.zeros(blocked.shape, dtype=np.uint8)
    for px, pz in METAL:
        field = np.hypot(x - px, z - pz) <= 18
        assert not np.any(blocked & field)
        metal[field] = 240
    rgb_mask(metal).save(work / "besi.bmp")

    preview = terrain.resize((768, 768), Image.Resampling.LANCZOS)
    draw = ImageDraw.Draw(preview)
    for i, (x, z) in enumerate(STARTS, 1):
        x, z = x * .375, z * .375
        draw.ellipse((x - 13, z - 13, x + 13, z + 13), fill="#f3e8cc", outline="#251f17", width=2)
        draw.text((x, z), str(i), fill="#251f17", anchor="mm")
    for x, z in METAL:
        x, z = x * .375, z * .375
        draw.ellipse((x - 3, z - 3, x + 3, z + 3), fill="#edaf72", outline="#624230")
    preview.save(work / "pratinjau.png")

    # Clear only compiler outputs so a stale file cannot pass validation.
    for suffix in ("smf", "smt"):
        (work / f"{MAP}.{suffix}").unlink(missing_ok=True)
    result = subprocess.run(
        [compiler / "pymapconv.exe", "-t", "warna.bmp", "-a", "tinggi.raw", "-y", "tipe.bmp",
         "-m", "besi.bmp", "-o", f"{MAP}.smf", "-n", "0", "-x", str(MAX_HEIGHT), "-q", "1"],
        cwd=work, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
        encoding="utf-8", errors="replace", timeout=150, creationflags=subprocess.CREATE_NO_WINDOW,
    )
    (work / "kompilasi.log").write_text(result.stdout, encoding="utf-8")
    if result.returncode not in (0, 1) or "All Done!" not in result.stdout:
        raise RuntimeError(f"Kompilasi gagal. Lihat {work / 'kompilasi.log'}")
    smf, smt = (work / f"{MAP}.{suffix}" for suffix in ("smf", "smt"))
    with smf.open("rb") as source:
        magic, version, _, width, depth = struct.unpack("<16siiii", source.read(32))
    assert magic.rstrip(b"\0") == b"spring map file" and version == 1 and (width, depth) == (256, 256)
    with smt.open("rb") as source:
        assert source.read(16).rstrip(b"\0") == b"spring tilefile"

    portable = ROOT / "maps" / f"{MAP}.sdz"
    pending = work / portable.name
    with ZipFile(pending, "w", compression=ZIP_DEFLATED) as archive:
        archive.write(ROOT / "maps/mapinfo-bukit-tengah.lua", "mapinfo.lua")
        archive.write(smf, f"maps/{smf.name}")
        archive.write(smt, f"maps/{smt.name}")
    os.replace(pending, portable)
    (engine / "maps").mkdir(exist_ok=True)
    shutil.copy2(portable, engine / "maps" / portable.name)
    print(f"{portable.name} | {SIZE} x {SIZE} elmo | {len(METAL)} besi | "
          f"{np.count_nonzero(blocked)} sel typemap terblokir")


if __name__ == "__main__":
    main()
