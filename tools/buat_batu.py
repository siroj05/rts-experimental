"""Model batu kapur untuk objek peta (tahap 7, docs/aturan-peta.md bagian 5).

Keputusan user 2026-11-26: "pohon dan batu pakai punya recoil". Konten Recoil tidak menyertakan batu, jadi user
meminta batu acak ("batunya acak"). Model dibuat sendiri:
- dasarnya ikosfer dipahat oleh bidang-bidang acak, supaya bersegi seperti bongkah kapur;
- diberi noise kecil dan lapisan mendatar;
- shading datar per segi (verteks dipisah per segitiga).

Tiga varian, masing-masing 1.280 segitiga, masuk anggaran 600-6.000:
- batu-kapur-1: bongkah ±2,4 m;
- batu-kapur-2: lempeng lebar ±4 m, tinggi ±1,3 m;
- batu-kapur-3: batu kecil ±1,3 m.

Tekstur bersama: batu-kapur-tex1.png (warna kapur krem keabuan, retak, bercak lumut/lichen) dan
batu-kapur-tex2.png (kilap kecil). Satuan: 8 elmo per meter. Pivot ada di dasar, dan bagian bawah sedikit
terbenam supaya tidak melayang di lereng.

    python tools/buat_batu.py   -> game/RTSPC.sdd/objects3d/batu-kapur-{1,2,3}.glb (+ .glb.lua),
                                   unittextures/batu-kapur-tex{1,2}.png, .cache/batu.png (pratinjau)
"""
import json
import struct
from pathlib import Path

import numpy as np
from PIL import Image

import buat_dnts as D

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "game/RTSPC.sdd"
ELMO = 8
VARIAN = {  # nama: (seed, skala x, y, z dalam meter, jumlah bidang pahat)
    "batu-kapur-1": (11, (1.25, 1.05, 1.1), 9),
    "batu-kapur-2": (12, (2.1, .7, 1.5), 8),
    "batu-kapur-3": (13, (.7, .55, .65), 8),
}


def ikosfer(sub):
    t = (1 + 5 ** .5) / 2
    v = [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t), (0, -1, -t), (0, 1, -t),
         (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]
    f = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6),
         (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10),
         (8, 6, 7), (9, 8, 1)]
    v = [np.array(p, float) / np.linalg.norm(p) for p in v]
    for _ in range(sub):
        tengah, f2 = {}, []

        def mid(a, b):
            k = (min(a, b), max(a, b))
            if k not in tengah:
                p = v[a] + v[b]
                v.append(p / np.linalg.norm(p))
                tengah[k] = len(v) - 1
            return tengah[k]
        for a, b, c in f:
            ab, bc, ca = mid(a, b), mid(b, c), mid(c, a)
            f2 += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)]
        f = f2
    return np.array(v), np.array(f)


def bentuk(seed, skala, pahat):
    rng = np.random.default_rng(seed)
    v, f = ikosfer(3)
    # Noise halus: jumlah gelombang sinus 3D acak
    n = np.zeros(len(v))
    for _ in range(6):
        k = rng.normal(size=3) * rng.uniform(1.5, 4)
        n += np.sin(v @ k + rng.uniform(0, 6.3)) * .045
    v = v * (1 + n)[:, None]
    # Pahat: bidang acak memotong bagian luar sehingga muncul segi datar
    for _ in range(pahat):
        nrm = rng.normal(size=3)
        nrm[1] *= .6
        nrm /= np.linalg.norm(nrm)
        d = rng.uniform(.62, .86)
        lebih = v @ nrm - d
        v = v - np.maximum(lebih, 0)[:, None] * nrm
    # Lapisan kapur mendatar: undakan halus pada jari-jari horizontal
    lapis = np.sin(v[:, 1] * 11 + rng.uniform(0, 6.3)) * .025
    v[:, [0, 2]] *= (1 + lapis)[:, None]
    # Atas sedikit rata, dasar dipotong rata
    v[:, 1] = np.where(v[:, 1] > .55, .55 + (v[:, 1] - .55) * .45, v[:, 1])
    v[:, 1] = np.maximum(v[:, 1], -.55)
    v = v * np.array(skala)
    v[:, 1] -= v[:, 1].min() + .18 * (v[:, 1].max() - v[:, 1].min()) * .5  # ±9% tinggi terbenam
    return v, f


def ke_glb(v, f, nama):
    # Verteks dipisah per segitiga supaya shading datar per segi
    p = v[f].reshape(-1, 3)
    a, b, c = v[f[:, 0]], v[f[:, 1]], v[f[:, 2]]
    nf = np.cross(b - a, c - a)
    nf /= np.linalg.norm(nf, axis=1, keepdims=True) + 1e-9
    nrm = np.repeat(nf, 3, axis=0)
    # UV proyeksi kotak per segi: sumbu dominan normal dibuang (1 ulangan tekstur per 2 m)
    sumbu = np.abs(nf).argmax(1).repeat(3)
    uv = np.where(sumbu[:, None] == 0, p[:, [2, 1]], np.where(sumbu[:, None] == 1, p[:, [0, 2]], p[:, [0, 1]])) / 2
    # Konversi sumbu seperti tools/impor_markas.py (vec_z_up) lalu ke elmo
    pos = (p[:, (0, 2, 1)] * np.array([1, -1, 1]) * ELMO).astype("<f4")
    nrm = (nrm[:, (0, 2, 1)] * np.array([1, -1, 1])).astype("<f4")
    uv = uv.astype("<f4")
    idx = np.arange(len(p), dtype="<u4")
    raw, views, acc = b"", [], []

    def tambah(arr, tipe, komp, minmax=False):
        nonlocal raw
        data = arr.tobytes()
        views.append({"buffer": 0, "byteOffset": len(raw), "byteLength": len(data)})
        a = {"bufferView": len(views) - 1, "componentType": komp, "count": len(arr), "type": tipe}
        if minmax:
            a["min"], a["max"] = arr.min(0).tolist(), arr.max(0).tolist()
        acc.append(a)
        raw += data + b"\0" * (-len(data) % 4)
        return len(acc) - 1
    prim = {"attributes": {"POSITION": tambah(pos, "VEC3", 5126, True), "NORMAL": tambah(nrm, "VEC3", 5126),
                           "TEXCOORD_0": tambah(uv, "VEC2", 5126)}, "indices": tambah(idx, "SCALAR", 5125)}
    header = {"asset": {"version": "2.0"}, "scene": 0, "scenes": [{"nodes": [0]}],
              "nodes": [{"name": nama, "mesh": 0}], "meshes": [{"primitives": [prim]}],
              "accessors": acc, "bufferViews": views, "buffers": [{"byteLength": len(raw)}]}
    js = json.dumps(header, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    out = GAME / "objects3d" / f"{nama}.glb"
    out.write_bytes(struct.pack("<4s3I4s", b"glTF", 2, 28 + len(raw) + len(js), len(js), b"JSON") + js
                    + struct.pack("<I4s", len(raw), b"BIN\0") + raw)
    out.with_suffix(".glb.lua").write_text(
        'return {tex1 = "batu-kapur-tex1.png", tex2 = "batu-kapur-tex2.png", '
        'fliptextures = true, invertteamcolor = false, s3ocompat = true}\n', encoding="utf-8")
    return len(f)


def tekstur():
    rng = np.random.default_rng(5)
    besar = D.spektral(rng, 1.8, 1, 16)
    sedang = D.spektral(rng, 1.2, 4, 90)
    halus = D.spektral(rng, .5, 40, 300)
    f1, f2, _ = D.voronoi(rng, 7)
    retak = np.clip(1 - (f2 - f1) * 10, 0, 1) * np.clip(D.spektral(rng, 1.5, 2, 30) - .3, 0, 1)
    lumut = np.clip((D.spektral(rng, 1.6, 2, 60) - .9) * 1.5, 0, 1)
    lichen = (D.spektral(rng, .8, 30, 200) > 2.0).astype(float)
    kapur = np.array([150, 144, 128], float)
    c = kapur * (1 + besar[..., None] * .06 + sedang[..., None] * .05 + halus[..., None] * .04)
    c = c * (1 - retak[..., None] * .3)
    c = c + (np.array([84, 96, 58]) - c) * (lumut * .7)[..., None]
    c = c + (np.array([196, 188, 150]) - c) * (lichen * .5)[..., None]
    # Resize RGB dulu: Pillow mengalikan warna dengan alpha saat resize RGBA, dan alpha warna tim di sini 0
    rgb = np.asarray(Image.fromarray(np.clip(c, 0, 255).astype(np.uint8)).resize((512, 512), Image.LANCZOS))
    Image.fromarray(np.dstack([rgb, np.zeros((512, 512), np.uint8)]), "RGBA").save(GAME / "unittextures/batu-kapur-tex1.png")
    t1 = rgb
    t2 = np.zeros((512, 512, 4), np.uint8)
    t2[..., 1], t2[..., 3] = 10, 255
    Image.fromarray(t2, "RGBA").save(GAME / "unittextures/batu-kapur-tex2.png")
    return t1


def buat():
    warna = tekstur()
    lembar = []
    for nama, (seed, skala, pahat) in VARIAN.items():
        v, f = bentuk(seed, skala, pahat)
        tri = ke_glb(v, f, nama)
        ukuran = v.max(0) - v.min(0)
        print(f"{nama}: {tri} segitiga, {ukuran[0]:.1f} x {ukuran[2]:.1f} m, tinggi {ukuran[1]:.1f} m")
        lembar.append(pratinjau(v, f, warna))
    Image.fromarray(np.hstack(lembar)).save(ROOT / ".cache/batu.png")


def pratinjau(v, f, warna, uk=320):
    """Render sederhana dari samping-atas, painter's algorithm, cahaya dari barat laut."""
    from PIL import ImageDraw
    im = Image.new("RGB", (uk, uk), (62, 90, 42))
    d = ImageDraw.Draw(im)
    rot = np.radians(35)
    m = np.array([[1, 0, 0], [0, np.cos(rot), -np.sin(rot)], [0, np.sin(rot), np.cos(rot)]])
    p = v @ m.T
    s = uk * .4 / np.abs(p[:, [0, 1]]).max()
    a, b, c = v[f[:, 0]], v[f[:, 1]], v[f[:, 2]]
    nf = np.cross(b - a, c - a)
    nf /= np.linalg.norm(nf, axis=1, keepdims=True) + 1e-9
    lampu = np.array([-.5, .7, -.5]) / np.linalg.norm([-.5, .7, -.5])
    terang = np.clip(nf @ lampu, 0, 1) * .75 + .3
    dasar = warna.reshape(-1, 3).mean(0)
    for i in np.argsort(p[f].mean(1)[:, 2]):
        tri = [(uk / 2 + p[k, 0] * s, uk * .7 - p[k, 1] * s) for k in f[i]]
        d.polygon(tri, fill=tuple(int(min(255, x)) for x in dasar * terang[i]))
    return np.asarray(im)


if __name__ == "__main__":
    buat()
