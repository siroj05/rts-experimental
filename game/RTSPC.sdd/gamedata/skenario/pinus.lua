local skenario = {
    startScript = "gamedata/skenario/pinus-start.txt",
    radius = 88, detikRebut = 4, poinPerDetik = 1, targetSkor = 2400, -- Tempo 🟡 2026-11-24 (lihat docs/tahapan.md)
    titik = {
        {nama = "A", x = 1776, z = 792},
        {nama = "B", x = 2312, z = 792},
        {nama = "C", x = 1784, z = 2280},
        {nama = "D", x = 2320, z = 2280},
    },
    ladang = {
        {810, 384}, {850, 596}, {1264, 520},
        {810, 1072}, {850, 1284}, {1264, 1208},
        {810, 1808}, {850, 2020}, {1264, 1944},
        {810, 2496}, {850, 2708}, {1264, 2632},
        {1624, 500}, {1760, 940}, {1696, 1536},
        {1760, 2132}, {1576, 2496}, {490, 1736},
        {3286, 2688}, {3246, 2476}, {2832, 2552},
        {3286, 2000}, {3246, 1788}, {2832, 1864},
        {3286, 1264}, {3246, 1052}, {2832, 1128},
        {3286, 576}, {3246, 364}, {2832, 440},
        {2472, 2572}, {2336, 2132}, {2400, 1536},
        {2336, 940}, {2520, 576}, {3606, 1336},
    },
    awal = {
        {pos = {1024, 480}, hadap = 1, insinyur = {116, 65}, kamera = {65, 30}, tank = {170, -86}},
        {pos = {1024, 1168}, hadap = 1, insinyur = {116, 65}, kamera = {65, 30}, tank = {170, -86}},
        {pos = {1024, 1904}, hadap = 1, insinyur = {116, 65}, kamera = {65, 30}, tank = {170, -86}},
        {pos = {1024, 2592}, hadap = 1, insinyur = {116, 65}, kamera = {65, 30}, tank = {170, -86}},
        {pos = {3072, 2592}, hadap = 3, insinyur = {-116, -65}, kamera = {-65, -30}, tank = {-170, 86}},
        {pos = {3072, 1904}, hadap = 3, insinyur = {-116, -65}, kamera = {-65, -30}, tank = {-170, 86}},
        {pos = {3072, 1168}, hadap = 3, insinyur = {-116, -65}, kamera = {-65, -30}, tank = {-170, 86}},
        {pos = {3072, 480}, hadap = 3, insinyur = {-116, -65}, kamera = {-65, -30}, tank = {-170, 86}},
    },
    lawan = {},
}
for i = 1, 8 do
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
return skenario
