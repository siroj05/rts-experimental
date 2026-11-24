local sp = Spring
local turret, laras, moncong = piece("turret", "laras", "moncong")
local target = VFS.Include("gamedata/lontar.lua").target
local minPitch, maxPitch = math.rad(-20), math.rad(35)
local jarakMin = tonumber(WeaponDefNames.rts_meriam_menara.customParams.jarak_min)

local function bolehTembak(weapon)
    if sp.GetUnitRulesParam(unitID, "daya_fraksi1") ~= 1 then return false end
    local tx, _, tz = target(unitID, weapon)
    if not tx then return false end
    local x, _, z = sp.GetUnitPosition(unitID)
    return (x - tx)^2 + (z - tz)^2 >= jarakMin^2
end

function script.AimFromWeapon() return laras end
function script.QueryWeapon() return moncong end

function script.AimWeapon(weapon, heading, pitch)
    Signal(1)
    SetSignalMask(1)
    if not bolehTembak(weapon) or pitch < minPitch or pitch > maxPitch then return false end
    Turn(turret, y_axis, heading, math.rad(35))
    Turn(laras, x_axis, -pitch, math.rad(20))
    WaitForTurn(turret, y_axis)
    WaitForTurn(laras, x_axis)
    return bolehTembak(weapon)
end

function script.BlockShot(weapon) return not bolehTembak(weapon) end

function script.Killed() return 1 end
