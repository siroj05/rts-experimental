"""Latih AI Brutal antarronde: mainkan ronde headless, catat gaya main mana yang menang per peta.

Pemakaian:
    python tools/latih_ai.py <start-script> [--ronde 12] [--lawan normal|hard|brutal] [--jobs 3] [--menit 30]

- Tiap ronde, tim Brutal mendapat gaya dari UCB1 atas statistik saat ini (rumus sama dengan
  LuaRules/ai/otak_brutal.lua `pilihGaya`), dipaksa lewat modoption ai_gaya_<tim>. Sisi Brutal bergantian
  antar-ronde supaya keuntungan posisi awal tidak ikut terhitung.
- Hasil ditulis ke game/RTSPC.sdd/gamedata/belajar_ai.lua per batch (`--jobs` ronde paralel), jadi batch berikutnya
  memakai statistik terbaru. Di game, AI membaca file ini saat ronde dimulai.
- Ronde tanpa pemenang (waktu habis atau error) tidak dihitung.
"""
import argparse
import math
import random
import re
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import uji_ronde

ROOT = Path(__file__).resolve().parents[1]
BERKAS = ROOT / "game/RTSPC.sdd/gamedata/belajar_ai.lua"
GAYA = ["seimbang", "serbu", "ekonomi", "lapis_baja"]


def baca():
    teks = BERKAS.read_text(encoding="utf-8")
    peta = {}
    for nama, isi in re.findall(r'\["([^"]+)"\] = \{(.*?)\n        \}', teks, re.S):
        peta[nama] = {g: {"main": int(m), "menang": int(w)}
                      for g, m, w in re.findall(r"(\w+) = \{main = (\d+), menang = (\d+)\}", isi)}
    return peta


def tulis(peta):
    baris = ["-- Statistik belajar antarronde AI Brutal (LuaRules/ai/otak_brutal.lua). Ditulis ulang oleh tools/latih_ai.py.",
             "-- peta[<Game.mapName>][<gaya>] = {main = ronde dimainkan, menang = ronde dimenangkan}.",
             "return {", "    versi = 1,", "    peta = {"]
    for nama in sorted(peta):
        baris.append(f'        ["{nama}"] = {{')
        for g in GAYA:
            s = peta[nama].get(g)
            if s:
                baris.append(f"            {g} = {{main = {s['main']}, menang = {s['menang']}}},")
        baris.append("        },")
    baris += ["    },", "}", ""]
    BERKAS.write_text("\n".join(baris), encoding="utf-8", newline="\n")


def pilih(stat):
    total = sum(s["main"] for s in stat.values())
    def nilai(g):
        s = stat.get(g, {"main": 0, "menang": 0})
        return (s["menang"] + 1) / (s["main"] + 2) + .35 * math.sqrt(math.log(total + 2) / (s["main"] + 1)) + random.random() * .04
    return max(GAYA, key=nilai)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("start")
    ap.add_argument("--ronde", type=int, default=12)
    ap.add_argument("--lawan", default="normal")
    ap.add_argument("--jobs", type=int, default=3)
    ap.add_argument("--menit", type=float, default=30)
    a = ap.parse_args()
    teks = (ROOT / a.start).read_text(encoding="utf-8")
    nama_peta = re.search(r"MapName=([^;]+);", teks).group(1)
    sekutu = {int(t): int(al) for t, al in re.findall(r"\[TEAM(\d+)\]\{[^}]*AllyTeam=(\d+);", teks)}
    peta = baca()
    nomor = 0
    while nomor < a.ronde:
        stat = peta.setdefault(nama_peta, {})
        tugas = []
        for k in range(min(a.jobs, a.ronde - nomor)):
            sisi = (nomor + k) % 2  # ally Brutal
            gaya = pilih(stat)
            opsi = [f"tingkat_ai_{t}={'brutal' if al == sisi else a.lawan}" for t, al in sekutu.items()]
            opsi += [f"ai_gaya_{t}={gaya}" for t, al in sekutu.items() if al == sisi]
            tugas.append((nomor + k + 1, sisi, gaya, opsi))
        with ThreadPoolExecutor(max_workers=a.jobs) as pool:
            hasil = list(pool.map(lambda t: (t, uji_ronde.jalankan(a.start, "latih", t[0], a.menit, t[3], True)), tugas))
        for (seed, sisi, gaya, _), h in hasil:
            akhir = [r for r in h["baris"] if r[0] == "HASIL"]
            pemenang = int(akhir[-1][2].split("=")[1]) if akhir else None
            status = "tidak dihitung" if pemenang is None or pemenang < 0 or h["error"] else (
                "MENANG" if pemenang == sisi else "kalah")
            print(f"ronde {seed}: brutal sisi {sisi} gaya {gaya} vs {a.lawan}: {status}"
                  + (f" ({akhir[-1][1]} s)" if akhir else ""))
            if status != "tidak dihitung":
                s = stat.setdefault(gaya, {"main": 0, "menang": 0})
                s["main"] += 1
                s["menang"] += status == "MENANG"
        nomor += len(tugas)
        tulis(peta)
    for g in GAYA:
        s = peta[nama_peta].get(g)
        if s:
            print(f"{nama_peta} {g}: {s['menang']}/{s['main']}")


if __name__ == "__main__":
    raise SystemExit(main())
