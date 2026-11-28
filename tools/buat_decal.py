"""Tekstur decal medan buatan sendiri (tahap 6).

1. Tapak bangunan: tanah padat di bawah bangunan (useBuildingGroundDecal, gamedata/defs.lua).

Satu tekstur dipakai semua bangunan dan diregangkan ke ukuran tapak + 1 m tiap sisi. Bentuk persegi membulat dengan
tepi berbaur noise. Isinya tanah cokelat terinjak, butir kerikil, dan bercak lembap. Tanah lebih gelap di tepi
karena terinjak dan terkena cipratan lumpur.

Keluaran ada di game/RTSPC.sdd/unittextures/:
- tapak_tanah.tga: RGBA, A = tutupan;
- tapak_tanah_normal.tga: normal ruang tangen, A = tinggi.

2. Bekas kawah: game/RTSPC.sdd/bitmaps/scars/kawah{1,2}.tga + _normal.tga (gamedata/resources.lua).
   Gaya kawah bulan: dasar gelap, dinding, bibir terangkat yang terang, selimut lontaran, dan sinar. Lubangnya
   sendiri dibuat oleh deformasi heightmap (craterMult), decal ini memberi warna dan bentuk halus lewat normal map.

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
    """Kawah gaya bulan (user 2026-11-27: "stylenya kaya kawah dibulan").

    Jari-jari dinormalkan ke tepi decal (r = 1). Decal ±2,2x diameter lubang, jadi bibir kawah ada di r ±0,45.
    - Dasar (r < 0,28): datar, gelap, bekas gosong.
    - Dinding (0,28-0,45): naik curam. Bentuknya dibawa normal map, karena heightmap 1 m terlalu kasar untuk
      kawah 3-6 m.
    - Bibir (r ±0,47): cincin terangkat, tanah kapur segar yang paling terang.
    - Selimut lontaran (0,47-0,78): bergelombang, memudar ke luar.
    - Sinar (sampai r = 1): lajur tipis terang memancar dari pusat.
    """
    rng = np.random.default_rng(seed)
    y, x = (np.mgrid[0:UK, 0:UK] + .5) / UK * 2 - 1
    r0 = np.hypot(x, y)
    sudut = np.arctan2(y, x)
    tepi_n = kecil(D.spektral(rng, 1.3, 3, 30))
    sedang = kecil(D.spektral(rng, 1.1, 6, 80))
    halus = kecil(D.spektral(rng, .5, 50, 300))
    r = r0 * (1 + tepi_n * .05)  # bibir sedikit tidak bulat

    # Profil tinggi: dasar -1, bibir +0,35, selimut turun ke 0
    dasar, bibir = .28, .47
    dinding = np.clip((r - dasar) / (bibir - dasar), 0, 1)
    h = -1 + 1.35 * dinding ** 1.6
    luar = np.clip((r - bibir) / .33, 0, 1)
    h = np.where(r > bibir, .35 * (1 - luar) ** 2, h)
    # Gumpalan lontaran di selimut
    f1, f2, idx = D.voronoi(rng, 60)
    acak = np.random.default_rng(seed + 1).random(60 * 60)[idx]
    gumpal = kecil(np.clip(1 - f1 / .5, 0, 1) * (acak > .55)) * np.clip(1 - np.abs(r - .6) / .2, 0, 1)
    # Bubuk pasir di pinggiran (user 2026-11-27: "pinggirannya kasih bubuk pasir dikit biar ga flat"): butir halus
    # berbintik dengan tepi tak beraturan, makin jarang ke luar.
    butir_n = np.random.default_rng(seed + 2).random((UK, UK))
    sebar = kecil(D.spektral(rng, 1.2, 4, 50))
    jangkau = .9 + sebar * .08 + tepi_n * .06  # batas luar bubuk bergelombang
    padat = np.clip((jangkau - r) / (jangkau - bibir), 0, 1) ** 1.4 * (r > bibir - .02)
    padat = padat * np.clip(.55 + sebar * .5, 0, 1)
    pasir = (butir_n < padat * 1.1).astype(np.float32) * np.clip(.6 + butir_n * .8, 0, 1)
    pasir = np.maximum(pasir, padat * .5)  # lapisan debu tipis di bawah butirnya
    h = h + gumpal * .12 + sedang * .03 + halus * .015 + pasir * .04

    # Sinar: 9-14 lajur sempit dengan panjang acak
    n_sinar = rng.integers(9, 15)
    arah = rng.uniform(-np.pi, np.pi, n_sinar)
    sinar = np.zeros_like(r)
    for s0, panjang, lebar in zip(arah, rng.uniform(.75, 1.0, n_sinar), rng.uniform(.035, .07, n_sinar)):
        beda = np.abs((sudut - s0 + np.pi) % (2 * np.pi) - np.pi)
        sinar = np.maximum(sinar, np.clip(1 - beda / lebar, 0, 1) * np.clip((panjang - r) / .2, 0, 1)
                           * np.clip((r - bibir) / .08, 0, 1))
    sinar = sinar * np.clip(.7 + halus * .6, 0, 1)

    # Warna sRGB: dasar gosong gelap, bibir dan lontaran kapur terang, tanah teraduk di antaranya
    gelap = np.array([46, 42, 38], np.float32)
    tanah = np.array([104, 92, 76], np.float32)
    kapur = np.array([176, 168, 150], np.float32)
    t_dinding = dinding[..., None]
    warna = gelap + (tanah - gelap) * t_dinding
    segar = np.clip(1 - np.abs(r - bibir) / .1, 0, 1) * .8 + (1 - luar) * (r > bibir) * .45 + sinar * .6
    warna = warna + (kapur - warna) * np.clip(segar, 0, 1)[..., None]
    warna = warna * (1 + sedang[..., None] * .07 + halus[..., None] * .05)
    pasir_w = np.array([168, 150, 118], np.float32) * (.85 + butir_n[..., None] * .3)
    luar_bibir = (r > bibir + .03)[..., None]
    warna = np.where(luar_bibir, warna + (pasir_w - warna) * (pasir * .8)[..., None], warna)

    a = np.where(r < bibir + .05, 1.0, np.clip(1 - luar * 1.1, 0, 1) ** 1.5)
    a = np.maximum(a, sinar * .75)
    a = np.maximum(a, pasir * .85)
    a = np.clip(a * np.clip((1.0 - r0) / .06, 0, 1) * (.92 + sedang * .06), 0, .97)

    rgba = np.concatenate([np.clip(warna, 0, 255), (a * 255)[..., None]], -1)
    keluar = ROOT / "game/RTSPC.sdd/bitmaps/scars"
    keluar.mkdir(parents=True, exist_ok=True)
    Image.fromarray((rgba + .5).astype(np.uint8), "RGBA").save(keluar / f"{nama}.tga")
    n = D.ke_normal(h, 40)
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
