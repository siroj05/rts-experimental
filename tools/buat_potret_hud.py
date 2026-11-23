"""Buat potret ortografis HUD dari model dan atlas Recoil proyek."""

import re
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from impor_medium_tank import GAME, load_glb


MODELS = (
    "medium-tank", "robot-insinyur", "inti-komando", "pabrik-kendaraan", "ekstraktor-besi", "pompa-minyak",
    "tank-ringan", "medium-tank-destroyer", "pengintai", "artileri-ringan", "robot-infanteri", "robot-roket",
    "pabrik-robot",
)
SIZE = 256


def potret(model, target):
    gltf, blob = load_glb(GAME / "objects3d" / f"{model}.glb")
    with Image.open(GAME / "unittextures" / f"{model}-tex1.png") as atlas:
        color_map = np.array(atlas)
    with Image.open(GAME / "unittextures" / f"{model}-tex2.png") as atlas:
        shade_map = np.array(atlas)

    def read(index):
        acc = gltf["accessors"][index]
        view = gltf["bufferViews"][acc["bufferView"]]
        width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}[acc["type"]]
        dtype = np.dtype({5125: "<u4", 5126: "<f4"}[acc["componentType"]])
        return np.ndarray((acc["count"], width), dtype=dtype, buffer=blob, offset=view.get("byteOffset", 0))

    faces, normals, coords = [], [], []

    def add_node(index, offset):
        node = gltf["nodes"][index]
        offset = offset + node.get("translation", [0, 0, 0])
        if "mesh" in node and not re.fullmatch(r"track_(kiri|kanan)_\d+", node["name"]):
            for part in gltf["meshes"][node["mesh"]]["primitives"]:
                face = read(part["indices"]).reshape(-1, 3)
                attributes = part["attributes"]
                faces.append(read(attributes["POSITION"])[face] + offset)
                normals.append(read(attributes["NORMAL"])[face].mean(axis=1))
                coords.append(read(attributes["TEXCOORD_0"])[face].mean(axis=1))
        for child in node.get("children", []):
            add_node(child, offset)

    for root in gltf["scenes"][0]["nodes"]:
        add_node(root, np.zeros(3))

    faces = np.concatenate(faces)
    normals, coords = np.concatenate(normals), np.concatenate(coords)
    camera = np.array([0.87, 1.15, 0.88])
    camera /= np.linalg.norm(camera)
    right = np.cross(camera, [0, 0, 1])
    right /= np.linalg.norm(right)
    up = np.cross(right, camera)
    projected = faces @ np.stack((right, -up), axis=1)
    lo, hi = projected.min(axis=(0, 1)), projected.max(axis=(0, 1))
    projected = (projected - (lo + hi) * 0.5) * (SIZE * 0.91 / (hi - lo).max()) + SIZE / 2
    depth = (faces @ camera).mean(axis=1)
    ix = (coords[:, 0] * color_map.shape[1]).astype(int).clip(0, color_map.shape[1] - 1)
    iy = (coords[:, 1] * color_map.shape[0]).astype(int).clip(0, color_map.shape[0] - 1)
    texels = color_map[iy, ix].astype(float)
    luminance = texels[:, :3] @ [0.24, 0.64, 0.12]
    colors = luminance[:, None] * [0.93, 1.06, 1.08] + [24, 29, 33]
    colors[texels[:, 3] > 127] *= [0.77, 1.09, 1.26]
    light = np.array([-0.41, 0.34, 0.85])
    lighting = 0.53 + 0.55 * np.clip(normals @ light, 0, 1)
    emit = shade_map[iy, ix, 0] / 255
    colors = (colors * lighting[:, None] + emit[:, None] * [12, 77, 80]).clip(0, 255).astype("u1")

    portrait = Image.new("RGBA", (SIZE, SIZE))
    draw = ImageDraw.Draw(portrait)
    points = projected.round().astype(int).reshape(-1, 6).tolist()
    inks = colors.tolist()
    for index in np.argsort(depth):
        draw.polygon(points[index], fill=tuple(inks[index]) + (255,))
    portrait.save(target / f"{model}.png", optimize=True)


if __name__ == "__main__":
    target = Path(GAME) / "LuaUI" / "potret"
    target.mkdir(exist_ok=True)
    for model in sys.argv[1:] or MODELS:
        potret(model, target)
        if model in MODELS[6:]:
            shutil.copyfile(target / f"{model}.png", GAME / "unitpics" / f"{model}.png")
