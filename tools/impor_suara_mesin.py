"""Siapkan potongan loop mesin V2 untuk pemutaran sampel di Recoil."""

from array import array
import math
from pathlib import Path
import sys
import wave


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT.parent / "rts-pc-v2" / "Assets/Konten/Suara"
OUTPUT = ROOT / "game/RTSPC.sdd/sounds/mesin"
HOP = .25
OVERLAP = .10
SEGMENTS = 16
SOURCES = {
    "ringan": "tank_ringan_mesin.wav",
    "medium": "Resources/Mesin/medium_tank.wav",
    "pengintai": "Resources/Mesin/pengintai.wav",
}


def impor(nama, sumber):
    with wave.open(str(sumber), "rb") as asal:
        if asal.getnchannels() != 1 or asal.getsampwidth() != 2:
            raise ValueError(f"Perlu WAV PCM mono 16-bit: {sumber}")
        rate = asal.getframerate()
        hop, overlap = round(rate * HOP), round(rate * OVERLAP)
        if asal.getnframes() != SEGMENTS * hop:
            raise ValueError(f"Panjang loop harus {SEGMENTS * HOP} detik: {sumber}")
        pcm = array("h")
        pcm.frombytes(asal.readframes(asal.getnframes()))
    if sys.byteorder != "little":
        pcm.byteswap()

    fade = [.5 - .5 * math.cos(math.pi * i / (overlap - 1)) for i in range(overlap)]
    for i in range(SEGMENTS):
        start = i * hop
        potongan = array("h", (pcm[(start + j) % len(pcm)] for j in range(hop + overlap)))
        # Fade keluar menimpa fade masuk potongan berikutnya pada sampel sumber yang sama.
        for j, bobot in enumerate(fade):
            potongan[j] = round(potongan[j] * bobot)
            potongan[hop + j] = round(potongan[hop + j] * (1 - bobot))
        if sys.byteorder != "little":
            potongan.byteswap()
        with wave.open(str(OUTPUT / f"{nama}-{i + 1:02d}.wav"), "wb") as hasil:
            hasil.setparams((1, 2, rate, 0, "NONE", "not compressed"))
            hasil.writeframes(potongan.tobytes())


if __name__ == "__main__":
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for nama, file in SOURCES.items():
        impor(nama, SOURCE / file)
