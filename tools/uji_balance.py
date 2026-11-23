"""Uji pembukaan, peran unit, dan pemulihan AI di Recoil headless."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import re
import shutil
import subprocess
import time


ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / ".deps/recoil/2026.09.03"
GAME = ROOT / "game/RTSPC.sdd"
OPENINGS = ("kendaraan", "robot", "ekonomi", "ekonomi_paralel")
CASES = (*OPENINGS, "peran", "pulih", "taktik")
EVENT = re.compile(r"\bBALANCE, ([^\r\n]+)")
ERRORS = ("LUA_ERRRUN", "stack traceback", "Fatal:")


def run(case, seed, output):
    scratch = output / f"{case}-{seed}"
    game = scratch / "games/RTSPC.sdd"
    for folder in ("base", "fonts", "AI/Interfaces", "AI/Skirmish/NullAI"):
        shutil.copytree(ENGINE / folder, scratch / folder, dirs_exist_ok=True)
    (scratch / "maps").mkdir(exist_ok=True)
    shutil.copyfile(ROOT / "maps/bukit-tengah-1v1.sdz", scratch / "maps/bukit-tengah-1v1.sdz")
    shutil.copytree(GAME, game, dirs_exist_ok=True)
    shutil.copyfile(ROOT / "uji/balance_bukit.lua", game / "LuaRules/Gadgets/uji_balance.lua")
    with (game / "LuaUI/main.lua").open("a", encoding="utf-8") as ui:
        ui.write("""
local updateAwal, dipercepat = Update, false
function Update(...)
    updateAwal(...)
    if not dipercepat and Spring.GetGameFrame() >= 6 then
        dipercepat = true
        Spring.SendCommands("setspeed 10")
    end
end
""")
    if case == "pulih":
        # Beri waktu pemulihan walau AI menguasai semua titik dalam fixture.
        map_rules = game / "gamedata/skenario/bukit.lua"
        content = map_rules.read_text(encoding="utf-8")
        map_rules.write_text(content.replace("targetSkor = 1000", "targetSkor = 999999"), encoding="utf-8")
    config = (GAME / "gamedata/skenario/bukit-start.txt").read_text(encoding="utf-8")
    config = config.replace("GameStartDelay=1;", "GameStartDelay=1;\n MinSpeed=10;\n MaxSpeed=10;")
    config = config.replace("FixedRNGSeed=1;", f"FixedRNGSeed={seed};")
    config = config.replace("ekonomi=1;", f"ekonomi=1;uji_balance={case};")
    if case == "peran":
        config = config.replace("lawanuji=1;", "lawanuji=0;")
    script = scratch / "start.txt"
    script.write_text(config, encoding="ascii")
    log = scratch / "uji.log"
    with log.open("wb") as stream:
        process = subprocess.Popen(
            [ENGINE / "spring-headless.exe", "--isolation", "--isolation-dir", scratch,
             "--write-dir", scratch, "--only-local", "--nocolor", "--hidden", script],
            cwd=scratch, stdout=stream, stderr=subprocess.STDOUT,
        )
        try:
            deadline = time.monotonic() + 145
            while process.poll() is None and time.monotonic() < deadline:
                time.sleep(.3)
                text = log.read_text(encoding="utf-8", errors="replace")
                if f"BALANCE, DONE, {case}" in text or any(error in text for error in ERRORS):
                    break
        finally:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=6)
    text = log.read_text(encoding="utf-8", errors="replace")
    if f"BALANCE, DONE, {case}" not in text or any(error in text for error in ERRORS):
        raise RuntimeError(f"Pengujian {case}/{seed} gagal. Baca {log}")
    events = [row.split(", ") for row in EVENT.findall(text)]
    summary = [event for event in events if event[0] in ("RESULT", "RECOVERY", "ROLE", "DEFENSE")]
    print(f"{case}/{seed} {summary}", flush=True)
    return {"case": case, "seed": seed, "events": events}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", choices=CASES, action="append")
    parser.add_argument("--seed", type=int, nargs="+", default=[1])
    parser.add_argument("--output", type=Path, default=ROOT / ".cache/balance-bukit")
    parser.add_argument("--jobs", type=int, default=3)
    args = parser.parse_args()
    output = args.output.resolve()
    cases = args.case or CASES
    runs = [(case, seed) for case in cases for seed in (args.seed if case in OPENINGS else args.seed[:1])]
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = [pool.submit(run, case, seed, output) for case, seed in runs]
        report = [future.result() for future in futures]
    (output / "hasil.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
