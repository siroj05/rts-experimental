local sp = Spring
local def = UnitDefs[sp.GetUnitDefID(unitID)]
local rig = VFS.Include("gamedata/rig_fraksi1.lua")[def.name]
local distant = def.name == "artileri_ringan"
local lontar = distant and VFS.Include("gamedata/lontar.lua")
local map = sp.GetUnitPieceMap(unitID)
local turret = map.turret and piece("turret")
local barrel = map.laras and piece("laras")
local nano = map.nano and piece("nano")
local muzzle = map.moncong and piece("moncong")
local second = map.moncong_2 and piece("moncong_2")
local nextMuzzle = muzzle
local turretSpeed = math.rad(tonumber(def.customParams.turret_speed) or 143)
local barrelSpeed = math.rad(60)
local axes = {x_axis, y_axis, z_axis}
local satuPutaran = 65536
local lurus = satuPutaran * 3 / 360
local putarPerFrame = distant and math.max(1, math.floor(def.turnRate + .5))
local jangkauanLontar = distant and WeaponDefs[def.weapons[1].weaponDef].range
local aimWatch
local sides = {}
for _, k in ipairs({"kiri", "kanan"}) do
    local roda = {}
    for i, entry in ipairs(rig.roda[k]) do roda[i] = {piece(entry[1]), entry[2]} end
    local trace = rig.track[k]
    if trace then
        local lanes = {}
        for i, name in ipairs(trace.fase) do lanes[i] = piece(name) end
        sides[k] = {roda = roda, lane = lanes, phase = 1, dist = 0, omega = 0,
                    pitch = trace.pitch, gauge = trace.jarak}
    end
end

local function track(side, travel)
    if math.abs(travel) < .002 then travel = 0 end
    side.dist = (side.dist + travel) % side.pitch
    local nextPhase = math.floor(side.dist * #side.lane / side.pitch) + 1
    if nextPhase ~= side.phase then
        Hide(side.lane[side.phase])
        Show(side.lane[nextPhase])
        side.phase = nextPhase
    end
    local omega = travel * Game.gameSpeed
    if omega == side.omega then return end
    for _, roda in ipairs(side.roda) do
        if omega == 0 then StopSpin(roda[1], x_axis, 0)
        else Spin(roda[1], x_axis, omega / roda[2], 0) end
    end
    side.omega = omega
end

local walk = rig.langkah
local legPieces, poses = {}, {}
if walk then
    for name, frames in pairs(walk.pose) do
        poses[#poses + 1] = {name = name, id = piece(name), frames = frames}
    end
    table.sort(poses, function(a, b) return a.name < b.name end)
elseif map.kaki_kiri_paha then
    local a,b,c,d = piece("kaki_kiri_paha", "kaki_kiri_betis", "kaki_kanan_paha", "kaki_kanan_betis")
    legPieces = {a,b,c,d}
end

local function stride(distance, weight)
    if walk then
        for _, p in ipairs(poses) do
            local frames = p.frames
            local at = (distance / walk.langkah) % 1 * (#frames - 2)
            local index = math.floor(at)
            local a, b, alpha = frames[index + 2], frames[index + 3], at - index
            for i, axis in ipairs(axes) do
                local neutral = frames[1]
                local offset = neutral[i] + weight * (a[i] + (b[i]-a[i])*alpha - neutral[i])
                Move(p.id, axis, offset)
                local j = i + 3
                if p.id ~= turret or axis ~= y_axis then
                    Turn(p.id, axis, neutral[j] + weight * (a[j] + (b[j]-a[j])*alpha - neutral[j]))
                end
            end
        end
    elseif #legPieces > 0 then
        local swing = math.sin(distance / 7.2 * (2 * math.pi))
        Turn(legPieces[1], x_axis, swing * .45 * weight)
        Turn(legPieces[2], x_axis, math.max(0, -swing) * .55 * weight)
        Turn(legPieces[3], x_axis, -swing * .45 * weight)
        Turn(legPieces[4], x_axis, math.max(0, swing) * .55 * weight)
    end
end

local function arahLontar(weapon, x, z, heading)
    local tx, _, tz = lontar.target(unitID, weapon)
    if not tx then return end
    local dx, dz = tx - x, tz - z
    local jarak = math.sqrt(dx * dx + dz * dz)
    if jarak < lontar.jarakMin then return end
    local target = sp.GetHeadingFromVector(dx, dz)
    local selisih = (target - heading + satuPutaran / 2) % satuPutaran - satuPutaran / 2
    return jarak, selisih
end

local function putarKeSasaran(x, z, heading)
    local cmd = sp.GetUnitCurrentCommand(unitID)
    if (cmd and cmd ~= CMD.ATTACK) or sp.GetUnitIsStunned(unitID) then return heading end
    local jarak, selisih = arahLontar(1, x, z, heading)
    if not jarak or jarak > jangkauanLontar or math.abs(selisih) <= lurus then return heading end
    -- Recoil dapat berhenti berputar saat sasaran masuk kerucut bidik 3D.
    -- Lanjutkan putaran sasis yang diam sampai azimut laras tetap selaras.
    local langkah = math.max(-putarPerFrame, math.min(putarPerFrame, selisih))
    local baru = (heading + langkah + satuPutaran / 2) % satuPutaran - satuPutaran / 2
    local _, atas = sp.GetUnitVectors(unitID)
    sp.SetUnitHeadingAndUpDir(unitID, baru, atas[1], atas[2], atas[3])
    return baru
end

local function gerak()
    local px, _, pz = sp.GetUnitPosition(unitID)
    local lastHeading = sp.GetUnitHeading(unitID)
    local distance, weight = 0, 0
    while true do
        Sleep(33)
        local x, _, z = sp.GetUnitPosition(unitID)
        local fx, _, fz = sp.GetUnitDirection(unitID)
        local heading = sp.GetUnitHeading(unitID)
        if not x or not fx or not heading then return end
        local dx, dz = x - px, z - pz
        if distant and heading == lastHeading and math.abs(dx) + math.abs(dz) < .05 then
            heading = putarKeSasaran(x, z, heading)
        end
        if sides.kiri and sides.kanan then
            local roll = dx * fx + dz * fz
            local turn = ((heading - lastHeading + 32768) % 65536 - 32768) * (2 * math.pi / 65536)
            track(sides.kiri, roll - turn * sides.kiri.gauge)
            track(sides.kanan, roll + turn * sides.kanan.gauge)
        else
            local step = math.sqrt(dx * dx + dz * dz)
            local before = weight
            weight = step > .015 and math.min(1, weight + .17) or math.max(0, weight - .13)
            distance = distance + step
            if before > 0 or weight > 0 then stride(distance, weight) end
        end
        px, pz, lastHeading = x, z, heading
    end
end

function script.Create()
    for _, side in pairs(sides) do
        for i = 2, #side.lane do Hide(side.lane[i]) end
    end
    if nano then sp.SetUnitNanoPieces(unitID, {nano}) end
    StartThread(gerak)
end

function script.StartBuilding() SetUnitValue(COB.INBUILDSTANCE, 1) end
function script.StopBuilding() SetUnitValue(COB.INBUILDSTANCE, 0) end
function script.AimFromWeapon() return barrel or turret or muzzle end
function script.QueryWeapon() return nextMuzzle end

local function kembali(weapon)
    SetSignalMask(0)
    local idle = 0
    while idle < 7 do
        Sleep(150)
        local target = sp.GetUnitWeaponTarget(unitID, weapon)
        idle = target and target ~= 0 and 0 or idle + 1
    end
    if turret then Turn(turret, y_axis, 0, turretSpeed) end
    if barrel then Turn(barrel, x_axis, distant and -math.rad(15) or 0, barrelSpeed) end
    aimWatch = nil
end

function script.AimWeapon(weapon, heading, pitch)
    Signal(1)
    SetSignalMask(1)
    if distant then
        local x, _, z = sp.GetUnitPosition(unitID)
        local range, selisih = arahLontar(weapon, x, z, sp.GetUnitHeading(unitID))
        if not range or math.abs(selisih) > lurus then return false end
        pitch = lontar.sudut(range)
    elseif not turret and math.abs(heading) > math.rad(14) then
        return false
    end
    local min = math.rad(rig.min or -20)
    local max = math.rad(rig.max or 30)
    if turret then Turn(turret, y_axis, heading, turretSpeed) end
    if barrel then Turn(barrel, x_axis, -math.max(min, math.min(max, pitch)), barrelSpeed) end
    if not aimWatch and (turret or barrel) then
        aimWatch = true
        StartThread(kembali, weapon)
    end
    if turret then WaitForTurn(turret, y_axis) end
    if barrel then WaitForTurn(barrel, x_axis) end
    return pitch >= min and pitch <= max
end

local function recoil()
    Signal(2)
    SetSignalMask(2)
    Move(barrel, z_axis, -1.6, 28)
    WaitForMove(barrel, z_axis)
    Move(barrel, z_axis, 0, 12)
end

local function kilatan(weapon)
    if not nextMuzzle or not GG.FxMoncongV2 then return end
    local x, y, z = sp.GetUnitPiecePosDir(unitID, nextMuzzle)
    local dx, dy, dz = sp.GetUnitDirection(unitID)
    if barrel or turret then
        local px, py, pz = sp.GetUnitPiecePosDir(unitID, barrel or turret)
        dx, dy, dz = x - px, y - py, z - pz
        local len = math.sqrt(dx*dx + dy*dy + dz*dz)
        if len <= 0 then return end
        dx, dy, dz = dx/len, dy/len, dz/len
    end
    local kecil = def.name == "robot_infanteri" or def.name == "pengintai" or def.name == "robot_roket"
    GG.FxMoncongV2(unitID, kecil, x, y, z, dx, dy, dz, weapon)
end

function script.Shot(weapon)
    kilatan(weapon)
    if barrel then StartThread(recoil) end
end

function script.EndBurst()
    if second then nextMuzzle = nextMuzzle == muzzle and second or muzzle end
end

function script.Killed() return 1 end
