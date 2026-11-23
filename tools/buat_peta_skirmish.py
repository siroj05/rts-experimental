"""Cetak peta briefing dari relief dan warna peta Bukit yang dimainkan."""
import numpy as np
from PIL import Image

from buat_bukit_tengah import ROOT, SIZE, color_map, height, noise, radius


Z_MIN, Z_MAX = 316, 1732
WIDTH = 1280
HEIGHT = round(WIDTH * (Z_MAX - Z_MIN) / SIZE)


def main():
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
    out = ROOT / "menu/RTSPCMenu.sdd/LuaMenu/bukit.jpg"
    Image.fromarray(np.clip(gambar, 0, 255).astype(np.uint8)).save(out, quality=93, subsampling=0)


if __name__ == "__main__":
    main()
