local lontar = {jarakMin = 240}

function lontar.target(unit, weapon)
    local jenis, _, sasaran = Spring.GetUnitWeaponTarget(unit, weapon)
    if jenis == 2 and sasaran then return sasaran[1], sasaran[2], sasaran[3] end
    if jenis == 1 and sasaran and Spring.ValidUnitID(sasaran) then
        local _, _, _, _, _, _, x, y, z = Spring.GetUnitPosition(sasaran, true, true)
        return x, y, z
    end
end

function lontar.sudut(jarak)
    return math.rad(25 + 30 * math.max(0, math.min(1, (jarak - lontar.jarakMin) / 720)))
end

return lontar
