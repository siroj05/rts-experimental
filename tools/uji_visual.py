"""Uji visual Recoil grafis: jalankan start script di salinan terisolasi, gerakkan kamera, ambil screenshot, catat fps.

Pemakaian:
    python tools/uji_visual.py <start-script> <nama-run> [--hook tools/uji_visual/<hook>.lua] [--spectator]
        [--opsi kunci=nilai ...] [--batas 600]

- Start script relatif terhadap root repo (mis. game/RTSPC.sdd/gamedata/skenario/pinus-start.txt).
- Hook Lua ditambahkan ke akhir LuaUI/main.lua di salinan (game asli tidak berubah). Hook mendefinisikan SHOTS
  dan opsional preUpdate(); lihat tools/uji_visual/README.md.
- `--spectator` menjadikan PLAYER0 penonton (semua tim AI); `--opsi` menambah MODOPTIONS.
- Hasil: .cache/uji-visual/<nama-run>/ berisi uji.log, infolog.txt, dan shot-NN-<nama>.png (urut).
  Baris log `VISUAL, SHOT, ...` mencatat frame, fps, jumlah unit, dan target kamera.
"""
import argparse
import re
import shutil
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / ".deps/recoil/2026.09.03"
GAME = ROOT / "game/RTSPC.sdd"
HOOKS = ROOT / "tools/uji_visual"
ERRORS = ("LUA_ERRRUN", "stack traceback", "Fatal:")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("start")
    ap.add_argument("nama")
    ap.add_argument("--hook", default=str(HOOKS / "umum.lua"))
    ap.add_argument("--spectator", action="store_true")
    ap.add_argument("--opsi", nargs="*", default=[])
    ap.add_argument("--batas", type=float, default=600)
    ap.add_argument("--lebar", type=int, default=1600)
    ap.add_argument("--tinggi", type=int, default=900)
    a = ap.parse_args()

    scratch = ROOT / ".cache/uji-visual" / a.nama
    if scratch.exists():
        shutil.rmtree(scratch)
    for folder in ("base", "fonts", "AI/Interfaces", "AI/Skirmish/NullAI"):
        shutil.copytree(ENGINE / folder, scratch / folder, dirs_exist_ok=True)
    (scratch / "maps").mkdir(parents=True, exist_ok=True)
    for sdz in (ROOT / "maps").glob("*.sdz"):
        shutil.copy2(sdz, scratch / "maps")
    game = scratch / "games/RTSPC.sdd"
    shutil.copytree(GAME, game, dirs_exist_ok=True)
    (scratch / "springsettings.cfg").write_text(
        f"Fullscreen=0\nXResolutionWindowed={a.lebar}\nYResolutionWindowed={a.tinggi}\n"
        "WindowPosX=40\nWindowPosY=40\nVSync=0\nWindowBorderless=0\n", encoding="ascii")
    hook = (HOOKS / "dasar.lua").read_text(encoding="utf-8") + "\n" + Path(a.hook).read_text(encoding="utf-8")
    with (game / "LuaUI/main.lua").open("a", encoding="utf-8") as ui:
        ui.write("\n" + hook)

    start = (ROOT / a.start).read_text(encoding="utf-8")
    start = start.replace("GameStartDelay=1;", "GameStartDelay=1; MaxSpeed=20;")
    if a.spectator:
        start = re.sub(r"(\[PLAYER0\]\{[^}]*Spectator=)0", r"\g<1>1", start)
    if a.opsi:
        start = re.sub(r"\[MODOPTIONS\]\{", "[MODOPTIONS]{" + "".join(f"{o};" for o in a.opsi), start)
    (scratch / "start.txt").write_text(start, encoding="ascii")

    log = scratch / "uji.log"
    with log.open("wb") as stream:
        p = subprocess.Popen([ENGINE / "spring.exe", "--isolation", "--isolation-dir", scratch, "--write-dir", scratch,
                              "--only-local", "--window", scratch / "start.txt"],
                             cwd=scratch, stdout=stream, stderr=subprocess.STDOUT)
        t0 = time.monotonic()
        while p.poll() is None and time.monotonic() - t0 < a.batas:
            time.sleep(1)
            text = log.read_text(encoding="utf-8", errors="replace")
            if "VISUAL, SELESAI" in text:
                time.sleep(3)
                break
            if any(e in text for e in ERRORS):
                time.sleep(2)
                break
        if p.poll() is None:
            p.terminate()
            try:
                p.wait(timeout=8)
            except subprocess.TimeoutExpired:
                p.kill()

    text = log.read_text(encoding="utf-8", errors="replace")
    names = [m.group(1) for m in re.finditer(r"VISUAL, SHOT, \d+, ([^,]+),", text)]
    shots = sorted((scratch / "screenshots").glob("*.png")) if (scratch / "screenshots").exists() else []
    for k, shot in enumerate(shots):
        label = names[k] if k < len(names) else f"x{k}"
        shot.rename(scratch / f"shot-{k:02d}-{label}.png")
    for line in text.splitlines():
        if "VISUAL," in line or any(e in line for e in ERRORS):
            print(line)
    print("folder:", scratch)
    return 1 if any(e in text for e in ERRORS) else 0


if __name__ == "__main__":
    raise SystemExit(main())
