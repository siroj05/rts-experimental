"""Tekstur decal medan buatan sendiri (tahap 6).

1. Tapak bangunan: tanah padat di bawah bangunan (useBuildingGroundDecal, gamedata/defs.lua).

Satu tekstur dipakai semua bangunan dan diregangkan ke ukuran tapak + 1 m tiap sisi. Bentuk persegi membulat dengan
tepi berbaur noise. Isinya tanah cokelat terinjak, butir kerikil, dan bercak lembap. Tanah lebih gelap di tepi
karena terinjak dan terkena cipratan lumpur.

Keluaran ada di game/RTSPC.sdd/unittextures/:
- tapak_tanah.tga: RGBA, A = tutupan;
- tapak_tanah_normal.tga: normal ruang tangen, A = tinggi.

2. Bekas kawah: game/RTSPC.sdd/bitmaps/scars/kawah{1,2}.tga + _normal.tga (gamedata/resources.lua).
   Pusatnya gosong, dikelilingi cincin tanah cokelat teraduk dan gumpalan yang terlempar. Lubangnya sendiri
   dibuat oleh deformasi heightmap (craterMult), jadi decal ini cuma memberi warna dan detail.

    python tools/buat_decal.py   -> + .cache/tapak.png, .cache/kawah.png (pratinjau di atas rumput)
"""
from pathlib import Path

import numpy as np
from PIL import Image

import buat_dnts as D

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game/RTSPC.sdd/unittextures"
UK = 512


def kecil(a):
    return np.asarray(Image.fromarray(a.astype(np.float32), "F").resize((UK, UK), Image.BILINEAR))


def buat():
    rng = np.random.default_rng(7)
    besar = kecil(D.spektral(rng, 1.8, 1, 12))
    sedang = kecil(D.spektral(rng, 1.2, 4, 60))
    halus = kecil(D.spektral(rng, .6, 40, 300))
    tepi_n = kecil(D.spektral(rng, 1.4, 3, 40))
    f1, f2, idx = D.voronoi(rng, 90)
    butir = kecil(np.clip(1 - f1 / .42, 0, 1) * (np.random.default_rng(8).random(90 * 90)[idx] > .55))

    y, x = (np.mgrid[0:UK, 0:UK] + .5) / UK * 2 - 1
    # Persegi membulat (superelips p = 6): 1 di tengah, 0 di luar. Tepi digeser noise supaya tidak lurus.
    r = (np.abs(x) ** 6 + np.abs(y) ** 6) ** (1 / 6) + tepi_n * .035
    tutup = np.clip((.97 - r) / .13, 0, 1)
    tutup = tutup * tutup * (3 - 2 * tutup)
    tepi = np.clip((r - .62) / .3, 0, 1)  # 0 di dalam, 1 di tepi luar

    # Warna sRGB 0-255: tanah terinjak cokelat keabuan, lebih gelap dan lembap ke tepi.
    dasar = np.array([112, 96, 74], np.float32)
    gelap = np.array([74, 62, 47], np.float32)
    t = np.clip(.35 + besar * .18 + tepi * .35, 0, 1)[..., None]
    warna = dasar + (gelap - dasar) * t
    warna = warna * (1 + (sedang * .05 + halus * .035))[..., None]
    warna = warna + butir[..., None] * np.array([30, 28, 24]) * (1 - tepi[..., None] * .5)
    a = tutup * (.93 - tepi * .12)
    rgba = np.concatenate([np.clip(warna, 0, 255), (a * 255)[..., None]], -1)
    OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray((rgba + .5).astype(np.uint8), "RGBA").save(OUT / "tapak_tanah.tga")

    h = sedang * .5 + halus * .35 + butir * 1.4 + besar * .4
    n = D.ke_normal(h, 1.6)
    nt = np.concatenate([n * .5 + .5, np.clip(.5 + h * .1, 0, 1)[..., None]], -1)
    Image.fromarray((nt * 255 + .5).astype(np.uint8), "RGBA").save(OUT / "tapak_tanah_normal.tga")

    rumput = np.full((UK, UK, 3), (62, 90, 42), np.float32)
    lampu = np.clip((n * np.array([-.4, -.4, .82])).sum(-1), 0, 1)[..., None]
    pr = rumput * (1 - a[..., None]) + warna * a[..., None] * (.7 + .4 * lampu)
    Image.fromarray(np.clip(pr, 0, 255).astype(np.uint8)).save(ROOT / ".cache/tapak.png")
    print("tapak:", OUT / "tapak_tanah.tga")


def kawah(seed, nama):
    rng = np.random.default_rng(seed)
    y, x = (np.mgrid[0:UK, 0:UK] + .5) / UK * 2 - 1
    r0 = np.hypot(x, y)
    sudut = np.arctan2(y, x)
    tepi_n = kecil(D.spektral(rng, 1.3, 3, 30))
    sedang = kecil(D.spektral(rng, 1.1, 6, 80))
    halus = kecil(D.spektral(rng, .5, 50, 300))
    # Lontaran radial: lajur memanjang ke luar dengan panjang acak
    titik = rng.random(48)
    lajur = np.interp(sudut, np.linspace(-np.pi, np.pi, 49), np.r_[titik, titik[0]])
    r = r0 * (1 + tepi_n * .12) / (.78 + lajur * .22)
    f1, f2, idx = D.voronoi(rng, 70)
    acak = np.random.default_rng(seed + 1).random(70 * 70)[idx]
    gumpal = kecil(np.clip(1 - f1 / .45, 0, 1) * (acak > .6))
    gumpal = gumpal * np.clip((r - .35) / .2, 0, 1) * np.clip((1.05 - r) / .25, 0, 1)

    gosong = np.clip((.42 - r) / .3, 0, 1) ** 1.3
    teraduk = np.clip(1 - np.abs(r - .55) / .32, 0, 1)
    tanah = np.array([96, 76, 56], np.float32) * (1 + sedang[..., None] * .08 + halus[..., None] * .05)
    hitam = np.array([30, 27, 24], np.float32)
    warna = tanah + (hitam - tanah) * gosong[..., None] * .85
    warna = warna + gumpal[..., None] * np.array([28, 24, 18])
    a = np.clip(np.clip((.8 - r) / .22, 0, 1) + gumpal * .7, 0, 1) * np.clip((1.0 - r) / .15, 0, 1)
    a = np.clip(a * (.9 + sedang * .1), 0, .95)
    rgba = np.concatenate([np.clip(warna, 0, 255), (a * 255)[..., None]], -1)
    keluar = ROOT / "game/RTSPC.sdd/bitmaps/scars"
    keluar.mkdir(parents=True, exist_ok=True)
    Image.fromarray((rgba + .5).astype(np.uint8), "RGBA").save(keluar / f"{nama}.tga")
    h = sedang * .4 + halus * .3 + gumpal * 2.2 + teraduk * sedang * .6
    n = D.ke_normal(h, 1.5)
    nt = np.concatenate([n * .5 + .5, a[..., None]], -1)
    Image.fromarray((nt * 255 + .5).astype(np.uint8), "RGBA").save(keluar / f"{nama}_normal.tga")
    return warna, a, n


def pratinjau_kawah(hasil):
    lembar = []
    for warna, a, n in hasil:
        rumput = np.full((UK, UK, 3), (62, 90, 42), np.float32)
        lampu = np.clip((n * np.array([-.4, -.4, .82])).sum(-1), 0, 1)[..., None]
        lembar.append(rumput * (1 - a[..., None]) + warna * a[..., None] * (.7 + .4 * lampu))
    Image.fromarray(np.clip(np.hstack(lembar), 0, 255).astype(np.uint8)).save(ROOT / ".cache/kawah.png")


if __name__ == "__main__":
    buat()
    pratinjau_kawah([kawah(51, "kawah1"), kawah(52, "kawah2")])
