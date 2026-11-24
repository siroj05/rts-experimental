"""Grading warna albedo medan bersama untuk semua generator peta (tahap 5).

🟡 Usulan Claude 2026-11-24, arah "natural dan dramatis": hijau yang terlalu jenuh dan terang (rumput kartun)
digeser ke hijau zaitun tua yang lebih kalem, batu/tanah dibiarkan, dan kontras tengah sedikit dinaikkan supaya
bentuk medan terbaca di bawah cahaya baru (tools/poles_peta.py). Warna lain tidak disentuh.

Pemakaian di generator: `from grading_medan import grade` lalu `image = grade(image)` sebelum disimpan ke warna.bmp
(dan minimap, karena Recoil memakai minimap untuk mewarnai rumput). Uji cepat:
    python tools/grading_medan.py <masuk.png> <keluar.png>   (menulis keluar + perbandingan sebelum/sesudah)
"""
import sys

import numpy as np
from PIL import Image

KEKUATAN = 1.0


def grade(image, kekuatan=KEKUATAN):
    rgb = np.asarray(image.convert("RGB"), dtype=np.float32) / 255
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    luma = .2126 * r + .7152 * g + .0722 * b
    # Seberapa "rumput jenuh": hijau melebihi rata-rata merah dan biru.
    hijau = np.clip((g - np.maximum(r, b) * .92) / .12, 0, 1) * kekuatan
    # 1) Turunkan saturasi hijau 35% dan geser ke zaitun (sedikit merah, kurangi biru).
    abu = luma[..., None]
    kalem = abu + (rgb - abu) * .65
    kalem = kalem * np.array([1.03, .98, .90])
    # 2) Gelapkan rumput 12% supaya tidak menyala di bawah matahari hangat.
    kalem *= .88
    hasil = rgb + (kalem - rgb) * hijau[..., None]
    # 3) Kontras tengah lembut (kurva S kecil di sekitar luma 0,35) untuk semua piksel.
    tengah = .35
    hasil = tengah + (hasil - tengah) * (1 + .10 * kekuatan)
    return Image.fromarray((np.clip(hasil, 0, 1) * 255 + .5).astype(np.uint8))


if __name__ == "__main__":
    masuk, keluar = sys.argv[1], sys.argv[2]
    awal = Image.open(masuk).convert("RGB")
    akhir = grade(awal)
    akhir.save(keluar)
    w, h = awal.size
    s = 1600 / (w * 2)
    banding = Image.new("RGB", (int(w * 2 * s), int(h * s)))
    banding.paste(awal.resize((int(w * s), int(h * s))), (0, 0))
    banding.paste(akhir.resize((int(w * s), int(h * s))), (int(w * s), 0))
    banding.save(keluar.rsplit(".", 1)[0] + "-banding.jpg", quality=90)
    print("selesai", keluar)
