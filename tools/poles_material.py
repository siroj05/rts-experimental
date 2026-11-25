"""Poles material unit (tahap 6): naikkan kanal pantulan tex2 (G) unit dan bangunan hidup.

Importer lama mengisi tex2.G = metallic × 0,28 dan membuang roughness, jadi pantulan hampir nol dan unit tampak
kusam/plastik di bawah cahaya baru. 🟡 Usulan Claude 2026-11-24: G' = min(1, G × 2,2 + 0,03) pada piksel yang
tertutup (alpha > 0). Bangkai dan tracer tidak disentuh. Idempoten: sumber asli disimpan sekali ke
.cache/tex2-asli/ dan selalu dibaca dari sana.

Pelapukan bangunan (tex1, 🟡 2026-11-24): albedo bangunan yang polos diberi noda besar, bintik kotoran, dan sedikit
desaturasi supaya tidak tampak plastik. Alpha (mask warna tim) tidak disentuh. Sumber asli di .cache/tex1-asli/.

Pemakaian: python tools/poles_material.py
"""
import shutil
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
TEKSTUR = ROOT / "game/RTSPC.sdd/unittextures"
ASLI = ROOT / ".cache/tex2-asli"
KALI, DASAR = 2.2, 0.03


def main():
    ASLI.mkdir(parents=True, exist_ok=True)
    for f in sorted(TEKSTUR.glob("*-tex2.png")):
        if "bangkai" in f.name or f.name.startswith("fx-"):
            continue
        sumber = ASLI / f.name
        if not sumber.exists():
            shutil.copy2(f, sumber)
        a = np.asarray(Image.open(sumber).convert("RGBA")).astype(np.float32) / 255
        tertutup = a[..., 3] > 0
        g = a[..., 1].copy()
        a[..., 1] = np.where(tertutup, np.minimum(1, g * KALI + DASAR), g)
        Image.fromarray((a * 255 + .5).astype(np.uint8), "RGBA").save(f, optimize=True)
        print(f"{f.name}: pantulan rata-rata {g[tertutup].mean():.3f} -> {a[..., 1][tertutup].mean():.3f}")


BANGUNAN = ("inti-komando", "pabrik-kendaraan", "pabrik-robot", "ekstraktor-besi", "pompa-minyak", "gardu", "gudang",
            "radar", "tiang-relay", "menara-pertahanan")


def noise(shape, skala, seed):
    rng = np.random.default_rng(seed)
    kecil = rng.random((max(2, shape[0] // skala), max(2, shape[1] // skala))).astype(np.float32)
    return np.asarray(Image.fromarray((kecil * 255).astype(np.uint8)).resize(shape[::-1], Image.Resampling.BICUBIC),
                      dtype=np.float32) / 255


def lapuk():
    asli = ROOT / ".cache/tex1-asli"
    asli.mkdir(parents=True, exist_ok=True)
    for stem in BANGUNAN:
        f = TEKSTUR / f"{stem}-tex1.png"
        sumber = asli / f.name
        if not sumber.exists():
            shutil.copy2(f, sumber)
        a = np.asarray(Image.open(sumber).convert("RGBA")).astype(np.float32) / 255
        rgb = a[..., :3]
        h, w = rgb.shape[:2]
        noda = noise((h, w), 96, 1) * .6 + noise((h, w), 24, 2) * .4      # noda besar dan sedang
        bintik = noise((h, w), 3, 3)                                       # bintik kotoran halus
        gelap = 1 - .28 * np.clip((noda - .45) / .55, 0, 1) - .07 * (bintik > .78)
        luma = (rgb @ np.array([.2126, .7152, .0722], dtype=np.float32))[..., None]
        kotor = np.array([.36, .33, .27], dtype=np.float32)               # debu kecoklatan
        rgb = luma + (rgb - luma) * .9                                     # desaturasi 10%
        rgb = rgb * gelap[..., None]
        rgb = rgb + (kotor * luma * 1.6 - rgb) * (.22 * np.clip((noda - .55) / .45, 0, 1))[..., None]
        a[..., :3] = np.clip(rgb, 0, 1)
        Image.fromarray((a * 255 + .5).astype(np.uint8), "RGBA").save(f, optimize=True)
        print(f"{f.name}: dilapukkan")


if __name__ == "__main__":
    main()
    lapuk()
