"""Cetak peta briefing dari relief peta skirmish yang dimainkan."""
import numpy as np
from PIL import Image, ImageDraw

from buat_bukit_tengah import ROOT, SIZE, color_map, height, noise, radius
import buat_lembah_sungai as sungai


Z_MIN, Z_MAX = 316, 1732
WIDTH = 1280
HEIGHT = round(WIDTH * (Z_MAX - Z_MIN) / SIZE)
MENU = ROOT / "menu/RTSPCMenu.sdd/LuaMenu"


def bukit():
    x = np.linspace(0, SIZE, WIDTH, endpoint=False)[None, :]
    z = np.linspace(Z_MIN, Z_MAX, HEIGHT, endpoint=False)[:, None]
    relief = height(x, z)
    dz, dx = np.gradient(relief)
    lereng = np.hypot(dx, dz)
    albedo = np.asarray(color_map().crop((0, Z_MIN, SIZE, Z_MAX)).resize((WIDTH, HEIGHT)), dtype=np.float32)
    kertas = np.array([229, 218, 190])
    tekstur = (albedo - np.array([90, 108, 70])) @ [.45, .40, .15]
    tinta = (np.clip(lereng, 0, 1) * 66 + (radius(x, z) < 1.04) * 17
             + np.clip(relief / 150, 0, 1) * 13 - np.clip(dx + dz, -1, 1) * 30)
    # Satu kontur tiap 3 m, dengan garis indeks tiap 12 m.
    kontur = np.abs((relief + 12) % 24 - 12)
    garis = np.clip(1 - kontur / np.maximum(.22, lereng * 1.22), 0, 1)
    indeks = np.abs((relief + 48) % 96 - 48) < 1.5
    tinta += garis * (32 + indeks * 19)
    rng = np.random.default_rng(804)
    grain = rng.normal(0, 2.1, relief.shape) + noise(rng, 18, WIDTH)[:HEIGHT] * 2.2
    gambar = kertas + (grain - tekstur * .65 - tinta)[..., None] * [1, 1.03, .94]
    Image.fromarray(np.clip(gambar, 0, 255).astype(np.uint8)).save(MENU / "bukit.jpg", quality=93, subsampling=0)


def lembah():
    width = 1000
    x = np.linspace(0, sungai.SIZE, width, endpoint=False)[None, :]
    z = x.T
    relief, ridge, distance, road = sungai.terrain(x, z)
    dz, dx = np.gradient(relief)
    slope = np.hypot(dx, dz)
    contour = np.clip(1 - np.abs((relief + 12) % 24 - 12) / np.maximum(.25, slope * 1.22), 0, 1)
    hill = sungai.smooth((1.22 - ridge) / .54)
    ink = np.clip(slope * 9 - (dx + dz) * 5, -9, 38) + hill * 24 + contour * hill * 35
    grain = noise(np.random.default_rng(804), 180, width) * 2.3
    paper = np.array([229, 218, 190]) + (grain - ink)[..., None] * [1, 1.02, .94]
    path = sungai.smooth((46 - road) / 32) * sungai.smooth((1100 - distance) / 500)
    paper += (np.array([201, 181, 148]) - paper) * path[..., None] * .66
    water = np.array([133, 166, 164]) + (grain - sungai.smooth(-relief / 33) * 22)[..., None]
    color = np.where(relief[..., None] < 0, water, paper)
    image = Image.fromarray(np.clip(color, 0, 255).astype(np.uint8))
    draw = ImageDraw.Draw(image)
    for x, z, kind, _ in sungai.tree_positions():
        px, pz = (x + .5) * width / sungai.SIZE, (z + .5) * width / sungai.SIZE
        r = 1.5 + kind * .34
        draw.ellipse((px - r, pz - r, px + r, pz + r), fill="#68775b")
    image.save(MENU / "sungai.jpg", quality=93, subsampling=0)


if __name__ == "__main__":
    bukit()
    lembah()
