"""Buat model roket kecil (Rocket Pods Robot Roket Fraksi 2) dari fx-tracer-roket.glb: semua posisi x0,55.

✅ user 2026-11-28: "robot roket fraksi 2 8 kali nembak, 4 kiri 4 kanan roketnya lebih kecil asepnya lebih tipis".
"""
import json
from pathlib import Path
import struct

import numpy as np

GAME = Path(__file__).resolve().parents[1] / "game/RTSPC.sdd"
SKALA = 0.55


def main():
    src = GAME / "objects3d/fx-tracer-roket.glb"
    raw = bytearray(src.read_bytes())
    n_json = struct.unpack("<I", raw[12:16])[0]
    doc = json.loads(raw[20:20 + n_json])
    bin_start = 20 + n_json + 8
    for mesh in doc["meshes"]:
        for prim in mesh["primitives"]:
            acc = doc["accessors"][prim["attributes"]["POSITION"]]
            view = doc["bufferViews"][acc["bufferView"]]
            assert acc["componentType"] == 5126 and acc["type"] == "VEC3" and "byteStride" not in view
            off = bin_start + view.get("byteOffset", 0) + acc.get("byteOffset", 0)
            pos = np.frombuffer(raw, dtype="<f4", count=acc["count"] * 3, offset=off).copy() * SKALA
            raw[off:off + pos.nbytes] = pos.tobytes()
            acc["min"] = [v * SKALA for v in acc["min"]]
            acc["max"] = [v * SKALA for v in acc["max"]]
    text = json.dumps(doc, separators=(",", ":")).encode()
    text += b" " * (len(raw[20:20 + n_json]) - len(text)) if len(text) <= n_json else b""
    assert len(text) == n_json, "panjang JSON berubah"
    raw[20:20 + n_json] = text
    (GAME / "objects3d/fx-tracer-roket-kecil.glb").write_bytes(bytes(raw))
    (GAME / "objects3d/fx-tracer-roket-kecil.glb.lua").write_text(
        (GAME / "objects3d/fx-tracer-roket.glb.lua").read_text(encoding="utf-8"), encoding="utf-8")
    print("roket kecil", acc["min"], acc["max"])


if __name__ == "__main__":
    main()
