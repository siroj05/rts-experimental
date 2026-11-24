-- Koordinat elmo sesuai peta Lembah Sungai.
return {
    startScript = "gamedata/skenario/sungai-start.txt",
    tankAwal = {232, -104},
    radius = 80,
    detikRebut = 4,
    poinPerDetik = 1 --[[ Tempo 🟡 2026-11-24: 2 titik 20 menit, 4 titik 10 menit ]],
    targetSkor = 2400,
    titik = {
        {nama = "A", x = 1736, z = 1152},
        {nama = "B", x = 2504, z = 1152},
        {nama = "C", x = 1592, z = 2944},
        {nama = "D", x = 2360, z = 2944},
    },
    ladang = {
        {408, 1792}, {408, 2304}, {820, 2048}, {1288, 964}, {1152, 3064}, {760, 2920},
        {3688, 2304}, {3688, 1792}, {3276, 2048}, {2808, 3132}, {2944, 1032}, {3336, 1176},
    },
    awal = {
        {hadap = 1, insinyur = {140, 105}, kamera = {65, 30}},
        {hadap = 3, insinyur = {-140, -105}, kamera = {-65, -30}},
    },
    lawan = {
        tim = 1, hadap = 3,
        bangunan = {
            {unit = "pabrik_kendaraan", jumlah = 1, tapak = {{3396, 1916}, {3326, 2186}}},
            {unit = "ekstraktor_besi", jumlah = 1, tapak = {{3688, 1792}, {3688, 2304}}},
            {unit = "pompa_minyak", jumlah = 1, tapak = {{3236, 1866}, {3336, 1716}}},
            {unit = "ekstraktor_besi", jumlah = 2, tapak = {{3688, 1792}, {3688, 2304}}},
            {unit = "pabrik_robot", jumlah = 1, tapak = {{3326, 2186}, {3236, 1866}}},
        },
    },
}
