"""Bangun mesh LOD Recoil memakai model dan atlas Fraksi 1 yang sudah diimpor."""

import argparse
import json
from math import ceil, sqrt
from pathlib import Path
import re
import subprocess
import tempfile

import numpy as np

from impor_medium_tank import PADDING, ROLES, SOURCE as MEDIUM_V2, TILE_SIZE
from impor_unit_fraksi1 import (
    ELMO_PER_METER, GAME, LINKS, MODELS, ROOT, SOURCE, accessor,
    convex_profile, load_glb, lua, metadata, saat_mesh, track_poses,
)

APPROVED = {
    "medium_tank": "fx1_medium_tank",
    "medium_tank_destroyer": "fx1_tank_medium_destroyer",
    "pengintai": "fx1_pengintai_halftrack",
    "tank_ringan": "fx1_tank_ringan",
    "artileri_ringan": "fx1_artileri_ringan",
}
ROBOTS = {"robot_insinyur": .27, "robot_infanteri": .46, "robot_roket": .37}
TO_ENGINE = np.array([-1, 1, -1], dtype="<f4")


def read_source(path, scratch, ratio=None, piece_prefix=None):
    gltf, blob = load_glb(path)
    if ratio is None and "EXT_meshopt_compression" not in gltf.get("extensionsUsed", ()):
        return gltf, blob
    output = scratch / path.name
    command = ["node", ROOT / "tools/dekode_glb.mjs", path, output]
    if ratio is not None:
        command.append(str(ratio))
    if piece_prefix is not None:
        command.append(piece_prefix)
    subprocess.run(command, check=True)
    return load_glb(output)


def mesh_nodes(gltf):
    prefix = next(n["name"] for n in gltf["nodes"] if n["name"].endswith("_ekspor"))
    prefix = prefix.removesuffix("ekspor")
    return {n["name"].removeprefix(prefix): n for n in gltf["nodes"] if "mesh" in n}


def native_pieces(gltf, blob):
    pieces = {}

    def visit(index, origin):
        node = gltf["nodes"][index]
        x, y, z = origin + node.get("translation", [0, 0, 0])
        if "mesh" in node:
            primitive, = gltf["meshes"][node["mesh"]]["primitives"]
            triangles = gltf["accessors"][primitive["indices"]]["count"] // 3
            positions = accessor(gltf, blob, primitive["attributes"]["POSITION"])
            world = (positions + [x, y, z])[:, [0, 2, 1]] * [1, 1, -1]
            pieces[node["name"]] = (np.array([x, z, -y]) / ELMO_PER_METER, triangles, world)
        for child in node.get("children", ()):
            visit(child, np.array([x, y, z]))

    for root in gltf["scenes"][gltf["scene"]]["nodes"]:
        visit(root, np.zeros(3))
    return pieces


def convert(key, scratch, destination):
    stem = key.replace("_", "-")
    native_path = GAME / "objects3d" / f"{stem}.glb"
    native = native_pieces(*load_glb(native_path))
    name = MODELS[key][0] or APPROVED[key]
    source_dir = SOURCE / key
    source, source_blob = read_source(source_dir / f"{name}.glb", scratch)
    if key in APPROVED:
        lod, blob = read_source(source_dir / f"{APPROVED[key]}_lod1.glb", scratch)
    else:
        lod, blob = read_source(source_dir / f"{name}.glb", scratch, ROBOTS[key])
    source_nodes, lod_nodes = mesh_nodes(source), mesh_nodes(lod)
    if source_nodes.keys() != lod_nodes.keys():
        raise ValueError(f"{key}: LOD mengubah nama bagian")

    material_names = lambda model: [m.get("name") for m in model["materials"]]
    if material_names(source) != material_names(lod):
        raise ValueError(f"{key}: LOD mengganti urutan material sumber")
    is_medium = key == "medium_tank"
    if is_medium:
        atlas = (2, TILE_SIZE, PADDING)
        slots = [ROLES.index(m["extras"]["mtf_final_role"]) for m in lod["materials"]]
        for mesh in lod["meshes"]:
            for primitive in mesh["primitives"]:
                primitive["material"] = slots[primitive["material"]]
        medium_rig = json.loads((MEDIUM_V2 / "Model.bagian.json").read_text(encoding="utf-8-sig"))
        track_settings = {part["nama"]: part for part in medium_rig["bagian"] if part["jenis"] == "track"}
        wheel_lod, wheel_blob = read_source(native_path, scratch, .06, "roda_")
    else:
        atlas = (ceil(sqrt(len(source["materials"]))), 512 if source.get("images") else 16, 4)

    vertices, indices, parts = [], [], []
    bounds = []
    vertex_count = 0

    def add(part, positions, normals, uv, faces):
        nonlocal vertex_count
        pivot, _, _ = native[part]
        used, clean = np.unique(faces.reshape(-1), return_inverse=True)
        local = (positions[used] - pivot) * ELMO_PER_METER * TO_ENGINE
        engine_uv = uv[used] * [1, -1] + [0, 1]
        vertices.append(np.column_stack((local, normals[used] * TO_ENGINE, engine_uv,
                                         np.full(len(used), len(parts)))).astype("<f4"))
        indices.append((clean.reshape(-1) + vertex_count).astype("<u4"))
        parts.append(part)
        vertex_count += len(used)
        if not re.match(r"^track_.*_[1-4]$", part):
            bounds.append(positions[used] * ELMO_PER_METER)

    for part, node in lod_nodes.items():
        pivot = np.asarray(node.get("translation", np.zeros(3)))
        expected = source_nodes[part].get("translation", [0, 0, 0])
        if not np.array_equal(pivot, expected):
            raise ValueError(f"{key}/{part}: pivot sumber berbeda")
        if is_medium and part.startswith("roda_"):
            continue
        if is_medium and part == "badan":
            primitives = lod["meshes"][node["mesh"]]["primitives"]
            team_slot = ROLES.index("team")
            base = [p for p in primitives if p["material"] != team_slot]
            team = [p for p in primitives if p["material"] == team_slot]
            add("model", *saat_mesh(lod, blob, node, pivot, atlas, base))
            add("model_tim", *saat_mesh(lod, blob, node, pivot, atlas, team))
            continue
        pos, normal, uv, faces = saat_mesh(lod, blob, node, pivot, atlas)
        add(part, pos, normal, uv, faces)
        if part.startswith("track_"):
            if is_medium:
                settings = track_settings[part]
            else:
                authored = metadata(node.get("extras", {}).get("authored_track"))
                if authored:
                    path, links, sign = authored["path"], authored["links"], authored["travelSign"]
                else:
                    full, *_ = saat_mesh(source, source_blob, source_nodes[part], pivot, atlas)
                    path, links, sign = convex_profile(full), LINKS[key], -1
                settings = {"lintasan": path, "mata": links, "arah": sign}
            for i, (shifted, rotated) in enumerate(track_poses(pos, normal, settings), 1):
                add(f"{part}_{i}", shifted, rotated, uv, faces)

    if is_medium:
        # The approved source spans each axle in one mesh. Recoil steers the
        # two wheel halves independently, so reduce those native pieces as-is.
        for node in wheel_lod["nodes"]:
            part = node["name"]
            if not part.startswith("roda_"):
                continue
            primitive, = wheel_lod["meshes"][node["mesh"]]["primitives"]
            attributes = primitive["attributes"]
            pos = accessor(wheel_lod, wheel_blob, attributes["POSITION"])
            normal = accessor(wheel_lod, wheel_blob, attributes["NORMAL"])
            uv = accessor(wheel_lod, wheel_blob, attributes["TEXCOORD_0"])
            faces = accessor(wheel_lod, wheel_blob, primitive["indices"])
            axes = [0, 2, 1]
            sign = [1, 1, -1]
            pos = pos[:, axes] * sign / ELMO_PER_METER + native[part][0]
            add(part, pos, normal[:, axes] * sign, uv, faces)

    expected = set(native)
    if len(parts) != len(expected) or set(parts) != expected:
        raise ValueError(f"{key}: bagian berbeda ({set(parts) ^ expected})")
    combined = np.concatenate(bounds)
    full = np.concatenate([data[2] for name, data in native.items()
                           if not re.match(r"^track_.*_[1-4]$", name)])
    delta = max(np.abs(combined.min(axis=0) - full.min(axis=0)).max(),
                np.abs(combined.max(axis=0) - full.max(axis=0)).max())
    if delta >= .01 * ELMO_PER_METER:
        raise ValueError(f"{key}: batas LOD bergeser {delta / ELMO_PER_METER:.3f} m")
    data, faces = np.concatenate(vertices), np.concatenate(indices)
    if not np.isfinite(data).all() or faces.max() >= len(data):
        raise ValueError(f"{key}: mesh LOD tidak valid")
    (destination / f"{stem}.bin").write_bytes(data.tobytes() + faces.tobytes())
    first_phases = [len(f) // 3 for part, f in zip(parts, indices)
                    if not re.match(r"^track_.*_[1-4]$", part)]
    print(f"{key}: {sum(p[1] for p in native.values()):,} -> {len(faces)//3:,} tris"
          f" ({sum(first_phases):,} tanpa fase cadangan); batas berubah {delta/ELMO_PER_METER:.3f} m")
    return {"parts": parts, "vertices": len(data), "indices": len(faces)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=GAME / "objects3d/lod")
    output = parser.parse_args().output
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="rts-lod-") as scratch:
        catalog = {key: convert(key, Path(scratch), output) for key in MODELS}
    (output / "index.lua").write_text("return " + lua(catalog) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
