"""Buat kursor mouse RTS PC (gambar sendiri, PIL) ke game/RTSPC.sdd/anims/.

Recoil membaca kursor dari anims/cursor<nama>.txt (daftar frame) sebelum gambar bawaan engine, jadi file di arsip
game menggantikan kursor Recoil. Digambar 4x lalu diperkecil ke 32x32 (tepi halus). Gaya mengikuti HUD:
garis luar gelap, isi terang, aksen teal. Kursor normal hotspot kiri atas, lainnya tengah (aturan engine).

    python tools/buat_kursor.py
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "game/RTSPC.sdd/anims"
UKURAN, SS = 32, 4
N = UKURAN * SS
GELAP = (12, 18, 20, 255)
PUTIH = (236, 242, 240, 255)
TEAL = (77, 217, 199, 255)
MERAH = (240, 72, 60, 255)
ORANYE = (255, 160, 60, 255)
HIJAU = (96, 226, 140, 255)
BIRU = (90, 160, 255, 255)
CYAN = (90, 220, 240, 255)
KUNING = (250, 210, 70, 255)
UNGU = (190, 120, 240, 255)


def kanvas():
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def p(v):
    """Koordinat 0-32 ke kanvas besar."""
    return v * SS


def garis(d, pts, warna, lebar):
    """Garis berlapis: luar gelap lalu warna."""
    pts = [(p(x), p(y)) for x, y in pts]
    d.line(pts, fill=GELAP, width=int(p(lebar + 2)), joint="curve")
    for x, y in (pts[0], pts[-1]):
        r = p(lebar + 2) / 2
        d.ellipse((x - r, y - r, x + r, y + r), fill=GELAP)
    d.line(pts, fill=warna, width=int(p(lebar)), joint="curve")
    for x, y in (pts[0], pts[-1]):
        r = p(lebar) / 2
        d.ellipse((x - r, y - r, x + r, y + r), fill=warna)


def cincin(d, cx, cy, r, warna, lebar, dari=0, ke=360):
    box = (p(cx - r), p(cy - r), p(cx + r), p(cy + r))
    d.arc(box, dari, ke, fill=GELAP, width=int(p(lebar + 2)))
    box2 = (p(cx - r), p(cy - r), p(cx + r), p(cy + r))
    d.arc(box2, dari, ke, fill=warna, width=int(p(lebar)))


def poligon(d, pts, warna, tepi=1.2):
    pts = [(p(x), p(y)) for x, y in pts]
    d.polygon(pts, fill=GELAP)
    # isi diperkecil ke arah pusat supaya tepi gelap terlihat
    cx = sum(x for x, _ in pts) / len(pts)
    cy = sum(y for _, y in pts) / len(pts)
    dalam = []
    for x, y in pts:
        dx, dy = x - cx, y - cy
        l = math.hypot(dx, dy) or 1
        k = max(0, (l - p(tepi)) / l)
        dalam.append((cx + dx * k, cy + dy * k))
    d.polygon(dalam, fill=warna)


def titik(d, cx, cy, r, warna):
    d.ellipse((p(cx - r - 1), p(cy - r - 1), p(cx + r + 1), p(cy + r + 1)), fill=GELAP)
    d.ellipse((p(cx - r), p(cy - r), p(cx + r), p(cy + r)), fill=warna)


def bidikan(d, warna, r=9):
    cincin(d, 16, 16, r, warna, 2)
    for a in (0, 90, 180, 270):
        dx, dy = math.cos(math.radians(a)), math.sin(math.radians(a))
        garis(d, [(16 + dx * (r - 3), 16 + dy * (r - 3)), (16 + dx * (r + 5), 16 + dy * (r + 5))], warna, 2)
    titik(d, 16, 16, 1.3, warna)


def k_normal():
    img, d = kanvas()
    poligon(d, [(2, 2), (2, 25), (8, 19.5), (12.5, 28.5), (17, 26.5), (12.5, 17.5), (20.5, 17.5)], PUTIH, 1.8)
    return img


def k_move():
    img, d = kanvas()
    for a in (45, 135, 225, 315):
        dx, dy = math.cos(math.radians(a)), math.sin(math.radians(a))
        px, py = -dy, dx
        ujung, pangkal = 6, 13
        garis(d, [(16 + dx * pangkal + px * 5, 16 + dy * pangkal + py * 5), (16 + dx * ujung, 16 + dy * ujung),
                  (16 + dx * pangkal - px * 5, 16 + dy * pangkal - py * 5)], HIJAU, 2.4)
    titik(d, 16, 16, 1.8, HIJAU)
    return img


def k_attack():
    img, d = kanvas()
    bidikan(d, MERAH)
    return img


def k_fight():
    img, d = kanvas()
    bidikan(d, ORANYE, 8)
    poligon(d, [(22, 22), (31, 25), (25, 31)], ORANYE, 1)
    return img


def k_areaattack():
    img, d = kanvas()
    for a in range(0, 360, 40):
        cincin(d, 16, 16, 14, MERAH, 1.5, a, a + 22)
    bidikan(d, MERAH, 7)
    return img


def k_patrol():
    img, d = kanvas()
    cincin(d, 16, 16, 9, BIRU, 2.2, 200, 340)
    cincin(d, 16, 16, 9, BIRU, 2.2, 20, 160)
    for a, arah in ((340, 1), (160, 1)):
        x, y = 16 + math.cos(math.radians(a)) * 9, 16 + math.sin(math.radians(a)) * 9
        tx, ty = -math.sin(math.radians(a)), math.cos(math.radians(a))
        nx, ny = math.cos(math.radians(a)), math.sin(math.radians(a))
        poligon(d, [(x + tx * 5, y + ty * 5), (x + nx * 4, y + ny * 4), (x - nx * 4, y - ny * 4)], BIRU, 1)
    titik(d, 16, 16, 1.3, BIRU)
    return img


def k_defend():
    img, d = kanvas()
    poligon(d, [(16, 4), (26, 8), (25, 17), (16, 28), (7, 17), (6, 8)], CYAN, 1.6)
    garis(d, [(16, 9), (16, 22)], GELAP, 1)
    return img


def k_repair():
    img, d = kanvas()
    garis(d, [(10, 22), (20, 12)], KUNING, 3.2)
    cincin(d, 22, 10, 5, KUNING, 2.6, 60, 330)
    titik(d, 9, 23, 2, KUNING)
    return img


def k_reclaim():
    img, d = kanvas()
    garis(d, [(16, 4), (16, 17)], UNGU, 3)
    poligon(d, [(9, 15), (23, 15), (16, 24)], UNGU, 1.2)
    garis(d, [(8, 27), (24, 27)], UNGU, 2)
    return img


def k_wait():
    img, d = kanvas()
    garis(d, [(9, 5), (23, 5)], PUTIH, 2)
    garis(d, [(9, 27), (23, 27)], PUTIH, 2)
    poligon(d, [(10, 6), (22, 6), (16, 16)], TEAL, 1.2)
    poligon(d, [(16, 16), (22, 26), (10, 26)], PUTIH, 1.2)
    return img


def k_buildgood():
    img, d = kanvas()
    garis(d, [(16, 8), (16, 24)], HIJAU, 3)
    garis(d, [(8, 16), (24, 16)], HIJAU, 3)
    return img


def k_buildbad():
    img, d = kanvas()
    garis(d, [(9, 9), (23, 23)], MERAH, 3)
    garis(d, [(23, 9), (9, 23)], MERAH, 3)
    return img


KURSOR = {
    "cursornormal": k_normal, "cursormove": k_move, "cursorattack": k_attack, "cursorfight": k_fight,
    "cursorareaattack": k_areaattack, "cursorpatrol": k_patrol, "cursordefend": k_defend,
    "cursorrepair": k_repair, "cursorreclamate": k_reclaim, "cursorwait": k_wait,
    "cursorbuildgood": k_buildgood, "cursorbuildbad": k_buildbad,
}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    lembar = Image.new("RGBA", (len(KURSOR) * 72, 72), (60, 80, 60, 255))
    for i, (nama, buat) in enumerate(KURSOR.items()):
        img = buat().resize((UKURAN, UKURAN), Image.LANCZOS)
        img.save(OUT / f"{nama}_0.png")
        (OUT / f"{nama}.txt").write_text(f"frame anims/{nama}_0.png 0.100\n", encoding="ascii")
        lembar.alpha_composite(img.resize((64, 64), Image.NEAREST), (i * 72 + 4, 4))
    contoh = ROOT / ".cache/kursor-lembar.png"
    contoh.parent.mkdir(exist_ok=True)
    lembar.save(contoh)
    print(f"{len(KURSOR)} kursor -> {OUT}; contoh: {contoh}")


if __name__ == "__main__":
    main()
