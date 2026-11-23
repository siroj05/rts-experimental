"""Bangun tracer kotak 3D dari ukuran EfekTempur.Box di V2."""

import numpy as np
from PIL import Image

from impor_medium_tank import GAME
from impor_unit_fraksi1 import Pieces


def tracer(stem, width, length, color):
    # Pieces menerima meter, Y atas dan -Z depan. Titik proyektil ada di ujung depan.
    half = width / 2
    corners = np.array([[-half, -half, 0], [half, -half, 0], [half, half, 0], [-half, half, 0],
                        [-half, -half, length], [half, -half, length], [half, half, length], [-half, half, length]])
    faces = ((0, 3, 2, 1), (4, 5, 6, 7), (4, 7, 3, 0), (1, 2, 6, 5), (3, 7, 6, 2), (4, 0, 1, 5))
    vertices, normals, uv, indices = [], [], [], []
    for face in faces:
        points = corners[list(face)]
        n = np.cross(points[1] - points[0], points[2] - points[0])
        offset = len(vertices)
        indices.extend(offset + np.array((0, 1, 2, 0, 2, 3)))
        vertices.extend(points)
        normals.extend([n / np.linalg.norm(n)] * 4)
        uv.extend((.25 if v[2] == 0 else .75, .5) for v in points)
    pieces = Pieces()
    pieces.piece("tracer", [0, 0, 0], geometry=tuple(np.array(a) for a in (vertices, normals, uv, indices)))
    pieces.save(stem)
    diffuse = Image.new("RGBA", (16, 4))
    for x in range(diffuse.width):
        t = x / (diffuse.width - 1)
        rgb = tuple(round(c * (1 - .36 * t)) for c in color)
        diffuse.paste((*rgb, 0), (x, 0, x + 1, diffuse.height))
    diffuse.save(GAME / "unittextures" / f"{stem}-tex1.png")
    Image.new("RGBA", diffuse.size, (255, 0, 0, 255)).save(GAME / "unittextures" / f"{stem}-tex2.png")


if __name__ == "__main__":
    tracer("fx-tracer-meriam", .22, 3.2, (255, 218, 139))
    tracer("fx-tracer-kecil", .12, 1.45, (255, 227, 160))
    tracer("fx-tracer-roket", .27, 1.55, (255, 171, 78))
