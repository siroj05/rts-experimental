function gadget:GetInfo()
    return {name = "Scenario Start", desc = "Spawns scenario starting units", layer = 1, enabled = true}
end

if not gadgetHandler:IsSyncedCode() then
    return
end

local skenario = VFS.Include("gamedata/skenario.lua")
if not skenario then return false end

local ekonomi = Spring.GetModOptions().ekonomi == "1"

local function buat(nama, x, z, hadap, tim)
    return assert(Spring.CreateUnit(nama, x, Spring.GetGroundHeight(x, z), z, hadap, tim),
        "Failed to spawn " .. nama)
end

function gadget:GameStart()
    for i, awal in ipairs(skenario.awal) do
        local team = i - 1
        local x, _, z = Spring.GetTeamStartPosition(team)
        local facing = awal.hadap
        if ekonomi then
            buat("inti_komando", x, z, facing, team)
            buat("robot_insinyur", x + awal.insinyur[1], z + awal.insinyur[2], facing, team)
            if skenario.tankAwal then
                local tanda = i == 1 and 1 or -1
                buat("medium_tank", x + tanda * skenario.tankAwal[1], z + tanda * skenario.tankAwal[2], facing, team)
            end
            local hq = UnitDefNames.inti_komando
            Spring.SetTeamResource(team, "ms", hq.metalStorage)
            Spring.SetTeamResource(team, "es", hq.energyStorage)
            Spring.SetTeamResource(team, "metal", 800)
            Spring.SetTeamResource(team, "energy", 2600)
        else
            for i = -1, 1 do
                buat("medium_tank", x, z + i * 65, facing, team)
            end
        end
    end
    Spring.Echo(ekonomi and "RTS_V3_TEST_READY Headquarters and one engineer per team" or "RTS_V3_TEST_READY Three Medium Tanks per team")
end
