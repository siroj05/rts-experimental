"""Uji ronde headless: jalankan pertandingan AI vs AI (atau AI vs pemain diam) dan catat statistik tiap menit.

Pemakaian:
    python tools/uji_ronde.py <start-script> [--nama run] [--seed 1 2 3] [--menit 30] [--opsi k=v ...]
        [--semua-ai] [--jobs 3]

- `--semua-ai`: tim 0 (pemain) juga dikendalikan AI skenario (PLAYER0 jadi penonton, tim 0 diberi AI NullAI
  supaya AI skenario mengambil alih). Tanpa ini tim 0 diam.
- Hasil per run: .cache/uji-ronde/<nama>-<seed>/uji.log dan ringkasan di layar; semua run: hasil.json.
Baris log: `RONDE, TIM, detik, tim, tempur=, bangunan=, insinyur=, mati=, besi=stok+pemasukan, energi=..., jenis`
dan `RONDE, SKOR, detik, skor0, skor1, pemilik titik`, `RONDE, KONTAK, detik`, `RONDE, HASIL, detik, pemenang=`.
"""
import argparse
import json
import re
import shutil
import subprocess
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / ".deps/recoil/2026.09.03"
GAME = ROOT / "game/RTSPC.sdd"
ERRORS = ("LUA_ERRRUN", "stack traceback", "Fatal:")


def siapkan_start(teks, seed, menit, opsi, semua_ai):
    teks = teks.replace("GameStartDelay=1;", "GameStartDelay=1;\n    MinSpeed=40;\n    MaxSpeed=40;")
    teks = re.sub(r"FixedRNGSeed=\d+;", f"FixedRNGSeed={seed};", teks)
    tambahan = f"uji_menit={menit};" + "".join(f"{o};" for o in opsi)
    teks = re.sub(r"\[MODOPTIONS\]\{", "[MODOPTIONS]{" + tambahan, teks)
    if semua_ai:
        teks = re.sub(r"(\[PLAYER0\]\{[^}]*Spectator=)0", r"\g<1>1", teks)
        if not re.search(r"\[AI\d+\]\{[^}]*Team=0;", teks):
            ids = [int(n) for n in re.findall(r"\[AI(\d+)\]", teks)]
            nomor = max(ids) + 1 if ids else 0
            teks = teks.replace("[MODOPTIONS]", f"[AI{nomor}]{{Name=Blue AI;ShortName=NullAI;Version=0.1;Team=0;Host=0;}}\n    [MODOPTIONS]", 1)
    return teks


def jalankan(start, nama, seed, menit, opsi, semua_ai):
    scratch = ROOT / ".cache/uji-ronde" / f"{nama}-{seed}"
    if scratch.exists():
        shutil.rmtree(scratch)
    for folder in ("base", "fonts", "AI/Interfaces", "AI/Skirmish/NullAI"):
        shutil.copytree(ENGINE / folder, scratch / folder, dirs_exist_ok=True)
    (scratch / "maps").mkdir(parents=True, exist_ok=True)
    for sdz in (ROOT / "maps").glob("*.sdz"):
        shutil.copy2(sdz, scratch / "maps")
    game = scratch / "games/RTSPC.sdd"
    shutil.copytree(GAME, game, dirs_exist_ok=True)
    shutil.copy2(ROOT / "tools/uji_ronde/catat.lua", game / "LuaRules/Gadgets/uji_ronde_catat.lua")
    with (game / "LuaUI/main.lua").open("a", encoding="utf-8") as ui:
        ui.write("""
local updateRonde, dipercepat = Update, false
function Update(...)
    if updateRonde then updateRonde(...) end
    if not dipercepat and Spring.GetGameFrame() >= 6 then
        dipercepat = true
        Spring.SendCommands("setspeed 40")
    end
end
""")
    teks = siapkan_start((ROOT / start).read_text(encoding="utf-8"), seed, menit, opsi, semua_ai)
    (scratch / "start.txt").write_text(teks, encoding="ascii")
    log = scratch / "uji.log"
    t0 = time.monotonic()
    with log.open("wb") as stream:
        p = subprocess.Popen([ENGINE / "spring-headless.exe", "--isolation", "--isolation-dir", scratch, "--write-dir", scratch,
                              "--only-local", "--nocolor", "--hidden", scratch / "start.txt"],
                             cwd=scratch, stdout=stream, stderr=subprocess.STDOUT)
        try:
            while p.poll() is None and time.monotonic() - t0 < menit * 60 / 4 + 180:
                time.sleep(.5)
                text = log.read_text(encoding="utf-8", errors="replace")
                if "RONDE, SELESAI" in text or any(e in text for e in ERRORS):
                    break
        finally:
            if p.poll() is None:
                p.terminate()
                try:
                    p.wait(timeout=6)
                except subprocess.TimeoutExpired:
                    p.kill()
    text = log.read_text(encoding="utf-8", errors="replace")
    rows = [r.split(", ") for r in re.findall(r"RONDE, ([^\r\n]+)", text)]
    errors = [l for l in text.splitlines() if any(e in l for e in ERRORS)]
    return {"nama": nama, "seed": seed, "detik_nyata": round(time.monotonic() - t0, 1), "baris": rows, "error": errors[:10]}


def ringkas(hasil):
    print(f"== {hasil['nama']} seed {hasil['seed']} ({hasil['detik_nyata']} s nyata)")
    for e in hasil["error"]:
        print("   ERROR", e)
    for r in hasil["baris"]:
        if r[0] in ("SKOR", "HASIL", "KONTAK") or (r[0] == "TIM" and int(r[1]) % 240 == 0):
            print("  ", ", ".join(r))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("start")
    ap.add_argument("--nama", default="ronde")
    ap.add_argument("--seed", type=int, nargs="+", default=[1])
    ap.add_argument("--menit", type=float, default=30)
    ap.add_argument("--opsi", nargs="*", default=[])
    ap.add_argument("--semua-ai", action="store_true")
    ap.add_argument("--jobs", type=int, default=3)
    a = ap.parse_args()
    with ThreadPoolExecutor(max_workers=a.jobs) as pool:
        semua = list(pool.map(lambda s: jalankan(a.start, a.nama, s, a.menit, a.opsi, a.semua_ai), a.seed))
    for h in semua:
        ringkas(h)
    out = ROOT / ".cache/uji-ronde" / f"{a.nama}-hasil.json"
    out.write_text(json.dumps(semua, indent=1), encoding="utf-8")
    print("hasil:", out)
    return 1 if any(h["error"] for h in semua) else 0


if __name__ == "__main__":
    raise SystemExit(main())
