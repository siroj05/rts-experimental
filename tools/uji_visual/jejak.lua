-- Uji jejak track kendaraan di Limestone Valley. Pakai dengan kapur-start.txt dan --opsi lawanuji=0.
-- Tiga tank dan satu robot insinyur berjalan zig-zag di padang rumput dekat markas biru, lalu difoto.
local X, Z = 1700, 2000
SHOTS = {
    {f = 700, nama = "jejak-dekat", target = "titik", x = X + 150, z = Z + 150, jarak = 260},
    {f = 710, nama = "jejak-rts", target = "titik", x = X + 150, z = Z + 150, jarak = 700},
}
local cheat, diberi, jalan
preUpdate = function()
    local f = Spring.GetGameFrame()
    if not cheat and f >= 30 then cheat = true; Spring.SendCommands("cheat 1") end
    if cheat and not diberi and f >= 60 then
        diberi = true
        for i, u in ipairs({"medium_tank", "tank_ringan", "medium_tank_destroyer", "robot_insinyur"}) do
            Spring.SendCommands(string.format("give 1 %s 0 @%d,0,%d", u, X + i * 60, Z))
        end
    end
    if diberi and not jalan and f >= 90 then
        jalan = true
        for _, id in ipairs(Spring.GetTeamUnits(0)) do
            local x, _, z = Spring.GetUnitPosition(id)
            if z and math.abs(z - Z) < 5 and x > X then
                Spring.GiveOrderToUnit(id, CMD.MOVE, {x + 120, 0, Z + 150}, 0)
                Spring.GiveOrderToUnit(id, CMD.MOVE, {x - 40, 0, Z + 300}, {"shift"})
                Spring.GiveOrderToUnit(id, CMD.MOVE, {x + 160, 0, Z + 420}, {"shift"})
            end
        end
    end
end
