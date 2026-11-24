"""Verdant Ridge. Geometry is designed in metres, game markers in elmos."""
import numpy as np

WIDTH, DEPTH = 8192, 6144
STEM = "punggung-hijau-4v4"
NAME = "Verdant Ridge 4v4"
LOW, HIGH = -48, 384
ROWS = (94, 282, 478, 672)
STARTS = [(x*8, z*8) for x in (122, 902) for z in ROWS]
POINTS = [(4096, z*8) for z in (100, 275, 478, 670)]
WEST_ORE = [(122+dx,z+dz) for z in ROWS for dx,dz in ((-36,-28),(-32,31),(43,12))]
WEST_ORE += [(318,82),(455,124),(353,247),(476,303),(328,456),(461,493),(346,635),(445,686)]
IRON = [(8*x,8*z) for x,z in WEST_ORE] + [(WIDTH-8*x,8*z) for x,z in WEST_ORE]


def smooth(x):
    t = np.clip(x,0,1)
    return t*t*(3-2*t)


def lanes(u):
    bend = np.sin((512-u)*np.pi/390)
    return [z + amplitude*bend for z,amplitude in zip((100,275,478,670),(18,-24,14,-21))]


def fields(x,z):
    """x,z in metres. Mirroring also covers forest, lanes, river and objectives."""
    u = np.minimum(x,1024-x)
    lane = np.minimum.reduce(np.broadcast_arrays(*[abs(z-y) for y in lanes(u)]))
    base = 6.7 + 1.6*np.sin(u/51+z/113) + 1.1*np.cos(z/35-u/97)
    # Broad saddle at A. C is bounded by two opposing spurs.
    base += 14*np.exp(-((u-512)/116)**2-((z-100)/65)**2)
    edge = np.full(np.broadcast(u,z).shape,9.,dtype=np.float32)
    for cx,cz,rx,rz,tilt in ((376,174,130,43,.12),(245,364,83,49,-.24),
            (464,389,114,53,.15),(466,536,111,37,-.10),(278,566,97,46,.24),
            (368,731,132,34,-.12),(274,19,85,38,-.18),(21,385,54,57,0)):
        r = np.hypot((u-cx)/rx,(z-cz-(u-cx)*tilt)/rz)
        edge = np.minimum(edge,r)
    edge += .075*np.sin(u/14+z/11) + .04*np.sin(z/4-u/7)
    cut = smooth((lane-24)/12)
    # Two narrow natural passes through the rock bands, mirrored on the east.
    flanks = np.minimum(abs(u-(362+8*np.sin(z/35))),abs(u-(237+9*np.cos(z/39))))
    cut = np.minimum(cut,smooth((flanks-8)/9))
    rock = smooth((1.15-edge)/.58)*cut
    h = base + rock*(28+4*np.sin(u/17+z/21))
    # Transverse creek stops short of both teams' building terraces.
    stream = 371+11*np.sin(u/32)+7*np.cos(u/18)
    distance = abs(z-stream)
    bank = smooth((distance-4)/10)
    ford = np.minimum.reduce(np.broadcast_arrays(*[abs(u-a) for a in (209,353,485)]))
    bottom = -3.1 + 4.3*(1-smooth((ford-22)/10))
    incision = smooth((u-165)/35)*(1-bank)
    h += (bottom-h)*incision
    for row in ROWS:
        t = smooth((np.maximum(abs(u-122),abs(z-row))-56)/16)
        h = 7+(h-7)*t
    for px,pz in POINTS + [(a*8,b*8) for a,b in WEST_ORE[12:]]:
        if px > WIDTH//2: continue
        a,b = px/8,pz/8
        target = 20 if (a==512 and b==100) else 7
        flat = 1-smooth((np.hypot(u-a,z-b)-(13 if a==512 else 8))/16)
        h += (target-h)*flat
    sand_field = (.63*np.exp(-((z-668+14*np.cos(u/38))/42)**2)
                 +.66*np.exp(-((distance-4)/18)**2)*smooth((u-165)/35)
                 +.26*np.cos(u/48-z/51)+.12*np.sin(z/21+u/35))
    sand = smooth((sand_field-.235)/.28)
    blocked = ((rock>.30)&(edge<.97)&(cut>.32)&(incision<.45)) | (h < -.15)
    return h,blocked,rock,sand,lane,flanks


def forest():
    rng=np.random.default_rng(319046)
    z,x=np.mgrid[3:766:4.5,3:512:4.5]
    x=x.ravel()+rng.uniform(-1.35,1.35,x.size)
    z=z.ravel()+rng.uniform(-1.35,1.35,z.size)
    h,block,rock,_,lane,flanks=fields(x,z)
    woods=(np.sin(x/39+z/52)+.64*np.cos(z/25-x/62)+.54*np.sin(z/57-x/29)
           +.27*np.sin(x/8+z/12)+rng.uniform(-.24,.24,x.size))
    keep=(woods>.12)&(lane>28)&(flanks>10)&(h>2)&~block&(rock<.22)&(x<510)
    for row in ROWS:
        keep &= np.maximum(abs(x-122),abs(z-row))>62
    for a,b in (*POINTS,*IRON):
        keep &= np.hypot(x-a/8,z-b/8)>16
    ix=np.flatnonzero(keep)
    rng.shuffle(ix)
    ix=ix[:2050]
    west=[(round(x[i]*8),round(z[i]*8),int(rng.integers(4)),int(rng.integers(-32760,32760))) for i in ix]
    return west+[(WIDTH-x,z,k,-r) for x,z,k,r in west]

