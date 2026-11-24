"""Stage procedural albedo; compile Blender's exported heightmap and marker layout."""
import argparse
import json
from pathlib import Path
import shutil
import struct
import subprocess
from zipfile import ZIP_DEFLATED, ZipFile

import numpy as np
from PIL import Image, ImageDraw

from grading_medan import grade
from pine_crossing_layout import DEPTH, FILENAME, HIGH, IRON, LOW, STEM, WIDTH, smooth, terrain

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / ".cache" / STEM
ART = ROOT.parent / "blender-assets/peta/pine-crossing-4v4"


def prepare():
    WORK.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(39416)
    layers = []
    for n in (20, 70, 224, 720, 1800, 4096):
        low = rng.integers(0, 256, (n*3//4,n), dtype=np.uint8)
        layers.append(np.asarray(Image.fromarray(low).resize((WIDTH,DEPTH), Image.Resampling.BICUBIC)))
    image=Image.new("RGB",(WIDTH,DEPTH))
    x=np.arange(WIDTH,dtype=np.float32)[None,:]
    for row in range(0,DEPTH,96):
        z=np.arange(row,row+96,dtype=np.float32)[:,None]
        h, ridge, shore, ford=terrain(x,z)
        rough=np.hypot(terrain(x+3,z)[0]-terrain(x-3,z)[0],terrain(x,z+3)[0]-terrain(x,z-3)[0])/6
        large,middle,small,detail,micro,grain=(v[row:row+96].astype(np.float32)/255-.5 for v in layers)
        green=np.array([59,87,45])+(.60*large+.26*middle+.14*small)[...,None]*np.array([49,61,43])
        green += (detail*13+micro*11+grain*8)[...,None]
        stone=np.array([130,126,112])+(large*23+small*20+detail*25+micro*23+grain*12)[...,None]
        stratum=np.sin(h*.17+z*.029+middle*6+detail)
        stone += (stratum*5*(.65+small))[...,None]
        grey=np.array([146,140,125])+(large*22+small*18+detail*17+micro*22+grain*16)[...,None]
        rock=smooth((rough-.32+middle*.20)/.72)*smooth((1.15-ridge)/.33)
        sand=smooth((11-h+middle*8)/16)
        trails=smooth((33+middle*28-ford)/26)*smooth((650-shore)/410)*.80
        bars=smooth((large+.59*middle+.24*small-.26)/.20)*.62*smooth((shore-140)/160)
        sand=np.maximum.reduce([sand,trails,bars])
        color=green+(stone-green)*rock[...,None]
        color+=(grey-color)*(sand*(1-rock*.75))[...,None]
        for px,pz in IRON:
            if row-36 <= pz < row+132:
                ore=smooth((32+small*12-np.hypot(x-px,z-pz))/22)
                iron=np.array([122,92,67])+(detail*37+micro*34+grain*23)[...,None]
                color+=(iron-color)*ore[...,None]
        wet=smooth((2-h)/33)*.44
        color*=1-wet[...,None]
        image.paste(Image.fromarray(np.clip(color,0,255).astype(np.uint8)),(0,row))
    image.save(WORK/"warna.png")
    image.save(WORK/"warna.bmp")


def scenario(layout):
    starts, points, iron = (layout[k] for k in ("starts","points","iron"))
    template = (ROOT/"maps/mapinfo-lembah-sungai.lua").read_text(encoding="utf-8")
    template = template.replace("River Valley 1v1", "Pine Crossing 4v4").replace("lembah-sungai-1v1",STEM)
    template = template.replace("Two fords cross a winding river between steep hills and fir groves.",
                                "Three fords between pine groves and slate bluffs.")
    begin,end=template.index("    teams"),template.index("    terrainTypes")
    info=template[:begin]+"    teams = {\n"+"".join(
        f"        [{i}] = {{startPos = {{x = {x}, z = {z}}}}},\n" for i,(x,z) in enumerate(starts))+"    },\n"+template[end:]
    (ROOT/f"maps/mapinfo-{STEM}.lua").write_text(info,encoding="utf-8")

    lines=['return {', '    startScript = "gamedata/skenario/pinus-start.txt",',
           '    radius = 88, detikRebut = 4, poinPerDetik = 1, targetSkor = 2400,', '    titik = {']
    lines += [f'        {{nama = "{label}", x = {x}, z = {z}}},' for label,(x,z) in zip("ABCD",points)]
    lines += ['    },', '    ladang = {']
    lines += ['        '+', '.join(f'{{{x}, {z}}}' for x,z in iron[i:i+3])+',' for i in range(0,len(iron),3)]
    lines += ['    },', '    awal = {']
    for i,(x,z) in enumerate(starts):
        sign=1 if i<4 else -1
        lines.append(f'        {{pos = {{{x}, {z}}}, hadap = {1 if i<4 else 3}, '
                     f'insinyur = {{{sign*116}, {sign*65}}}, kamera = {{{sign*65}, {sign*30}}}, '
                     f'tank = {{{sign*170}, {-sign*86}}}}},')
    lines += ['    },', '    lawan = {},', '}','']
    ai='''for i = 1, 8 do
    local a = skenario.awal[i]
    local x, z = unpack(a.pos)
    local arah = i <= 4 and 1 or -1
    skenario.lawan[i] = {tim = i - 1, hadap = a.hadap, bangunan = {
        {unit = "pabrik_kendaraan", jumlah = 1, tapak = {{x + arah * 100, z - arah * 105}}},
        {unit = "ekstraktor_besi", jumlah = 1, tapak = {{x - arah * 214, z - arah * 96}}},
        {unit = "pompa_minyak", jumlah = 1, tapak = {{x - arah * 111, z + arah * 106}}},
        {unit = "ekstraktor_besi", jumlah = 2, tapak = {{x - arah * 214, z - arah * 96}, {x - arah * 174, z + arah * 116}}},
        {unit = "pabrik_robot", jumlah = 1, tapak = {{x + arah * 106, z + arah * 103}}},
    }}
end
'''
    # Local AI layouts use only exported data and are also readable by LuaMenu.
    lines[0]='local skenario = {'
    folder=ROOT/"game/RTSPC.sdd/gamedata/skenario"
    (folder/"pinus.lua").write_text("\n".join(lines)+ai+"return skenario\n",encoding="utf-8")
    start=['[GAME]', '{', f'    MapName={FILENAME};', '    GameType=RTSPC.sdd;',
           '    MyPlayerName=Player;', '    IsHost=1;', '    StartPosType=0;',
           '    GameStartDelay=1;', '    RecordDemo=0;', '    FixedRNGSeed=1;',
           '    [PLAYER0]{Name=Player;Team=0;Spectator=0;}',
           '    [ALLYTEAM0]{NumAllies=0;}', '    [ALLYTEAM1]{NumAllies=0;}']
    for i in range(8):
        start.append(f'    [TEAM{i}]{{TeamLeader=0;AllyTeam={i//4};RgbColor={"0.23 0.65 1" if i<4 else "1 0.25 0.2"};}}')
        if i:
            team="Ally" if i<4 else "Opponent"
            start.append(f'    [AI{i-1}]{{Name={team} {i};ShortName=NullAI;Version=0.1;Team={i};Host=0;}}')
    start += ['    [MODOPTIONS]{skenario=pinus;lawanuji=1;ekonomi=1;}', '}', '']
    (folder/"pinus-start.txt").write_text("\n".join(start),encoding="utf-8")


def compile_map():
    layout=json.loads((WORK/"layout.json").read_text(encoding="utf-8"))
    heights=np.fromfile(WORK/"tinggi.raw",dtype="<u2").reshape(DEPTH//8+1,WIDTH//8+1)
    h=heights[1::2,1::2].astype(np.float32)*(HIGH-LOW)/65535+LOW
    z,x=np.ogrid[8:DEPTH:16,8:WIDTH:16]
    _,ridge,_,_=terrain(x,z)
    types=np.select([(ridge<.92)&(h>52),h < -7,h < 1],[1,2,3],default=0)
    for xp,zp in (*layout["starts"],*layout["points"],*layout["iron"]):
        assert types[zp//16,xp//16]==0, (xp,zp,"in blocked terrain")
    # Prove all starts and capture points are on the same passable grid.
    from collections import deque
    allowed=(types==0)|(types==3)
    queue=deque([(layout["starts"][0][1]//16,layout["starts"][0][0]//16)])
    reached=set(queue)
    while queue:
        y,xp=queue.popleft()
        for yn,xn in ((y-1,xp),(y+1,xp),(y,xp-1),(y,xp+1)):
            if 0<=yn<h.shape[0] and 0<=xn<h.shape[1] and allowed[yn,xn] and (yn,xn) not in reached:
                reached.add((yn,xn))
                queue.append((yn,xn))
    assert all((z//16,x//16) in reached for x,z in (*layout["starts"],*layout["points"],*layout["iron"]))
    metal=np.zeros(h.shape,dtype=np.uint8)
    z,x=np.ogrid[8:DEPTH:16,8:WIDTH:16]
    for px,pz in layout["iron"]:
        metal[np.hypot(x-px,z-pz)<21]=240
    Image.fromarray(types.astype(np.uint8)).convert("RGB").save(WORK/"tipe.bmp")
    Image.fromarray(metal).convert("RGB").save(WORK/"besi.bmp")
    mask=(h[::2,::2]>18)&(types[::2,::2]==0)
    rz,rx=np.ogrid[0:mask.shape[0],0:mask.shape[1]]
    mask &= np.cos(rx*.41+rz*.29)+np.sin(rz*.27-rx*.31)>.30
    for px,pz in layout["iron"]:
        mask &= np.hypot(rx*32+16-px,rz*32+16-pz)>38
    Image.fromarray(mask.astype(np.uint8)).save(WORK/"rumput.bmp")

    (WORK/"pohon.lua").write_text("".join(
        f"{{name='TreeType{k}', x={x}, z={z}, rot={r}, scale=1.0}}\n" for x,z,k,r in layout["trees"]),encoding="ascii")
    # Grading medan bersama (tahap 5): albedo yang dikompilasi dan minimap (warna rumput) memakai versi tergrading.
    graded=grade(Image.open(WORK/"warna.png"))
    graded.save(WORK/"warna.bmp")
    color=graded.resize((1024,768),Image.Resampling.LANCZOS)
    ground=np.asarray(color,dtype=np.float32)
    relh=np.asarray(Image.fromarray(h).resize(color.size,Image.Resampling.BILINEAR))
    dz,dx=np.gradient(relh)
    ground*=np.clip(1+dx*.11+dz*.08,.57,1.38)[...,None]
    water=smooth(-relh/9)[...,None]
    ground=ground*(1-water)+np.array([49,91,102])*water
    color=Image.fromarray(np.clip(ground,0,255).astype(np.uint8))
    draw=ImageDraw.Draw(color)
    for x,z,k,r in layout["trees"]:
        draw.ellipse((x/4-2.3,z/4-2.3,x/4+2.3,z/4+2.3),fill="#203d28")
    color.resize((1024,1024), Image.Resampling.LANCZOS).save(WORK/"minimap.bmp")
    color.save(ROOT/"menu/RTSPCMenu.sdd/LuaMenu/pinus.jpg",quality=94)
    for x,z in layout["iron"]:
        draw.ellipse((x/4-3,z/4-3,x/4+3,z/4+3),fill="#e4ba68")
    for i,(x,z) in enumerate(layout["starts"]):
        draw.ellipse((x/4-11,z/4-11,x/4+11,z/4+11),fill="#3274a7" if i<4 else "#bb5942",outline="white",width=2)
        draw.text((x/4,z/4),str(i+1),fill="white",anchor="mm")
    for label,(x,z) in zip("ABCD",layout["points"]):
        draw.ellipse((x/4-11,z/4-11,x/4+11,z/4+11),fill="#ebdfbd",outline="#192423",width=2)
        draw.text((x/4,z/4),label,fill="#192423",anchor="mm")
    color.save(ART/"pine-crossing-denah.png")
    scenario(layout)

    lock=json.loads((ROOT/"dependencies.windows.json").read_text(encoding="utf-8"))
    compiler=ROOT/".deps"/next(p["folder"] for p in lock if p["nama"]=="PyMapConv")
    (WORK/"resources").mkdir(exist_ok=True)
    for source in ("nvdxt.exe","resources/geovent.bmp"):
        shutil.copy2(compiler/source,WORK/source)
    smf,smt=(WORK/f"{STEM}.{ext}" for ext in ("smf","smt"))
    for path in (smf,smt):
        path.unlink(missing_ok=True)
    with (WORK/"kompilasi.log").open("wb") as log:
        subprocess.run([compiler/"pymapconv.exe","-t","warna.bmp","-a","tinggi.raw","-y","tipe.bmp",
                        "-m","besi.bmp","-k","pohon.lua","-r","rumput.bmp","-p","minimap.bmp","-o",smf.name,
                        "-n",str(LOW),"-x",str(HIGH),"-q","1"],cwd=WORK,stdout=log,stderr=subprocess.STDOUT,
                       timeout=240,creationflags=subprocess.CREATE_NO_WINDOW)
    if "All Done!" not in (WORK/"kompilasi.log").read_text(encoding="utf-8",errors="replace"):
        raise RuntimeError(f"PyMapConv gagal. Lihat {WORK/'kompilasi.log'}")
    with smf.open("rb") as src:
        magic,version,_,width,depth=struct.unpack("<16siiii",src.read(32))
    assert magic.rstrip(b"\0")==b"spring map file" and version==1 and (width,depth)==(WIDTH//8,DEPTH//8)
    pending=WORK/f"{STEM}.sdz"
    with ZipFile(pending,"w",compression=ZIP_DEFLATED) as pack:
        pack.write(ROOT/f"maps/mapinfo-{STEM}.lua","mapinfo.lua")
        for path in (smf,smt):
            pack.write(path,f"maps/{path.name}")
    pending.replace(ROOT/"maps"/pending.name)
    print(f"{pending.name}: {len(layout['trees'])} trees, {len(layout['iron'])} iron deposits, {len(reached)} connected cells")


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage",choices=("prepare","compile"))
    if parser.parse_args().stage=="prepare":
        prepare()
    else:
        compile_map()
