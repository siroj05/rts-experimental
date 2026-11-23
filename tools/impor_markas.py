"""Port aset markas v2 ke format bagian dan tekstur bawaan Recoil."""

from io import BytesIO
import json
from math import atan2, ceil, sqrt
from pathlib import Path
import struct

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from impor_medium_tank import ELMO_PER_METER, GAME, ROOT, load_glb


V2 = ROOT.parent / "rts-pc-v2" / "Assets" / "Konten"
MODELS = {
    "inti-komando": "Bangunan/IntiKomando/IntiKomando.glb",
    "robot-insinyur": "Unit/RobotInsinyur/RobotInsinyur.glb",
    "pabrik-kendaraan": "Bangunan/pabrik_kendaraan/Model.glb",
    "ekstraktor-besi": "Bangunan/ekstraktor_besi/Model.glb",
    "pompa-minyak": "Bangunan/pompa_minyak/Model.glb",
}


def write_build_buttons():
    target = GAME / "unitpics"
    target.mkdir(exist_ok=True)
    items = {
        "pabrik-kendaraan": ("FACTORY", (178, 199, 198)),
        "ekstraktor-besi": ("IRON", (239, 185, 100)),
        "pompa-minyak": ("OIL PUMP", (125, 222, 210)),
        "robot-insinyur": ("ENGINEER", (163, 209, 249)),
        "medium-tank": ("MEDIUM", (163, 209, 249)),
    }
    font = ImageFont.load_default(size=18)
    for name, (label, color) in items.items():
        image = Image.new("RGB", (116, 72), (24, 33, 37))
        draw = ImageDraw.Draw(image)
        draw.rectangle((1, 1, 114, 70), outline=(71, 89, 92), width=2)
        draw.line((9, 56, 106, 56), fill=color, width=3)
        draw.text((58, 30), label, anchor="mm", fill=color, font=font)
        image.save(target / f"{name}.png")


def vec_z_up(data):
    return data[..., (0, 2, 1)] * np.array([1, -1, 1], dtype=np.float32)


def pixels(gltf, blob, texture, fallback, size):
    if texture is None:
        return np.broadcast_to(np.asarray(fallback, dtype="u1"), (size, size, 3))
    entry = gltf["textures"][texture["index"]]
    source = entry.get("source")
    if source is None:
        source = entry["extensions"]["EXT_texture_webp"]["source"]
    image = gltf["images"][source]
    view = gltf["bufferViews"][image["bufferView"]]
    offset = view.get("byteOffset", 0)
    with Image.open(BytesIO(blob[offset:offset + view["byteLength"]])) as rgb:
        return np.asarray(rgb.convert("RGB").resize((size, size), Image.Resampling.LANCZOS))


def write_textures(stem, gltf, blob, tile_size=1024):
    materials = gltf["materials"]
    row = ceil(sqrt(len(materials)))
    tile = tile_size if gltf.get("images") else 16
    padding = 4
    size = tile - padding * 2
    maps = [Image.new("RGBA", (row * tile, row * tile)) for _ in range(2)]
    for index, mat in enumerate(materials):
        pbr = mat.get("pbrMetallicRoughness", {})
        team = mat.get("name", "").startswith("FX1_TEAM_COLOR")
        color = pbr.get("baseColorFactor", [1, 1, 1])[:3]
        solid = [round(255 * max(0, c) ** (1 / 2.2)) for c in color]
        if team and pbr.get("baseColorTexture") is None:
            solid = [192, 192, 192]
        albedo = pixels(gltf, blob, pbr.get("baseColorTexture"), solid, size)
        diffuse = np.zeros((size, size, 4), dtype="u1")
        diffuse[..., :3], diffuse[..., 3] = albedo, 255 if team else 0
        shade = np.zeros_like(diffuse)
        metal = round(255 * pbr.get("metallicFactor", 1.0))
        orm = pixels(gltf, blob, pbr.get("metallicRoughnessTexture"), [255, 255, metal], size)
        shade[..., 1], shade[..., 3] = (orm[..., 2] * .28).astype("u1"), 255
        emission = [round(255 * min(1, c)) for c in mat.get("emissiveFactor", [0, 0, 0])]
        shade[..., 0] = pixels(gltf, blob, mat.get("emissiveTexture"), emission, size).max(axis=2)
        xy = (index % row * tile, index // row * tile)
        for atlas, data in zip(maps, (diffuse, shade)):
            atlas.paste(Image.fromarray(np.pad(data, ((padding, padding), (padding, padding), (0, 0)), mode="edge")), xy)
    for index, atlas in enumerate(maps, start=1):
        atlas.save(GAME / "unittextures" / f"{stem}-tex{index}.png", optimize=True)
    return row, tile, padding


def door_data(source, stem):
    meta = json.loads(source.with_name("Model.bagian.json").read_text(encoding="utf-8-sig"))
    frames = []
    for part in meta["bagian"]:
        if part["nama"].startswith("pintu_") and part["nama"] != "pintu_poros":
            # Pose sumber dinormalisasi dari 0 (tutup) sampai 1 (buka penuh).
            pose = np.asarray(part["pose"]).reshape(-1, 11)
            _, py, pz = part["pivot"]
            frames.append((part["nama"], part["pivot"], [
                ((p[2] - py) * ELMO_PER_METER, -(p[3] - pz) * ELMO_PER_METER, -2 * atan2(p[4], p[7]))
                for p in pose
            ]))
    lines = ["return {"]
    for name, _, motion in frames:
        lines.append(f'    {{nama = "{name}", pose = {{')
        lines.extend("        {%.5f, %.5f, %.5f}," % frame for frame in motion)
        lines.append("    }},")
    lines.append("}")
    suffix = "_robot" if stem == "pabrik-robot" else ""
    (GAME / f"gamedata/pintu_pabrik{suffix}.lua").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return {name: np.asarray(pivot, dtype="f4") for name, pivot, _ in frames}


def convert(stem, source, tile_size=1024):
    gltf, source_blob = load_glb(source)
    transforms = ("translation", "scale", "rotation", "matrix")
    if any(any(key in n for key in transforms) for n in gltf["nodes"]):
        raise ValueError(f"Transform mesh belum diterapkan: {source}")
    doors = door_data(source, stem) if stem in ("pabrik-kendaraan", "pabrik-robot") else {}
    row, tile, pad = write_textures(stem, gltf, source_blob, tile_size)
    raw = bytearray()
    nodes, meshes, accessors, views = [], [], [], []

    def read(index):
        acc = gltf["accessors"][index]
        view = gltf["bufferViews"][acc["bufferView"]]
        dtype = np.dtype({5121: "u1", 5123: "<u2", 5125: "<u4", 5126: "<f4"}[acc["componentType"]])
        width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}[acc["type"]]
        return np.ndarray(
            (acc["count"], width), dtype, buffer=source_blob,
            offset=acc.get("byteOffset", 0) + view.get("byteOffset", 0),
            strides=(view.get("byteStride", width * dtype.itemsize), dtype.itemsize),
        )

    def add(data, kind, component, position=False):
        raw.extend(bytes(-len(raw) % 4))
        view_index = len(views)
        views.append({"buffer": 0, "byteOffset": len(raw), "byteLength": data.nbytes})
        raw.extend(data.tobytes())
        acc = {"bufferView": view_index, "componentType": component, "count": len(data), "type": kind}
        if position:
            acc.update(min=data.min(axis=0).tolist(), max=data.max(axis=0).tolist())
        accessors.append(acc)
        return len(accessors) - 1

    for item in gltf["nodes"]:
        if "mesh" not in item:
            continue
        name = item["name"].removeprefix("bagian_")
        pivot = doors.get(name, np.zeros(3, dtype="f4"))
        # Satu primitive per bagian untuk importer Recoil yang sama dengan Medium Tank.
        positions, normals, coords, faces = [], [], [], []
        count = 0
        for part in gltf["meshes"][item["mesh"]]["primitives"]:
            attrs = part["attributes"]
            pos = read(attrs["POSITION"])
            uv = read(attrs["TEXCOORD_0"]).copy() if "TEXCOORD_0" in attrs else np.full((len(pos), 2), .5, dtype="f4")
            slot = part["material"]
            uv = (uv * (tile - 2 * pad) + [slot % row * tile + pad, slot // row * tile + pad]) / (row * tile)
            positions.append(vec_z_up(pos - pivot) * ELMO_PER_METER)
            normals.append(vec_z_up(read(attrs["NORMAL"])))
            coords.append(uv.astype("<f4"))
            faces.append(read(part["indices"]).astype("<u4") + count)
            count += len(pos)
        nodes.append({"name": name, "mesh": len(meshes), "translation": (vec_z_up(pivot) * ELMO_PER_METER).tolist()})
        meshes.append({"primitives": [{
            "attributes": {
                "POSITION": add(np.concatenate(positions), "VEC3", 5126, position=True),
                "NORMAL": add(np.concatenate(normals), "VEC3", 5126),
                "TEXCOORD_0": add(np.concatenate(coords), "VEC2", 5126),
            },
            "indices": add(np.concatenate(faces), "SCALAR", 5125),
        }]})

    # Soket memakai koordinat glTF sumber (depan -Z). Titik awal tank berada di dalam garasi.
    sockets = {
        "inti-komando": {"produksi": [0, 0, -13.75], "nano": [0, 3.5, -11.9]},
        "pabrik-kendaraan": {"produksi": [0, 0.05, -2.5], "nano": [0, 4.55, -5.7]},
        "pabrik-robot": {"produksi": [2.35, 0.04, -4.5], "nano": [2.35, 3.0, -5.45]},
        "robot-insinyur": {"nano": [0.45, 1.65, -1.08]},
    }
    for name, offset in sockets.get(stem, {}).items():
        nodes.append({"name": name, "translation": (vec_z_up(np.asarray(offset)) * ELMO_PER_METER).tolist()})
    header = {
        "asset": {"version": "2.0"}, "scene": 0,
        "scenes": [{"nodes": list(range(len(nodes)))}], "nodes": nodes, "meshes": meshes,
        "accessors": accessors, "bufferViews": views, "buffers": [{"byteLength": len(raw)}],
    }
    payload = json.dumps(header, separators=(",", ":")).encode()
    payload += b" " * (-len(payload) % 4)
    target = GAME / "objects3d" / f"{stem}.glb"
    target.write_bytes(struct.pack("<4s3I4s", b"glTF", 2, 28 + len(raw) + len(payload), len(payload), b"JSON")
                       + payload + struct.pack("<I4s", len(raw), b"BIN\0") + raw)
    target.with_suffix(".glb.lua").write_text(
        f'return {{tex1 = "{stem}-tex1.png", tex2 = "{stem}-tex2.png", '
        'fliptextures = true, invertteamcolor = false, s3ocompat = true}\n', encoding="utf-8",
    )
    print(f"{stem}: {len(nodes)} bagian, {sum(a['count'] // 3 for a in accessors if a['type'] == 'SCALAR')} segitiga")


if __name__ == "__main__":
    for model, path in MODELS.items():
        convert(model, V2 / Path(path))
    write_build_buttons()
