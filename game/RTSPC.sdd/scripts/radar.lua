local parabola = piece("parabola")

local function pantau()
    local aktif = false
    while true do
        local nyala = Spring.GetUnitRulesParam(unitID, "daya_fraksi1") == 1
        if nyala ~= aktif then
            aktif = nyala
            if aktif then Spin(parabola, y_axis, math.rad(90), math.rad(180))
            else StopSpin(parabola, y_axis, math.rad(180)) end
        end
        Sleep(100)
    end
end

function script.Create() StartThread(pantau) end
function script.Killed() return 1 end
