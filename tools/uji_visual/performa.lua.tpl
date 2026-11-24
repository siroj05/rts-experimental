-- Uji performa: JUMLAH unit tempur per tim (campuran 7 jenis) bertempur di tengah Central Hill.
-- FPS dicatat di zoom dekat (400 elmo) dan jauh (1800 elmo) saat pertempuran berlangsung.
local N = JUMLAH
local PUSAT = {1024, 1550}
for k = 0, 3 do
    SHOTS[#SHOTS + 1] = {f = 330 + k * 40, nama = "dekat" .. k, target = "titik", x = PUSAT[1], z = PUSAT[2], jarak = 400}
    SHOTS[#SHOTS + 1] = {f = 350 + k * 40, nama = "jauh" .. k, target = "titik", x = PUSAT[1], z = PUSAT[2], jarak = 1800}
end
local jenis = {"medium_tank", "tank_ringan", "medium_tank_destroyer", "pengintai", "artileri_ringan", "robot_infanteri", "robot_roket"}
local cheat, diberi = false, 0
preUpdate = function()
    local f = Spring.GetGameFrame()
    if not cheat and f >= 30 then cheat = true; Spring.SendCommands("cheat 1") end
    -- Diberi bertahap (20 per frame per tim) supaya perintah give tidak menumpuk dalam satu frame.
    if cheat and f >= 60 and diberi < N then
        for _ = 1, math.min(20, N - diberi) do
            diberi = diberi + 1
            local u = jenis[(diberi - 1) % #jenis + 1]
            local baris, kolom = math.floor((diberi - 1) / 20), (diberi - 1) % 20
            Spring.SendCommands(string.format("give 1 %s 0 @%d,0,%d", u, PUSAT[1] - 260 - baris * 30, PUSAT[2] - 300 + kolom * 30))
            Spring.SendCommands(string.format("give 1 %s 1 @%d,0,%d", u, PUSAT[1] + 260 + baris * 30, PUSAT[2] - 300 + kolom * 30))
        end
    end
end
