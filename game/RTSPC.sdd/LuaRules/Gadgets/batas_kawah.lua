function gadget:GetInfo()
    return {name = "Crater Depth Limit", desc = "Caps cumulative crater depth so tanks can drive out", layer = -11,
        enabled = true}
end

if not gadgetHandler:IsSyncedCode() then return false end

-- Bug user 2026-11-28: "tank terjebak". Kawah Recoil menumpuk tanpa batas: kawah yang saling tumpang tindih makin
-- dalam dan dindingnya melebihi tanjakan maksimal tank (maxslope 28°), jadi tank di dasar tidak bisa keluar.
-- 🟡 Perbaikan: sesudah ledakan berkawah, tinggi tanah di sekitarnya dijepit ke [asli - 0,5 m, asli + 0,2 m].
-- Satu kawah tunggal (0,2-0,7 m) hampir tidak berubah; tumpukan kawah berhenti di 0,5 m.
-- Layer -11: jalan sebelum gadget lain yang mungkin menghentikan Explosion dengan return true.
local sp = Spring
local DALAM, BIBIR = 4, 1.6 -- elmo (0,5 m dan 0,2 m)
local radius, antre = {}, {}

function gadget:Initialize()
    -- Senjata berkawah = yang punya customparams.kawah_ukuran (diameter bekas, elmo; gamedata/defs.lua).
    for id, def in pairs(WeaponDefs) do
        local d = tonumber(def.customParams.kawah_ukuran)
        if d then
            -- Lubang Recoil ternyata lebih lebar dari setengah diameter bekas (uji 2026-11-28: artileri masih 2,2 m di
            -- luar radius d/2), jadi radius jepit = diameter bekas penuh + 16.
            radius[id] = d + 16
            Script.SetWatchExplosion(id, true)
        end
    end
end

function gadget:Explosion(weapon, x, y, z)
    local r = radius[weapon]
    if r then antre[#antre + 1] = {x, z, r, Spring.GetGameFrame()} end
    return false
end

local siap = {}
local function jepit()
    local kotak = Game.squareSize
    for _, e in ipairs(siap) do
        local x0, x1 = math.max(0, e[1] - e[3]), math.min(Game.mapSizeX, e[1] + e[3])
        local z0, z1 = math.max(0, e[2] - e[3]), math.min(Game.mapSizeZ, e[2] + e[3])
        for x = x0 - x0 % kotak, x1, kotak do
            for z = z0 - z0 % kotak, z1, kotak do
                local h, asli = sp.GetGroundHeight(x, z), sp.GetGroundOrigHeight(x, z)
                if h < asli - DALAM then
                    sp.SetHeightMap(x, z, asli - DALAM)
                elseif h > asli + BIBIR then
                    sp.SetHeightMap(x, z, asli + BIBIR)
                end
            end
        end
    end
end

-- Recoil menerapkan lubang sesudah callin Explosion (uji 2026-11-28: penjepitan pada frame yang sama meloloskan kawah
-- terakhir, kedalaman tetap 2,5 m), jadi tiap ledakan dijepit 2 frame kemudian.
function gadget:GameFrame(frame)
    if #antre == 0 then return end
    local sisa = {}
    siap = {}
    for _, e in ipairs(antre) do
        if frame >= e[4] + 2 then siap[#siap + 1] = e else sisa[#sisa + 1] = e end
    end
    antre = sisa
    if #siap > 0 then sp.SetHeightMapFunc(jepit) end
end
