"""Build Verdant Ridge. prepare writes editable Blender inputs; compile creates the Recoil archive."""
import argparse
from io import BytesIO
import json
from pathlib import Path
import shutil
import struct
import subprocess
from zipfile import ZIP_DEFLATED, ZipFile

import numpy as np
from PIL import Image, ImageDraw

from punggung_hijau_layout import DEPTH,HIGH,IRON,LOW,NAME,POINTS,STARTS,STEM,WIDTH,fields,forest,smooth

ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/".cache"/STEM
ART=ROOT.parent/"blender-assets/peta"/STEM
LOCK=json.loads((ROOT/"dependencies.windows.json").read_text(encoding="utf8"))
PACKAGES={p["nama"]:ROOT/".deps"/p["folder"] for p in LOCK}


def prepare():
    WORK.mkdir(parents=True,exist_ok=True)
    z,x=np.ogrid[0:769,0:1025]
    h,_,rock,sand,_,_=fields(x,z)
    for px,pz in STARTS:
        i,j=px//8,pz//8
        assert np.ptp(h[j-56:j+57,i-56:i+57])<.001
    assert all(np.hypot(x-a,z-b)>=200 for i,(x,z) in enumerate(IRON) for a,b in IRON[i+1:])
    assert h.min()*8>=LOW and h.max()*8<=HIGH
    np.rint((h*8-LOW)*65535/(HIGH-LOW)).astype('<u2').tofile(WORK/'tinggi.raw')
    zc,xc=np.ogrid[1:768:2,1:1024:2]
    g,block,_,s,_,_=fields(xc,zc)
    types=np.where(g<-.15,2,block.astype('uint8'))
    metal=np.zeros(types.shape,'uint8')
    for px,pz in (*POINTS,*IRON):
        field=np.hypot(xc-px/8,zc-pz/8)<4
        assert not np.any(block[field])
        if (px,pz) in IRON: metal[field]=240
    Image.fromarray(types.astype('uint8')).convert('RGB').save(WORK/'tipe.bmp')
    Image.fromarray(metal).convert('RGB').save(WORK/'besi.bmp')
    grass=(~block & (g>1.5)&(s<.65)&(np.cos(zc/13+xc/17)+np.sin(xc/31-zc/8)>-.85))
    Image.fromarray(grass[::2,::2].astype('uint8')).save(WORK/'rumput.bmp')
    trees=forest()
    assert 3000<=len(trees)<=5000
    (WORK/'pohon.lua').write_text(''.join(
        f"{{name='TreeType{k}', x={a}, z={b}, rot={r}, scale=1.0}}\n" for a,b,k,r in trees),encoding='ascii')
    print(f'{len(trees)} trees, sand {100*(sand>.5).mean():.2f}%, blocked {100*block.mean():.2f}%',flush=True)
    texture(h,rock,sand)
    overview(h,trees)


def texture(h,rock,sand):
    rng=np.random.default_rng(16409)
    # Sample macro fields bilinearly; retain fine grass blades and stone grains at 8 px/m.
    maps=[Image.fromarray(a.astype('float32')) for a in (h,rock,sand)]
    rngmaps=[Image.fromarray(rng.integers(0,256,(n*3//4,n),dtype='uint8')) for n in (64,256,1024)]
    with ZipFile(PACKAGES["Recoil Engine"]/'base/spring/bitmaps.sdz') as archive:
        grass=np.asarray(Image.open(BytesIO(archive.read('bitmaps/grass3.jpg'))).convert('L'),dtype='float32')
        detail=np.asarray(Image.open(BytesIO(archive.read('bitmaps/detailtex2.bmp'))).convert('L'),dtype='float32')
    grass-=grass.mean()
    detail-=detail.mean()
    image=Image.new('RGB',(WIDTH,DEPTH))
    x=np.arange(WIDTH)[None,:]
    for row in range(0,DEPTH,96):
        z=np.arange(row,row+96)[:,None]
        def band(im,filter):
            box=(0,row/DEPTH*im.height,im.width,(row+96)/DEPTH*im.height)
            return np.asarray(im.resize((WIDTH,96),filter,box),dtype='float32')
        altitude,cliff,sandmask=(band(im,Image.Resampling.BILINEAR) for im in maps)
        broad,medium,fine=(band(im,Image.Resampling.BICUBIC)/255-.5 for im in rngmaps)
        blade=grass[(z+x//151)%grass.shape[0],(x+z//93)%grass.shape[1]]
        grit=detail[(z-x//76)%detail.shape[0],(x+z//41)%detail.shape[1]]
        grain=rng.normal(0,2,(96,WIDTH)).astype('float32')
        green=np.array([57,82,43],dtype='float32')+(broad*48+medium*31+fine*16+blade*.57+grain)[...,None]
        green[:,:,0]+=6*np.sin(x/338+z/420)
        stone=np.array([113,110,101],dtype='float32')+(broad*25+fine*24+grit*.53+grain
            +8*np.sin(altitude*1.9+z/41+medium*5))[...,None]
        grey=np.array([114,109,99],dtype='float32')+(medium*29+fine*19+grit*.52+grain)[...,None]
        mix=smooth((sandmask+medium*.24+fine*.16-.10)/.8)
        color=green+(grey-green)*mix[...,None]
        mix=smooth((cliff+medium*.08+fine*.05-.09)/.44)
        color+=(stone-color)*mix[...,None]
        color*=1-.26*smooth((1-altitude)/3)[...,None]
        for px,pz in IRON:
            if row-42 < pz < row+138:
                ore=smooth((35+fine*16-np.hypot(x-px,z-pz))/21)
                color+=(np.array([118,85,65])+grit[...,None]*.6-color)*ore[...,None]
        image.paste(Image.fromarray(np.clip(color,0,255).astype('uint8')),(0,row))
    image.save(WORK/'warna.bmp')
    image.save(WORK/'warna.png',compress_level=2)


def overview(h,trees):
    image=Image.open(WORK/'warna.bmp').resize((1024,768),Image.Resampling.LANCZOS)
    elevation=h[:768,:1024]
    dz,dx=np.gradient(elevation)
    shade=np.clip(1+.57*dx+.5*dz,.53,1.35)
    col=np.array(image)*shade[...,None]
    water=smooth(-elevation)[...,None]
    image=Image.fromarray(np.clip(col*(1-water)+np.array([48,84,77])*water,0,255).astype('uint8'))
    d=ImageDraw.Draw(image)
    for x,z,k,_ in trees:
        a,b=x/8,z/8
        d.ellipse((a-1.4,b-1.4,a+1.4,b+1.4),fill=(30+k*2,54+k*2,35))
    image.save(ROOT/'menu/RTSPCMenu.sdd/LuaMenu/hijau.jpg',quality=94)
    image.resize((1024,1024),Image.Resampling.LANCZOS).save(WORK/'minimap.bmp')
    for x,z in IRON:
        a,b=x/8,z/8
        d.ellipse((a-3,b-3,a+3,b+3),fill='#efc47d',outline='#594026')
    for i,(x,z) in enumerate(STARTS+POINTS):
        a,b=x/8,z/8
        d.ellipse((a-10,b-10,a+10,b+10),fill=('#346d94' if i<4 else '#a35242') if i<8 else '#e9dfc3',outline='#222c26',width=2)
        d.text((a,b),str(i+1) if i<8 else 'ABCD'[i-8],fill='white' if i<8 else 'black',anchor='mm')
    image.save(ROOT/'maps/punggung-hijau-denah.png')


def compile_map():
    compiler=PACKAGES['PyMapConv']
    (WORK/'resources').mkdir(exist_ok=True)
    for source in ('nvdxt.exe','resources/geovent.bmp'):
        shutil.copy2(compiler/source,WORK/source)
    smf,smt=[WORK/f'{STEM}.{ext}' for ext in ('smf','smt')]
    for p in (smf,smt): p.unlink(missing_ok=True)
    with (WORK/'kompilasi.log').open('wb') as log:
        subprocess.run([compiler/'pymapconv.exe','-t','warna.bmp','-a','tinggi.raw','-y','tipe.bmp','-m','besi.bmp',
                        '-k','pohon.lua','-r','rumput.bmp','-p','minimap.bmp','-o',smf.name,'-n',str(LOW),'-x',str(HIGH),'-q','1'],
                       cwd=WORK,stdout=log,stderr=subprocess.STDOUT,timeout=900,creationflags=subprocess.CREATE_NO_WINDOW)
    assert 'All Done!' in (WORK/'kompilasi.log').read_text(errors='replace')
    with smf.open('rb') as f:
        magic,version,_,sx,sz=struct.unpack('<16siiii',f.read(32))
    assert (magic.rstrip(b'\0'),version,sx,sz)==(b'spring map file',1,1024,768)
    with smt.open('rb') as f: assert f.read(16).rstrip(b'\0')==b'spring tilefile'
    out=WORK/f'{STEM}.sdz'
    with ZipFile(out,'w',ZIP_DEFLATED) as zipf:
        zipf.write(ROOT/f'maps/mapinfo-{STEM}.lua','mapinfo.lua')
        for p in (smf,smt): zipf.write(p,'maps/'+p.name)
    out.replace(ROOT/'maps'/out.name)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage',choices=('prepare','compile'))
    if parser.parse_args().stage=='prepare': prepare()
    else: compile_map()

