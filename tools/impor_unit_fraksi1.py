"""Port seluruh roster aktif Fraksi 1, termasuk bagian, atlas tim, dan bangkai."""

import json
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile

import numpy as np

from impor_markas import V2, convert, vec_z_up, write_textures
from impor_medium_tank import ELMO_PER_METER, GAME, ROOT, load_glb, track_poses


SOURCE = ROOT.parent / "rts-pc/konten/fraksi-1/unit"
MODELS = {
    "robot_insinyur": ("fx1_robot_insinyur_v2", "RobotInsinyur/RobotInsinyur_Bangkai"),
    "robot_infanteri": ("fx1_robot_infanteri", "robot_infanteri/Bangkai"),
    "robot_roket": ("fx1_infantri_roket", "robot_roket/Bangkai"),
    "medium_tank_destroyer": ("fx1_tank_medium_destroyer", "medium_tank_destroyer/Bangkai"),
    "pengintai": ("fx1_pengintai_halftrack", "pengintai/Bangkai"),
    "tank_ringan": ("fx1_tank_ringan", "TankRingan/TankRingan_Bangkai"),
    "medium_tank": (None, "medium_tank/Bangkai"),
    "artileri_ringan": ("fx1_artileri_ringan_game", "artileri_ringan/Bangkai"),
}

# Profile polos memakai keliling geometri, seperti renderer v1.
LINKS = {"robot_insinyur": 48, "tank_ringan": 58, "artileri_ringan": 72}


def accessor(gltf, blob, index):
    spec = gltf["accessors"][index]
    view = gltf["bufferViews"][spec["bufferView"]]
    dtype = np.dtype({5121: "u1", 5123: "<u2", 5125: "<u4", 5126: "<f4"}[spec["componentType"]])
    size = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}[spec["type"]]
    return np.ndarray((spec["count"], size), dtype=dtype, buffer=blob,
                      offset=view.get("byteOffset", 0) + spec.get("byteOffset", 0),
                      strides=(view.get("byteStride", size * dtype.itemsize), dtype.itemsize))


class Pieces:
    def __init__(self):
        self.blob = bytearray()
        self.nodes = {}
        self.pivots = {}
        self.parents = {}
        self.accessors = []
        self.views = []
        self.meshes = []

    def array(self, data, kind, component, position=False):
        dtype = "<f4" if component == 5126 else "<u4"
        data = data.astype(dtype, copy=False)
        self.blob.extend(bytes(-len(self.blob) % 4))
        self.views.append({"buffer": 0, "byteOffset": len(self.blob), "byteLength": data.nbytes})
        self.blob.extend(data.tobytes())
        spec = {"bufferView": len(self.views) - 1, "type": kind,
                "componentType": component, "count": len(data)}
        if position:
            spec.update(min=data.min(axis=0).tolist(), max=data.max(axis=0).tolist())
        self.accessors.append(spec)
        return len(self.accessors) - 1

    def piece(self, name, pivot, parent=None, geometry=None):
        if name in self.nodes:
            raise ValueError(f"Bagian ganda: {name}")
        node = self.nodes[name] = {"name": name}
        self.parents[name], self.pivots[name] = parent, np.asarray(pivot)
        if geometry is None:
            return
        pos, normal, uv, faces = geometry
        node["mesh"] = len(self.meshes)
        self.meshes.append({"primitives": [{
            "attributes": {
                "POSITION": self.array(vec_z_up(pos - pivot) * ELMO_PER_METER, "VEC3", 5126, True),
                "NORMAL": self.array(vec_z_up(normal), "VEC3", 5126),
                "TEXCOORD_0": self.array(uv, "VEC2", 5126),
            },
            "indices": self.array(faces, "SCALAR", 5125),
        }]})

    def save(self, stem):
        roots = []
        indices = {name: i for i, name in enumerate(self.nodes)}
        for name, node in self.nodes.items():
            local = self.pivots[name]
            parent = self.parents[name]
            if parent:
                self.nodes[parent].setdefault("children", []).append(indices[name])
                local = local - self.pivots[parent]
            else:
                roots.append(indices[name])
            node["translation"] = (vec_z_up(local) * ELMO_PER_METER).tolist()

        self.blob.extend(bytes(-len(self.blob) % 4))
        gltf = {"asset": {"version": "2.0"}, "scene": 0, "scenes": [{"nodes": roots}],
                "nodes": list(self.nodes.values()), "meshes": self.meshes,
                "bufferViews": self.views, "accessors": self.accessors,
                "buffers": [{"byteLength": len(self.blob)}]}
        json_chunk = json.dumps(gltf, separators=(",", ":")).encode()
        json_chunk += b" " * (-len(json_chunk) % 4)
        prefix = struct.pack("<4s3I4s", b"glTF", 2, 28 + len(json_chunk) + len(self.blob),
                             len(json_chunk), b"JSON")
        target = GAME / "objects3d" / f"{stem}.glb"
        target.write_bytes(prefix + json_chunk + struct.pack("<I4s", len(self.blob), b"BIN\0") + self.blob)
        target.with_suffix(".glb.lua").write_text(
            f'return {{tex1 = "{stem}-tex1.png", tex2 = "{stem}-tex2.png", '
            'fliptextures = true, invertteamcolor = false, s3ocompat = true}\n', encoding="utf-8")
        return sum(self.accessors[m["primitives"][0]["indices"]]["count"] // 3 for m in self.meshes)


def saat_mesh(gltf, blob, node, pivot, atlas, primitives=None):
    row, tile, pad = atlas
    elements = ([], [], [], [])
    offset = 0
    if primitives is None:
        primitives = gltf["meshes"][node["mesh"]]["primitives"]
    for prim in primitives:
        a = prim["attributes"]
        pos = accessor(gltf, blob, a["POSITION"])
        normal = accessor(gltf, blob, a["NORMAL"])
        uv = accessor(gltf, blob, a["TEXCOORD_0"]) if "TEXCOORD_0" in a else np.full((len(pos), 2), 0.5)
        m = prim["material"]
        uv = (uv * (tile - 2 * pad) + [m % row * tile + pad, m // row * tile + pad]) / (row * tile)
        index = accessor(gltf, blob, prim["indices"]).reshape(-1).astype("<u4")
        if index.max() >= len(pos):
            raise ValueError(f"Indeks mesh tidak valid: {node['name']}")
        for array, value in zip(elements, (pos + pivot, normal, uv, index + offset)):
            array.append(value)
        offset += len(pos)
    return tuple(np.concatenate(a) for a in elements)


def convex_profile(pos):
    points = sorted(set(map(tuple, np.round(pos[:, (2, 1)] * [-1, 1], 5))))

    def half(ordered):
        edge = []
        for p in ordered:
            while len(edge) >= 2:
                a, b = edge[-2:]
                if (b[0]-a[0])*(p[1]-a[1]) > (b[1]-a[1])*(p[0]-a[0]):
                    break
                edge.pop()
            edge.append(p)
        return edge[:-1]

    path = np.asarray(half(points) + half(reversed(points)))
    seg = np.roll(path, -1, axis=0) - path
    lengths = np.linalg.norm(seg, axis=1)
    cumulative = np.r_[0, np.cumsum(lengths)]
    uniform = np.linspace(0, cumulative[-1], 64, endpoint=False)
    indices = np.searchsorted(cumulative[1:], uniform, side="right")
    return (path[indices] + seg[indices] * ((uniform - cumulative[indices]) / lengths[indices])[:, None]).tolist()


def metadata(value):
    return json.loads(value) if isinstance(value, str) else value


def gait_data(raw, pieces):
    gait = metadata(raw)
    cycle = gait["steady_cycle"]
    frames = [gait["timeline"][0]] + [
        f for f in gait["timeline"] if cycle["frame_start"] <= f["frame"] <= cycle["frame_end"]
    ]
    mirror = np.diag([1., 1., -1.])
    data = {}
    for name in frames[0]["inplace_delta"]:
        if name not in pieces.pivots:
            continue
        pivot = mirror @ pieces.pivots[name]
        poses = []
        for frame in frames[::2] + [frames[-1]]:
            mat = np.asarray(frame["inplace_delta"][name]).reshape((4, 4), order="F")
            rotation = mirror @ mat[:3, :3] @ mirror
            rotation /= np.linalg.norm(rotation, axis=0)
            translation = (rotation @ pivot + mirror @ mat[:3, 3] - pivot) * ELMO_PER_METER
            x = np.arctan2(rotation[2, 1], rotation[2, 2])
            y = np.arcsin(np.clip(-rotation[2, 0], -1, 1))
            z = np.arctan2(rotation[1, 0], rotation[0, 0])
            poses.append([*translation.tolist(), float(x), float(y), float(z)])
        data[name] = poses
    return {"langkah": cycle["stride_m"] * ELMO_PER_METER, "pose": data}


def model_hidup(key, source):
    gltf, blob = load_glb(source)
    stem = key.replace("_", "-")
    atlas = write_textures(stem, gltf, blob, tile_size=512)
    root = next(n for n in gltf["nodes"] if n["name"].endswith("_ekspor"))
    prefix = root["name"].removesuffix("ekspor")
    pieces = Pieces()
    rig = {"track": {}, "roda": {"kiri": [], "kanan": []}}
    for node in gltf["nodes"]:
        if "mesh" not in node:
            continue
        if any(k in node for k in ("matrix", "scale", "rotation")):
            raise ValueError(f"Bagian harus berupa translasi saja: {node['name']}")
        name = node["name"].removeprefix(prefix)
        pivot = np.asarray(node.get("translation", [0., 0., 0.]))
        extras = node.get("extras", {})
        geo = saat_mesh(gltf, blob, node, pivot, atlas)
        pieces.piece(name, pivot, extras.get("induk_bagian"), geo)
        if name.startswith("roda_"):
            radius = extras.get("radius_roda") or np.linalg.norm((geo[0] - pivot)[:, 1:], axis=1).max()
            side = "kiri" if pivot[0] < 0 else "kanan"
            rig["roda"][side].append([name, float(radius) * ELMO_PER_METER])
        if name.startswith("track_"):
            pos, norm, uv, faces = geo
            track = metadata(extras.get("authored_track")) or {
                "path": convex_profile(pos), "links": LINKS[key], "travelSign": -1,
            }
            path = np.asarray(track["path"])
            span = np.linalg.norm(np.roll(path, -1, axis=0) - path, axis=1).sum()
            side = "kiri" if pos[:, 0].mean() < 0 else "kanan"
            phases = [name]
            settings = {"lintasan": path, "mata": track["links"], "arah": track["travelSign"]}
            for i, (changed, rotated) in enumerate(track_poses(pos, norm, settings), 1):
                phase = f"{name}_{i}"
                phases.append(phase)
                pieces.piece(phase, pivot, geometry=(changed, rotated, uv, faces))
            rig["track"][side] = {"fase": phases, "pitch": float(span) * ELMO_PER_METER / track["links"],
                                  "jarak": float(abs(pos[:, 0].mean())) * ELMO_PER_METER}
        if name == "laras":
            rim = geo[0][geo[0][:, 2] <= geo[0][:, 2].min() + .04]
            fallback_muzzle = rim.mean(axis=0)
            rig["min"], rig["max"] = extras["elevasi_min_deg"], extras["elevasi_max_deg"]

    extras = root.get("extras", {})
    sockets = extras.get("weapon_sockets") or ([extras["weapon_socket"]] if "weapon_socket" in extras else [])
    for i, socket in enumerate(sockets):
        pieces.piece("moncong" if i == 0 else f"moncong_{i+1}",
                     np.asarray(socket["position"]) * [-1, 1, -1], socket["part"])
    if not sockets and "laras" in pieces.pivots:
        pieces.piece("moncong", fallback_muzzle, "laras")
    if extras.get("authored_gait"):
        rig["langkah"] = gait_data(extras["authored_gait"], pieces)
    if key == "robot_insinyur":
        pieces.piece("nano", [0.45, 1.65, -1.08])
    print(f"{key}: {len(pieces.nodes)} bagian, {pieces.save(stem):,} segitiga tersimpan")
    return rig


def lua(value):
    if isinstance(value, dict):
        return "{"+", ".join(f"{key} = {lua(item)}" for key, item in value.items())+"}"
    if isinstance(value, list):
        return "{"+", ".join(map(lua, value))+"}"
    return json.dumps(value) if isinstance(value, str) else f"{value:.8g}"


def main():
    rigs = {}
    for key, (name, wreck) in MODELS.items():
        if name:
            original = SOURCE / key / f"{name}.glb"
            gltf, _ = load_glb(original)
            with tempfile.TemporaryDirectory(prefix="rts-model-") as tmp:
                source = original
                if "EXT_meshopt_compression" in gltf.get("extensionsUsed", ()):
                    source = Path(tmp) / original.name
                    subprocess.run(["node", ROOT / "tools/dekode_glb.mjs", original, source], check=True)
                rigs[key] = model_hidup(key, source)
        convert(key.replace("_", "-") + "-bangkai", V2 / "Unit" / (wreck + ".glb"), tile_size=512)
        if key not in ("robot_insinyur", "medium_tank"):
            suara = V2 / "Suara"
            if key == "tank_ringan":
                path = suara / "tank_ringan_tembak_1.wav"
            else:
                path = sorted((suara / "Resources/Tembakan" / key).glob("*tembak*.wav"))[0]
            shutil.copyfile(path, GAME / "sounds" / (key + "_tembak.wav"))
    lines = [f"    {key} = {lua(rig)}," for key, rig in rigs.items()]
    (GAME / "gamedata/rig_fraksi1.lua").write_text("return {\n" + "\n".join(lines) + "\n}\n", encoding="utf-8")
    convert("pabrik-robot", V2 / "Bangunan/pabrik_robot/Model.glb", tile_size=512)


if __name__ == "__main__":
    main()
