function gadget:GetInfo()
    return {name = "Building Collision Boxes", desc = "Box collision volumes fitted to building models", layer = 0,
        enabled = true}
end

if not gadgetHandler:IsSyncedCode() then return false end

-- Bug user 2026-11-28: "selalu mengincar titik tertinggi bangunan". Bangunan tanpa collisionvolume memakai bola bawaan
-- Recoil yang jauh lebih besar dari modelnya (uji: Depot F2 tinggi 38 elmo, bola diameter 174; HQ F1 tinggi 66, bola
-- 189), jadi peluru meledak di udara di atas bangunan dan pasukan mengerubungi bangunan tanpa merusaknya.
-- 🟡 Perbaikan: saat bangunan dibuat, volume diganti kotak seukuran batas model (90% lebar dan panjang, 100% tinggi),
-- berpusat di tengah model. Unit bergerak tidak diubah (sudah punya kotak di def).
local sp = Spring
local KOTAK, UJI_KONTINU = 2, 1
local data = {}
for id, ud in pairs(UnitDefs) do
    local m = ud.model
    if ud.speed == 0 and m and m.maxy and m.maxy > m.miny then
        local sx, sy, sz = (m.maxx - m.minx) * .9, m.maxy - m.miny, (m.maxz - m.minz) * .9
        data[id] = {sx, sy, sz}
    end
end

function gadget:UnitCreated(unit, def)
    local d = data[def]
    if not d then return end
    -- Offset relatif ke titik tengah model; tengah model = tengah batas, jadi offset nol.
    sp.SetUnitCollisionVolumeData(unit, d[1], d[2], d[3], 0, 0, 0, KOTAK, UJI_KONTINU, 1)
end

function gadget:Initialize()
    for _, unit in ipairs(sp.GetAllUnits()) do gadget:UnitCreated(unit, sp.GetUnitDefID(unit)) end
end
