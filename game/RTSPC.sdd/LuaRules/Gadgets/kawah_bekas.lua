function gadget:GetInfo()
    return {name = "Crater Marks", desc = "Permanent soil marks on cratered ground", layer = -10, enabled = true}
end

-- Tahap 6 Limestone Valley (✅ user 2026-11-26: "map bisa berlubang permanen jika terkena tembakan atau ledakan").
-- Lubang dibuat Recoil di heightmap (craterMult, gamedata/defs.lua). Gadget ini menempelkan bekas tanah teraduk di
-- atas lubang.
-- - Bekas ledakan bawaan dimatikan (explosionScar = false), karena shader Recoil mengalikan warnanya dengan
--   minimap: cokelat di atas rumput jadi hijau gelap.
-- - Decal Lua tetap memakai warna teksturnya sendiri (bitmaps/scars/kawah*.tga, tools/buat_decal.py) dan tidak
--   memudar.
-- - Bekas yang terjadi di luar pandangan baru ditempel saat lokasinya terlihat oleh tim.
-- Layer -10: handler berhenti di gadget pertama yang return true (efek_benturan_tanah, layer 0), jadi gadget ini
-- harus jalan duluan dan selalu return false.
local aksi = "rts_kawah"

if gadgetHandler:IsSyncedCode() then
    local ukuran = {}
    function gadget:Initialize()
        for id, def in pairs(WeaponDefs) do
            local d = tonumber(def.customParams.kawah_ukuran)
            if d then
                ukuran[id] = d
                Script.SetWatchExplosion(id, true)
            end
        end
    end

    function gadget:Explosion(weapon, x, y, z)
        local d = ukuran[weapon]
        if d and y - Spring.GetGroundHeight(x, z) <= 6 and Spring.GetGroundHeight(x, z) > -2 then
            SendToUnsynced(aksi, x, z, d)
        end
        return false
    end
    return
end

local sp = Spring
local MAKS = 2500
local tunggu, aktif = {}, {}
local nomor = 0

local function tempel(x, z, d)
    local id = sp.CreateGroundDecal()
    if not id then return end
    nomor = nomor + 1
    local h = ((x * 12.9898 + z * 78.233) * 43758.5453) % 1
    local s = d * (.9 + h * .25)
    sp.SetGroundDecalPosAndDims(id, x, z, s, s, 48)
    sp.SetGroundDecalRotation(id, h * 2 * math.pi)
    local n = (nomor % 2) + 1
    sp.SetGroundDecalTexture(id, "mainscar_" .. n, true)
    sp.SetGroundDecalTexture(id, "normscar_" .. n, false)
    sp.SetGroundDecalAlpha(id, .95, 0)
    aktif[#aktif + 1] = id
    if #aktif > MAKS then sp.DestroyGroundDecal(table.remove(aktif, 1)) end
end

local function terlihat(x, z)
    local _, semua = sp.GetSpectatingState()
    return semua or sp.IsPosInLos(x, sp.GetGroundHeight(x, z) + 6, z, sp.GetMyAllyTeamID())
end

local function kawah(_, x, z, d)
    if terlihat(x, z) then tempel(x, z, d)
    elseif #tunggu < 1000 then tunggu[#tunggu + 1] = {x, z, d} end
end

function gadget:Initialize()
    gadgetHandler:AddSyncAction(aksi, kawah)
end

function gadget:Shutdown()
    gadgetHandler:RemoveSyncAction(aksi)
    for _, id in ipairs(aktif) do sp.DestroyGroundDecal(id) end
end

function gadget:GameFrame(f)
    if f % 15 ~= 0 or #tunggu == 0 then return end
    for i = #tunggu, 1, -1 do
        local t = tunggu[i]
        if terlihat(t[1], t[2]) then
            tempel(t[1], t[2], t[3])
            table.remove(tunggu, i)
        end
    end
end
