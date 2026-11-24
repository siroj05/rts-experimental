"""Poles material unit (tahap 6): naikkan kanal pantulan tex2 (G) unit dan bangunan hidup.

Importer lama mengisi tex2.G = metallic × 0,28 dan membuang roughness, jadi pantulan hampir nol dan unit tampak
kusam/plastik di bawah cahaya baru. 🟡 Usulan Claude 2026-11-24: G' = min(1, G × 2,2 + 0,03) pada piksel yang
tertutup (alpha > 0). Bangkai dan tracer tidak disentuh. Idempoten: sumber asli disimpan sekali ke
.cache/tex2-asli/ dan selalu dibaca dari sana.

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


if __name__ == "__main__":
    main()
