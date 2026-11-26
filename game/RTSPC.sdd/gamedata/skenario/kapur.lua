-- Limestone Valley 4v4 (dibuat tools/buat_lembah_kapur.py, seed 1). Deathmatch dulu (keputusan user
-- 2026-11-26); titik A-C (dua arung + pulau) disiapkan untuk mode Control Points.
local skenario = {
    startScript = "gamedata/skenario/kapur-start.txt",
    radius = 88, detikRebut = 4, poinPerDetik = 1, targetSkor = 2400,
    titik = {
        {nama = "A", x = 6332, z = 1768},
        {nama = "B", x = 6144, z = 6144},
        {nama = "C", x = 5956, z = 10520},
    },
    ladang = {{1412, 1326}, {1310, 2067}, {782, 1546}, {2055, 4082}, {1662, 4513}, {1425, 3843}, {1992, 6691}, {1344, 6800}, {1453, 6129}, {1754, 9945}, {1112, 9964}, {1380, 9281}, {4913, 7684}, {5242, 7983}, {4818, 8116}, {3155, 10837}, {2815, 11123}, {2739, 10686}, {5532, 11449}, {5099, 11349}, {5404, 11026}, {10876, 10962}, {10978, 10221}, {11506, 10742}, {10233, 8206}, {10626, 7775}, {10863, 8445}, {10296, 5597}, {10944, 5488}, {10835, 6159}, {10534, 2343}, {11176, 2324}, {10908, 3007}, {7375, 4604}, {7046, 4305}, {7470, 4172}, {9133, 1451}, {9473, 1165}, {9549, 1602}, {6756, 839}, {7189, 939}, {6884, 1262}, {6149, 5904}, {6139, 6384}},
    awal = {
        {pos = {1197, 1680}, hadap = 1, insinyur = {116, 65}, kamera = {65, 30}, tank = {170, -86}},
        {pos = {1707, 4156}, hadap = 1, insinyur = {116, 65}, kamera = {65, 30}, tank = {170, -86}},
        {pos = {1615, 6515}, hadap = 1, insinyur = {116, 65}, kamera = {65, 30}, tank = {170, -86}},
        {pos = {1389, 9724}, hadap = 1, insinyur = {116, 65}, kamera = {65, 30}, tank = {170, -86}},
        {pos = {11091, 10608}, hadap = 3, insinyur = {-116, -65}, kamera = {-65, -30}, tank = {-170, 86}},
        {pos = {10581, 8132}, hadap = 3, insinyur = {-116, -65}, kamera = {-65, -30}, tank = {-170, 86}},
        {pos = {10673, 5773}, hadap = 3, insinyur = {-116, -65}, kamera = {-65, -30}, tank = {-170, 86}},
        {pos = {10899, 2564}, hadap = 3, insinyur = {-116, -65}, kamera = {-65, -30}, tank = {-170, 86}},
    },
}
return skenario
