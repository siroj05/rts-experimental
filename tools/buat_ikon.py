"""Buat ikon strategis (zoom jauh) per jenis unit untuk Recoil: gamedata/icontypes.lua + game/RTSPC.sdd/icons/*.png.

Bentuk putih berkontur gelap di kanvas transparan; Recoil mewarnai ikon dengan warna tim. Bentuk orisinal proyek
ini (🟡 2026-11-24), dibaca dari siluet: kendaraan = persegi panjang + laras, destroyer = baji, pengintai = segitiga
kecil, artileri = lingkaran + busur, robot = lingkaran/belah ketupat kecil, insinyur = plus, bangunan = persegi,
markas = persegi besar bertanda, menara = persegi + laras.
Pemakaian: python tools/buat_ikon.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "game/RTSPC.sdd"
S = 128  # digambar besar lalu diperkecil ke 64 supaya halus


def kanvas():
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def isi(d, bentuk, *args, **kw):
    # Kontur gelap dulu (tebal), lalu isi putih.
    getattr(d, bentuk)(*args, fill=(20, 22, 24, 255), outline=(20, 22, 24, 255), width=14, **kw)
    getattr(d, bentuk)(*args, fill=(255, 255, 255, 255), **kw)


def kendaraan(laras=True, lebar=.62, tinggi=.42, rongga=False):
    im, d = kanvas()
    w, h = S * lebar, S * tinggi
    isi(d, "rectangle", ((S - w) / 2, (S - h) / 2, (S + w) / 2, (S + h) / 2))
    if rongga:
        # Tank ringan: badan berongga supaya beda dari Medium Tank di ukuran kecil (2026-11-26).
        t = S * .1
        d.rectangle(((S - w) / 2 + t, (S - h) / 2 + t, (S + w) / 2 - t, (S + h) / 2 - t), fill=(20, 22, 24, 255))
    if laras:
        isi(d, "rectangle", (S * .5 - 5, S * .14, S * .5 + 5, S * .5))
    return im


def baji():
    im, d = kanvas()
    isi(d, "polygon", [(S * .5, S * .14), (S * .84, S * .8), (S * .16, S * .8)])
    return im


def chevron():
    # Pengintai: chevron terbuka (^), dulu segitiga kecil yang tertukar dengan baji Destroyer (2026-11-26).
    im, d = kanvas()
    pts = [(S * .2, S * .72), (S * .5, S * .26), (S * .8, S * .72)]
    d.line(pts, fill=(20, 22, 24, 255), width=34, joint="curve")
    d.line(pts, fill=(255, 255, 255, 255), width=18, joint="curve")
    return im


def artileri():
    im, d = kanvas()
    isi(d, "ellipse", (S * .26, S * .34, S * .74, S * .82))
    d.arc((S * .14, S * .1, S * .86, S * .82), 200, 340, fill=(255, 255, 255, 255), width=10)
    return im


def bulat(r=.2):
    im, d = kanvas()
    isi(d, "ellipse", (S * (.5 - r), S * (.5 - r), S * (.5 + r), S * (.5 + r)))
    return im


def ketupat(r=.24):
    im, d = kanvas()
    isi(d, "polygon", [(S * .5, S * (.5 - r)), (S * (.5 + r), S * .5), (S * .5, S * (.5 + r)), (S * (.5 - r), S * .5)])
    return im


def plus():
    im, d = kanvas()
    isi(d, "polygon", [(S * .42, S * .2), (S * .58, S * .2), (S * .58, S * .42), (S * .8, S * .42), (S * .8, S * .58),
                       (S * .58, S * .58), (S * .58, S * .8), (S * .42, S * .8), (S * .42, S * .58), (S * .2, S * .58),
                       (S * .2, S * .42), (S * .42, S * .42)])
    return im


def persegi(r=.3, tanda=None):
    im, d = kanvas()
    isi(d, "rectangle", (S * (.5 - r), S * (.5 - r), S * (.5 + r), S * (.5 + r)))
    if tanda == "markas":
        d.ellipse((S * .4, S * .4, S * .6, S * .6), fill=(20, 22, 24, 255))
    elif tanda == "menara":
        isi(d, "rectangle", (S * .5 - 5, S * .08, S * .5 + 5, S * .5))
    elif tanda == "pabrik":
        d.rectangle((S * .38, S * .62, S * .62, S * (.5 + r)), fill=(20, 22, 24, 255))
    return im


# nama ikon -> (gambar, ukuran relatif)
IKON = {
    "tank": (kendaraan(), 1.25), "tank_ringan": (kendaraan(lebar=.56, tinggi=.4, rongga=True), 1.1),
    "destroyer": (baji(), 1.25), "pengintai": (chevron(), .9), "artileri": (artileri(), 1.15),
    "robot": (bulat(), .8), "roket": (ketupat(), .85), "insinyur": (plus(), .95),
    "markas": (persegi(.34, "markas"), 2.0), "pabrik": (persegi(.32, "pabrik"), 1.6), "menara": (persegi(.24, "menara"), 1.3),
    "bangunan": (persegi(.22), 1.1),
}
UNIT = {
    "medium_tank": "tank", "tank_ringan": "tank_ringan", "medium_tank_destroyer": "destroyer", "pengintai": "pengintai",
    "artileri_ringan": "artileri", "robot_infanteri": "robot", "robot_roket": "roket", "robot_insinyur": "insinyur",
    "inti_komando": "markas", "pabrik_kendaraan": "pabrik", "pabrik_robot": "pabrik", "menara_pertahanan": "menara",
}


def main():
    (GAME / "icons").mkdir(exist_ok=True)
    baris = ["-- Dibuat tools/buat_ikon.py. Ikon strategis zoom jauh; Recoil mewarnainya dengan warna tim.",
             "return {", '    default = {bitmap = "icons/bangunan.png", size = 1.1},']
    for nama, (im, ukuran) in IKON.items():
        im.resize((64, 64), Image.Resampling.LANCZOS).save(GAME / "icons" / f"{nama}.png")
        baris.append(f'    {nama} = {{bitmap = "icons/{nama}.png", size = {ukuran}}},')
    baris.append("}")
    (GAME / "gamedata/icontypes.lua").write_text("\n".join(baris) + "\n", encoding="utf-8", newline="\n")
    (GAME / "gamedata/ikon_unit.lua").write_text(
        "-- Dibuat tools/buat_ikon.py: jenis ikon per unit (unit lain memakai `bangunan`).\nreturn {\n"
        + "".join(f'    {k} = "{v}",\n' for k, v in UNIT.items()) + "}\n", encoding="utf-8", newline="\n")
    print(len(IKON), "ikon")


if __name__ == "__main__":
    main()
