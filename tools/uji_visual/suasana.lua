-- Langit, cahaya, kabut, air (tahap 6 peta). Pakai dengan --spectator. rx = kemiringan kamera Spring (radian):
-- turun = rx - pi/2, bawaan 2,677 ≈ 63°. ry = arah hadap, 0 = utara.
SHOTS = {
    {f = 60, nama = "peta-jauh", target = "tengah", jarak = 9000},
    {f = 70, nama = "rts-sungai", target = "titik", x = 6144, z = 6144, jarak = 1100},
    {f = 80, nama = "sungai-dekat", target = "titik", x = 6144, z = 6144, jarak = 350},
    {f = 90, nama = "cakrawala-a", target = "titik", x = 4000, z = 6144, jarak = 1400, rx = 1.9, ry = 1.57},
    {f = 100, nama = "cakrawala-b", target = "titik", x = 6144, z = 8000, jarak = 1400, rx = 1.9, ry = 0},
    {f = 110, nama = "sungai-miring", target = "titik", x = 6144, z = 6500, jarak = 500, rx = 2.2, ry = 0},
}
