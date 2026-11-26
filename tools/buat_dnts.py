"""Tekstur detail DNTS (splat detail normal) yang dipakai ulang antar-peta (docs/aturan-peta.md bagian 7).

Empat ubin 1024 x 1024 seamless, TGA (bukan DDS: kanal hijau normal bisa terbalik, saran BAR):
  rumput  - rumput pendek/turf: goresan helai acak arah + rumpun
  tanah   - gumpalan tanah + retak halus
  kerikil - batu kerikil (voronoi periodik) dengan sela gelap
  batu    - kapur: lapisan miring, retakan, lubang pelarutan
RGB = normal ruang tangen Recoil (R = +X, G = +Z, B = atas; SMFFragProg.glsl, stnMatrix), A = detail terang-gelap
berpusat di 0,5 (dipakai dengan splatDetailNormalDiffuseAlpha = true; ditambahkan ke warna diffuse).

Dibuat dengan numpy (sintesis spektral FFT dan voronoi periodik) supaya tersambung sempurna saat diulang. Blender
headless tidak dipakai di sini karena noise prosedural Blender tidak seamless (🟡 2026-11-26, dicatat di aturan).

    python tools/buat_dnts.py      -> .cache/dnts/<nama>.tga + .cache/dnts/lembar.png
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / ".cache/dnts"
N = 1024


def spektral(rng, beta, fmin=1, fmax=None, aniso=None):
    """Noise periodik: white noise disaring 1/f^beta di pita [fmin, fmax] (siklus per ubin)."""
    w = rng.standard_normal((N, N))
    F = np.fft.fft2(w)
    fy = np.fft.fftfreq(N) * N
    fx = np.fft.fftfreq(N) * N
    FX, FY = np.meshgrid(fx, fy)
    if aniso is not None:
        sudut, rasio = aniso
        c, s = np.cos(sudut), np.sin(sudut)
        u, v = FX * c + FY * s, -FX * s + FY * c
        f = np.hypot(u * rasio, v)
    else:
        f = np.hypot(FX, FY)
    filt = np.where(f > 0, 1 / np.maximum(f, 1e-9) ** beta, 0)
    filt[f < fmin] = 0
    if fmax:
        filt *= np.exp(-(f / fmax) ** 2)
    a = np.real(np.fft.ifft2(F * filt))
    return (a - a.mean()) / (a.std() + 1e-9)


def voronoi(rng, sel):
    """F1, F2 periodik (jarak dalam satuan sel) dengan satu titik acak per sel."""
    titik = rng.random((sel, sel, 2))
    y, x = np.mgrid[0:N, 0:N] * (sel / N)
    ci, cj = np.floor(y).astype(int), np.floor(x).astype(int)
    f1 = np.full((N, N), 9.0)
    f2 = np.full((N, N), 9.0)
    idx = np.zeros((N, N), int)
    for di in (-1, 0, 1):
        for dj in (-1, 0, 1):
            ni, nj = (ci + di) % sel, (cj + dj) % sel
            p = titik[ni, nj]
            py, px = ci + di + p[..., 0], cj + dj + p[..., 1]
            d = np.hypot(y - py, x - px)
            lebih = d < f1
            f2 = np.where(lebih, f1, np.minimum(f2, d))
            idx = np.where(lebih, ni * sel + nj, idx)
            f1 = np.where(lebih, d, f1)
    return f1, f2, idx


def ke_normal(h, kuat):
    """Normal dari tinggi periodik (np.roll benar di sini karena ubin tersambung)."""
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * .5 * kuat
    gz = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * .5 * kuat
    n = np.stack([-gx, -gz, np.ones_like(h)], -1)
    return n / np.linalg.norm(n, axis=-1, keepdims=True)


def simpan(nama, h, kuat, terang):
    n = ke_normal(h, kuat)
    t = np.clip(.5 + terang, 0, 1)
    rgba = np.concatenate([(n * .5 + .5), t[..., None]], -1)
    Image.fromarray((rgba * 255 + .5).astype(np.uint8), "RGBA").save(OUT / f"{nama}.tga")
    return n, t


def buat():
    OUT.mkdir(parents=True, exist_ok=True)
    hasil = {}
    # Rumput: helai pendek berarah acak per petak + rumpun
    rng = np.random.default_rng(11)
    helai = sum(spektral(rng, 0.0, 14, 60, (a, 5)) for a in np.linspace(0, np.pi, 6, endpoint=False)) / 2.5
    rumpun = spektral(rng, 1.4, 2, 24)
    h = helai * .8 + rumpun * .2
    hasil["rumput"] = simpan("rumput", h, 1.1, helai * .03)
    # Tanah: gumpalan + retak halus
    rng = np.random.default_rng(22)
    f1, f2, _ = voronoi(rng, 18)
    gumpal = spektral(rng, 1.6, 2, 60)
    retak = np.clip((f2 - f1) * 4, 0, 1)
    h = gumpal * .9 + retak * 1.0 + spektral(rng, .6, 30, 140) * .3
    hasil["tanah"] = simpan("tanah", h, 1.7, gumpal * .05 + (retak - .5) * .08)
    # Kerikil: batu bulat voronoi, sela gelap, permukaan batu bertekstur
    rng = np.random.default_rng(33)
    f1, f2, idx = voronoi(rng, 24)
    batu = np.sqrt(np.clip(1 - (f1 / np.maximum(f2, 1e-6)) ** 1.2, 0, 1))
    acak = np.random.default_rng(34).random(24 * 24)[idx]
    h = batu * (1.4 + acak * .8) * 3 + spektral(rng, .5, 40, 200) * .2
    hasil["kerikil"] = simpan("kerikil", h, 1.3, (acak - .5) * .16 + (batu - .6) * .14)
    # Batu kapur: lapisan miring, retakan, lubang pelarutan
    rng = np.random.default_rng(44)
    y, x = np.mgrid[0:N, 0:N] / N
    warp = spektral(rng, 1.8, 1, 30)
    lapis = np.sin((y * 9 + x * 1) * 2 * np.pi + warp * 1.6)
    f1, f2, _ = voronoi(rng, 12)
    retak = 1 - np.clip((f2 - f1) * 6, 0, 1)
    lubang = np.clip(spektral(rng, 1.0, 20, 200) - 1.6, 0, None)
    h = lapis * .35 + spektral(rng, 1.2, 4, 200) * .7 - retak * .9 - lubang * .8
    hasil["batu"] = simpan("batu", h, 2.0, spektral(rng, 1.3, 2, 60) * .06 - retak * .1 - lubang * .06)
    # Lembar pratinjau: ubin 2x2 diterangi dari barat laut (cek sambungan)
    lampu = np.array([-.5, -.5, .7])
    lampu /= np.linalg.norm(lampu)
    lembar = []
    for nama, (n, t) in hasil.items():
        s = np.clip((n * lampu).sum(-1), 0, 1) * (0.6 + 0.8 * (t - .5) + .4)
        s = np.tile(s[::2, ::2], (2, 2))
        lembar.append((np.clip(s, 0, 1) * 255).astype(np.uint8))
    Image.fromarray(np.hstack(lembar)).save(OUT / "lembar.png")
    print("DNTS:", ", ".join(f"{k}.tga" for k in hasil), "->", OUT)


if __name__ == "__main__":
    buat()
