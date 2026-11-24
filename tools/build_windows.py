"""Buat paket RTS PC v3 mandiri dari commit Git dan rilis Recoil yang dikunci."""

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
from tempfile import TemporaryDirectory
from zipfile import ZIP_DEFLATED, ZipFile


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "dist/windows/RTS-PC-v3-win-x64.exe"


def archive_sources(source, temp, revision):
    snapshot = temp / "snapshot.tar"
    subprocess.run(["git", "archive", f"--output={snapshot}", revision, "game", "maps", "menu", "README.md",
                    "config/windows-defaults.cfg", "dependencies.windows.json", "tools/launcher_windows.cs"],
                   cwd=ROOT, check=True)
    source.mkdir()
    subprocess.run(["tar.exe", "-xf", snapshot, "-C", source], check=True)


def stage_engine(runtime, temp, package):
    archive = ROOT / ".cache/downloads" / package["arsip"]
    if not archive.is_file():
        archive = temp / package["arsip"]
        subprocess.run(["curl.exe", "--fail", "--location", "--retry", "2", "--connect-timeout", "15",
                        "--max-time", "240", "--output", archive, package["url"]], check=True)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != package["sha256"]:
        raise ValueError(f"SHA-256 arsip Recoil tidak cocok: {archive}")
    engine = temp / "engine"
    engine.mkdir()
    subprocess.run(["tar.exe", "-xf", archive, "-C", engine], check=True)
    for folder in ("base", "doc", "fonts", "AI/Interfaces/C", "AI/Skirmish/NullAI"):
        shutil.copytree(engine / folder, runtime / folder)
    for path in (*engine.glob("*.dll"), *(engine / name for name in (
            "spring.exe", "cmdcolors.txt", "ctrlpanel.txt", "README-SDL.txt"))):
        shutil.copy2(path, runtime / path.name)
    (runtime / "isolated.txt").touch()


def stage_game(source, runtime):
    data = source / "game/RTSPC.sdd/gamedata"
    menu = runtime / "games/RTSPCMenu.sdd/LuaMenu"
    shutil.copytree(source / "game/RTSPC.sdd", runtime / "games/RTSPC.sdd")
    shutil.copytree(source / "menu/RTSPCMenu.sdd", menu.parent)
    for name in ("skenario/bukit.lua", "skenario/bukit-start.txt", "skenario/sungai.lua",
                 "skenario/sungai-start.txt", "skenario/pinus.lua", "skenario/pinus-start.txt",
                 "skenario/hijau.lua", "skenario/hijau-start.txt", "profil_ai.lua"):
        shutil.copy2(data / name, menu)
    for name in ("mapinfo-bukit-tengah.lua", "mapinfo-lembah-sungai.lua", "mapinfo-lintasan-pinus-4v4.lua",
                 "mapinfo-punggung-hijau-4v4.lua"):
        shutil.copy2(source / "maps" / name, menu)
    (runtime / "maps").mkdir()
    for path in sorted((source / "maps").glob("*.sdz")):
        shutil.copy2(path, runtime / "maps" / path.name)
    shutil.copy2(source / "README.md", runtime)
    shutil.copy2(source / "config/windows-defaults.cfg", runtime / "springsettings.cfg")


def main():
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    framework = Path(os.environ["WINDIR"]) / "Microsoft.NET/Framework64/v4.0.30319"
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(prefix="build-", dir=OUTPUT.parent) as folder:
        temp = Path(folder)
        source, runtime = temp / "source", temp / "runtime"
        runtime.mkdir()
        archive_sources(source, temp, revision)
        packages = json.loads((source / "dependencies.windows.json").read_text(encoding="utf-8"))
        package = next(p for p in packages if p["nama"] == "Recoil Engine")
        stage_engine(runtime, temp, package)
        stage_game(source, runtime)
        (runtime / "BUILD.txt").write_text(
            f"RTS PC v3 Windows x64\nCommit game: {revision}\n"
            f"Recoil: {package['versi']}\nRilis: {package['url']}\n"
            f"Sumber Recoil: https://github.com/beyond-all-reason/RecoilEngine/tree/{package['versi']}\n"
            "Lisensi engine ada di doc/.\n", encoding="utf-8")

        launcher = runtime / "RTS PC.exe"
        subprocess.run([framework / "csc.exe", "/nologo", "/optimize+", "/target:winexe", "/platform:x64",
                        "/reference:System.Windows.Forms.dll", "/reference:System.IO.Compression.dll",
                        "/reference:System.IO.Compression.FileSystem.dll", f"/out:{launcher}",
                        source / "tools/launcher_windows.cs"], check=True)
        build = temp / OUTPUT.name
        shutil.copy2(launcher, build)
        # Mode append mencatat posisi ZIP relatif ke awal file PE.
        with ZipFile(build, "a", compression=ZIP_DEFLATED, compresslevel=6) as zip_file:
            for path in sorted(runtime.rglob("*")):
                if path.is_file():
                    zip_file.write(path, path.relative_to(runtime).as_posix())
            zip_file.comment = f"RTSPC3:{revision[:12]}".encode("ascii")
        with ZipFile(build) as zip_file:
            invalid = zip_file.testzip()
            if invalid is not None:
                raise ValueError(f"Gagal memverifikasi isi paket: {invalid}")
        os.replace(build, OUTPUT)
    print(f"{OUTPUT} | {OUTPUT.stat().st_size:,} byte | {revision[:12]}")


if __name__ == "__main__":
    main()
