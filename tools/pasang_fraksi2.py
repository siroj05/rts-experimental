"""Pasang 15 aset Fraksi 2 yang sudah lulus uji batch ke game aktif.

Sumber: `.cache/kandidat/fraksi-2/batch-recoil/` (enam tank) dan `batch-recoil/ekspor-recoil/` (sembilan aset
yang diekspor dan diuji 2026-11-28). File diberi nama ulang menurut kunci unit (`<kunci>.glb`, `<kunci>-bangkai.glb`)
supaya pencarian bangkai otomatis di `gamedata/defs.lua` ikut bekerja.

Hasil:
- `objects3d/`, `unittextures/`: model, sidecar, dan atlas resolusi penuh (tekstur tidak diperkecil).
- `gamedata/rig_fraksi2.lua`: rig roda/track/langkah/elevasi per kunci unit.
- `gamedata/ukuran_fraksi2.lua`: ukuran model (elmo) untuk volume tumbukan dan tapak.
- `gamedata/<kunci>-pintu.lua`, `gamedata/tank_insinyur_f2-rig.lua`, `scripts/pabrik_fraksi2.lua`,
  `scripts/tank_insinyur_f2.lua`.
- `unitpics/<kunci>.png` dan `LuaUI/potret/<kunci>.png` lewat buat_potret_hud.py.
"""

import json
from pathlib import Path
import re
import shutil
import struct

import numpy as np

REPO = Path(__file__).resolve().parents[1]
BATCH = REPO / ".cache/kandidat/fraksi-2/batch-recoil"
GAME = REPO / "game/RTSPC.sdd"

# kunci unit -> folder paket relatif terhadap BATCH
PAKET = {
    "pengintai_f2": "scout-tank",
    "tank_ringan_f2": "tank-ringan",
    "medium_tank_f2": "medium-tank",
    "medium_tank_destroyer_f2": "medium-destroyer",
    "heavy_tank_f2": "heavy-tank",
    "tank_insinyur_f2": "tank-insinyur",
    "robot_infanteri_f2": "ekspor-recoil/robot-infanteri-f2",
    "robot_roket_f2": "ekspor-recoil/robot-roket-f2",
    "inti_komando_f2": "ekspor-recoil/inti-komando-f2",
    "pabrik_kendaraan_f2": "ekspor-recoil/pabrik-kendaraan-f2",
    "pabrik_robot_f2": "ekspor-recoil/pabrik-robot-f2",
    "menara_pertahanan_f2": "ekspor-recoil/menara-pertahanan-f2",
    "gudang_f2": "ekspor-recoil/gudang-f2",
    "tiang_relay_f2": "ekspor-recoil/tiang-relay-f2",
    "gardu_f2": "ekspor-recoil/gardu-f2",
    # Artileri F2: diekspor Claude 2026-11-28 (blender-assets/fraksi-2/tank-artilery-f2-review/ekspor_artileri_f2.py
    # lalu siapkan_recoil_artileri_f2.py), di luar batch.
    "artileri_ringan_f2": "../artileri",
}


def load_glb(path):
    raw = path.read_bytes()
    size = struct.unpack("<I", raw[12:16])[0]
    return json.loads(raw[20:20 + size])


def bounds(path, skip=("laras", "moncong")):
    """Batas model (elmo) dan batas lambung tanpa laras."""
    doc = load_glb(path)
    nodes = doc["nodes"]
    parent = {c: i for i, n in enumerate(nodes) for c in n.get("children", [])}

    def chain(i):
        names, offset = [], np.zeros(3)
        while i is not None:
            names.append(nodes[i]["name"])
            offset += nodes[i].get("translation", [0, 0, 0])
            i = parent.get(i)
        return names, offset

    full = [np.full(3, 1e9), np.full(3, -1e9)]
    hull = [np.full(3, 1e9), np.full(3, -1e9)]
    for i, node in enumerate(nodes):
        if "mesh" not in node:
            continue
        names, offset = chain(i)
        if re.fullmatch(r"track_(kiri|kanan)_\d+", node["name"]):
            continue
        for prim in doc["meshes"][node["mesh"]]["primitives"]:
            acc = doc["accessors"][prim["attributes"]["POSITION"]]
            lo, hi = np.array(acc["min"]) + offset, np.array(acc["max"]) + offset
            full = [np.minimum(full[0], lo), np.maximum(full[1], hi)]
            if not any(n.startswith(skip) for n in names):
                hull = [np.minimum(hull[0], lo), np.maximum(hull[1], hi)]
    return full, hull


def lua(value, indent=""):
    if isinstance(value, dict):
        inner = indent + "    "
        rows = [f"{inner}{k} = {lua(v, inner)}," for k, v in value.items()]
        return "{\n" + "\n".join(rows) + "\n" + indent + "}"
    if isinstance(value, (list, tuple)):
        return "{" + ", ".join(lua(v, indent) for v in value) + "}"
    if isinstance(value, str):
        return json.dumps(value)
    return repr(round(float(value), 2))


def main():
    rigs, sizes = [], {}
    for key, folder in PAKET.items():
        src = BATCH / folder
        manifest = json.loads((src / "manifest-kandidat.json").read_text(encoding="utf-8"))
        target = manifest["recoil"]
        stem = key.replace("_", "-")
        for phase, suffix in (("aset", ""), ("bangkai", "-bangkai")):
            glb = src / target[phase]
            side = glb.with_suffix(".glb.lua").read_text(encoding="utf-8")
            texs = re.findall(r'tex([12]) = "([^"]+)"', side)
            assert len(texs) == 2, glb
            for slot, name in texs:
                new = f"{stem}{suffix}-tex{slot}.png"
                shutil.copyfile(src / target["tekstur"] / name, GAME / "unittextures" / new)
                side = side.replace(f'"{name}"', f'"{new}"')
            shutil.copyfile(glb, GAME / "objects3d" / f"{stem}{suffix}.glb")
            (GAME / "objects3d" / f"{stem}{suffix}.glb.lua").write_text(side, encoding="utf-8")
        if "rig" in target:
            row = (src / target["rig"]).read_text(encoding="utf-8").strip()
            assert row.startswith("return {"), key
            rigs.append(f"    {key} = {row.removeprefix('return ')},\n")
            if key == "tank_insinyur_f2":
                shutil.copyfile(src / target["rig"], GAME / "gamedata" / "tank_insinyur_f2-rig.lua")
        if "pintu" in target:
            shutil.copyfile(src / target["pintu"], GAME / "gamedata" / f"{stem}-pintu.lua")
        if "skrip_unit" in target:
            name = Path(target["skrip_unit"]).name
            shutil.copyfile(src / target["skrip_unit"], GAME / "scripts" / name)
        full, hull = bounds(GAME / "objects3d" / f"{stem}.glb")
        sizes[key] = {"model": (full[1] - full[0]).tolist(), "lambung": (hull[1] - hull[0]).tolist(),
                      "tengah_lambung": ((hull[1] + hull[0]) / 2).tolist()}
        print(key, np.round(full[1] - full[0], 1), "lambung", np.round(hull[1] - hull[0], 1))

    head = "-- Dibuat tools/pasang_fraksi2.py dari paket batch Fraksi 2 (lulus uji 2026-11-28). Jangan disunting tangan.\n"
    (GAME / "gamedata/rig_fraksi2.lua").write_text(head + "return {\n" + "".join(rigs) + "}\n", encoding="utf-8")
    (GAME / "gamedata/ukuran_fraksi2.lua").write_text(
        head + "-- Ukuran elmo: {x lebar, y panjang, z tinggi} dari GLB Recoil; lambung tanpa laras.\nreturn "
        + lua(sizes) + "\n", encoding="utf-8")

    import buat_potret_hud as potret
    target = GAME / "LuaUI" / "potret"
    for key in PAKET:
        stem = key.replace("_", "-")
        potret.potret(stem, target)
        shutil.copyfile(target / f"{stem}.png", GAME / "unitpics" / f"{stem}.png")


if __name__ == "__main__":
    main()
