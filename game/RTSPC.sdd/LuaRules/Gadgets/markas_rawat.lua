function gadget:GetInfo()
    return {name = "Command Core Repair Zone", desc = "Command Cores heal allied units inside their zone", enabled = true}
end
if not gadgetHandler:IsSyncedCode() then return false end

-- Tiap 0,5 detik: unit dan bangunan sekutu di dalam radius zona Command Core yang sudah jadi pulih
-- rawat_persen % HP maksimum per detik (minimal rawat_min HP/detik). Zona yang tumpang tindih tidak menumpuk.
local sp = Spring
local markas = UnitDefNames.inti_komando
local radius = tonumber(markas.customParams.radius_zona)
local persen = tonumber(markas.customParams.rawat_persen) / 100
local minimum = tonumber(markas.customParams.rawat_min)
local selang = 15
local detik = selang / Game.gameSpeed
local daftar = {}

function gadget:UnitFinished(unit, def)
    if VFS.Include("gamedata/fraksi.lua").dasar[def] == markas.id then daftar[unit] = true end
end

function gadget:UnitDestroyed(unit)
    daftar[unit] = nil
end

function gadget:GameFrame(frame)
    if frame % selang ~= 0 then return end
    local sudah = {}
    for hq in pairs(daftar) do
        local x, _, z = sp.GetUnitPosition(hq)
        local ally = sp.GetUnitAllyTeam(hq)
        if x then
            for _, u in ipairs(sp.GetUnitsInCylinder(x, z, radius)) do
                if not sudah[u] and u ~= hq and sp.GetUnitAllyTeam(u) == ally and not sp.GetUnitIsBeingBuilt(u) then
                    sudah[u] = true
                    local hp, maks = sp.GetUnitHealth(u)
                    if hp and hp < maks then
                        sp.SetUnitHealth(u, math.min(maks, hp + math.max(minimum, maks * persen) * detik))
                    end
                end
            end
        end
    end
end
