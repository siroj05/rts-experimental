"""Jalankan uji kontrol Central Hill di salinan game Recoil headless."""

import argparse
from pathlib import Path
import shutil
import subprocess
import time

from uji_balance import ENGINE, GAME, ROOT


CASES = ("koridor", "koridor-stop", "rally", "rally-barat", "lereng", "artileri", "radar")
ERRORS = ("LUA_ERRRUN", "Fatal:", "stack traceback")


def run(case):
    scratch = ROOT / ".cache" / "uji-kontrol" / case
    game = scratch / "games/RTSPC.sdd"
    for folder in ("base", "fonts", "AI/Interfaces", "AI/Skirmish/NullAI"):
        shutil.copytree(ENGINE / folder, scratch / folder, dirs_exist_ok=True)
    (scratch / "maps").mkdir(exist_ok=True)
    shutil.copy2(ROOT / "maps/bukit-tengah-1v1.sdz", scratch / "maps")
    shutil.copytree(GAME, game, dirs_exist_ok=True)
    shutil.copy2(ROOT / "uji/kontrol_bukit.lua", game / "LuaRules/Gadgets/uji_kontrol.lua")
    with (game / "LuaUI/main.lua").open("a", encoding="utf-8") as ui:
        ui.write("""
local updateUji, dipercepat = Update, false
function Update(...)
    updateUji(...)
    if not dipercepat and Spring.GetGameFrame() >= 6 then
        dipercepat = true
        Spring.SendCommands("setspeed 10")
    end
end
""")
    start = (GAME / "gamedata/skenario/bukit-start.txt").read_text(encoding="utf-8")
    start = start.replace("GameStartDelay=1;", "GameStartDelay=1;\n MinSpeed=10;\n MaxSpeed=10;")
    start = start.replace("lawanuji=1;", f"lawanuji=0;uji_kontrol={case};")
    launch = scratch / "start.txt"
    launch.write_text(start, encoding="ascii")
    log = scratch / "uji.log"
    selesai = f"KONTROL, SELESAI, {case}"
    with log.open("wb") as stream:
        process = subprocess.Popen(
            [ENGINE / "spring-headless.exe", "--isolation", "--isolation-dir", scratch,
             "--write-dir", scratch, "--only-local", "--nocolor", "--hidden", launch],
            cwd=scratch, stdout=stream, stderr=subprocess.STDOUT,
        )
        try:
            deadline = time.monotonic() + 105
            while process.poll() is None and time.monotonic() < deadline:
                time.sleep(.25)
                content = log.read_text(encoding="utf-8", errors="replace")
                if selesai in content or any(error in content for error in ERRORS):
                    break
        finally:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=6)
    content = log.read_text(encoding="utf-8", errors="replace")
    for line in content.splitlines():
        if "KONTROL," in line or any(error in line for error in ERRORS):
            print(line, flush=True)
    return selesai in content and "KONTROL, GAGAL" not in content and not any(error in content for error in ERRORS)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", choices=CASES, action="append")
    args = parser.parse_args()
    results = [run(case) for case in args.case or CASES]
    return 0 if all(results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
