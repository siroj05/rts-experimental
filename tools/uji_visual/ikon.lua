-- Ikon zoom jauh: pasukan campuran di Central Hill dilihat dari 900, 1500, dan 2200 elmo.
local PUSAT = {800, 1640}
for k, j in ipairs({900, 1500, 2200}) do
    SHOTS[#SHOTS + 1] = {f = 200 + k * 30, nama = "ikon" .. j, target = "titik", x = PUSAT[1], z = PUSAT[2], jarak = j}
end
local cheat, diberi = false, false
preUpdate = function()
    local f = Spring.GetGameFrame()
    -- /cheat harus aktif satu frame sebelum /give (kalau dikirim bersamaan, give ditolak).
    if not cheat and f >= 30 then cheat = true; Spring.SendCommands("cheat 1") end
    if cheat and not diberi and f >= 60 then
        diberi = true
        for _, u in ipairs({"medium_tank", "tank_ringan", "medium_tank_destroyer", "robot_roket", "robot_infanteri", "robot_infanteri"}) do
            Spring.SendCommands(string.format("give 1 %s 0 @%d,0,%d", u, PUSAT[1] - 110, PUSAT[2] + math.random(-50, 50)))
            Spring.SendCommands(string.format("give 1 %s 1 @%d,0,%d", u, PUSAT[1] + 110, PUSAT[2] + math.random(-50, 50)))
        end
        Spring.SendCommands("give 1 artileri_ringan 0 @" .. (PUSAT[1] - 420) .. ",0," .. PUSAT[2])
        Spring.SendCommands("give 1 artileri_ringan 1 @" .. (PUSAT[1] + 420) .. ",0," .. PUSAT[2])
    end
end
