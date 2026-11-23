-- Posisi simetris di dua koridor Bukit Tengah. Koordinat dalam elmo Recoil.
return {
    radius = 80,
    detikRebut = 4,
    poinPerDetik = 5,
    targetSkor = 1000,
    titik = {
        {nama = "A", x = 776, z = 496},
        {nama = "B", x = 1272, z = 496},
        {nama = "C", x = 776, z = 1552},
        {nama = "D", x = 1272, z = 1552},
    },
    ladang = {
        {240, 880}, {240, 1168}, {452, 1024},
        {1808, 880}, {1808, 1168}, {1596, 1024},
        {800, 368}, {1248, 368}, {800, 1680}, {1248, 1680},
    },
    awal = {
        {hadap = 1, insinyur = {140, 105}, kamera = {65, 30}},
        {hadap = 3, insinyur = {-140, 105}, kamera = {-65, 30}},
    },
    lawan = {
        tim = 1,
        hadap = 3,
        bangunan = {
            {unit = "pabrik_kendaraan", jumlah = 1, tapak = {{1520, 1120}, {1520, 928}}},
            {unit = "ekstraktor_besi", jumlah = 1, tapak = {{1808, 880}, {1808, 1168}}},
            {unit = "pompa_minyak", jumlah = 1, tapak = {{1856, 1024}, {1920, 1008}}},
            {unit = "ekstraktor_besi", jumlah = 2, tapak = {{1808, 880}, {1808, 1168}}},
            {unit = "pabrik_robot", jumlah = 1, tapak = {{1520, 920}, {1576, 1240}}},
        },
    },
}
