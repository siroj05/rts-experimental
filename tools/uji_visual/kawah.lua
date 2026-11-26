-- Uji tapak bangunan + kawah di Limestone Valley (tahap 6). Pakai dengan kapur-start.txt dan --opsi lawanuji=0.
-- Tiap senjata menembak tanah sekali. Kawah pertama diukur dari GetGroundOrigHeight dikurangi GetGroundHeight
-- (kedalaman pusat dan diameter |selisih| > 0,05 m), lalu unit dihentikan supaya kawah tidak bertumpuk.
-- Baris log: KAWAH, <senjata>, dalam=<m>, bibir=<m>, diameter=<m>.
local SX, SZ = 1197, 1680
local UJI = {
    -- unit, x target, z target, jarak tembak (elmo, unit di utara target)
    {"medium_tank", 1700, 2300, 200},
    {"tank_ringan", 1950, 2300, 200},
    {"medium_tank_destroyer", 2200, 2300, 200},
    {"robot_roket", 2450, 2300, 180},
    {"artileri_ringan", 1450, 2300, 420},
}
local BANGUNAN = {{"pabrik_kendaraan", SX + 260, SZ + 40}, {"gudang", SX + 260, SZ - 170},
    {"radar", SX - 10, SZ + 230}, {"ekstraktor_besi", SX + 140, SZ + 240}, {"pompa_minyak", SX + 230, SZ + 240}}

SHOTS = {
    {f = 900, nama = "tapak-dekat", target = "titik", x = SX + 150, z = SZ + 60, jarak = 380},
    {f = 910, nama = "tapak-rts", target = "titik", x = SX + 150, z = SZ + 60, jarak = 900},
    {f = 920, nama = "kawah-medium", target = "titik", x = 1700, z = 2300, jarak = 200},
    {f = 930, nama = "kawah-destroyer", target = "titik", x = 2200, z = 2300, jarak = 200},
    {f = 940, nama = "kawah-artileri", target = "titik", x = 1450, z = 2300, jarak = 200},
    {f = 950, nama = "kawah-rts", target = "titik", x = 2200, z = 2250, jarak = 700},
}
local cheat, diberi, perintah = false, false, false
local uji = {}

local function ukur(t)
    local best, bx, bz = 0, t.x, t.z
    for dz = -64, 64, 4 do
        for dx = -64, 64, 4 do
            local d = Spring.GetGroundOrigHeight(t.x + dx, t.z + dz) - Spring.GetGroundHeight(t.x + dx, t.z + dz)
            if d > best then best, bx, bz = d, t.x + dx, t.z + dz end
        end
    end
    if best < .4 then return nil end
    local rim, r = 0, 0
    for a = 0, 7 do
        local ang = a * math.pi / 4
        for s = 1, 64 do
            local x, z = bx + math.cos(ang) * s, bz + math.sin(ang) * s
            local d = Spring.GetGroundOrigHeight(x, z) - Spring.GetGroundHeight(x, z)
            if math.abs(d) > .4 then r = math.max(r, s) end
            rim = math.max(rim, -d)
        end
    end
    return best, rim, r
end

preUpdate = function()
    local f = Spring.GetGameFrame()
    if not cheat and f >= 30 then cheat = true; Spring.SendCommands("cheat 1") end
    if cheat and not diberi and f >= 60 then
        diberi = true
        for _, b in ipairs(BANGUNAN) do
            Spring.SendCommands(string.format("give 1 %s 0 @%d,0,%d", b[1], b[2], b[3]))
        end
        for _, u in ipairs(UJI) do
            Spring.SendCommands(string.format("give 1 %s 0 @%d,0,%d", u[1], u[2], u[3] - u[4]))
        end
    end
    if diberi and not perintah and f >= 120 then
        perintah = true
        for _, id in ipairs(Spring.GetTeamUnits(0)) do
            local def = UnitDefs[Spring.GetUnitDefID(id)].name
            for _, u in ipairs(UJI) do
                if def == u[1] then
                    uji[#uji + 1] = {id = id, nama = def, x = u[2], z = u[3]}
                    Spring.GiveOrderToUnit(id, CMD.ATTACK, {u[2], Spring.GetGroundHeight(u[2], u[3]), u[3]}, 0)
                end
            end
        end
    end
    for _, t in ipairs(uji) do
        if not t.selesai then
            if not t.kena then
                if ukur(t) then t.kena = f; Spring.GiveOrderToUnit(t.id, CMD.STOP, {}, 0) end
            elseif f >= t.kena + 30 then
                t.selesai = true
                local d, rim, r = ukur(t)
                Spring.Echo(string.format("KAWAH, %s, dalam=%.2f m, bibir=%.2f m, diameter=%.1f m, frame=%d",
                    t.nama, (d or 0) / 8, (rim or 0) / 8, (r or 0) * 2 / 8, t.kena))
            end
        end
    end
end
