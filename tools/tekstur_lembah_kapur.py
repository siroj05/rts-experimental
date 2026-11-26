"""Tahap 4 Limestone Valley: tekstur warna final, normal map detail 8K, specular (docs/aturan-peta.md bagian 7).

Dipanggil dari tools/buat_lembah_kapur.py (tahap "tekstur"). Semua lapisan diturunkan dari data medan hasil tahap 2
(tinggi, lereng, aliran air, endapan) supaya medan terbaca dari tekstur (aturan BAR):
- datar = rumput (dua warna: segar di dekat alur air, kering di tempat tinggi), lereng = kerikil/tanah,
  tebing = batu kapur berlapis, alur air dan tepi sungai = kerikil, kipas endapan = lanau, titik tambang = karat.
- Gelap di cekungan (AO/cavity dari heightmap), tepi cembung sedikit terang.
- Normal map detail (ruang tangen Recoil: R = +X dunia, G = +Z dunia, B = atas, A = kekuatan campuran) untuk relief
  di bawah 1 m: lapisan dan retakan kapur, butir kerikil, rumpun rumput. Normal makro tetap dari heightmap (engine).
- Specular: RGB = warna kilap, A x 16 = eksponen (Recoil SMFFragProg.glsl).
"""
import math

import numpy as np
from PIL import Image

RNG = np.random.default_rng(424242)


def _halus(t):
    t = np.clip(t, 0, 1)
    return t * t * (3 - 2 * t)


def kotak_blur(A, r):
    """Rata-rata kotak (2r+1)^2 dengan jumlah kumulatif; tepi ditahan."""
    P = np.pad(A, r + 1, mode="edge").astype(np.float64)
    S = P.cumsum(0).cumsum(1)
    k = 2 * r + 1
    n0, n1 = A.shape
    out = (S[k:k + n0, k:k + n1] - S[0:n0, k:k + n1] - S[k:k + n0, 0:n1] + S[0:n0, 0:n1]) / (k * k)
    return out


def ubin(n, sel, seed):
    """Noise ubin (tileable) n x n dari grid acak sel x sel, diperbesar bicubic dengan bungkus tepi."""
    r = np.random.default_rng(seed).random((sel, sel)).astype(np.float32)
    besar = np.tile(r, (3, 3))
    im = Image.fromarray(besar, "F").resize((3 * n, 3 * n), Image.BICUBIC)
    return np.asarray(im)[n:2 * n, n:2 * n] - .5


UBIN = {nama: ubin(1024, sel, s) for nama, sel, s in
        (("kasar", 8, 1), ("sedang", 32, 2), ("halus", 128, 3), ("butir", 512, 4), ("rumpun", 220, 5))}


def ambil_ubin(nama, X, Z, skala, geser=0.0):
    """Sampel noise ubin di koordinat dunia (m) dengan skala (m per ubin)."""
    t = UBIN[nama]
    n = t.shape[0]
    i = ((Z / skala + geser) * n).astype(np.int64) % n
    j = ((X / skala + geser * 1.7) * n).astype(np.int64) % n
    return t[i, j]


class Medan:
    """Data medan 1 m/piksel dan turunannya, disampel per pita."""

    def __init__(self, H, aliran, endapan, L, ukuran):
        self.L = L
        self.ukuran = ukuran
        gz, gx = np.gradient(H, 1.0)
        miring = np.degrees(np.arctan(np.hypot(gx, gz)))
        # Cavity: tinggi rata-rata sekitar minus tinggi (positif = cekungan); dua skala
        cav = (kotak_blur(H, 3) - H) * .6 + (kotak_blur(H, 12) - H) * .25
        self.peta = {nama: Image.fromarray(a.astype(np.float32), "F") for nama, a in (
            ("h", H), ("miring", miring), ("aliran", aliran), ("endapan", np.log1p(np.maximum(endapan, 0) * 4)),
            ("cav", cav))}
        self.n = H.shape[0]

    def pita(self, nama, baris0, tinggi_pita, lebar_px):
        im = self.peta[nama]
        skala = (self.n - 1) / self.ukuran  # piksel peta per meter
        y0 = baris0 * skala
        y1 = (baris0 + tinggi_pita) * skala
        return np.asarray(im.resize((lebar_px, int(round(tinggi_pita * lebar_px / self.ukuran))), Image.BILINEAR,
                                    (0, y0, im.width - 1, y1)), dtype=np.float32)


def warna_pita(M, X, Z, h, m, a, e, cav, tambang):
    """Warna RGB float untuk satu pita (koordinat dunia X, Z dalam meter)."""
    k1 = ambil_ubin("kasar", X, Z, 900)
    k2 = ambil_ubin("sedang", X, Z, 260, .3)
    k3 = ambil_ubin("halus", X, Z, 60, .6)
    k4 = ambil_ubin("butir", X, Z, 9, .1)
    k5 = ambil_ubin("butir", X, Z, 2.7, .8)
    rp = ambil_ubin("rumpun", X, Z, 14, .4)
    L = M.L
    # Rumput: segar (dekat alur, rendah) vs kering (tinggi, cembung)
    basah = _halus((a - 2.5) / 3) * .6 + _halus((L.t_teras - 10 - h) / 25) * .4
    # Rumput hampir polos (user 2026-11-26: "rumputnya ko ga hijau polos, banyak banget coraknya jadi jelek"):
    # satu hijau, variasi hanya skala besar dan sangat lembut, butir halus kecil.
    kering = np.clip(.12 + k1 * .5 - basah * .2, 0, .35)[..., None]
    segar = np.array([60, 90, 40], np.float32)
    layu = np.array([88, 98, 50], np.float32)
    rumput = segar + (layu - segar) * kering
    rumput = rumput + ((k2 * 6 + k5 * 4)[..., None]) * np.array([.9, 1, .7])
    # Tanah/lanau dan kerikil
    tanah = np.array([112, 96, 72], np.float32) + ((k3 * 20 + k4 * 18 + k5 * 12)[..., None])
    lanau = np.array([138, 124, 98], np.float32) + ((k3 * 14 + k4 * 12 + k5 * 8)[..., None])
    kerikil = np.array([128, 122, 106], np.float32) + ((k3 * 16 + k4 * 30 + k5 * 26)[..., None])
    # Batu kapur berlapis: pita horizontal mengikuti tinggi (lapisan batuan), retakan gelap, bercak lumut
    lapis = np.sin(h * 2 * math.pi / 3.2 + k2 * 9 + k3 * 5)
    batu = np.array([146, 141, 127], np.float32) + ((k1 * 40 + lapis * 6 + k3 * 22 + k4 * 24 + k5 * 16)[..., None])
    retak = _halus((np.abs(ambil_ubin("halus", X, Z * .35, 18, .2)) - .45) / .03)
    batu = batu * (1 - .3 * retak[..., None])
    lumut = _halus((k2 + k3 * .8 - .12) / .2) * _halus((40 - m) / 12)
    batu = batu + (np.array([92, 102, 66], np.float32) - batu) * (lumut * .5)[..., None]
    # Campuran menurut medan (aturan BAR: datar = rumput, lereng = kerikil/tanah, tebing = batu)
    w = rumput
    t_tanah = _halus((m - 19 + k3 * 4) / 6)
    w = w + (tanah - w) * t_tanah[..., None]
    t_batu = _halus((m - 25 + k3 * 10 + k4 * 5) / 6)
    w = w + (batu - w) * t_batu[..., None]
    t_alur = _halus((a - 6.2 + k3 * 1.2) / 1.2) * (1 - t_batu)
    w = w + (kerikil - w) * (t_alur * .45)[..., None]
    t_endap = _halus((e - 1.3 + k3 * .5) / .8) * (1 - t_batu) * (1 - t_alur)
    w = w + (lanau - w) * (t_endap * .2)[..., None]
    # Tepi sungai dan arung: kerikil basah; dasar sungai gelap
    t_tepi = _halus((1.6 - h + k4 * .3) / 1.2)
    w = w + (kerikil * .82 - w) * t_tepi[..., None]
    w = w + (np.array([52, 58, 50], np.float32) - w) * _halus((-.2 - h) / 1.2)[..., None]
    # Titik tambang: tanah berkarat
    if tambang is not None:
        w = w + (np.array([104, 82, 62], np.float32) + (k4 * 30)[..., None] - w) * (tambang * .6)[..., None]
    # AO/cavity: cekungan gelap, punggung cembung sedikit terang
    # AO lembut; di rumput lebih lemah lagi supaya tidak belang
    lemah = 1 - .6 * np.clip(1 - t_batu - t_tanah, 0, 1)
    gelap = np.clip(1 - np.clip(cav, 0, 3) * .11 * lemah + np.clip(-cav, 0, 3) * .03, .7, 1.05)
    w = w * gelap[..., None]
    return np.clip(w, 0, 255)


def masker_tambang(L, X, Z):
    m = np.zeros(X.shape, np.float32)
    for x, z in L.tambang:
        if abs(z - Z[0, 0]) > 60 and abs(z - Z[-1, 0]) > 60 and not (Z[0, 0] <= z <= Z[-1, 0]):
            continue
        d = np.hypot(X - x, Z - z)
        n = ambil_ubin("halus", X, Z, 30, .9)
        m = np.maximum(m, _halus((14 + n * 10 - d) / 6))
    return m


def detail_tinggi(X, Z, h, m, a):
    """Tinggi detail (m) di bawah 1 m untuk normal map: kapur berlapis + retak, kerikil, rumpun rumput."""
    t_batu = _halus((m - 24) / 7)
    t_kerikil = np.maximum(_halus((m - 13) / 7) * (1 - t_batu), _halus((a - 5) / 1.6) * (1 - t_batu))
    t_kerikil = np.maximum(t_kerikil, _halus((1.6 - h) / 1.2))
    t_rumput = np.clip(1 - t_batu - t_kerikil, 0, 1)
    k3 = ambil_ubin("halus", X, Z, 60, .6)
    lapis = np.abs(np.sin(h * 2 * math.pi / 3.2 + k3 * 5)) ** 3 * .07
    retak = -_halus((np.abs(ambil_ubin("halus", X, Z * .35, 18, .2)) - .45) / .03) * .1
    batu = lapis + retak + ambil_ubin("butir", X, Z, 9, .1) * .14 + ambil_ubin("sedang", X, Z, 30, .5) * .25
    kerikil = ambil_ubin("butir", X, Z, 2.7, .8) * .07 + ambil_ubin("butir", X, Z, 6, .3) * .05
    rumput = ambil_ubin("rumpun", X, Z, 14, .4) * .06 + ambil_ubin("butir", X, Z, 3.3, .7) * .02
    return batu * t_batu + kerikil * t_kerikil + rumput * t_rumput, t_batu, t_kerikil


def buat_semua(H, aliran, endapan, L, ukuran, path_warna, path_normal, path_spek, N_WARNA=12288, N_NORMAL=8192,
               N_SPEK=6144, cetak=print):
    M = Medan(H, aliran, endapan, L, ukuran)
    # --- Warna ---
    img = Image.new("RGB", (N_WARNA, N_WARNA))
    pita = 384
    per_px = ukuran / N_WARNA
    xs = (np.arange(N_WARNA, dtype=np.float32) + .5) * per_px
    for row in range(0, N_WARNA, pita):
        z0 = row * per_px
        tinggi_m = pita * per_px
        h, m, a, e, cav = (M.pita(n, z0, tinggi_m, N_WARNA) for n in ("h", "miring", "aliran", "endapan", "cav"))
        Z = (np.arange(row, row + pita, dtype=np.float32)[:, None] + .5) * per_px
        X = np.broadcast_to(xs[None, :], (pita, N_WARNA))
        Z = np.broadcast_to(Z, (pita, N_WARNA))
        tambang = masker_tambang(L, X, Z)
        img.paste(Image.fromarray(warna_pita(M, X, Z, h, m, a, e, cav, tambang).astype(np.uint8)), (0, row))
        if row % (pita * 8) == 0:
            cetak(f"  warna {100 * row / N_WARNA:.0f}%")
    img.save(path_warna)
    # --- Normal detail + specular ---
    for nama, NN, path in (("normal", N_NORMAL, path_normal), ("spek", N_SPEK, path_spek)):
        out = Image.new("RGBA", (NN, NN))
        per_px = ukuran / NN
        xs = (np.arange(NN, dtype=np.float32) + .5) * per_px
        pita = 512
        for row in range(0, NN, pita):
            z0 = row * per_px
            h, m, a = (M.pita(n, z0, pita * per_px, NN) for n in ("h", "miring", "aliran"))
            Z = np.broadcast_to((np.arange(row, row + pita, dtype=np.float32)[:, None] + .5) * per_px, (pita, NN))
            X = np.broadcast_to(xs[None, :], (pita, NN))
            d, t_batu, t_kerikil = detail_tinggi(X, Z, h, m, a)
            if nama == "normal":
                gz, gx = np.gradient(d, per_px)
                n = np.stack([-gx, -gz, np.ones_like(d)], -1)
                n /= np.linalg.norm(n, axis=-1, keepdims=True)
                rgb = (n * .5 + .5) * 255
                alfa = (.55 + .4 * t_batu + .15 * t_kerikil) * 255
                arr = np.concatenate([rgb, alfa[..., None]], -1)
            else:
                basah = _halus((1.4 - h) / 1.2)
                spek = .05 + .09 * t_batu + .05 * t_kerikil + .22 * basah
                eksp = (.28 + .25 * t_batu + .45 * basah)  # x16 = 4.5 .. 15
                arr = np.stack([spek * 255, spek * 250, spek * 235, eksp * 255], -1)
            out.paste(Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA"), (0, row))
        out.save(path)
        cetak(f"  {nama} {NN}x{NN} selesai")
