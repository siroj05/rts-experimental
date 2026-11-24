"""Kompilasi Lembah Sungai dengan tekstur dari paket dasar Recoil."""

import json
from io import BytesIO
import os
import shutil
import struct
import subprocess

from grading_medan import grade
from zipfile import ZIP_DEFLATED, ZipFile

import numpy as np
from PIL import Image, ImageDraw

from buat_bukit_tengah import ROOT, rgb_mask, smooth


MAP = "lembah-sungai-1v1"
SIZE = 4096
MIN_HEIGHT, MAX_HEIGHT = -48, 224
STARTS = ((560, 2048), (3536, 2048))
FORDS = (1152, 2944)
HILLS = ((1460, 2048), (2636, 2048))
FORESTS = ((390, 580), (760, 1260), (1300, 650), (1600, 1520),
           (420, 2800), (800, 3460), (1580, 3610), (1120, 2560))
POINTS = ((1736, 1152), (2504, 1152), (1592, 2944), (2360, 2944))
IRON_WEST = ((408, 1792), (408, 2304), (820, 2048), (1288, 964), (1152, 3064), (760, 2920))
IRON = IRON_WEST + tuple((SIZE - x, SIZE - z) for x, z in IRON_WEST)
INFRA = ((700, 2180), (770, 1910), (860, 2230), (760, 2380))


def river_x(z):
    return 2048 + 210 * np.sin(z * (2 * np.pi / SIZE)) + 132 * np.sin(z * (4 * np.pi / SIZE))


def crossings(z):
    return np.minimum(abs(z - FORDS[0]), abs(z - FORDS[1]))


def terrain(x, z):
    dx, dz = x - SIZE / 2, z - SIZE / 2
    distance = abs(x - river_x(z))
    road = crossings(z)
    bend = 66 * np.sin(dz / 167) + 25 * np.sin(dz / 78)
    ridge = np.minimum(*(np.hypot((x + bend - bx) / 365, (z - bz) / 572) for bx, bz in HILLS))
    ridge += .13 * np.cos((dx - dz) / 119) + .062 * np.cos((dx + dz) / 64)
    noise = np.cos(dx / 188) * np.cos(dz / 253) + .38 * np.sin(dx / 77) * np.sin(dz / 105)
    floor = 31 + 10 * noise
    for bx, bz in (*STARTS, *POINTS, *IRON):
        flat = smooth((np.hypot(x - bx, z - bz) - 70) / 78)
        floor = flat * floor + (1 - flat) * 31
    for ox, oz in INFRA:
        for bx, bz in ((ox, oz), (SIZE - ox, SIZE - oz)):
            flat = smooth((np.hypot(x - bx, z - bz) - 78) / 52)
            floor = flat * floor + (1 - flat) * 31
    ridge_height = smooth((1.22 - ridge) / .82) * (164 + noise * 13)
    wide = 94 + 21 * np.cos(dz / 252) + 11 * np.cos(dz / 102)
    bottom = -24 - 8 * np.cos(dz / 190)
    ford = smooth((144 - road) / 58)
    bottom = ford * -3.1 + (1 - ford) * bottom
    bank = smooth((distance - wide * .46) / (wide * 1.34))
    h = (floor + ridge_height) * bank + bottom * (1 - bank)
    return h, ridge, distance, road


def textures(bitmaps, work):
    def bitmap(name):
        return Image.open(BytesIO(bitmaps.read("bitmaps/" + name)))

    grass = np.asarray(bitmap("grass3.jpg").convert("RGB"), dtype=np.float32)
    detail = np.asarray(bitmap("detailtex2.bmp").convert("L"), dtype=np.float32) / 255 - .5
    work_image = Image.new("RGB", (SIZE, SIZE))
    overview = Image.new("RGB", (SIZE, SIZE))
    x = np.arange(SIZE)[None, :]
    for first in range(0, SIZE, 128):
        z = np.arange(first, first + 128)[:, None]
        h, ridge, distance, road = terrain(x, z)
        large = .55 * np.sin((x + z) / 157) + .25 * np.cos((x - z) / 76)
        small = detail[z % detail.shape[0], x % detail.shape[1]]
        base = grass[z % grass.shape[0], x % grass.shape[1]] * [.81, .78, .91]
        base += (large * 7 + small * 20)[..., None]
        stratum = 4 * np.sin((x + .64 * z) / 22 + large * 2 + small * 3)
        stone = np.array([114, 111, 99]) + (small * 105 + large * 13 + stratum)[..., None]
        exposed = smooth((.97 - ridge + large * .17) / .34)
        gravel = np.array([144, 123, 96]) + (small * 59 + large * 9)[..., None]
        path = smooth((44 + large * 12 - road) / 31) * smooth((1100 - distance) / 500)
        bank = np.maximum(smooth((15 - h) / 22), path * .76)
        color = base + (stone - base) * exposed[..., None]
        color += (gravel - color) * bank[..., None]
        for px, pz in IRON:
            patch = smooth((29 - np.hypot(x - px, z - pz)) / 19)
            color += (np.array([151, 111, 84]) + small[..., None] * 53 - color) * patch[..., None]
        work_image.paste(Image.fromarray(np.clip(color, 0, 255).astype(np.uint8)), (0, first))
        water = smooth(-h / 26)
        color += (np.array([62, 109, 115]) - color) * (water * .92)[..., None]
        overview.paste(Image.fromarray(np.clip(color, 0, 255).astype(np.uint8)), (0, first))
    work_image = grade(work_image)  # grading medan bersama (tahap 5)
    overview = grade(overview)
    work_image.save(work / "warna.bmp")
    overview.resize((1024, 1024), Image.Resampling.LANCZOS).save(work / "minimap.bmp")
    return overview.resize((900, 900), Image.Resampling.LANCZOS)


def populate(work, preview):
    z, x = np.ogrid[0:SIZE + 1:8, 0:SIZE + 1:8]
    h, _, _, _ = terrain(x, z)
    np.rint((h - MIN_HEIGHT) * (65535 / (MAX_HEIGHT - MIN_HEIGHT))).astype("<u2").tofile(work / "tinggi.raw")

    z, x = np.ogrid[8:SIZE:16, 8:SIZE:16]
    h, ridge, distance, road = terrain(x, z)
    deep = h < -7
    ford = (h < 2) & ~deep
    blocked = ridge < .96
    types = np.select([blocked, deep, ford], [1, 2, 3], default=0)
    rgb_mask(types.astype(np.uint8)).save(work / "tipe.bmp")
    assert np.all(terrain(river_x(z), z)[0] < 0)
    assert np.any(blocked) and np.any(deep) and np.any(ford)
    metal = np.zeros(h.shape, dtype=np.uint8)
    for px, pz in IRON:
        field = np.hypot(x - px, z - pz) <= 18
        assert np.all(types[field] == 0)
        metal[field] = 240
    rgb_mask(metal).save(work / "besi.bmp")

    z, x = np.ogrid[16:SIZE:32, 16:SIZE:32]
    h, ridge, distance, road = terrain(x, z)
    grass = (h > 10) & (ridge > 1.07) & ((road > 60) | (distance > 850))
    for px, pz in (*STARTS, *IRON):
        grass &= np.hypot(x - px, z - pz) > 25
    var = np.sin((x + z) / 108) + np.cos(x / 125) * np.cos(z / 177)
    mask = grass & (var > -.82)
    Image.fromarray(mask.astype(np.uint8)).save(work / "rumput.bmp")

    trees = tree_positions()
    assert len(trees) > 300
    (work / "pohon.lua").write_text("\n".join(
        f"{{ name = 'TreeType{kind}', x = {x}, z = {z}, rot = {angle}, scale = 1.0 }}"
        for x, z, kind, angle in trees
    ) + "\n", encoding="ascii")

    draw = ImageDraw.Draw(preview)
    scale = preview.width / SIZE
    for px, pz, _, _ in trees:
        x, y = px * scale, pz * scale
        draw.ellipse((x - 2, y - 2, x + 2, y + 2), fill="#244b32")
    for px, pz in IRON:
        x, y = px * scale, pz * scale
        draw.ellipse((x - 2, y - 2, x + 2, y + 2), fill="#eac376")
    for label, (px, pz) in zip("12ABCD", (*STARTS, *POINTS)):
        x, y = px * scale, pz * scale
        draw.ellipse((x - 10, y - 10, x + 10, y + 10), fill="#f5eccc", outline="#182520", width=2)
        draw.text((x, y), label, fill="#182520", anchor="mm")
    preview.save(ROOT / "maps/lembah-sungai-denah.png", optimize=True)
    return len(trees), int(mask.sum())


def tree_positions():
    rng = np.random.default_rng(22026)
    trees = []
    protected = (*STARTS, *POINTS, *IRON, *INFRA, *((SIZE - a, SIZE - b) for a, b in INFRA))
    for cx, cz in FORESTS:
        for _ in range(108):
            dx, dz = rng.normal(0, (103, 134))
            x, z = round(cx + dx), round(cz + dz)
            if min(x, z, SIZE - x, SIZE - z) < 48 or (dx / 103)**2 + (dz / 134)**2 > 4:
                continue
            h, ridge, distance, road = terrain(x, z)
            if h < 12 or ridge < .94 or (road < 98 and distance < 1100):
                continue
            if any((x - a)**2 + (z - b)**2 < 140**2 for a, b in protected):
                continue
            if any((x - a)**2 + (z - b)**2 < 28**2 for a, b, _, _ in trees):
                continue
            trees.append((x, z, int(rng.integers(4)), int(rng.integers(-32768, 32768))))
    return trees + [(SIZE - x, SIZE - z, kind, angle - 32768 if angle >= 0 else angle + 32768)
                    for x, z, kind, angle in trees]


def main():
    lock = json.loads((ROOT / "dependencies.windows.json").read_text(encoding="utf-8"))
    installed = {p["nama"]: ROOT / ".deps" / p["folder"] for p in lock}
    engine, compiler = installed["Recoil Engine"], installed["PyMapConv"]
    work = ROOT / ".cache" / MAP
    (work / "resources").mkdir(parents=True, exist_ok=True)
    for source in ("nvdxt.exe", "resources/geovent.bmp"):
        shutil.copy2(compiler / source, work / source)
    with ZipFile(engine / "base/spring/bitmaps.sdz") as bitmaps:
        tree_count, grass_count = populate(work, textures(bitmaps, work))
    smf, smt = (work / f"{MAP}.{ext}" for ext in ("smf", "smt"))
    for target in (smf, smt):
        target.unlink(missing_ok=True)
    with (work / "kompilasi.log").open("wb") as log:
        subprocess.run([compiler / "pymapconv.exe", "-t", "warna.bmp", "-a", "tinggi.raw", "-y", "tipe.bmp",
                        "-m", "besi.bmp", "-k", "pohon.lua", "-r", "rumput.bmp", "-p", "minimap.bmp", "-o", smf.name,
                        "-n", str(MIN_HEIGHT), "-x", str(MAX_HEIGHT), "-q", "1"],
                       cwd=work, stdout=log, stderr=subprocess.STDOUT, timeout=210,
                       creationflags=subprocess.CREATE_NO_WINDOW)
    if "All Done!" not in (work / "kompilasi.log").read_text(encoding="utf-8", errors="replace"):
        raise RuntimeError(f"Kompilasi gagal. Lihat {work / 'kompilasi.log'}")
    with smf.open("rb") as source:
        magic, version, _, width, depth = struct.unpack("<16siiii", source.read(32))
    assert magic.rstrip(b"\0") == b"spring map file" and version == 1 and (width, depth) == (512, 512)
    with smt.open("rb") as source:
        assert source.read(16).rstrip(b"\0") == b"spring tilefile"
    output = ROOT / "maps" / f"{MAP}.sdz"
    pending = work / output.name
    with ZipFile(pending, "w", compression=ZIP_DEFLATED) as archive:
        archive.write(ROOT / "maps/mapinfo-lembah-sungai.lua", "mapinfo.lua")
        for target in (smf, smt):
            archive.write(target, f"maps/{target.name}")
    os.replace(pending, output)
    print(f"{output.name} | {SIZE} x {SIZE} elmo | {tree_count} pohon | {grass_count} sel rumput")


if __name__ == "__main__":
    main()
