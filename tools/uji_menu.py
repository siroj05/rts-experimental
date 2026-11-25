"""Uji visual menu skirmish: jalankan menu Recoil di salinan terisolasi, ambil screenshot, lalu keluar.

Pemakaian:
    python tools/uji_menu.py <nama-run> [--lua "<kode Lua per langkah>" ...] [--lebar 1280 --tinggi 720]

- Tiap `--lua` adalah satu langkah: kodenya dijalankan di dalam chunk LuaMenu/main.lua (bisa mengubah variabel lokal
  menu seperti `selectedMode`, `selectedMap`, `selected`), lalu 40 frame kemudian screenshot diambil. Tanpa `--lua`
  hanya satu screenshot keadaan awal.
- Hasil: .cache/uji-menu/<nama-run>/shot-NN.png dan uji.log.
"""
import argparse
import shutil
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / ".deps/recoil/2026.09.03"
SALIN = ["skenario/bukit.lua", "skenario/bukit-start.txt", "skenario/sungai.lua", "skenario/sungai-start.txt",
         "skenario/pinus.lua", "skenario/pinus-start.txt", "skenario/hijau.lua", "skenario/hijau-start.txt",
         "profil_ai.lua"]
PETA = ["mapinfo-bukit-tengah.lua", "mapinfo-lembah-sungai.lua", "mapinfo-lintasan-pinus-4v4.lua",
        "mapinfo-punggung-hijau-4v4.lua"]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("nama")
    ap.add_argument("--lua", nargs="*", default=[""])
    ap.add_argument("--lebar", type=int, default=1280)
    ap.add_argument("--tinggi", type=int, default=720)
    a = ap.parse_args()

    scratch = ROOT / ".cache/uji-menu" / a.nama
    if scratch.exists():
        shutil.rmtree(scratch)
    for folder in ("base", "fonts"):
        shutil.copytree(ENGINE / folder, scratch / folder, dirs_exist_ok=True)
    (scratch / "maps").mkdir(parents=True)
    (scratch / "screenshots").mkdir()
    for sdz in (ROOT / "maps").glob("*.sdz"):
        shutil.copy2(sdz, scratch / "maps")
    games = scratch / "games"
    shutil.copytree(ROOT / "game/RTSPC.sdd", games / "RTSPC.sdd")
    shutil.copytree(ROOT / "menu/RTSPCMenu.sdd", games / "RTSPCMenu.sdd")
    lua_menu = games / "RTSPCMenu.sdd/LuaMenu"
    for f in SALIN:
        shutil.copy2(ROOT / "game/RTSPC.sdd/gamedata" / f, lua_menu)
    for f in PETA:
        shutil.copy2(ROOT / "maps" / f, lua_menu)
    langkah = "\n".join(f"    function() {kode} end," for kode in (a.lua or [""]))
    with (lua_menu / "main.lua").open("a", encoding="utf-8") as f:
        f.write(f"""
-- Hook uji tools/uji_menu.py
local ujiLangkah = {{
{langkah}
}}
local ujiFrame, ujiIdx, ujiAmbil = 0, 1, false
local ujiUpdate = Update
function Update(...)
    if ujiUpdate then ujiUpdate(...) end
    ujiFrame = ujiFrame + 1
    if ujiFrame == 30 and ujiLangkah[ujiIdx] then ujiLangkah[ujiIdx]() end
    if ujiFrame == 70 then ujiAmbil = true end
end
local ujiDraw = DrawScreen
function DrawScreen(...)
    if ujiDraw then ujiDraw(...) end
    if ujiAmbil then
        ujiAmbil = false
        local w, h = gl.GetViewSizes()
        gl.SaveImage(0, 0, w, h, string.format("screenshots/menu-%02d.png", ujiIdx), {{alpha = false}})
        Spring.Echo("MENU, SHOT, " .. ujiIdx)
        ujiIdx, ujiFrame = ujiIdx + 1, 0
        if not ujiLangkah[ujiIdx] then Spring.Echo("MENU, SELESAI") end
    end
end
""")
    (scratch / "springsettings.cfg").write_text(
        f"Fullscreen=0\nXResolutionWindowed={a.lebar}\nYResolutionWindowed={a.tinggi}\nWindowPosX=40\nWindowPosY=40\n"
        "VSync=1\n", encoding="ascii")
    log = scratch / "uji.log"
    with log.open("wb") as stream:
        p = subprocess.Popen([ENGINE / "spring.exe", "--isolation", "--isolation-dir", scratch, "--write-dir", scratch,
                              "--only-local", "--window", "--menu", "RTSPCMenu.sdd"],
                             cwd=scratch, stdout=stream, stderr=subprocess.STDOUT)
        t0 = time.monotonic()
        while p.poll() is None and time.monotonic() - t0 < 90:
            time.sleep(1)
            if "MENU, SELESAI" in log.read_text(encoding="utf-8", errors="replace"):
                time.sleep(3)
                break
        if p.poll() is None:
            p.terminate()
            try:
                p.wait(timeout=8)
            except subprocess.TimeoutExpired:
                p.kill()
    shots = sorted((scratch / "screenshots").glob("*.png")) if (scratch / "screenshots").exists() else []
    for k, shot in enumerate(shots):
        shot.rename(scratch / f"shot-{k:02d}.png")
    text = log.read_text(encoding="utf-8", errors="replace")
    for line in text.splitlines():
        if "MENU," in line or "Error" in line:
            print(line)
    print("folder:", scratch, "shots:", len(shots))


if __name__ == "__main__":
    raise SystemExit(main())
