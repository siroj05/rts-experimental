"""Limestone Valley 4v4 (lembah kapur): generator tata letak acak ber-seed, dipakai denah dan generator heightmap.

Keputusan user 2026-11-26: peta 4v4 baru 1536 x 1536 m (24 x 24 SMU), tema pegunungan Eropa, Deathmatch dulu; layout
"bisa random aja ... polanya ga ketebak tapi tetap pada pedoman aturan" (docs/aturan-peta.md, BAR + FAF).

Cara kerja 🟡 Claude:
- Satu seed = satu layout. Semua unsur diacak dalam batas aturan: posisi markas, jumlah/bentuk/sudut segmen punggung
  kapur, letak bukaan, kelokan sungai, jumlah dan letak arung, lebar lembah, kelompok ekspansi, hutan.
- Sisi barat diacak, sisi timur = putar 180° (keadilan; tiap markas punya pasangan setara).
- Layout yang gagal pemeriksaan aturan dibuang; seed berikutnya dicoba.

    python tools/lembah_kapur_layout.py --kandidat 6        -> maps/lembah-kapur-kandidat.png (lembar pilihan)
    python tools/lembah_kapur_layout.py --seed 17           -> maps/lembah-kapur-denah.png + laporan aturan
Koordinat: X ke timur, Z ke selatan, dari sudut barat laut, dalam meter. Recoil: kalikan 8 (elmo).
"""
import argparse
import math
import random
from pathlib import Path

import numpy as np

UKURAN = 1536
STEM = "lembah-kapur-4v4"
NAMA = "Limestone Valley 4v4"
TENGAH = UKURAN / 2
ELMO = 8
# ✅ user 2026-11-26: tambang lebih banyak dan lebih acak, hasil per tambang diturunkan supaya total tetap di batas
# aturan (5-15/detik per pemain). Ekstraktor di peta ini menghasilkan 1,5 (gamedata/defs.lua, skenario kapur).
LOGAM_PER_TAMBANG = 1.5
TAMBANG_EKSPANSI = 24  # per sisi, di luar 12 tambang start dan pulau
TERAS_R = 70
BELA_R = 35
SUNGAI_SETENGAH = 16
ROOT = Path(__file__).resolve().parents[1]
# Seed terkunci untuk Limestone Valley (user 2026-11-26: "boleh deh yang mana aja"; dipilih Claude: seed 1, 4 punggung,
# 3 bukaan per sisi). Generator heightmap memakai seed ini.
SEED_TERPILIH = 1


def _halus(t):
    t = np.clip(t, 0, 1)
    return t * t * (3 - 2 * t)


def putar(p):
    return (UKURAN - p[0], UKURAN - p[1]) + tuple(p[2:])


def jarak(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


class Layout:
    """Layout satu seed. Atribut berakhiran _b = sisi barat; tanpa akhiran = kedua sisi (barat + putaran)."""

    def __init__(self, seed):
        self.seed = seed
        r = random.Random(seed)
        self.r = r
        # Medan
        self.t_teras = r.uniform(36, 46)
        self.t_lembah = r.uniform(6, 14)
        self.lembah_setengah = r.uniform(140, 200)
        self.lereng_lebar = r.uniform(180, 280)
        # Sungai: jumlah suku sinus ganjil terhadap pusat -> simetris putar 180°
        self.sungai_suku = [(r.uniform(25, 60), r.uniform(70, 140), r.choice((-1, 1))),
                            (r.uniform(6, 18), r.uniform(28, 50), r.choice((-1, 1)))]
        # Markas barat: 4 markas, z terurut dengan jarak acak >= 290, x acak
        while True:
            zs = sorted(r.uniform(150, UKURAN - 150) for _ in range(4))
            if all(b - a >= 290 for a, b in zip(zs, zs[1:])):
                break
        self.markas_b = [(r.uniform(120, 240), z) for z in zs]
        # Segmen punggung kapur barat: 3-5 segmen berurutan utara-selatan dengan celah acak
        n = r.randint(3, 5)
        while True:
            panjang = [r.uniform(170, 330) for _ in range(n)]
            celah = [r.uniform(100, 150) for _ in range(n - 1)]
            total = sum(panjang) + sum(celah)
            sisa = UKURAN - total
            if 160 < sisa < 420:
                break
        utara = r.uniform(.35, .65) * sisa
        self.segmen_b = []
        z = utara
        for i in range(n):
            zc = z + panjang[i] / 2
            self.segmen_b.append({"z": zc, "h": panjang[i] / 2, "x": r.uniform(390, 500),
                                  "lebar": r.uniform(80, 125), "lengkung": r.uniform(-40, 40),
                                  "miring": math.radians(r.uniform(-14, 14)), "tinggi": r.uniform(36, 58)})
            z += panjang[i] + (celah[i] if i < n - 1 else 0)
        # Bukaan utama = celah antar-segmen; titik pertahanan di mulut dalam (barat bukaan)
        self.bukaan_b = []
        for a, b in zip(self.segmen_b, self.segmen_b[1:]):
            z0, z1 = a["z"] + a["h"], b["z"] - b["h"]
            xm = (self._seg_x(a, z0) + self._seg_x(b, z1)) / 2
            self.bukaan_b.append({"z": (z0 + z1) / 2, "lebar": z1 - z0, "x": xm})
        self.bela_b = [(bk["x"] - r.uniform(70, 100), bk["z"]) for bk in self.bukaan_b]
        # Lorong raid di ujung utara dan selatan: tebing tepi menyisakan 40-80 m
        self.raid_b = []
        self.tebing_b = []
        for ujung, seg in (("utara", self.segmen_b[0]), ("selatan", self.segmen_b[-1])):
            lorong = r.uniform(45, 75)
            if ujung == "utara":
                tepi = seg["z"] - seg["h"]
                tz1 = tepi - lorong
                self.tebing_b.append((self._seg_x(seg, tepi), tz1 / 2 - 30, 130, tz1 / 2 + 30))
                self.raid_b.append((self._seg_x(seg, tepi), tepi - lorong / 2, lorong))
            else:
                tepi = seg["z"] + seg["h"]
                tz0 = tepi + lorong
                self.tebing_b.append((self._seg_x(seg, tepi), (tz0 + UKURAN) / 2 + 30, 130, (UKURAN - tz0) / 2 + 30))
                self.raid_b.append((self._seg_x(seg, tepi), tepi + lorong / 2, lorong))
        # Massif (zona mati) di ujung sungai, acak lebar
        rx = r.uniform(200, 300)
        self.massif = [(TENGAH, -40, rx, r.uniform(100, 140))]
        self.massif.append(putar(self.massif[0]))
        # Arung: 2 pasang (z dan cerminnya) + pulau di pusat
        za = sorted(r.uniform(140, TENGAH - 120) for _ in range(2))
        if za[1] - za[0] < 180:
            za[1] = min(TENGAH - 120, za[0] + 180)
        self.arung = []
        for z in za:
            lebar = r.uniform(40, 56)
            self.arung += [(z, lebar), (UKURAN - z, lebar)]
        self.pulau = (TENGAH, r.uniform(40, 60))
        # Pulau rebutan tersambung ke kedua tepi lewat gosong kerikil (arung di z pusat), supaya tambangnya terjangkau.
        self.arung.append((TENGAH, 2 * self.pulau[1]))
        # Tambang start: 3 per markas pada sudut acak
        self.start_b = []
        for mx, mz in self.markas_b:
            a0 = r.uniform(0, 2 * math.pi)
            for k in range(3):
                a = a0 + k * 2 * math.pi / 3 + r.uniform(-.3, .3)
                d = r.uniform(42, 56)
                self.start_b.append((mx + math.cos(a) * d, mz + math.sin(a) * d))
        self.tengah = [(self.sungai_x(TENGAH - 30), TENGAH - 30), (self.sungai_x(TENGAH + 30), TENGAH + 30)]
        self.markas = self.markas_b + [putar(p) for p in self.markas_b]
        self.bela = self.bela_b + [putar(p) for p in self.bela_b]
        # Ekspansi (user 2026-11-26: "mineralnya disebar dimana aja", lalu "sebaran mineral kurang banyak dan kurang
        # acak"): kelompok acak berisi 1-4 tambang dengan jarak antartambang acak, di mana saja yang datar. Zona dihitung
        # dari jarak ke markas sendiri vs lawan. Wajib >= 1 aman dan >= 1 rampok per sisi.
        self.ekspansi_b = self._sebar_ekspansi()
        # Rute dan hutan
        self.rute_b = self._rute()
        self.hutan_b = self._hutan()
        # Kedua sisi
        self.zona = [(x, z, "aman") for x, z in self.start_b]
        for k in self.ekspansi_b:
            self.zona += [(x, z, k["zona"]) for x, z in k["titik"]]
        self.zona = self.zona + [putar(p) for p in self.zona] + [(x, z, "rebutan") for x, z in self.tengah]
        self.tambang = [(x, z) for x, z, _ in self.zona]
        self.hutan = self.hutan_b + [putar(h) for h in self.hutan_b]
        self.tebing = self.tebing_b + [putar(t) for t in self.tebing_b]
        self.rute = self.rute_b + [[putar(p) for p in rt] for rt in self.rute_b]

    # --- bantuan ---
    def _seg_x(self, s, z):
        t = (z - s["z"]) / s["h"]
        return s["x"] - s["lengkung"] * t * t + math.tan(s["miring"]) * (z - s["z"])

    def _sebar_ekspansi(self):
        r = self.r
        kel, total, rebutan = [], 0, 0
        for _ in range(4000):
            if total >= TAMBANG_EKSPANSI:
                break
            cx, cz = r.uniform(50, TENGAH - 30), r.uniform(50, UKURAN - 50)
            pusat = (cx, cz)
            if abs(cx - self.sungai_x(cz)) < 50:
                continue
            if min(jarak(pusat, m) for m in self.markas) < 140 or min(jarak(pusat, b) for b in self.bela) < 55:
                continue
            if any(jarak(pusat, k["pusat"]) < 75 or jarak(pusat, putar(k["pusat"])) < 75 for k in kel):
                continue
            if jarak(pusat, putar(pusat)) < 150 or jarak(pusat, (TENGAH, TENGAH)) < 100:
                continue
            ds = min(jarak(pusat, m) for m in self.markas_b)
            de = min(jarak(pusat, m) for m in self.markas[4:])
            rasio = ds / de
            if rasio < .65:
                zona = "aman"
            elif rasio <= .85 and ds >= 300:
                zona = "rampok"
            elif rebutan < 2:
                zona = "rebutan"  # sedikit saja (aturan: rebutan <= 10%)
            else:
                continue
            n = min(r.choices((1, 2, 3, 4), weights=(35, 30, 25, 10))[0], TAMBANG_EKSPANSI - total)
            if zona == "rebutan":
                n = min(n, 2 - rebutan)
            titik = self._kelompok(cx, cz, n)
            tx = np.array([t[0] for t in titik])
            tz = np.array([t[1] for t in titik])
            e = 6.0
            hx = (self.tinggi_dasar(tx + e, tz) - self.tinggi_dasar(tx - e, tz)) / (2 * e)
            hz = (self.tinggi_dasar(tx, tz + e) - self.tinggi_dasar(tx, tz - e)) / (2 * e)
            if float(np.degrees(np.arctan(np.hypot(hx, hz))).max()) >= 8:
                continue
            if any(abs(x - self.sungai_x(z)) < 45 for x, z in titik):
                continue
            kel.append({"pusat": pusat, "zona": zona, "titik": titik})
            total += n
            rebutan += n if zona == "rebutan" else 0
        return kel

    def _kelompok(self, cx, cz, n):
        """n tambang di sekitar pusat: sudut dan jarak acak, minimal 20 m antartambang."""
        titik = [(cx, cz)]
        for _ in range(200):
            if len(titik) == n:
                break
            a, d = self.r.uniform(0, 2 * math.pi), self.r.uniform(22, 42)
            bx, bz = titik[self.r.randrange(len(titik))]
            p = (bx + math.cos(a) * d, bz + math.sin(a) * d)
            if all(jarak(p, q) >= 20 for q in titik):
                titik.append(p)
        return titik

    def sungai_x(self, z):
        t = z - TENGAH
        return TENGAH + sum(a * s * math.sin(t / w) for a, w, s in self.sungai_suku)

    def _rute(self):
        hasil = []
        arung = [(self.sungai_x(z), z) for z, _ in self.arung]
        for m in self.markas_b:
            b = min(self.bela_b, key=lambda p: jarak(p, m))
            bk = min(self.bukaan_b, key=lambda k: abs(k["z"] - b[1]))
            keluar = (bk["x"] + 120, bk["z"])
            a = min(arung, key=lambda p: jarak(p, keluar))
            hasil.append([m, b, (bk["x"], bk["z"]), keluar, (a[0] - 40, a[1]), a])
        return hasil

    def _bebas(self, x, z, r):
        """Titik hutan (x, z, r) tidak menimpa markas, titik pertahanan, tambang, rute."""
        for m in self.markas_b + [putar(p) for p in self.markas_b]:
            if jarak((x, z), m) < TERAS_R + r + 30:
                return False
        for p in self.bela_b + [putar(q) for q in self.bela_b]:
            if jarak((x, z), p) < BELA_R + r + 20:
                return False
        for p in self.start_b + [t for k in self.ekspansi_b for t in k["titik"]]:
            if jarak((x, z), p) < r + 25:
                return False
        for rt in self.rute_b + [[putar(p) for p in q] for q in self.rute_b]:
            for (x0, z0), (x1, z1) in zip([p[:2] for p in rt], [p[:2] for p in rt[1:]]):
                for i in range(21):
                    a = i / 20
                    if math.hypot(x - (x0 + (x1 - x0) * a), z - (z0 + (z1 - z0) * a)) < r + 18:
                        return False
        if abs(x - self.sungai_x(z)) < r + SUNGAI_SETENGAH + 10:
            return False
        return True

    def _hutan(self):
        hutan = []
        coba = 0
        target = self.r.randint(8, 13)
        while len(hutan) < target and coba < 400:
            coba += 1
            x = self.r.uniform(20, TENGAH - 40)
            z = self.r.uniform(20, UKURAN - 20)
            rr = self.r.uniform(30, 70)
            if self._bebas(x, z, rr) and all(jarak((x, z), h) > h[2] + rr - 10 for h in hutan):
                hutan.append((x, z, rr))
        return hutan

    # --- medan dasar sebelum erosi ---
    def tinggi_dasar(self, x, z, wx=0.0, wz=0.0):
        """wx, wz: domain warp (m) untuk punggung, tebing, massif; tepinya jadi tidak beraturan."""
        x = np.asarray(x, dtype=np.float64)
        z = np.asarray(z, dtype=np.float64)
        lereng = _halus((np.abs(x - TENGAH) - self.lembah_setengah) / self.lereng_lebar)
        h = self.t_lembah + (self.t_teras - self.t_lembah) * lereng
        for xr, zr in ((x + wx, z + wz), (UKURAN - x - wx, UKURAN - z - wz)):
            for s in self.segmen_b:
                t = (zr - s["z"]) / s["h"]
                xc = s["x"] - s["lengkung"] * t * t + np.tan(s["miring"]) * (zr - s["z"])
                ujung = _halus((1 - np.abs(t)) / .35)
                lebar = s["lebar"] / 2 * (.35 + .65 * ujung)
                # Profil cuesta kapur: lereng landai ke arah markas, tebing curam ke arah lembah, puncak agak rata.
                u = (xr - xc) / np.maximum(lebar, 1)
                f = np.where(u < 0, 1 - _halus(-u / 1.5), 1 - _halus(u / .55))
                f = np.minimum(1, f * 1.05)
                h = h + s["tinggi"] * f * ujung * (np.abs(t) < 1)
            for cx, cz, rx, rz in self.tebing_b:
                d = np.hypot((xr - cx) / rx, (zr - cz) / rz)
                h = h + 70 * (1 - _halus(d))
        for cx, cz, rx, rz in self.massif:
            d = np.hypot((x + wx - cx) / rx, (z + wz - cz) / rz)
            h = h + (150 - self.t_lembah) * (1 - _halus(d))
        t = z - TENGAH
        sx = TENGAH + sum(a * s * np.sin(t / w) for a, w, s in self.sungai_suku)
        dalam = 1 - _halus((np.abs(x - sx) - SUNGAI_SETENGAH) / 14)
        arung = np.zeros_like(h)
        for az, lebar in self.arung:
            arung = np.maximum(arung, 1 - _halus((np.abs(z - az) - lebar / 2) / 22))
        pulau = 1 - _halus(np.hypot((x - TENGAH) / 26, (z - TENGAH) / self.pulau[1]))
        alur = self.t_lembah - 4 + 3.2 * arung
        h = h + (alur - h) * dalam * (1 - pulau)
        for (px, pz), rad, target in ([(m, TERAS_R, self.t_teras) for m in self.markas]
                                      + [(b, BELA_R, None) for b in self.bela]):
            dd = np.hypot(x - px, z - pz)
            dalamnya = dd < rad
            tgt = target if target is not None else (float(np.mean(h[dalamnya])) if np.any(dalamnya) else self.t_teras)
            h = tgt + (h - tgt) * _halus((dd - rad) / 30)
        return h

    # --- aturan ---
    def periksa(self, cetak=False):
        hasil = []

        def cek(nama, ok, nilai):
            hasil.append((nama, bool(ok), nilai))

        smu = UKURAN * ELMO / 512
        cek("ukuran <= 32 SMU", smu <= 32, f"{smu:.0f} x {smu:.0f} SMU")
        logam = len(self.tambang) * LOGAM_PER_TAMBANG / len(self.markas)
        cek("logam 5-15/detik per pemain", 5 <= logam <= 15, f"{logam:.1f}")
        cek("start 2-5 tambang per markas", True, "3")
        zn = [k["zona"] for k in self.ekspansi_b]
        ukuran = [len(k["titik"]) for k in self.ekspansi_b]
        cek("ekspansi: kelompok acak 1-4 tambang, >= 1 aman dan >= 1 rampok",
            sum(ukuran) == TAMBANG_EKSPANSI and "aman" in zn and "rampok" in zn,
            f"{len(ukuran)} kelompok {sorted(ukuran)}, aman {zn.count('aman')}, rampok {zn.count('rampok')}")
        reb = sum(1 for *_, zn in self.zona if zn == "rebutan")
        cek("tambang rebutan <= 10%", reb / len(self.tambang) <= .10, f"{reb} dari {len(self.tambang)}")
        lorong = [round(l) for *_, l in self.raid_b]
        cek("lorong raid 40-80 m", all(40 <= l <= 80 for l in lorong), f"{lorong}")
        lebar = [round(b["lebar"]) for b in self.bukaan_b]
        cek("bukaan utama >= 100 m (peta tidak tertutup)", all(l >= 100 for l in lebar), f"{len(lebar)} bukaan {lebar}")
        jm = min(jarak(a, b) for i, a in enumerate(self.markas_b) for b in self.markas_b[i + 1:])
        cek("jarak antar-markas sekubu >= 290 m", jm >= 290, f"{jm:.0f} m")
        ok_tambang = all(not any(jarak(t, h) < h[2] + 20 for h in self.hutan) for t in self.tambang)
        cek("tambang tidak di hutan", ok_tambang, "")
        # Tambang di tanah datar: kemiringan bentuk dasar < 8° (bukan di lereng punggung/tebing)
        tx = np.array([t[0] for t in self.tambang])
        tz = np.array([t[1] for t in self.tambang])
        e = 6.0
        hx = (self.tinggi_dasar(tx + e, tz) - self.tinggi_dasar(tx - e, tz)) / (2 * e)
        hz = (self.tinggi_dasar(tx, tz + e) - self.tinggi_dasar(tx, tz - e)) / (2 * e)
        miring = float(np.degrees(np.arctan(np.hypot(hx, hz))).max())
        cek("tambang di tanah datar (< 8°)", miring < 8, f"maks {miring:.1f}°")
        if self.ekspansi_b:
            ds = [round(min(jarak(k["pusat"], m) for m in self.markas_b)) for k in self.ekspansi_b]
            cek("ekspansi tidak menempel markas (>= 140 m)", min(ds) >= 140, f"min {min(ds)} m")
        # Rute markas -> bukaan maksimal 90 detik Medium Tank
        tb = max(jarak(m, min(self.bela_b, key=lambda p: jarak(p, m))) for m in self.markas_b) / 5.5
        cek("markas -> titik pertahanan <= 90 s", tb <= 90, f"{tb:.0f} s")
        cek("rute bebas pohon", True, "dijamin saat penempatan hutan")
        cek("pasangan setara (putar 180°)", True, "dibangun dari putaran")
        if cetak:
            for nama, ok, nilai in hasil:
                print(f"  [{'OK' if ok else 'XX'}] {nama}: {nilai}")
            arung = [(self.sungai_x(z), z) for z, _ in self.arung]
            v = 5.5
            print("  waktu tempuh Medium Tank: markas -> titik pertahanan "
                  f"{[round(jarak(m, min(self.bela_b, key=lambda p: jarak(p, m))) / v) for m in self.markas_b]} s, "
                  f"-> arung {[round(min(jarak(m, a) for a in arung) / v) for m in self.markas_b]} s, "
                  f"-> markas lawan {[round(min(jarak(m, b) for b in self.markas[4:]) / v) for m in self.markas_b]} s")
        return all(ok for _, ok, _ in hasil)

    # --- gambar ---
    def denah(self, W=1152, label=True):
        from PIL import Image, ImageDraw, ImageFont
        S = W / UKURAN
        xs = (np.arange(W) + .5) / S
        X, Z = np.meshgrid(xs, xs)
        H = self.tinggi_dasar(X, Z)
        gz, gx = np.gradient(H, 1 / S)
        nx, nz, ny = -gx, -gz, np.ones_like(H)
        n = np.sqrt(nx * nx + ny * ny + nz * nz)
        lx, ly, lz = -.35, .75, -.55
        ln = math.sqrt(lx * lx + ly * ly + lz * lz)
        shade = np.clip((nx * lx + ny * ly + nz * lz) / (n * ln), 0, 1)
        slope = np.degrees(np.arctan(np.hypot(gx, gz)))
        t_l = np.clip((self.t_teras - H) / (self.t_teras - self.t_lembah), 0, 1)[..., None]
        base = np.array([92, 120, 70]) * (1 - t_l) + np.array([118, 138, 86]) * t_l
        k = np.clip((slope - 14) / 8, 0, 1)[..., None]
        base = base * (1 - k) + np.array([150, 146, 120]) * k
        b = np.clip((slope - 24) / 8, 0, 1)[..., None]
        base = base * (1 - b) + np.array([200, 196, 180]) * b
        base = np.where((H < self.t_lembah - 1.5)[..., None], np.array([60, 110, 130]), base)
        im = Image.fromarray(np.clip(base * (.55 + .6 * shade[..., None]), 0, 255).astype(np.uint8))
        d = ImageDraw.Draw(im, "RGBA")

        def p(x, z):
            return x * S, z * S

        lw = max(1, round(W / 576))
        for x, z, r in self.hutan:
            d.ellipse((p(x - r, z - r), p(x + r, z + r)), fill=(30, 58, 32, 165))
        for rt in self.rute:
            pts = [p(*q[:2]) for q in rt]
            d.line(pts, fill=(255, 250, 230, 150), width=lw)
        for x, z in self.markas:
            d.ellipse((p(x - TERAS_R, z - TERAS_R), p(x + TERAS_R, z + TERAS_R)), outline=(240, 230, 200, 180), width=lw)
        for x, z in self.bela:
            d.rectangle((p(x - BELA_R, z - BELA_R), p(x + BELA_R, z + BELA_R)), outline=(240, 150, 60, 235),
                        width=lw + 1)
        warna = {"aman": (110, 200, 110), "rampok": (240, 160, 60), "rebutan": (230, 70, 60)}
        rt_ = 7
        for x, z, zn in self.zona:
            d.ellipse((p(x - rt_, z - rt_), p(x + rt_, z + rt_)), fill=warna[zn], outline=(20, 20, 16), width=lw)
        try:
            f = ImageFont.truetype("arialbd.ttf", max(10, round(16 * W / 1152)))
            f2 = ImageFont.truetype("arial.ttf", max(10, round(13 * W / 1152)))
        except OSError:
            f = f2 = ImageFont.load_default()
        for i, (x, z) in enumerate(self.markas):
            c = (60, 120, 220) if i < 4 else (220, 70, 60)
            rr = 16
            d.ellipse((p(x - rr, z - rr), p(x + rr, z + rr)), fill=c, outline=(255, 255, 255), width=lw)
            d.text(p(x, z), str(i + 1), fill=(255, 255, 255), font=f, anchor="mm")
        if label:
            for x, z, _ in self.raid_b + [putar(q) for q in self.raid_b]:
                d.text(p(x, z), "lorong raid", fill=(250, 245, 230), font=f2, anchor="mm")
            lx, lz = 30, UKURAN - 168
            d.rectangle((p(lx - 8, lz - 14), p(lx + 300, lz + 150)), fill=(0, 0, 0, 140))
            for i, (zn, teks) in enumerate([("aman", "tambang aman (start + ekspansi aman)"),
                                             ("rampok", "tambang bisa dirampok"), ("rebutan", "tambang rebutan (pulau)")]):
                y = lz + i * 24
                d.ellipse((p(lx + 2, y), p(lx + 16, y + 14)), fill=warna[zn])
                d.text(p(lx + 28, y + 7), teks, fill=(255, 255, 255), font=f2, anchor="lm")
            y = lz + 72
            d.rectangle((p(lx, y), p(lx + 16, y + 16)), outline=(240, 150, 60), width=3)
            d.text(p(lx + 28, y + 8), "titik pertahanan (teras datar)", fill=(255, 255, 255), font=f2, anchor="lm")
            y += 24
            d.line((p(lx, y + 8), p(lx + 16, y + 8)), fill=(255, 250, 230), width=2)
            d.text(p(lx + 28, y + 8), "rute utama markas -> bukaan -> arung", fill=(255, 255, 255), font=f2,
                   anchor="lm")
            y += 30
            d.rectangle((p(lx, y), p(lx + 200, y + 4)), fill=(255, 255, 255))
            d.text(p(lx + 220, y + 2), "200 m", fill=(255, 255, 255), font=f2, anchor="lm")
        return im, H


def cari_seed(mulai, jumlah):
    hasil, s = [], mulai
    while len(hasil) < jumlah and s < mulai + 5000:
        try:
            L = Layout(s)
            if L.periksa():
                hasil.append(L)
        except (ValueError, IndexError):
            pass
        s += 1
    return hasil


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int)
    ap.add_argument("--kandidat", type=int, default=0)
    ap.add_argument("--mulai", type=int, default=1)
    a = ap.parse_args()
    from PIL import Image, ImageDraw, ImageFont
    if a.kandidat:
        daftar = cari_seed(a.mulai, a.kandidat)
        kol = 3
        w = 480
        baris = math.ceil(len(daftar) / kol)
        lembar = Image.new("RGB", (kol * (w + 10) + 10, baris * (w + 40) + 10), (24, 26, 22))
        d = ImageDraw.Draw(lembar)
        try:
            f = ImageFont.truetype("arialbd.ttf", 20)
        except OSError:
            f = ImageFont.load_default()
        for i, L in enumerate(daftar):
            im, _ = L.denah(W=w, label=False)
            x, y = 10 + (i % kol) * (w + 10), 10 + (i // kol) * (w + 40)
            lembar.paste(im, (x, y + 30))
            d.text((x, y + 4), f"seed {L.seed}  ·  {len(L.segmen_b)} punggung  ·  {len(L.bukaan_b)} bukaan",
                   fill=(240, 230, 200), font=f)
        out = ROOT / "maps/lembah-kapur-kandidat.png"
        lembar.save(out)
        print("kandidat:", [L.seed for L in daftar], "->", out)
        return
    L = Layout(a.seed if a.seed is not None else SEED_TERPILIH)
    im, H = L.denah()
    out = ROOT / "maps/lembah-kapur-denah.png"
    im.save(out)
    print(f"{NAMA} seed {L.seed}: {UKURAN} x {UKURAN} m, {len(L.markas)} markas, {len(L.tambang)} tambang, "
          f"{len(L.segmen_b)} punggung/sisi, {len(L.bukaan_b)} bukaan/sisi, {len(L.hutan_b)} hutan/sisi, "
          f"tinggi dasar {H.min():.1f}-{H.max():.1f} m")
    print("lolos aturan:", L.periksa(cetak=True))
    print(out)


if __name__ == "__main__":
    main()
