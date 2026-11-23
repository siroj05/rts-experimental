"""Ekspor model uji Medium Tank v2 dalam konvensi GLB dan atlas bawaan Recoil."""

from io import BytesIO
import json
from pathlib import Path
import struct

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT.parent / "rts-pc-v2/Assets/Konten/Unit/medium_tank"
GAME = ROOT / "game/RTSPC.sdd"
ELMO_PER_METER = 8
TILE_SIZE = 1024
PADDING = 4
TRACK_PHASES = 5
ROLES = ("ordinary", "lamp", "team", "decal")


def load_glb(path):
    source = path.read_bytes()
    magic, version, length, json_size, json_tag = struct.unpack_from("<4s3I4s", source)
    if (magic, version, length, json_tag) != (b"glTF", 2, len(source), b"JSON"):
        raise ValueError(f"GLB tidak valid: {path}")
    offset = 20 + json_size
    size, tag = struct.unpack_from("<I4s", source, offset)
    if tag != b"BIN\0" or offset + 8 + size != length:
        raise ValueError(f"Buffer GLB tidak valid: {path}")
    return json.loads(source[20:offset]), memoryview(source)[offset + 8:]


def read_atlas(glb, blob, name):
    image = next(image for image in glb["images"] if image["name"] == name)
    view = glb["bufferViews"][image["bufferView"]]
    start = view.get("byteOffset", 0)
    with Image.open(BytesIO(blob[start:start + view["byteLength"]])) as texture:
        size = TILE_SIZE - 2 * PADDING
        return np.asarray(texture.convert("RGB").resize((size, size), Image.Resampling.LANCZOS))


def write_atlases(glb, source_blob):
    base = read_atlas(glb, source_blob, "medium_base")
    orm = read_atlas(glb, source_blob, "medium_orm")
    emission = read_atlas(glb, source_blob, "medium_emission")
    diffuse = Image.new("RGBA", (2 * TILE_SIZE, 2 * TILE_SIZE))
    shading = Image.new("RGBA", diffuse.size)
    for slot, role in enumerate(ROLES):
        albedo = np.zeros((*base.shape[:2], 4), dtype=np.uint8)
        albedo[..., :3] = base
        if role == "team":
            albedo[..., 3] = 255
        extra = np.zeros_like(albedo)
        # tex2 uses red for self-illumination, green for reflection, and alpha for coverage.
        extra[..., 1] = (orm[..., 2] * .28).astype(np.uint8)
        extra[..., 3] = 255
        if role == "lamp":
            extra[..., 0] = emission.max(axis=2)
        origin = (slot % 2 * TILE_SIZE, slot // 2 * TILE_SIZE)
        for atlas, pixels in ((diffuse, albedo), (shading, extra)):
            padded = np.pad(pixels, ((PADDING, PADDING), (PADDING, PADDING), (0, 0)), mode="edge")
            atlas.paste(Image.fromarray(padded, "RGBA"), origin)
    diffuse.save(GAME / "unittextures/medium-tank-tex1.png")
    shading.save(GAME / "unittextures/medium-tank-tex2.png")


def track_poses(position, normal, part):
    """Move vertices around the closed v2 path, retaining their offset from the belt."""
    path = np.asarray(part["lintasan"], dtype=np.float64).reshape(-1, 2)
    segments = np.roll(path, -1, axis=0) - path
    lengths = np.linalg.norm(segments, axis=1)
    unit = segments / lengths[:, None]
    cumulative = np.r_[0, np.cumsum(lengths)]
    pitch = cumulative[-1] / part["mata"]
    plane = position[:, (2, 1)] * [-1, 1]
    direction = normal[:, (2, 1)] * [-1, 1]

    delta = plane[:, None, :] - path
    along = np.clip(np.einsum("vij,ij->vi", delta, unit), 0, lengths)
    residual = delta - along[..., None] * unit
    nearest = np.argmin(np.einsum("vij,vij->vi", residual, residual), axis=1)
    vertex = np.arange(len(plane))
    distances = cumulative[nearest] + along[vertex, nearest]
    center = path[nearest] + along[vertex, nearest, None] * unit[nearest]
    offsets = plane - center
    left_normal = np.stack((-unit[:, 1], unit[:, 0]), axis=1)

    for phase in range(1, TRACK_PHASES):
        next_distance = (distances + part.get("arah", -1) * phase * pitch / TRACK_PHASES) % cumulative[-1]
        nxt = np.searchsorted(cumulative[1:], next_distance, side="right")
        new_center = path[nxt] + (next_distance - cumulative[nxt])[:, None] * unit[nxt]
        cosine = np.einsum("ij,ij->i", unit[nearest], unit[nxt])
        sine = np.einsum("ij,ij->i", left_normal[nearest], unit[nxt])

        def rotate(vectors):
            return np.stack((vectors[:, 0] * cosine - vectors[:, 1] * sine,
                             vectors[:, 0] * sine + vectors[:, 1] * cosine), axis=1)

        changed_position, changed_normal = position.copy(), normal.copy()
        changed_position[:, (2, 1)] = (new_center + rotate(offsets)) * [-1, 1]
        changed_normal[:, (2, 1)] = rotate(direction) * [-1, 1]
        yield changed_position, changed_normal



def main():
    glb, source_blob = load_glb(SOURCE / "Model.glb")
    metadata = json.loads((SOURCE / "Model.bagian.json").read_text(encoding="utf-8-sig"))
    parts = {entry["nama"]: entry for entry in metadata["bagian"]}
    transforms = ("translation", "rotation", "scale", "matrix")
    if any(any(key in node for key in transforms) for node in glb["nodes"]):
        raise ValueError("Konverter ini mengharapkan mesh v2 dalam koordinat dunia.")

    write_atlases(glb, source_blob)
    blob = bytearray()
    nodes, meshes, views, accessors = [], [], [], []
    node_ids = {}
    pivots = {}

    def source_array(index):
        entry = glb["accessors"][index]
        view = glb["bufferViews"][entry["bufferView"]]
        dtype = np.dtype({5123: "<u2", 5125: "<u4", 5126: "<f4"}[entry["componentType"]])
        dims = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}[entry["type"]]
        return np.ndarray(
            (entry["count"], dims), dtype, buffer=source_blob,
            offset=view.get("byteOffset", 0) + entry.get("byteOffset", 0),
            strides=(view.get("byteStride", dims * dtype.itemsize), dtype.itemsize),
        )

    def add_array(data, kind, component, position=False):
        blob.extend(bytes(-len(blob) % 4))
        offset = len(blob)
        raw = data.tobytes()
        blob.extend(raw)
        view = len(views)
        views.append({"buffer": 0, "byteOffset": offset, "byteLength": len(raw)})
        access = {"bufferView": view, "componentType": component, "count": len(data), "type": kind}
        if position:
            access["min"] = data.min(axis=0).tolist()
            access["max"] = data.max(axis=0).tolist()
        accessors.append(access)
        return len(accessors) - 1

    def z_up(values):
        return values[..., (0, 2, 1)] * np.array([1, -1, 1], dtype=np.float32)

    parents = {}
    rig = {"skala": ELMO_PER_METER, "fase": TRACK_PHASES}
    wheel_names = []
    muzzle = None

    def add_piece(name, pivot, parent, position, normal, texcoords, triangles):
        parents[name] = parent
        pivots[name] = pivot
        node_ids[name] = len(nodes)
        nodes.append({"name": name, "mesh": len(meshes)})
        meshes.append({"primitives": [{
            "attributes": {
                "POSITION": add_array(z_up(position - pivot) * ELMO_PER_METER, "VEC3", 5126, position=True),
                "NORMAL": add_array(z_up(normal), "VEC3", 5126),
                "TEXCOORD_0": add_array(texcoords, "VEC2", 5126),
            },
            "indices": add_array(triangles, "SCALAR", 5125),
        }]})

    for item in glb["nodes"]:
        if "mesh" not in item:
            continue
        name = item["name"].removeprefix("bagian_")
        part = parts.get(name, {})
        pivot = np.asarray(part.get("pivot", [0, 0, 0]), dtype=np.float32)
        parent = part.get("induk")
        # Each piece needs one primitive because Recoil 2026.09.03 overwrites earlier indices.
        positions, normals, texcoords, triangles = [], [], [], []
        vertex_offset = 0
        for prim in glb["meshes"][item["mesh"]]["primitives"]:
            attr = prim["attributes"]
            role = glb["materials"][prim["material"]]["extras"]["mtf_final_role"]
            slot = ROLES.index(role)
            pos = source_array(attr["POSITION"])
            uv = source_array(attr["TEXCOORD_0"]).copy()
            uv *= (TILE_SIZE - 2 * PADDING) / (2 * TILE_SIZE)
            uv += [(slot % 2 * TILE_SIZE + PADDING) / (2 * TILE_SIZE),
                   (slot // 2 * TILE_SIZE + PADDING) / (2 * TILE_SIZE)]
            indices = source_array(prim["indices"]).astype("<u4")
            if np.any(indices >= len(pos)):
                raise ValueError(f"Indeks segitiga di luar mesh sumber: {name}")
            positions.append(pos)
            normals.append(source_array(attr["NORMAL"]))
            texcoords.append(uv)
            triangles.append(indices + vertex_offset)
            vertex_offset += len(pos)

        pos, normal, uv, indices = (np.concatenate(items) for items in (positions, normals, texcoords, triangles))
        if part.get("jenis") == "roda":
            faces = indices.reshape(-1, 3)
            xcoords = pos[faces, 0]
            wheel_names.append((name, part["radius"] * ELMO_PER_METER))
            for side, selected in (("kiri", xcoords < 0), ("kanan", xcoords > 0)):
                if np.any(np.any(selected, axis=1) != np.all(selected, axis=1)):
                    raise ValueError(f"Roda melintasi garis tengah: {name}")
                vertices, shifted = np.unique(faces[np.all(selected, axis=1)], return_inverse=True)
                add_piece(f"{name}_{side}", pivot, parent, pos[vertices], normal[vertices], uv[vertices],
                          shifted.astype("<u4").reshape(-1))
        else:
            add_piece(name, pivot, parent, pos, normal, uv, indices)
            if part.get("jenis") == "track":
                for phase, (offset, rotated) in enumerate(track_poses(pos, normal, part), start=1):
                    add_piece(f"{name}_{phase}", pivot, parent, offset, rotated, uv, indices)
                rig["pitch"] = part["panjang"] * ELMO_PER_METER / part["mata"]
                rig["gauge"] = float(abs(pos[:, 0].mean())) * ELMO_PER_METER
            elif name == "laras":
                rim = pos[pos[:, 2] < pos[:, 2].min() + .04]
                muzzle = rim.mean(axis=0)

    if muzzle is None or not wheel_names or not {"track_kiri", "track_kanan"}.issubset(node_ids):
        raise ValueError("Rig Medium Tank tidak lengkap.")
    node_ids["moncong"] = len(nodes)
    nodes.append({"name": "moncong"})
    pivots["moncong"] = muzzle
    parents["moncong"] = "laras"
    rig_path = GAME / "gamedata/medium_tank_rig.lua"
    text = [f"    {key} = {value:.8f}," for key, value in rig.items()]
    text.append("    roda = {")
    text.extend(f'        {{"{name}", {radius:.8f}}},' for name, radius in wheel_names)
    text.append("    },")
    rig_path.write_text("return {\n" + "\n".join(text) + "\n}\n", encoding="utf-8")

    roots = []
    for name, node_id in node_ids.items():
        parent = parents[name]
        offset = pivots[name]
        if parent:
            nodes[node_ids[parent]].setdefault("children", []).append(node_id)
            offset = offset - pivots[parent]
        else:
            roots.append(node_id)
        nodes[node_id]["translation"] = (z_up(offset) * ELMO_PER_METER).tolist()

    blob.extend(bytes(-len(blob) % 4))
    schema = {
        "asset": {"version": "2.0"},
        "scene": 0,
        "scenes": [{"nodes": roots}],
        "nodes": nodes,
        "meshes": meshes,
        "accessors": accessors,
        "bufferViews": views,
        "buffers": [{"byteLength": len(blob)}],
    }
    payload = json.dumps(schema, separators=(",", ":")).encode()
    payload += b" " * (-len(payload) % 4)
    header = struct.pack("<4s3I4s", b"glTF", 2, 28 + len(payload) + len(blob), len(payload), b"JSON")
    target = GAME / "objects3d/medium-tank.glb"
    target.write_bytes(header + payload + struct.pack("<I4s", len(blob), b"BIN\0") + blob)
    print(f"{len(nodes)} bagian | {sum(accessors[p['indices']]['count'] // 3 for m in meshes for p in m['primitives']):,} segitiga")


if __name__ == "__main__":
    main()
