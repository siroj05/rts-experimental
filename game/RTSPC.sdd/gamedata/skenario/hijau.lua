local skenario = {
    startScript = "gamedata/skenario/hijau-start.txt",
    radius = 88, detikRebut = 4, poinPerDetik = 1, targetSkor = 2400,
    titik = {
        {nama = "A", x = 4096, z = 800},
        {nama = "B", x = 4096, z = 2200},
        {nama = "C", x = 4096, z = 3824},
        {nama = "D", x = 4096, z = 5360},
    },
    ladang = {
        {688, 528}, {720, 1000}, {1320, 848}, {688, 2032},
        {720, 2504}, {1320, 2352}, {688, 3600}, {720, 4072},
        {1320, 3920}, {688, 5152}, {720, 5624}, {1320, 5472},
        {2544, 656}, {3640, 992}, {2824, 1976}, {3808, 2424},
        {2624, 3648}, {3688, 3944}, {2768, 5080}, {3560, 5488},
        {7504, 528}, {7472, 1000}, {6872, 848}, {7504, 2032},
        {7472, 2504}, {6872, 2352}, {7504, 3600}, {7472, 4072},
        {6872, 3920}, {7504, 5152}, {7472, 5624}, {6872, 5472},
        {5648, 656}, {4552, 992}, {5368, 1976}, {4384, 2424},
        {5568, 3648}, {4504, 3944}, {5424, 5080}, {4632, 5488},
    },
    awal = {
        {pos = {976, 752}, hadap = 1, insinyur = {116, 65}, kamera = {65, 30}, tank = {170, -86}},
        {pos = {976, 2256}, hadap = 1, insinyur = {116, 65}, kamera = {65, 30}, tank = {170, -86}},
        {pos = {976, 3824}, hadap = 1, insinyur = {116, 65}, kamera = {65, 30}, tank = {170, -86}},
        {pos = {976, 5376}, hadap = 1, insinyur = {116, 65}, kamera = {65, 30}, tank = {170, -86}},
        {pos = {7216, 752}, hadap = 3, insinyur = {-116, -65}, kamera = {-65, -30}, tank = {-170, 86}},
        {pos = {7216, 2256}, hadap = 3, insinyur = {-116, -65}, kamera = {-65, -30}, tank = {-170, 86}},
        {pos = {7216, 3824}, hadap = 3, insinyur = {-116, -65}, kamera = {-65, -30}, tank = {-170, 86}},
        {pos = {7216, 5376}, hadap = 3, insinyur = {-116, -65}, kamera = {-65, -30}, tank = {-170, 86}},
    },
    lawan = {},
}
for i = 1, 8 do
    local a = skenario.awal[i]
    local x, z = unpack(a.pos)
    local arah = i <= 4 and 1 or -1
    skenario.lawan[i] = {tim = i - 1, hadap = a.hadap, bangunan = {
        {unit = "pabrik_kendaraan", jumlah = 1, tapak = {{x + arah * 100, z - arah * 105}}},
        {unit = "ekstraktor_besi", jumlah = 1, tapak = {{x - arah * 288, z - 224}}},
        {unit = "pompa_minyak", jumlah = 1, tapak = {{x - arah * 111, z + arah * 106}}},
        {unit = "ekstraktor_besi", jumlah = 2, tapak = {{x - arah * 288, z - 224}, {x - arah * 256, z + 248}}},
        {unit = "pabrik_robot", jumlah = 1, tapak = {{x + arah * 106, z + arah * 103}}},
    }}
end
return skenario
