"""Skybox cubemap buatan sendiri (tahap 6 peta, docs/aturan-peta.md bagian 6-7).

Isi langit:
- gradasi dari zenit biru ke cakrawala pucat berkabut;
- cahaya hangat di sekitar arah matahari (sama dengan lighting.sunDir di mapinfo);
- awan kumulus tipis, diproyeksikan ke bidang langit;
- dua lapis barisan pegunungan di cakrawala: jauh pucat kebiruan, dekat lebih gelap, puncak bersalju;
- belahan bawah berwarna kabut tanah, supaya tepi peta menyatu dengan fogColor.

Sumbu Recoil: y ke atas, utara = -z. Urutan sisi cubemap mengikuti OpenGL (+X, -X, +Y, -Y, +Z, -Z).

    from buat_langit import buat_langit
    buat_langit("keluar.dds", matahari=(-0.32, 0.62, -0.71), seed=1, pratinjau="langit.png")
"""
import numpy as np
from PIL import Image

import buat_dnts as D
from dds_bc3 import simpan_bc3_kubus

ZENIT = np.array([.22, .40, .68])
CAKRAWALA = np.array([.73, .79, .85])
KABUT_BAWAH = np.array([.55, .61, .62])


def _arah(sisi, n):
    t, s = (np.mgrid[0:n, 0:n] + .5) / n * 2 - 1
    satu = np.ones_like(s)
    d = {0: (satu, -t, -s), 1: (-satu, -t, s), 2: (s, satu, t), 3: (s, -satu, -t), 4: (s, -t, satu),
         5: (-s, -t, -satu)}[sisi]
    d = np.stack(d, -1)
    return d / np.linalg.norm(d, axis=-1, keepdims=True)


def _profil(rng, n, kasar, pmin, pmaks):
    """Garis punggung gunung periodik per azimut (radian elevasi)."""
    f = np.fft.rfftfreq(n) * n
    amp = np.where(f > 0, 1 / np.maximum(f, 1) ** kasar, 0)
    spek = (rng.standard_normal(len(f)) + 1j * rng.standard_normal(len(f))) * amp
    p = np.fft.irfft(spek, n)
    p = (p - p.min()) / (p.max() - p.min())
    p = p ** 2.0  # puncak runcing, lembah lebar
    return np.radians(pmin + (pmaks - pmin) * p)


def _sampel(tex, u, v):
    """Bilinear dari tekstur periodik."""
    n = tex.shape[0]
    x, y = (u % 1) * n, (v % 1) * n
    x0, y0 = np.floor(x).astype(int), np.floor(y).astype(int)
    fx, fy = x - x0, y - y0
    x1, y1 = (x0 + 1) % n, (y0 + 1) % n
    x0, y0 = x0 % n, y0 % n
    return ((tex[y0, x0] * (1 - fx) + tex[y0, x1] * fx) * (1 - fy)
            + (tex[y1, x0] * (1 - fx) + tex[y1, x1] * fx) * fy)


def _halus(t):
    t = np.clip(t, 0, 1)
    return t * t * (3 - 2 * t)


def buat_langit(keluar, matahari, seed=1, n=1024, pratinjau=None):
    rng = np.random.default_rng(seed)
    s = np.asarray(matahari, float)
    s /= np.linalg.norm(s)
    awan_t = D.spektral(rng, 2.3, 1, 50)
    awan_h = D.spektral(rng, 1.7, 4, 110)
    gunung_jauh = _profil(rng, 4096, 1.15, 1.0, 10.0)
    gunung_dekat = _profil(rng, 4096, 1.3, .2, 5.5)
    tekstur_g = D.spektral(rng, 1.7, 3, 90)

    sisi = []
    for i in range(6):
        d = _arah(i, n)
        dy = d[..., 1]
        e = np.arcsin(np.clip(dy, -1, 1))
        az = np.arctan2(d[..., 0], -d[..., 2])  # 0 = utara, searah jarum jam dilihat dari atas
        cos_m = (d * s).sum(-1)

        # Langit
        t = _halus(e / (np.pi / 2)) ** .55
        c = CAKRAWALA + (ZENIT - CAKRAWALA) * t[..., None]
        silau = np.exp((cos_m - 1) * 6) * np.exp(-np.maximum(e, 0) * 2.5)
        c = c + np.array([.30, .22, .10]) * silau[..., None] * .55
        c = c + np.array([1.0, .93, .80]) * (np.exp((cos_m - 1) * 900) * .9 + np.exp((cos_m - 1) * 60) * .12)[..., None]

        # Awan: proyeksi ke bidang langit, menipis ke cakrawala
        naik = np.maximum(dy, .02)
        u, v = d[..., 0] / (naik + .12) * .22, d[..., 2] / (naik + .12) * .22
        rapat = _sampel(awan_t, u, v) * .85 + _sampel(awan_h, u * 2.3, v * 2.3) * .22
        awan = _halus((rapat - .35) / 1.3) * _halus(e / .08) * (1 - _halus((e - 1.0) / .4) * .6)
        terang = .5 + .5 * np.clip(_sampel(awan_t, u + .004 * s[0], v + .004 * s[2]) - rapat * .8 + .5, 0, 1)
        warna_awan = np.array([.62, .66, .73]) + (np.array([1.0, .98, .95]) - np.array([.62, .66, .73])) * terang[..., None]
        warna_awan = warna_awan + np.array([.25, .16, .05]) * silau[..., None] * .5
        c = c + (warna_awan - c) * (awan * .85)[..., None]

        # Gunung: dua lapis, dekat menutupi jauh
        k = (az / (2 * np.pi) % 1) * 4096
        k0 = np.floor(k).astype(int)
        fk = k - k0
        for prof, warna, kabut, salju_min in ((gunung_jauh, np.array([.47, .54, .64]), .5, 5.0),
                                              (gunung_dekat, np.array([.30, .36, .40]), .28, 3.2)):
            h = prof[k0 % 4096] * (1 - fk) + prof[(k0 + 1) % 4096] * fk
            di = e < h
            # Relief batu: noise 2D dengan skala sudut yang sama ke dua arah, dibuat bergalur (ridged)
            uu, vv = az / (2 * np.pi) * 2.5, e / (2 * np.pi) * 2.5  # ±1 piksel noise per piksel sisi (tanpa aliasing)
            galur = 1 - np.abs(_sampel(tekstur_g, uu, vv * 1.6))
            terang = (_sampel(tekstur_g, uu + .002, vv * 1.6) - _sampel(tekstur_g, uu - .002, vv * 1.6)) * 4
            w = warna * (.84 + galur[..., None] * .22 + np.clip(terang, -.12, .12)[..., None])
            # Salju di puncak, batasnya bergerigi mengikuti galur; lebih gelap dan berkabut ke kaki gunung
            batas = h - np.radians(1.1 + 1.4 * galur)
            salju = _halus((e - batas) / np.radians(.25)) * _halus((np.degrees(h) - salju_min) / .8)
            w = w + (np.array([.86, .89, .93]) - w) * (salju * .85)[..., None]
            w = w + (CAKRAWALA - w) * kabut
            c = np.where(di[..., None], w, c)

        # Belahan bawah: kabut tanah yang menyatu dengan fogColor
        bawah = _halus(-e / .12)
        c = c + (KABUT_BAWAH - c) * bawah[..., None]

        c = np.clip(c, 0, 1) * 255 + rng.uniform(-.6, .6, c.shape)  # dither melawan banding BC3
        sisi.append(np.concatenate([np.clip(c, 0, 255), np.full(c.shape[:2] + (1,), 255.)], -1).astype(np.uint8))
    simpan_bc3_kubus(sisi, keluar)
    if pratinjau:
        # Silang cubemap: +Y di atas, -X +Z +X -Z melintang, -Y di bawah (setengah ukuran)
        m = n // 2
        k = [np.asarray(Image.fromarray(a[..., :3]).resize((m, m))) for a in sisi]
        silang = np.zeros((m * 3, m * 4, 3), np.uint8)
        silang[0:m, m:2 * m] = k[2]
        for j, idx in enumerate((1, 4, 0, 5)):
            silang[m:2 * m, j * m:(j + 1) * m] = k[idx]
        silang[2 * m:, m:2 * m] = k[3]
        Image.fromarray(silang).save(pratinjau)
    return sisi
