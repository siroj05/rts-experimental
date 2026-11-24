"""Poles cahaya dan atmosfer peta (tahap 5): tulis ulang tabel `lighting` dan `atmosphere` di maps/mapinfo-*.lua
lalu ganti mapinfo.lua di arsip .sdz yang sesuai. Tekstur peta tidak berubah.

Pemakaian: python tools/poles_peta.py [stem ...]   (tanpa argumen: semua peta di PETA)

🟡 Usulan Claude 2026-11-24 untuk arah visual "natural dan dramatis": matahari ±35°, ambient gelap kebiruan dan
cahaya matahari hangat (hijau medan jadi lebih kalem dan bayangan terbaca), kabut udara mulai lebih dekat, specular
halus. Nilai per peta hanya berbeda di arah matahari (mengikuti arah bayangan asli peta) dan warna air.
"""
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

CAHAYA = """lighting = {
        sunDir = {SUN},
        groundAmbientColor = {0.36, 0.38, 0.42},
        groundDiffuseColor = {1.00, 0.93, 0.82},
        groundSpecularColor = {0.10, 0.10, 0.09},
        groundShadowDensity = 0.86,
        unitAmbientColor = {0.38, 0.40, 0.45},
        unitDiffuseColor = {1.02, 0.97, 0.88},
        unitSpecularColor = {0.55, 0.53, 0.50},
        unitShadowDensity = 0.86,
    }"""
UDARA = """atmosphere = {
        fogStart = 0.30,
        fogEnd = 1.0,
        fogColor = {0.60, 0.66, 0.72},
        skyColor = {0.40, 0.54, 0.69},
        sunColor = {1.0, 0.92, 0.80},
        minWind = 5,
        maxWind = 12,
    }"""

# Rumput engine: kunci yang dikenali Recoil adalah bladeHeight/bladeWidth/bladeWaveScale/bladeColor (kunci lama
# `grassBlade*` diabaikan sehingga warna bawaan {0.59, 0.81, 0.57} yang terlalu terang dipakai).
RUMPUT = """grass = {
        bladeHeight = 3.2,
        bladeWidth = 0.29,
        bladeWaveScale = 0.8,
        bladeColor = {0.34, 0.42, 0.25},
    }"""

# stem mapinfo -> (arsip .sdz, arah matahari)
PETA = {
    "bukit-tengah": ("bukit-tengah-1v1", "-0.62, 0.56, -0.55"),
    "lembah-sungai": ("lembah-sungai-1v1", "-0.62, 0.56, -0.55"),
    "punggung-hijau-4v4": ("punggung-hijau-4v4", "-0.67, 0.59, -0.45"),
    "lintasan-pinus-4v4": ("lintasan-pinus-4v4", "-0.62, 0.56, -0.55"),
}


def ganti_tabel(teks, kunci, baru):
    """Ganti `kunci = { ... }` (kurung seimbang) dengan teks baru."""
    m = re.search(r"\b" + kunci + r"\s*=\s*\{", teks)
    if not m:
        # Sisipkan sebelum kurung tutup terakhir tabel utama.
        akhir = teks.rstrip().rfind("}")
        return teks[:akhir].rstrip() + "\n    " + baru + ",\n" + teks[akhir:]
    i, dalam = m.end() - 1, 0
    for j in range(i, len(teks)):
        if teks[j] == "{":
            dalam += 1
        elif teks[j] == "}":
            dalam -= 1
            if dalam == 0:
                return teks[:m.start()] + baru + teks[j + 1:]
    raise ValueError(f"kurung {kunci} tidak seimbang")


def poles(stem):
    arsip, matahari = PETA[stem]
    sumber = ROOT / "maps" / f"mapinfo-{stem}.lua"
    teks = sumber.read_text(encoding="utf-8")
    teks = ganti_tabel(teks, "lighting", CAHAYA.replace("SUN", matahari))
    teks = ganti_tabel(teks, "atmosphere", UDARA)
    teks = ganti_tabel(teks, "grass", RUMPUT)
    sumber.write_text(teks, encoding="utf-8", newline="\n")
    sdz = ROOT / "maps" / f"{arsip}.sdz"
    sementara = sdz.with_suffix(".tmp")
    with zipfile.ZipFile(sdz) as lama, zipfile.ZipFile(sementara, "w", zipfile.ZIP_DEFLATED) as baru:
        for item in lama.infolist():
            data = teks.encode("utf-8") if item.filename == "mapinfo.lua" else lama.read(item.filename)
            baru.writestr(item, data)
    sementara.replace(sdz)
    print(f"{stem}: mapinfo diperbarui, {sdz.name} dikemas ulang")


if __name__ == "__main__":
    for s in sys.argv[1:] or PETA:
        poles(s)
