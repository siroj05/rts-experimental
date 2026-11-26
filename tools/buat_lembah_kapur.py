"""Bangun Limestone Valley 4v4 (lembah kapur) dari layout ber-seed (tools/lembah_kapur_layout.py).

Tahap 2 (docs/aturan-peta.md bagian 7): heightmap + erosi.
- Bentuk dasar = Layout.tinggi_dasar, ditambah noise fBm (kasar di punggung/massif, halus di padang).
- Erosi dihitung di 2 m/piksel (769 x 769): aliran air D8 (akumulasi diurutkan dari tinggi ke rendah), erosi
  stream-power (K * A^0.5 * S), endapan di tempat landai, lalu erosi termal (lereng > 33° longsor).
- Area main dilindungi: teras markas, titik pertahanan, tambang, sungai/arung (masker lindung).
- Naik ke 1537 x 1537 (1 piksel = 1 m = 8 elmo), detail halus, lalu batasan gameplay dipasang ulang dengan tepat.
- Keluaran .cache/lembah-kapur-4v4/: tinggi.npy (m, muka air = 0), aliran.npy dan endapan.npy (untuk tekstur),
  dan pratinjau maps/lembah-kapur-tinggi.png. Pemeriksaan: teras datar, tambang datar, jalur tersambung.

    python tools/buat_lembah_kapur.py tinggi
"""
import argparse
import math
import sys
import time
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lembah_kapur_layout import (BELA_R, SEED_TERPILIH, STEM, SUNGAI_SETENGAH, TENGAH, TERAS_R, UKURAN, Layout,
                                 _halus, putar)

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / ".cache" / STEM
N = UKURAN + 1          # 1537
NS = UKURAN // 2 + 1    # 769, 2 m/piksel
MIRING_MAKS = 26.0      # derajat; Medium Tank maxslope 28, sisakan cadangan


def fbm(n, oktaf, rng, skala0):
    """Value noise fBm n x n dalam [-1, 1], dari grid acak yang diperbesar bicubic."""
    hasil = np.zeros((n, n), np.float32)
    amp, total = 1.0, 0.0
    for o in range(oktaf):
        sel = max(2, int(n / (skala0 / 2 ** o)))
        g = rng.random((sel, sel)).astype(np.float32)
        im = Image.fromarray(g, "F").resize((n, n), Image.BICUBIC)
        hasil += amp * (np.asarray(im) * 2 - 1)
        total += amp
        amp *= .5
    return hasil / total


def grid(n, langkah):
    xs = np.arange(n, dtype=np.float64) * langkah
    return np.meshgrid(xs, xs)


def masker_lindung(L, X, Z):
    """1 = dilindungi penuh dari erosi/noise (area main), turun halus ke 0."""
    m = np.zeros_like(X)
    for (px, pz) in L.markas:
        m = np.maximum(m, 1 - _halus((np.hypot(X - px, Z - pz) - TERAS_R - 10) / 90))
    for (px, pz) in L.bela:
        m = np.maximum(m, 1 - _halus((np.hypot(X - px, Z - pz) - BELA_R - 5) / 70))
    for (px, pz) in L.tambang:
        m = np.maximum(m, 1 - _halus((np.hypot(X - px, Z - pz) - 12) / 26))
    t = Z - TENGAH
    sx = TENGAH + sum(a * s * np.sin(t / w) for a, w, s in L.sungai_suku)
    m = np.maximum(m, 1 - _halus((np.abs(X - sx) - SUNGAI_SETENGAH - 8) / 20))
    return m


def masker_kasar(L, H0):
    """0 di padang/teras, 1 di punggung, tebing, massif (tinggi di atas profil lembah-teras)."""
    xs = np.arange(H0.shape[1]) * (UKURAN / (H0.shape[1] - 1))
    lereng = _halus((np.abs(xs - TENGAH) - L.lembah_setengah) / L.lereng_lebar)
    profil = L.t_lembah + (L.t_teras - L.t_lembah) * lereng
    return np.clip((H0 - profil[None, :] - 2) / 12, 0, 1)


ARAH = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]


def aliran_d8(H, langkah):
    """Penerima D8 dan akumulasi aliran (jumlah sel hulu, termasuk diri)."""
    n = H.shape[0]
    pad = np.pad(H, 1, mode="edge")
    terbaik = np.zeros_like(H)
    arah = np.full(H.shape, -1, np.int8)
    for k, (dz, dx) in enumerate(ARAH):
        tetangga = pad[1 + dz:1 + dz + n, 1 + dx:1 + dx + n]
        s = (H - tetangga) / (langkah * math.hypot(dz, dx))
        lebih = s > terbaik
        terbaik = np.where(lebih, s, terbaik)
        arah = np.where(lebih, k, arah)
    zz, xx = np.mgrid[0:n, 0:n]
    dzs = np.array([a[0] for a in ARAH])
    dxs = np.array([a[1] for a in ARAH])
    rz = np.where(arah >= 0, np.clip(zz + dzs[arah], 0, n - 1), zz)
    rx = np.where(arah >= 0, np.clip(xx + dxs[arah], 0, n - 1), xx)
    penerima = (rz * n + rx).ravel()
    urut = np.argsort(-H.ravel(), kind="stable").tolist()
    rec = penerima.tolist()
    acc = [1.0] * (n * n)
    for i in urut:
        r = rec[i]
        if r != i:
            acc[r] += acc[i]
    return np.array(acc).reshape(H.shape), penerima.reshape(H.shape), terbaik


def aliran_mfd(H, langkah):
    """Aliran multi-arah (MFD, bobot lereng^1.1 ke semua tetangga lebih rendah): tanpa garis lurus khas D8.
    Kembalikan akumulasi (sel), lereng curam maksimum, dan bobot per arah (untuk endapan ke hilir)."""
    n = H.shape[0]
    pad = np.pad(H, 1, mode="edge")
    W = []
    smaks = np.zeros_like(H)
    for dz, dx in ARAH:
        tetangga = pad[1 + dz:1 + dz + n, 1 + dx:1 + dx + n]
        s = np.clip((H - tetangga) / (langkah * math.hypot(dz, dx)), 0, None)
        smaks = np.maximum(smaks, s)
        W.append(s ** 1.1)
    total = sum(W)
    total[total == 0] = 1
    W = [w / total for w in W]
    # Tepi peta: jangan alirkan keluar indeks
    for k, (dz, dx) in enumerate(ARAH):
        if dz == -1: W[k][0, :] = 0
        if dz == 1: W[k][-1, :] = 0
        if dx == -1: W[k][:, 0] = 0
        if dx == 1: W[k][:, -1] = 0
    off = [dz * n + dx for dz, dx in ARAH]
    Wl = [w.ravel().tolist() for w in W]
    urut = np.argsort(-H.ravel(), kind="stable").tolist()
    acc = [1.0] * (n * n)
    w0, w1, w2, w3, w4, w5, w6, w7 = Wl
    o0, o1, o2, o3, o4, o5, o6, o7 = off
    for i in urut:
        a = acc[i]
        v = w0[i]
        if v: acc[i + o0] += a * v
        v = w1[i]
        if v: acc[i + o1] += a * v
        v = w2[i]
        if v: acc[i + o2] += a * v
        v = w3[i]
        if v: acc[i + o3] += a * v
        v = w4[i]
        if v: acc[i + o4] += a * v
        v = w5[i]
        if v: acc[i + o5] += a * v
        v = w6[i]
        if v: acc[i + o6] += a * v
        v = w7[i]
        if v: acc[i + o7] += a * v
    return np.array(acc).reshape(H.shape), smaks, W


def droplet(H, keras, jumlah, rng, langkah, batas_x):
    """Erosi partikel: tiap tetes mengalir menuruni lereng, mengikis (kuas 3x3) saat membawa sedikit sedimen dan
    mengendap saat melambat atau naik. keras: 0 = mudah terkikis, 1 = tidak terkikis (area main).
    batas_x(z) -> kolom maksimum tempat tetes dilepas (sisi barat saja; timur hasil putaran)."""
    n = H.shape[0]
    h = H.ravel().tolist()
    k = (1 - keras).ravel().tolist()
    dep_total = [0.0] * (n * n)
    INERSIA, KAPASITAS, MIN_S, ENDAP, KIKIS, UAP, GRAV, LANGKAH_MAKS = .05, 6.0, .01, .3, .35, .015, 9.0, 60
    spawn_x = rng.random(jumlah)
    spawn_z = rng.random(jumlah) * (n - 3) + 1
    for d in range(jumlah):
        z = float(spawn_z[d])
        x = 1 + float(spawn_x[d]) * (batas_x[int(z)] - 2)
        dx = dz = 0.0
        v, air, sed = 1.0, 1.0, 0.0
        for _ in range(LANGKAH_MAKS):
            ix, iz = int(x), int(z)
            fx, fz = x - ix, z - iz
            i = iz * n + ix
            h00, h10, h01, h11 = h[i], h[i + 1], h[i + n], h[i + n + 1]
            gx = (h10 - h00) * (1 - fz) + (h11 - h01) * fz
            gz = (h01 - h00) * (1 - fx) + (h11 - h10) * fx
            hlama = h00 * (1 - fx) * (1 - fz) + h10 * fx * (1 - fz) + h01 * (1 - fx) * fz + h11 * fx * fz
            dx = dx * INERSIA - gx * (1 - INERSIA)
            dz = dz * INERSIA - gz * (1 - INERSIA)
            pj = math.sqrt(dx * dx + dz * dz)
            if pj < 1e-9:
                break
            dx /= pj
            dz /= pj
            x += dx
            z += dz
            if x < 1 or z < 1 or x >= n - 2 or z >= n - 2:
                break
            jx, jz = int(x), int(z)
            ex, ez = x - jx, z - jz
            j = jz * n + jx
            hbaru = h[j] * (1 - ex) * (1 - ez) + h[j + 1] * ex * (1 - ez) + h[j + n] * (1 - ex) * ez + h[j + n + 1] * ex * ez
            beda = hbaru - hlama
            kap = max(-beda, MIN_S) * v * air * KAPASITAS
            if sed > kap or beda > 0:
                taruh = min(beda, sed) if beda > 0 else (sed - kap) * ENDAP
                sed -= taruh
                h[i] += taruh * (1 - fx) * (1 - fz)
                h[i + 1] += taruh * fx * (1 - fz)
                h[i + n] += taruh * (1 - fx) * fz
                h[i + n + 1] += taruh * fx * fz
                dep_total[i] += taruh
            else:
                kikis = min((kap - sed) * KIKIS, -beda) * k[i]
                if kikis > 0:
                    # Kuas 3x3 berbobot di sekitar sel asal
                    for oz, ox, w in ((0, 0, .36), (0, 1, .12), (0, -1, .12), (1, 0, .12), (-1, 0, .12),
                                      (1, 1, .04), (1, -1, .04), (-1, 1, .04), (-1, -1, .04)):
                        q = i + oz * n + ox
                        h[q] -= kikis * w * k[q] / max(k[i], 1e-6) if k[q] > 0 else 0
                    sed += kikis
            v = math.sqrt(max(0.0, v * v + beda * GRAV * -1))
            air *= (1 - UAP)
    return np.array(h).reshape(H.shape), np.array(dep_total).reshape(H.shape)


def geser(A, dz, dx):
    """Seperti np.roll tetapi tepi ditahan (tidak membungkus ke sisi seberang peta)."""
    n0, n1 = A.shape
    P = np.pad(A, 1, mode="edge")
    return P[1 - dz:1 - dz + n0, 1 - dx:1 - dx + n1]


def termal(H, langkah, sudut, lindung, iterasi):
    batas = math.tan(math.radians(sudut)) * langkah
    for _ in range(iterasi):
        pindah = np.zeros_like(H)
        for dz, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
            t = geser(H, dz, dx)
            beda = H - t
            lebih = np.clip(beda - batas, 0, None) * .2 * (1 - lindung)
            pindah -= lebih
            pindah += geser(lebih, -dz, -dx)
        H = H + pindah
    return H


def erosi(L, rng):
    langkah = UKURAN / (NS - 1)
    X, Z = grid(NS, langkah)
    lindung = masker_lindung(L, X, Z)
    # Domain warp: tepi punggung/tebing/massif tidak beraturan (nol di area main)
    wx = fbm(NS, 5, rng, 320) * 110 * (1 - lindung)
    wz = fbm(NS, 5, rng, 320) * 110 * (1 - lindung)
    H0 = L.tinggi_dasar(X, Z, wx, wz)
    kasar = masker_kasar(L, H0)
    # Padang: gelombang bukit kecil (bisa dilalui); punggung: noise bergerigi (ridged) untuk alur dan tonjolan batu
    gelombang = fbm(NS, 5, rng, 300) * 7 + fbm(NS, 3, rng, 110) * 1.6
    gerigi = (1 - np.abs(fbm(NS, 5, rng, 160))) * 2 - 1
    noise = gelombang * (1 - kasar) + (gerigi * 5 + fbm(NS, 4, rng, 60) * 1.5) * kasar
    # Noise boleh lebih dekat ke area main daripada erosi (transisi tidak berbentuk cakram)
    dekat = np.clip(lindung * 1.6 - .6, 0, 1)
    H = H0 + noise * (1 - dekat)
    endapan = np.zeros_like(H)
    awal = H.copy()
    # Erosi partikel di sisi barat (timur = putaran 180° sesudahnya)
    t = (np.arange(NS) * langkah) - TENGAH
    sx = TENGAH + sum(a * s * np.sin(t / w) for a, w, s in L.sungai_suku)
    batas_x = np.clip((sx + 40) / langkah, 10, NS - 3).astype(int).tolist()
    # Kekerasan: kapur di punggung/tebing keras (tetap tebing), tanah di lereng lunak (alur), padang datar sedang.
    gz0, gx0 = np.gradient(H0, langkah)
    miring0 = np.degrees(np.arctan(np.hypot(gx0, gz0)))
    datar = np.clip((6 - miring0) / 4, 0, 1)
    keras = np.clip(lindung + .55 * kasar + .4 * (1 - kasar) * datar, 0, 1)
    # Pita 24 m di tepi peta tidak dikikis (tetes yang keluar peta dulu melubangi kolom tepi)
    tepi = np.minimum(np.minimum(X, UKURAN - X), np.minimum(Z, UKURAN - Z))
    keras = np.maximum(keras, 1 - _halus((tepi - 12) / 12))
    t1 = time.time()
    H, dep = droplet(H, keras, 260000, rng, langkah, batas_x)
    endapan += dep
    print(f"  erosi partikel 260.000 tetes: {time.time() - t1:.0f} s, turun maks {(awal - H).max():.1f} m, "
          f"naik maks {(H - awal).max():.1f} m", flush=True)
    H = termal(H, langkah, 40, lindung, 3)
    # Haluskan bopeng kecil hasil tetes di tanah (bukan di tebing kapur): rata-rata 3x3, dua kali.
    for _ in range(2):
        rata = sum(geser(H, a, b) for a in (-1, 0, 1) for b in (-1, 0, 1)) / 9
        H = H + (rata - H) * (.75 * (1 - kasar))
    putaran = 0
    for it in range(putaran):
        A, S, W = aliran_mfd(H, langkah)
        luas = A * langkah * langkah
        # Erosi stream-power: kapur lunak di punggung/massif, padang berumput jauh lebih tahan (cuma cekungan landai).
        K = 6e-3 * (.08 + .92 * kasar)
        E = np.clip(K * np.sqrt(luas) * S * langkah, 0, .7) * (1 - lindung)
        H = H - E
        # Endapan: sebagian sedimen berpindah ke tetangga hilir (bobot MFD) dan mengendap di tempat landai.
        dep = np.zeros_like(H)
        for k, (dz, dx) in enumerate(ARAH):
            dep += geser(E * W[k], dz, dx)
        dep *= .5 * (S < .08)
        H = H + dep * (1 - lindung)
        endapan += dep
        H = termal(H, langkah, 40, lindung, 2)
        if it % 6 == 5:
            print(f"  erosi {it + 1}/{putaran}: akumulasi maks {A.max():.0f} sel, turun maks {(awal - H).max():.1f} m",
                  flush=True)
    A, _, _ = aliran_mfd(H, langkah)
    return H, np.log1p(A).astype(np.float32), endapan.astype(np.float32)


def naik(a, n):
    return np.asarray(Image.fromarray(a.astype(np.float32), "F").resize((n, n), Image.BICUBIC))


def simetris(L, A, langkah):
    """Sisi barat garis tengah sungai dipakai, sisi timur = putaran 180°-nya (sambungan jatuh di alur sungai)."""
    n = A.shape[0]
    X, Z = grid(n, langkah)
    t = Z - TENGAH
    sx = TENGAH + sum(a * s * np.sin(t / w) for a, w, s in L.sungai_suku)
    return np.where(X <= sx, A, A[::-1, ::-1])


def batasan(L, H, X, Z):
    """Pasang ulang batasan gameplay secara tepat di resolusi penuh."""
    H0 = L.tinggi_dasar(X, Z)
    # Sungai, arung, pulau: pakai bentuk dasar
    t = Z - TENGAH
    sx = TENGAH + sum(a * s * np.sin(t / w) for a, w, s in L.sungai_suku)
    sungai = 1 - _halus((np.abs(X - sx) - SUNGAI_SETENGAH - 4) / 14)
    H = H + (H0 - H) * sungai
    # Teras markas datar tepat t_teras, titik pertahanan datar pada rata-ratanya, tambang datar lokal
    for (px, pz) in L.markas:
        d = np.hypot(X - px, Z - pz)
        H = L.t_teras + (H - L.t_teras) * _halus((d - TERAS_R) / 60)
    for (px, pz) in L.bela:
        d = np.hypot(X - px, Z - pz)
        tgt = float(H[d < BELA_R + 20].mean())
        H = tgt + (H - tgt) * _halus((d - BELA_R) / 45)
    for (px, pz) in L.tambang:
        i, j = int(round(pz)), int(round(px))
        sl = (slice(max(0, i - 40), i + 41), slice(max(0, j - 40), j + 41))
        d = np.hypot(X[sl] - px, Z[sl] - pz)
        tgt = float(H[sl][d < 24].mean())
        H[sl] = tgt + (H[sl] - tgt) * _halus((d - 9) / 28)
    return H


def tersambung(H, L, langkah=2.0):
    """BFS di grid 2 m: lereng < MIRING_MAKS dan di atas air. Kembalikan daftar tujuan yang tak terjangkau."""
    h = H[::2, ::2]
    n = h.shape[0]
    gz, gx = np.gradient(h, langkah)
    boleh = (np.degrees(np.arctan(np.hypot(gx, gz))) < MIRING_MAKS) & (h > .2)
    mulai = (int(L.markas[0][1] / langkah), int(L.markas[0][0] / langkah))
    seen = np.zeros_like(boleh)
    q = deque([mulai])
    seen[mulai] = True
    bolehL = boleh
    while q:
        i, j = q.popleft()
        for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            a, b = i + di, j + dj
            if 0 <= a < n and 0 <= b < n and not seen[a, b] and bolehL[a, b]:
                seen[a, b] = True
                q.append((a, b))
    gagal = []
    for nama, daftar in (("markas", L.markas), ("tambang", L.tambang), ("titik pertahanan", L.bela)):
        for k, (x, z) in enumerate(daftar):
            i, j = int(z / langkah), int(x / langkah)
            w = seen[max(0, i - 4):i + 5, max(0, j - 4):j + 5]
            if not w.any():
                gagal.append(f"{nama} {k + 1} ({x:.0f}, {z:.0f})")
    return gagal, float(boleh.mean())


def pratinjau(H, L, path, W=1152):
    h = naik(H, W)
    s = UKURAN / W
    gz, gx = np.gradient(h, s)
    nx, nz, ny = -gx, -gz, np.ones_like(h)
    n = np.sqrt(nx * nx + ny * ny + nz * nz)
    lx, ly, lz = -.35, .75, -.55
    shade = np.clip((nx * lx + ny * ly + nz * lz) / (n * math.sqrt(lx * lx + ly * ly + lz * lz)), 0, 1)
    slope = np.degrees(np.arctan(np.hypot(gx, gz)))
    t_l = np.clip((L.t_teras - 1.5 - h) / (L.t_teras - L.t_lembah), 0, 1)[..., None]
    base = np.array([92, 120, 70]) * (1 - t_l) + np.array([118, 138, 86]) * t_l
    k = np.clip((slope - 14) / 8, 0, 1)[..., None]
    base = base * (1 - k) + np.array([150, 146, 120]) * k
    b = np.clip((slope - MIRING_MAKS) / 4, 0, 1)[..., None]
    base = base * (1 - b) + np.array([205, 200, 184]) * b
    base = np.where((h < 0)[..., None], np.array([60, 110, 130]), base)
    img = Image.fromarray(np.clip(base * (.5 + .65 * shade[..., None]), 0, 255).astype(np.uint8))
    from PIL import ImageDraw
    d = ImageDraw.Draw(img, "RGBA")
    for i, (x, z) in enumerate(L.markas):
        c = (60, 120, 220) if i < 4 else (220, 70, 60)
        d.ellipse((x / s - 10, z / s - 10, x / s + 10, z / s + 10), fill=c, outline=(255, 255, 255), width=2)
    warna = {"aman": (110, 200, 110), "rampok": (240, 160, 60), "rebutan": (230, 70, 60)}
    for x, z, zn in L.zona:
        d.ellipse((x / s - 4, z / s - 4, x / s + 4, z / s + 4), fill=warna[zn], outline=(20, 20, 16))
    img.save(path)


def tinggi():
    t0 = time.time()
    L = Layout(SEED_TERPILIH)
    assert L.periksa(), "layout gagal aturan"
    rng = np.random.default_rng(SEED_TERPILIH * 7919)
    WORK.mkdir(parents=True, exist_ok=True)
    print(f"erosi {NS}x{NS} (2 m/piksel)...", flush=True)
    Hs, aliran, endapan = erosi(L, rng)
    print(f"  {time.time() - t0:.0f} s", flush=True)
    X, Z = grid(N, 1.0)
    H = naik(Hs, N).astype(np.float64)
    kasar = naik(masker_kasar(L, Hs), N)
    lindung = masker_lindung(L, X, Z)
    H += fbm(N, 3, rng, 24) * (.06 + .45 * kasar) * (1 - lindung)
    H = simetris(L, H, 1.0)
    aliran = simetris(L, aliran, UKURAN / (NS - 1))
    endapan = simetris(L, endapan, UKURAN / (NS - 1))
    H = batasan(L, H, X, Z)
    # Muka air = 0: dasar lembah 1,5 m di atas air, alur sungai di bawahnya
    air = L.t_lembah - 1.5
    H -= air
    np.save(WORK / "tinggi.npy", H.astype(np.float32))
    np.save(WORK / "aliran.npy", aliran)
    np.save(WORK / "endapan.npy", endapan)
    # Pemeriksaan
    gz, gx = np.gradient(H, 1.0)
    miring = np.degrees(np.arctan(np.hypot(gx, gz)))
    teras = [float(np.ptp(H[int(z) - 50:int(z) + 51, int(x) - 50:int(x) + 51])) for x, z in L.markas]
    tambang = [float(np.ptp(H[int(z) - 6:int(z) + 7, int(x) - 6:int(x) + 7])) for x, z in L.tambang]
    gagal, lolos = tersambung(H, L)
    # Simetri: H(x,z) vs H(1536-x,1536-z)
    sim = float(np.abs(H - H[::-1, ::-1]).max())
    print(f"heightmap {N}x{N}: {H.min():.1f} .. {H.max():.1f} m (air 0), {time.time() - t0:.0f} s")
    print(f"  teras markas datar: selisih maks {max(teras):.3f} m")
    print(f"  tambang datar (13 m): selisih maks {max(tambang):.2f} m")
    print(f"  area bisa dilalui (< {MIRING_MAKS}°, di atas air): {100 * lolos:.1f}%; lereng > 35°: "
          f"{100 * (miring > 35).mean():.1f}%")
    print(f"  tersambung dari markas 1: {'semua' if not gagal else 'GAGAL ' + ', '.join(gagal)}")
    print(f"  simetri putar 180°: selisih maks {sim:.2f} m")
    pratinjau(H, L, ROOT / "maps/lembah-kapur-tinggi.png")
    print("  pratinjau maps/lembah-kapur-tinggi.png")


# --- Tahap 3: kompilasi dengan tekstur sementara (tekstur final di tahap 4) ---
import json
import shutil
import struct
import subprocess
from zipfile import ZIP_DEFLATED, ZipFile

LOCK = json.loads((ROOT / "dependencies.windows.json").read_text(encoding="utf8"))
PAKET = {p["nama"]: ROOT / ".deps" / p["folder"] for p in LOCK}
TEKS = 12288  # 512 piksel per SMU x 24 SMU


def rentang(H):
    return int(math.floor(H.min() * 8)) - 8, int(math.ceil(H.max() * 8)) + 8


def pohon(L, H):
    """Pohon (TreeType0-3 bawaan Recoil) di rumpun hutan: jarak ±5,5 m, tidak di lereng > 28° atau air."""
    rng = np.random.default_rng(SEED_TERPILIH * 31)
    gz, gx = np.gradient(H, 1.0)
    miring = np.degrees(np.arctan(np.hypot(gx, gz)))
    hasil = []
    for hx, hz, hr in L.hutan:
        zz, xx = np.mgrid[hz - hr:hz + hr:5.5, hx - hr:hx + hr:5.5]
        xx = xx.ravel() + rng.uniform(-1.8, 1.8, xx.size)
        zz = zz.ravel() + rng.uniform(-1.8, 1.8, zz.size)
        d = np.hypot(xx - hx, zz - hz) / hr
        ambil = (d < 1) & (rng.random(xx.size) > _halus((d - .55) / .45))
        for x, z in zip(xx[ambil], zz[ambil]):
            i, j = int(round(z)), int(round(x))
            if 2 <= i < N - 2 and 2 <= j < N - 2 and H[i, j] > .6 and miring[i, j] < 28:
                hasil.append((round(x * 8), round(z * 8), int(rng.integers(4)), int(rng.integers(-32760, 32760))))
    return hasil


def _jarak_garis(px, pz, garis):
    """Jarak titik-titik ke polyline (meter)."""
    d = np.full(px.shape, 1e9)
    for (ax, az), (bx, bz) in zip(garis[:-1], garis[1:]):
        vx, vz = bx - ax, bz - az
        t = np.clip(((px - ax) * vx + (pz - az) * vz) / max(vx * vx + vz * vz, 1e-9), 0, 1)
        d = np.minimum(d, np.hypot(px - ax - t * vx, pz - az - t * vz))
    return d


def batu(L, H):
    """Batu kapur acak (tahap 7, ✅ user 2026-11-26 "batunya acak").

    Lebih rapat di kaki tebing (talus) dan jarang di padang. Batu menjauhi rute, bukaan, arungan, tambang,
    teras pertahanan, markas, hutan, dan air (aturan-peta.md bagian 5). Sebaran dibuat di separuh barat lalu
    diputar 180° supaya simetris dengan kubu lawan.
    """
    rng = np.random.default_rng(SEED_TERPILIH * 57)
    gz, gx = np.gradient(H, 1.0)
    miring = np.degrees(np.arctan(np.hypot(gx, gz)))
    curam = np.asarray(Image.fromarray((miring > 34).astype(np.float32), "F").filter(ImageFilter.MaxFilter(25)))
    n = 60000
    px, pz = rng.uniform(4, UKURAN / 2, n), rng.uniform(4, UKURAN - 4, n)
    i, j = np.clip(np.round(pz).astype(int), 0, N - 1), np.clip(np.round(px).astype(int), 0, N - 1)
    m, h, tal = miring[i, j], H[i, j], curam[i, j] > 0
    # Peluang: talus 3,5%, padang 0,35% per titik kandidat
    ambil = rng.random(n) < np.where(tal & (m > 8) & (m < 33), .035, .0035)
    ambil &= (h > .8) & (m < 33)
    for garis in L.rute:
        ambil &= _jarak_garis(px, pz, garis) > 14
    for x, z in L.tambang:
        ambil &= np.hypot(px - x, pz - z) > 22
    for x, z in L.markas:
        ambil &= np.hypot(px - x, pz - z) > 100
    for x, z in L.bela:
        ambil &= np.hypot(px - x, pz - z) > 32
    for x, z in L.arung:
        ambil &= np.hypot(px - x, pz - z) > 34
    for b in L.bukaan_b:
        ambil &= ~((np.abs(pz - b["z"]) < b["lebar"] / 2 + 10) & (np.abs(px - b["x"]) < 80))
    for x, z, r in L.hutan:
        ambil &= np.hypot(px - x, pz - z) > r
    hasil = []
    pakai = []
    for x, z, t in zip(px[ambil], pz[ambil], tal[ambil]):
        if any((x - a) ** 2 + (z - b) ** 2 < 5.5 ** 2 for a, b in pakai):
            continue
        pakai.append((x, z))
        k = int(rng.choice(3, p=(.35, .2, .45) if t else (.25, .1, .65))) + 1
        r = int(rng.integers(-32760, 32760))
        for x2, z2, r2 in ((x, z, r), (UKURAN - x, UKURAN - z, r + 32768 if r < 0 else r - 32768)):
            hasil.append((round(x2 * 8), round(z2 * 8), k, r2))
    return hasil


def objek():
    """Tulis ulang pohon.lua (pohon + batu) tanpa menyentuh tekstur. Lanjutkan dengan kompilasi lalu paket."""
    L = Layout(SEED_TERPILIH)
    H = np.load(WORK / "tinggi.npy").astype(np.float64)
    p, b = pohon(L, H), batu(L, H)
    baris = [f"{{name='TreeType{k}', x={a}, z={c}, rot={r}, scale=1.0}}\n" for a, c, k, r in p]
    baris += [f"{{name='batu_kapur_{k}', x={a}, z={c}, rot={r}, scale=1.0}}\n" for a, c, k, r in b]
    (WORK / "pohon.lua").write_text("".join(baris), encoding="ascii")
    per = [sum(1 for t in b if t[2] == k) for k in (1, 2, 3)]
    print(f"objek: {len(p)} pohon, {len(b)} batu (besar {per[0]}, lempeng {per[1]}, kecil {per[2]})")


def tekstur_sementara(H, aliran, path):
    """Warna dasar sederhana dari lereng, tinggi, dan aliran (diganti tekstur final di tahap 4)."""
    gz, gx = np.gradient(H, 1.0)
    miring = np.degrees(np.arctan(np.hypot(gx, gz))).astype(np.float32)
    rng = np.random.default_rng(5)
    noise = [Image.fromarray(rng.random((n, n)).astype(np.float32), "F") for n in (48, 192, 768)]
    sumber = [Image.fromarray(a.astype(np.float32), "F") for a in (H.astype(np.float32), miring, aliran)]
    img = Image.new("RGB", (TEKS, TEKS))
    band = 512
    for row in range(0, TEKS, band):
        def ambil(im, filt=Image.BILINEAR):
            box = (0, row / TEKS * im.height, im.width, (row + band) / TEKS * im.height)
            return np.asarray(im.resize((TEKS, band), filt, box), dtype=np.float32)
        h, m, a = (ambil(im) for im in sumber)
        n1, n2, n3 = (ambil(im, Image.BICUBIC) - .5 for im in noise)
        rumput = np.array([62, 84, 44], np.float32) + (n1 * 30 + n2 * 22 + n3 * 14)[..., None]
        rumput[..., 0] += np.clip(h - 20, 0, 40) * .25
        tanah = np.array([104, 92, 70], np.float32) + (n2 * 20 + n3 * 14)[..., None]
        kerikil = np.array([132, 126, 110], np.float32) + (n2 * 18 + n3 * 18)[..., None]
        batu = np.array([176, 170, 152], np.float32) + (n1 * 18 + n2 * 16 + n3 * 20)[..., None]
        warna = rumput
        alur = _halus((a - 4.5 + n2 * 1.5) / 2.5)[..., None]
        warna = warna + (tanah - warna) * alur * .7
        k = _halus((m - 14 + n2 * 6) / 8)[..., None]
        warna = warna + (kerikil - warna) * k
        b = _halus((m - 27 + n2 * 5) / 6)[..., None]
        warna = warna + (batu - warna) * b
        tepi = _halus((1.2 - h) / 1.2)[..., None]
        warna = warna + (kerikil * .8 - warna) * tepi
        img.paste(Image.fromarray(np.clip(warna, 0, 255).astype(np.uint8)), (0, row))
    img.save(path)
    return img


MAPINFO = '''-- Dibuat tools/buat_lembah_kapur.py (seed @SEED@). Aturan: docs/aturan-peta.md.
return {
    name = "Limestone Valley 4v4",
    version = "1.0",
    description = "Four bases per side behind broken limestone ridges, a winding gravel river and a contested island.",
    author = "RTS PC",
    modtype = 3,
    depend = {"Map Helper v1"},
    mapfile = "maps/@STEM@.smf",
    notDeformable = false,
    gravity = 100,
    maxMetal = 1.0,
    extractorRadius = 56,
    teams = {
@TIM@
    },
    terrainTypes = {
        [0] = {name = "Meadow", receiveTracks = true, hardness = 1.0},
        [2] = {name = "Deep River", receiveTracks = false, moveSpeeds = {tank = 0, kbot = 0, hover = 0, ship = 1}},
    },
    grass = {bladeHeight = 3.0, bladeWidth = 0.28, bladeWaveScale = 0.8, bladeColor = {0.33, 0.41, 0.24}},
    lighting = {
        -- Matahari dari utara, elevasi ±38° (aturan-peta.md bagian 6). Tahap 6: matahari hangat, bayangan dan
        -- ambient sejuk kebiruan supaya kontras (arah visual natural dan dramatis).
        sunDir = {-0.32, 0.62, -0.71},
        groundAmbientColor = {0.29, 0.33, 0.41},
        groundDiffuseColor = {1.00, 0.92, 0.77},
        groundSpecularColor = {0.10, 0.09, 0.08},
        groundShadowDensity = 0.90,
        unitAmbientColor = {0.33, 0.37, 0.45},
        unitDiffuseColor = {1.00, 0.94, 0.82},
        unitSpecularColor = {0.55, 0.53, 0.50},
        unitShadowDensity = 0.88,
    },
    atmosphere = {
        -- Skybox buatan sendiri (tools/buat_langit.py). Warna kabut = kabut cakrawala skybox.
        skyBox = "langit.dds",
        fogStart = 0.30, fogEnd = 1.0, fogColor = {0.69, 0.75, 0.80},
        skyColor = {0.45, 0.58, 0.76}, sunColor = {1.0, 0.92, 0.78}, minWind = 5, maxWind = 12,
        cloudDensity = 0.0,
    },
    water = {
        -- Sungai pegunungan: hijau toska jernih. Penyerapan rendah supaya dasar kerikil di dangkalan terlihat.
        surfaceColor = {0.50, 0.66, 0.62}, surfaceAlpha = 0.32,
        -- Tanpa bidang air tak hingga: di luar tepi peta yang terlihat adalah kabut bawah skybox.
        hasWaterPlane = false,
        baseColor = {0.40, 0.49, 0.43}, minColor = {0.09, 0.17, 0.17},
        absorb = {0.0105, 0.0068, 0.0058},
        diffuseColor = {0.85, 0.92, 0.88}, diffuseFactor = 1.0,
        specularColor = {1.0, 0.95, 0.85}, specularPower = 48, specularFactor = 0.55,
        fresnelMin = 0.12, fresnelMax = 0.55, fresnelPower = 4.0,
        reflectionDistortion = 0.7, blurBase = 2.0, blurExponent = 1.5,
        perlinStartFreq = 10.0, perlinLacunarity = 2.6, perlinAmplitude = 0.55,
        shoreWaves = false,
    },
    smf = {minheight = @RENDAH@, maxheight = @TINGGI@},
    resources = {
        -- Tahap 4: normal detail ruang tangen (A = kekuatan) dan specular (A x 16 = eksponen)
        detailNormalTex = "normal_detail.dds",
        specularTex = "spekular.dds",
        -- Tahap 5: DNTS (R rumput, G tanah, B kerikil, A batu); A ubin = detail terang-gelap
        splatDistrTex = "splat_campur.tga",
        splatDetailNormalTex1 = "dnts_rumput.tga",
        splatDetailNormalTex2 = "dnts_tanah.tga",
        splatDetailNormalTex3 = "dnts_kerikil.tga",
        splatDetailNormalTex4 = "dnts_batu.tga",
        splatDetailNormalDiffuseAlpha = true,
    },
    splats = {
        texScales = {@SKALA@},
        texMults = {1.0, 1.0, 1.0, 1.0},
    },
}
'''

SKENARIO = '''-- Limestone Valley 4v4 (dibuat tools/buat_lembah_kapur.py, seed @SEED@). Deathmatch dulu (keputusan user
-- 2026-11-26); titik A-C (dua arung + pulau) disiapkan untuk mode Control Points.
local skenario = {
    startScript = "gamedata/skenario/kapur-start.txt",
    radius = 88, detikRebut = 4, poinPerDetik = 1, targetSkor = 2400,
    titik = {
@TITIK@
    },
    ladang = {@LADANG@},
    awal = {
@AWAL@
    },
}
return skenario
'''


def tulis_mapinfo(L, rendah, tinggi_):
    tim = "\n".join(f"        [{i}] = {{startPos = {{x = {round(x * 8)}, z = {round(z * 8)}}}}},"
                    for i, (x, z) in enumerate(L.markas))
    teks = (MAPINFO.replace("@SEED@", str(L.seed)).replace("@STEM@", STEM).replace("@TIM@", tim)
            .replace("@RENDAH@", str(rendah)).replace("@TINGGI@", str(tinggi_))
            .replace("@SKALA@", ", ".join(f"{1 / (m * 8):.4f}" for m in DNTS_UBIN_M)))
    (ROOT / f"maps/mapinfo-{STEM}.lua").write_text(teks, encoding="utf-8")


def tulis_skenario(L):
    awal = []
    for i, (x, z) in enumerate(L.markas):
        barat = i < 4
        s = 1 if barat else -1
        awal.append(f"        {{pos = {{{round(x * 8)}, {round(z * 8)}}}, hadap = {1 if barat else 3}, "
                    f"insinyur = {{{116 * s}, {65 * s}}}, kamera = {{{65 * s}, {30 * s}}}, tank = {{{170 * s}, {-86 * s}}}}},")
    ladang = ", ".join(f"{{{round(x * 8)}, {round(z * 8)}}}" for x, z in L.tambang)
    a0, a1 = L.arung[0][0], L.arung[2][0]
    titik = "\n".join([
        f'        {{nama = "A", x = {round(L.sungai_x(a0) * 8)}, z = {round(a0 * 8)}}},',
        f'        {{nama = "B", x = {round(TENGAH * 8)}, z = {round(TENGAH * 8)}}},',
        f'        {{nama = "C", x = {round(L.sungai_x(UKURAN - a0) * 8)}, z = {round((UKURAN - a0) * 8)}}},'])
    teks = (SKENARIO.replace("@SEED@", str(L.seed)).replace("@TITIK@", titik).replace("@LADANG@", ladang)
            .replace("@AWAL@", "\n".join(awal)))
    (ROOT / "game/RTSPC.sdd/gamedata/skenario/kapur.lua").write_text(teks, encoding="utf-8")
    start = (ROOT / "game/RTSPC.sdd/gamedata/skenario/hijau-start.txt").read_text(encoding="utf-8")
    start = start.replace("Verdant Ridge 4v4 1.0", "Limestone Valley 4v4 1.0").replace("skenario=hijau", "skenario=kapur")
    (ROOT / "game/RTSPC.sdd/gamedata/skenario/kapur-start.txt").write_text(start, encoding="utf-8")


def siapkan():
    t0 = time.time()
    L = Layout(SEED_TERPILIH)
    H = np.load(WORK / "tinggi.npy").astype(np.float64)
    aliran = np.load(WORK / "aliran.npy")
    rendah, tinggi_ = rentang(H)
    raw = np.rint((H * 8 - rendah) * 65535 / (tinggi_ - rendah)).astype("<u2")
    raw.tofile(WORK / "tinggi.raw")
    h2 = H[1::2, 1::2][:768, :768]
    Image.fromarray(np.where(h2 < -.3, 2, 0).astype(np.uint8)).convert("RGB").save(WORK / "tipe.bmp")
    besi = np.zeros((768, 768), np.uint8)
    zz, xx = np.mgrid[0:768, 0:768] * 2 + 1
    for x, z in L.tambang:
        besi[np.hypot(xx - x, zz - z) < 4] = 240
    Image.fromarray(besi).convert("RGB").save(WORK / "besi.bmp")
    g2 = H[2::4, 2::4][:384, :384]
    gz, gx = np.gradient(g2, 4.0)
    # Rumput engine dimatikan (user 2026-11-26: "bisa di hapus rumputnya ngga?"): grass map kosong, detail tanah
    # ditanggung tekstur warna + normal detail.
    rumput = np.zeros(g2.shape, np.uint8)
    Image.fromarray(rumput).convert("RGB").save(WORK / "rumput.bmp")
    pohon_ = pohon(L, H)
    (WORK / "pohon.lua").write_text("".join(
        f"{{name='TreeType{k}', x={a}, z={b}, rot={r}, scale=1.0}}\n" for a, b, k, r in pohon_), encoding="ascii")
    img = tekstur_sementara(H, naik(aliran, N), WORK / "warna.bmp")
    img.resize((1024, 1024), Image.LANCZOS).save(WORK / "minimap.bmp")
    tulis_mapinfo(L, rendah, tinggi_)
    tulis_skenario(L)
    print(f"siapkan: {len(pohon_)} pohon, tinggi {rendah}..{tinggi_} elmo, {time.time() - t0:.0f} s")


def kompilasi():
    t0 = time.time()
    compiler = PAKET["PyMapConv"]
    (WORK / "resources").mkdir(exist_ok=True)
    for sumber in ("nvdxt.exe", "resources/geovent.bmp"):
        shutil.copy2(compiler / sumber, WORK / sumber)
    H = np.load(WORK / "tinggi.npy")
    rendah, tinggi_ = rentang(H)
    smf, smt = [WORK / f"{STEM}.{e}" for e in ("smf", "smt")]
    for p in (smf, smt):
        p.unlink(missing_ok=True)
    # pymapconv memanggil nvdxt.exe lewat cmd; pastikan folder kerja ada di PATH (cmd tidak selalu mencari di cwd).
    import os
    env = dict(os.environ)
    env.pop("NoDefaultCurrentDirectoryInExePath", None)
    env["PATH"] = str(WORK) + os.pathsep + env.get("PATH", "")
    with (WORK / "kompilasi.log").open("wb") as log:
        subprocess.run([compiler / "pymapconv.exe", "-t", "warna.bmp", "-a", "tinggi.raw", "-y", "tipe.bmp", "-m",
                        "besi.bmp", "-k", "pohon.lua", "-r", "rumput.bmp", "-p", "minimap.bmp", "-o", smf.name,
                        "-n", str(rendah), "-x", str(tinggi_), "-q", "1"],
                       cwd=WORK, stdout=log, stderr=subprocess.STDOUT, timeout=3600, env=env,
                       creationflags=subprocess.CREATE_NO_WINDOW)
    assert "All Done!" in (WORK / "kompilasi.log").read_text(errors="replace"), "kompilasi gagal, lihat kompilasi.log"
    with smf.open("rb") as f:
        magic, versi, _, sx, sz = struct.unpack("<16siiii", f.read(32))
    assert (magic.rstrip(b"\0"), versi, sx, sz) == (b"spring map file", 1, TEKS // 8, TEKS // 8), (magic, sx, sz)
    out = WORK / f"{STEM}.sdz"
    with ZipFile(out, "w", ZIP_DEFLATED) as z:
        z.write(ROOT / f"maps/mapinfo-{STEM}.lua", "mapinfo.lua")
        for p in (smf, smt):
            z.write(p, "maps/" + p.name)
        for nama in ("normal_detail.dds", "spekular.dds"):
            if (WORK / nama).exists():
                z.write(WORK / nama, "maps/" + nama)
    out.replace(ROOT / "maps" / out.name)
    print(f"kompilasi: maps/{STEM}.sdz {(ROOT / 'maps' / out.name).stat().st_size / 1e6:.0f} MB, "
          f"{time.time() - t0:.0f} s")


# --- Tahap 4: tekstur warna final, normal map detail, specular (tools/tekstur_lembah_kapur.py) ---
def dds(png, keluar, format_):
    """PNG -> DDS dengan nvdxt (mipmap penuh)."""
    import os
    env = dict(os.environ)
    env.pop("NoDefaultCurrentDirectoryInExePath", None)
    shutil.copy2(PAKET["PyMapConv"] / "nvdxt.exe", WORK / "nvdxt.exe")
    subprocess.run([str(WORK / "nvdxt.exe"), "-file", png.name, format_, "-output", keluar.name, "-quality_production"],
                   cwd=WORK, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT, timeout=3600,
                   creationflags=subprocess.CREATE_NO_WINDOW)
    assert keluar.exists(), f"nvdxt gagal untuk {png.name}"


def tekstur():
    import tekstur_lembah_kapur as T
    t0 = time.time()
    L = Layout(SEED_TERPILIH)
    H = np.load(WORK / "tinggi.npy").astype(np.float64)
    aliran = naik(np.load(WORK / "aliran.npy"), N)
    endapan = naik(np.load(WORK / "endapan.npy"), N)
    T.buat_semua(H, aliran, endapan, L, UKURAN, WORK / "warna.bmp", WORK / "normal_detail.png", WORK / "spekular.png",
                 cetak=lambda t: print(t, flush=True))
    Image.open(WORK / "warna.bmp").resize((1024, 1024), Image.LANCZOS).save(WORK / "minimap.bmp")
    Image.open(WORK / "minimap.bmp").convert("RGB").save(ROOT / "menu/RTSPCMenu.sdd/LuaMenu/kapur.jpg", quality=94)
    # nvdxt (32-bit) crash pada 8192^2; pakai encoder BC3 sendiri (tools/dds_bc3.py)
    from dds_bc3 import simpan_bc3
    for nama in ("normal_detail", "spekular"):
        simpan_bc3(np.asarray(Image.open(WORK / f"{nama}.png")), WORK / f"{nama}.dds")
    print(f"tekstur: {time.time() - t0:.0f} s")


# --- Tahap 5: DNTS (tools/buat_dnts.py untuk 4 ubin; peta campuran dari data medan) ---
DNTS = ("rumput", "tanah", "kerikil", "batu")
# Ukuran ubin di dunia (m): makin kecil makin rapat. texScales = 1 / (meter x 8 elmo).
DNTS_UBIN_M = (6.0, 10.0, 5.0, 16.0)
DNTS_TOTAL = .7  # jumlah bobot; < 1 supaya normal detail 8K tahap 4 tetap ikut terlihat


def dnts():
    import buat_dnts
    t0 = time.time()
    buat_dnts.buat()
    H = np.load(WORK / "tinggi.npy").astype(np.float32)
    aliran = naik(np.load(WORK / "aliran.npy"), N)
    endapan = naik(np.log1p(np.maximum(np.load(WORK / "endapan.npy"), 0) * 4), N)
    n2 = 2048

    def kecil(a):
        return np.asarray(Image.fromarray(np.asarray(a, np.float32), "F").resize((n2, n2), Image.BILINEAR))
    h = kecil(H)
    gz, gx = np.gradient(H, 1.0)
    m = kecil(np.degrees(np.arctan(np.hypot(gx, gz))))
    a = kecil(aliran)
    e = kecil(endapan)
    batu = _halus((m - 24) / 6)
    # Batas sama dengan tekstur warna (rumput polos, tanah hanya di lereng > ±19°, alur utama saja)
    kerikil = np.maximum(_halus((a - 6.2) / 1.2), _halus((1.6 - h) / 1.2)) * (1 - batu)
    tanah = np.maximum(_halus((m - 19) / 6), _halus((e - 1.3) / .8) * .3) * (1 - batu) * (1 - kerikil)
    rumput = np.clip(1 - batu - kerikil - tanah, 0, 1)
    w = np.stack([rumput, tanah, kerikil, batu], -1)
    w = w / np.maximum(w.sum(-1, keepdims=True), 1e-6) * DNTS_TOTAL
    Image.fromarray((w * 255 + .5).astype(np.uint8), "RGBA").save(WORK / "splat_campur.tga")
    for nama in DNTS:
        shutil.copy2(ROOT / ".cache/dnts" / f"{nama}.tga", WORK / f"dnts_{nama}.tga")
    print(f"dnts: campuran {n2}x{n2} (rumput {100 * (rumput > .5).mean():.0f}%, tanah {100 * (tanah > .5).mean():.0f}%, "
          f"kerikil {100 * (kerikil > .5).mean():.0f}%, batu {100 * (batu > .5).mean():.0f}%), {time.time() - t0:.0f} s")


# --- Tahap 6: langit (tools/buat_langit.py); cahaya, kabut, dan air ada di MAPINFO ---
def langit():
    from buat_langit import buat_langit
    t0 = time.time()
    buat_langit(WORK / "langit.dds", (-0.32, 0.62, -0.71), seed=SEED_TERPILIH, pratinjau=WORK / "langit.png")
    print(f"langit: {WORK / 'langit.dds'} {(WORK / 'langit.dds').stat().st_size / 1e6:.1f} MB, {time.time() - t0:.0f} s")


def paket():
    """Tulis ulang mapinfo lalu bungkus ulang .sdz dari .smf/.smt/.dds yang sudah ada (tanpa kompilasi ulang)."""
    L = Layout(SEED_TERPILIH)
    rendah, tinggi_ = rentang(np.load(WORK / "tinggi.npy"))
    tulis_mapinfo(L, rendah, tinggi_)
    out = WORK / f"{STEM}.sdz"
    with ZipFile(out, "w", ZIP_DEFLATED) as z:
        z.write(ROOT / f"maps/mapinfo-{STEM}.lua", "mapinfo.lua")
        for nama in (f"{STEM}.smf", f"{STEM}.smt", "normal_detail.dds", "spekular.dds", "splat_campur.tga",
                     *(f"dnts_{d}.tga" for d in DNTS), "langit.dds"):
            if (WORK / nama).exists():
                z.write(WORK / nama, "maps/" + nama)
    out.replace(ROOT / "maps" / out.name)
    print(f"paket: maps/{STEM}.sdz {(ROOT / 'maps' / out.name).stat().st_size / 1e6:.0f} MB")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("tahap", choices=["tinggi", "siapkan", "tekstur", "dnts", "langit", "objek", "kompilasi",
                                          "paket"])
    a = ap.parse_args()
    {"tinggi": tinggi, "siapkan": siapkan, "tekstur": tekstur, "dnts": dnts, "langit": langit, "objek": objek,
     "kompilasi": kompilasi, "paket": paket}[a.tahap]()

