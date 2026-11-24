"""Source layout for Pine Crossing. Recoil units, north at z=0."""
import math
import numpy as np

WIDTH, DEPTH = 4096, 3072
LOW, HIGH = -56, 216
STEM = "lintasan-pinus-4v4"
FILENAME = "Pine Crossing 4v4 1.0"
ROWS = (480, 1168, 1904, 2592)
STARTS = tuple((1024, z) for z in ROWS) + tuple((3072, DEPTH-z) for z in ROWS)
POINTS = ((1776, 792), (2312, 792), (1784, 2280), (2320, 2280))
FORDS = (792, 1536, 2280)
ROCKS = ((544, 800, 340, 180), (1350, 1460, 310, 195), (850, 2170, 245, 174),
         (1880, 1140, 115, 166), (1450, 2720, 260, 152))
FORESTS = ((310, 280), (425, 1110), (615, 1510), (365, 2080), (610, 2685),
           (1430, 235), (1260, 960), (1320, 2120), (1600, 1250), (1710, 2830))
IRON_WEST = tuple((x, z+dz) for z in ROWS for x, dz in ((810, -96), (850, 116), (1264, 40)))
IRON_WEST += ((1624, 500), (1760, 792+148), (1696, 1536), (1760, 2132), (1576, 2496), (490, 1736))
IRON = IRON_WEST + tuple((WIDTH-x, DEPTH-z) for x, z in IRON_WEST)


def smooth(t):
    t = np.clip(t, 0, 1)
    return t*t*(3-2*t)


def terrain(x, z):
    u, v = x-WIDTH/2, z-DEPTH/2
    river = WIDTH/2 + 67*np.sin(v/220) + 28*np.sin(v/102)
    shore = np.abs(x-river)
    ford_distance = np.minimum.reduce([np.abs(z-a) for a in FORDS])
    width = 82 + 14*np.cos(v/132) + 9*np.cos(v/87)
    floor = 26 + 6*np.sin(u/139)*np.sin(v/169) + 2*np.cos((u+v)/43)
    ridge = np.full(np.broadcast(u,v).shape, 9., dtype=np.float32)
    for px,pz,rx,rz in ROCKS:
        for bx,bz in ((px,pz),(WIDTH-px,DEPTH-pz)):
            radius = np.hypot((x-bx)/rx, (z-bz)/rz)
            radius += .10*np.cos((u+v)/52) + .05*np.cos((u-v)/19)
            ridge = np.minimum(ridge, radius)
    floor += smooth((1.24-ridge)/.88)*(152+10*np.cos(u/94)*np.cos(v/123))
    for sx, sz in STARTS:
        flat = smooth((np.hypot(x-sx, z-sz)-167)/75)
        floor = 26 + (floor-26)*flat
    for sx, sz in (*IRON, *POINTS):
        flat = smooth((np.hypot(x-sx, z-sz)-53)/58)
        floor = 26 + (floor-26)*flat
    riverflat = smooth((108-ford_distance)/62)
    bottom = -28-7*np.cos(v/113)
    bottom += (-3-bottom)*riverflat
    bank = smooth((shore-width*.37)/(width*1.36))
    return floor*bank+bottom*(1-bank), ridge, shore, ford_distance


def trees():
    rng = np.random.default_rng(18042)
    placed = []
    for cx, cz in FORESTS:
        for _ in range(95):
            ox, oz = rng.normal(0, (103, 104))
            x, z = round(cx+ox), round(cz+oz)
            if not (48 < x < WIDTH/2-126 and 48 < z < DEPTH-48):
                continue
            if (ox/103)**2 + (oz/104)**2 > 3.5:
                continue
            h, ridge, shore, ford = terrain(x,z)
            if h < 16 or (ford < 104 and shore < 510) or ridge < .94:
                continue
            if any(math.hypot(x-a,z-b) < 122 for a,b in (*STARTS,*POINTS,*IRON)):
                continue
            if any(math.hypot(x-a,z-b) < 42 for a,b,_,_ in placed):
                continue
            placed.append((x,z,int(rng.integers(4)),int(rng.integers(-32768,32768))))
    return placed + [(WIDTH-x, DEPTH-z, kind, (rot % 65536)-32768) for x,z,kind,rot in placed]
