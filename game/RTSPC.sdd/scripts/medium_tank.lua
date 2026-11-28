local rig = VFS.Include("gamedata/medium_tank_rig.lua")
local turret, barrel, muzzle = piece("turret", "laras", "moncong")
local turretSpeed, barrelSpeed = math.rad(100), math.rad(45)
local watchingAim = false
local sides = {}
for _, name in ipairs({"kiri", "kanan"}) do
    local track = "track_" .. name
    local side = {trace = {piece(track)}, wheels = {}, distance = 0, phase = 1, omega = 0}
    for phase = 1, rig.fase - 1 do
        side.trace[phase + 1] = piece(track .. "_" .. phase)
    end
    for i, wheel in ipairs(rig.roda) do
        side.wheels[i] = {piece(wheel[1] .. "_" .. name), wheel[2]}
    end
    sides[name] = side
end

local function animateSide(side, travel)
    if not (math.abs(travel) > 0.002) then -- juga menyaring NaN
        travel = 0
    end
    side.distance = (side.distance + travel) % rig.pitch
    local phase = math.min(rig.fase, math.max(1, math.floor(side.distance * rig.fase / rig.pitch) % rig.fase + 1))
    if phase ~= side.phase then
        Hide(side.trace[side.phase])
        Show(side.trace[phase])
        side.phase = phase
    end
    local omega = travel * Game.gameSpeed
    if omega ~= side.omega then
        for _, wheel in ipairs(side.wheels) do
            if omega == 0 then
                StopSpin(wheel[1], x_axis, 0)
            else
                Spin(wheel[1], x_axis, omega / wheel[2], 0)
            end
        end
        side.omega = omega
    end
end

local function drive()
    local lastX, _, lastZ = Spring.GetUnitPosition(unitID)
    local lastHeading = Spring.GetUnitHeading(unitID)
    while true do
        Sleep(33)
        local x, _, z = Spring.GetUnitPosition(unitID)
        local fx, _, fz = Spring.GetUnitDirection(unitID)
        local heading = Spring.GetUnitHeading(unitID)
        if not x or not fx or not heading then return end
        local roll = (x - lastX) * fx + (z - lastZ) * fz
        local turn = ((heading - lastHeading + 32768) % 65536 - 32768) * (2 * math.pi / 65536)
        -- Positive yaw turns toward engine +X, which is the model's left side.
        local diff = turn * rig.gauge
        animateSide(sides.kiri, roll - diff)
        animateSide(sides.kanan, roll + diff)
        lastX, lastZ, lastHeading = x, z, heading
    end
end

function script.Create()
    for _, side in pairs(sides) do
        for phase = 2, rig.fase do
            Hide(side.trace[phase])
        end
    end
    StartThread(drive)
end

function script.AimFromWeapon()
    return barrel
end

function script.QueryWeapon()
    return muzzle
end

local function restoreAim(weapon)
    -- This watcher survives the signals that replace an in-progress aim.
    SetSignalMask(0)
    local idleSince
    while true do
        Sleep(150)
        local target = Spring.GetUnitWeaponTarget(unitID, weapon)
        if target == nil then break end
        if target == 0 then
            local frame = Spring.GetGameFrame()
            idleSince = idleSince or frame
            if frame - idleSince >= Game.gameSpeed then
                Turn(turret, y_axis, 0, turretSpeed)
                Turn(barrel, x_axis, 0, barrelSpeed)
                break
            end
        else
            idleSince = nil
        end
    end
    watchingAim = false
end

function script.AimWeapon(weapon, heading, pitch)
    Signal(1)
    SetSignalMask(1)
    local limit = math.rad(10)
    Turn(turret, y_axis, heading, turretSpeed)
    Turn(barrel, x_axis, -math.max(-limit, math.min(limit, pitch)), barrelSpeed)
    if not watchingAim then
        watchingAim = true
        StartThread(restoreAim, weapon)
    end
    WaitForTurn(turret, y_axis)
    WaitForTurn(barrel, x_axis)
    -- Laras model dibatasi ±10°, tetapi tembakan boleh -25°..+35° (bug user 2026-11-28: "kadang diam tidak menembak tapi
    -- laras mencoba mengangkat elevasi setinggi mungkin"). Pitch dari engine relatif ke badan, jadi di lereng sasaran
    -- datar pun bisa lewat ±10° dan tank tidak pernah menembak. Arah peluru dihitung engine, bukan dari laras.
    return pitch >= -math.rad(25) and pitch <= math.rad(35)
end

local function recoil()
    Signal(2)
    SetSignalMask(2)
    Move(barrel, z_axis, -0.45 * rig.skala, 12 * rig.skala)
    WaitForMove(barrel, z_axis)
    Move(barrel, z_axis, 0, 1.8 * rig.skala)
end

function script.Shot()
    StartThread(recoil)
end

function script.Killed()
    return 1
end
