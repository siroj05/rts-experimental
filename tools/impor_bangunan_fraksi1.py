"""Port bangunan pelengkap dan bangkai bangunan Fraksi 1 dari aset aktif Unity."""

import json
import shutil

import numpy as np

from impor_markas import V2, convert, write_textures
from impor_medium_tank import GAME, load_glb
from impor_unit_fraksi1 import Pieces, saat_mesh


BANGUNAN = V2 / "Bangunan"
BARU = ("gardu", "gudang", "radar", "tiang_relay", "menara_pertahanan")
SEMUA = ("inti_komando", "pompa_minyak", "pabrik_kendaraan", "pabrik_robot", "ekstraktor_besi", *BARU)


def model_bergerak(stem, sumber):
    gltf, blob = load_glb(sumber)
    metadata = json.loads(sumber.with_suffix(".bagian.json").read_text(encoding="utf-8-sig"))
    bagian = {part["nama"]: part for part in metadata["bagian"]}
    atlas = write_textures(stem, gltf, blob, tile_size=512)
    pieces = Pieces()
    grup = {"badan": []}
    for node in gltf["nodes"]:
        if any(k in node for k in ("translation", "rotation", "scale", "matrix")):
            raise ValueError(f"Transform mesh belum diterapkan: {sumber}")
        if "mesh" in node:
            nama = node["name"].removeprefix("bagian_").removesuffix("_tim")
            if nama == "model":
                nama = "badan"
            grup.setdefault(nama, []).extend(gltf["meshes"][node["mesh"]]["primitives"])
    nol = np.zeros(3)
    for nama, primitives in grup.items():
        info = bagian[nama] if nama != "badan" else {}
        # Posisi vertex V2 sudah dalam koordinat global. Pieces memasangnya kembali di pivot lokal.
        geo = saat_mesh(gltf, blob, {"name": nama}, nol, atlas, primitives)
        pieces.piece(nama, info.get("pivot", nol), info.get("induk"), geo)
    if "laras" in bagian:
        ujung = min(grup["laras"], key=lambda p: gltf["accessors"][p["attributes"]["POSITION"]]["min"][2])
        batas = gltf["accessors"][ujung["attributes"]["POSITION"]]
        pivot = bagian["laras"]["pivot"]
        pieces.piece("moncong", [pivot[0], (batas["min"][1] + batas["max"][1]) / 2, batas["min"][2]], "laras")
    print(f"{stem}: {pieces.save(stem):,} segitiga")


def main():
    for key in BARU:
        stem = key.replace("_", "-")
        sumber = BANGUNAN / key / "Model.glb"
        if key in ("radar", "menara_pertahanan"):
            model_bergerak(stem, sumber)
        else:
            convert(stem, sumber, tile_size=512)

    for key in SEMUA:
        sumber = BANGUNAN / key / "Bangkai.glb"
        if key == "inti_komando":
            sumber = BANGUNAN / "IntiKomando/IntiKomando_Bangkai.glb"
        convert(key.replace("_", "-") + "-bangkai", sumber, tile_size=512)

    suara = V2 / "Suara/Resources/Tembakan/menara_pertahanan/menara_tembak.ogg"
    shutil.copyfile(suara, GAME / "sounds" / suara.name)


if __name__ == "__main__":
    main()
