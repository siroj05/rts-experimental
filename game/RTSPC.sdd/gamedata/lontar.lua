local lontar = {jarakMin = 240}

function lontar.posisiUnit(unit, target)
    -- Gunakan posisi perkiraan radar dari tim penembak dan posisi bidik asli saat terlihat.
    local _, _, _, _, _, _, x, y, z = CallAsTeam({read = Spring.GetUnitTeam(unit)}, Spring.GetUnitPosition, target, true, true)
    return x, y, z
end

function lontar.target(unit, weapon)
    local jenis, _, sasaran = Spring.GetUnitWeaponTarget(unit, weapon)
    if jenis == 2 and sasaran then return sasaran[1], sasaran[2], sasaran[3] end
    if jenis == 1 and sasaran and Spring.ValidUnitID(sasaran) then
        return lontar.posisiUnit(unit, sasaran)
    end
end

function lontar.sudut(jarak)
    return math.rad(25 + 30 * math.max(0, math.min(1, (jarak - lontar.jarakMin) / 720)))
end

return lontar
