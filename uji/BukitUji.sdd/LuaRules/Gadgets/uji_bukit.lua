function gadget:GetInfo()
    return {name = "Bukit 1v1", desc = "Skenario uji Medium Tank", layer = 1, enabled = true}
end

if not gadgetHandler:IsSyncedCode() then
    return
end

function gadget:GameStart()
    for team = 0, 1 do
        local x, _, z = Spring.GetTeamStartPosition(team)
        local facing = team == 0 and 1 or 3
        for i = -1, 1 do
            local pz = z + i * 65
            local unit = Spring.CreateUnit("medium_tank", x, Spring.GetGroundHeight(x, pz), pz, facing, team)
            assert(unit, "Gagal membuat Medium Tank")
        end
    end
    Spring.Echo("RTS_V3_UJI_SIAP 3 Medium Tank per tim")
end
