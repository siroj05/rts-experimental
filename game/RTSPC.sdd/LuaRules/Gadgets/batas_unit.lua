function gadget:GetInfo()
    return {name = "Unit Limit", desc = "Caps every team at 1000 units", layer = 0, enabled = true}
end

if not gadgetHandler:IsSyncedCode() then return false end

-- Batas unit per tim (✅ user 2026-11-28: "batas unit itu 1000 masing masing tim, jadi AI juga batasnya 1000").
-- Berlaku untuk pemain dan AI; pabrik dan insinyur tidak bisa membuat unit baru saat tim sudah 1000 unit.
local BATAS = 1000
local sp = Spring

function gadget:AllowUnitCreation(unitDefID, builderID, builderTeam)
    return sp.GetTeamUnitCount(builderTeam) < BATAS
end
