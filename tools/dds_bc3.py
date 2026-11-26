"""Encoder DDS BC3 (DXT5) sederhana dengan numpy, lengkap dengan mipmap.

Dipakai karena nvdxt.exe (32-bit) crash kehabisan memori pada tekstur 8192 x 8192 (2026-11-26).
Warna: endpoint = min/maks per kanal di blok 4x4 (bounding box), indeks = proyeksi ke garis endpoint (4 tingkat).
Alpha: endpoint min/maks, 8 tingkat interpolasi. Kualitas cukup untuk normal detail dan specular.

    from dds_bc3 import simpan_bc3
    simpan_bc3(array_rgba_uint8, "keluar.dds")
"""
import struct

import numpy as np
from PIL import Image


def _565(c):
    c = c.astype(np.uint32)
    return ((c[..., 0] >> 3) << 11) | ((c[..., 1] >> 2) << 5) | (c[..., 2] >> 3)


def _dari565(v):
    r = ((v >> 11) & 31).astype(np.float32) * (255 / 31)
    g = ((v >> 5) & 63).astype(np.float32) * (255 / 63)
    b = (v & 31).astype(np.float32) * (255 / 31)
    return np.stack([r, g, b], -1)


def _blok(a):
    """(H, W, 4) -> (H/4, W/4, 16, 4)"""
    h, w, _ = a.shape
    return a.reshape(h // 4, 4, w // 4, 4, 4).transpose(0, 2, 1, 3, 4).reshape(h // 4, w // 4, 16, 4)


def _kode_bc3(rgba):
    b = _blok(rgba.astype(np.float32))
    nb0, nb1 = b.shape[:2]
    # --- alpha ---
    al = b[..., 3]
    a0 = al.max(-1)
    a1 = al.min(-1)
    rentang = np.maximum(a0 - a1, 1e-6)
    t = (a0[..., None] - al) / rentang[..., None] * 7  # 0 = a0, 7 = a1
    k = np.clip(np.rint(t), 0, 7).astype(np.uint64)
    # urutan palet BC3 (a0 > a1): indeks 0 = a0, 1 = a1, 2..7 = interpolasi a0 -> a1
    peta = np.array([0, 2, 3, 4, 5, 6, 7, 1], np.uint64)
    idx = peta[k]
    sama = (a0 - a1) < .5
    idx[sama] = 0
    bit_a = np.zeros((nb0, nb1), np.uint64)
    for i in range(16):
        bit_a |= idx[..., i] << np.uint64(3 * i)
    a0b = np.rint(a0).astype(np.uint64)
    a1b = np.rint(a1).astype(np.uint64)
    alfa = a0b | (a1b << np.uint64(8)) | (bit_a << np.uint64(16))
    # --- warna ---
    rgb = b[..., :3]
    cmaks = rgb.max(-2)
    cmin = rgb.min(-2)
    c0 = _565(np.clip(cmaks, 0, 255))
    c1 = _565(np.clip(cmin, 0, 255))
    tukar = c0 < c1
    c0, c1 = np.where(tukar, c1, c0), np.where(tukar, c0, c1)
    p0 = _dari565(c0)
    p1 = _dari565(c1)
    arah = p1 - p0
    pj = np.maximum((arah * arah).sum(-1), 1e-6)
    s = ((rgb - p0[..., None, :]) * arah[..., None, :]).sum(-1) / pj[..., None]
    q = np.clip(np.rint(s * 3), 0, 3).astype(np.uint32)  # 0 = c0, 3 = c1
    peta_c = np.array([0, 2, 3, 1], np.uint32)  # 0 = c0, 1 = c1, 2 = 2/3 c0, 3 = 1/3 c0
    ic = peta_c[q]
    ic[c0 == c1] = 0
    bit_c = np.zeros((nb0, nb1), np.uint32)
    for i in range(16):
        bit_c |= ic[..., i] << np.uint32(2 * i)
    warna = c0.astype(np.uint64) | (c1.astype(np.uint64) << np.uint64(16)) | (bit_c.astype(np.uint64) << np.uint64(32))
    out = np.empty((nb0, nb1, 2), np.uint64)
    out[..., 0] = alfa
    out[..., 1] = warna
    return out.astype("<u8").tobytes()


def simpan_bc3(rgba, path, pita=1024):
    rgba = np.asarray(rgba, np.uint8)
    h, w = rgba.shape[:2]
    assert h % 4 == 0 and w % 4 == 0
    level = []
    im = Image.fromarray(rgba, "RGBA")
    lw, lh = w, h
    while True:
        a = np.asarray(im) if (lw, lh) == (w, h) else np.asarray(im.resize((lw, lh), Image.BOX))
        if lw % 4 or lh % 4:
            pad = np.zeros(((lh + 3) // 4 * 4, (lw + 3) // 4 * 4, 4), np.uint8)
            pad[:lh, :lw] = a
            pad[lh:, :] = pad[lh - 1:lh, :]
            pad[:, lw:] = pad[:, lw - 1:lw]
            a = pad
        level.append(a)
        if lw == 1 and lh == 1:
            break
        lw, lh = max(1, lw // 2), max(1, lh // 2)
    with open(path, "wb") as f:
        DDSD_CAPS, DDSD_HEIGHT, DDSD_WIDTH, DDSD_PIXELFORMAT, DDSD_MIPMAPCOUNT, DDSD_LINEARSIZE = (
            0x1, 0x2, 0x4, 0x1000, 0x20000, 0x80000)
        flags = DDSD_CAPS | DDSD_HEIGHT | DDSD_WIDTH | DDSD_PIXELFORMAT | DDSD_MIPMAPCOUNT | DDSD_LINEARSIZE
        linear = (w // 4) * (h // 4) * 16
        pf = struct.pack("<II4sIIIII", 32, 0x4, b"DXT5", 0, 0, 0, 0, 0)
        caps = struct.pack("<IIII", 0x1000 | 0x400000 | 0x8, 0, 0, 0)
        header = struct.pack("<4sIIIIIII", b"DDS ", 124, flags, h, w, linear, 0, len(level)) + b"\0" * 44 + pf + caps + b"\0" * 4
        f.write(header)
        for a in level:
            for r in range(0, a.shape[0], pita):
                f.write(_kode_bc3(a[r:r + pita]))
