function gadget:GetInfo()
    return {name = "Cannon Trajectories", desc = "Applies the per-tick gravity correction and artillery arc", layer = 0, enabled = true}
end

if not gadgetHandler:IsSyncedCode() then return false end

local sp = Spring
local lontar = VFS.Include("gamedata/lontar.lua")
local arcs, exact = {}, {}
local pendingGravity, groundShots = {}, {}

function gadget:Initialize()
    for id, def in pairs(WeaponDefs) do
        if def.customParams.lintasan_artileri == "1" then
            arcs[id] = true
            Script.SetWatchAllowTarget(id, true)
        end
        if def.customParams.kompensasi_tick == "1" then exact[id] = true end
        if arcs[id] or exact[id] then Script.SetWatchProjectile(id, true) end
    end
end

function gadget:AllowWeaponTarget(unit, target, _, weapon, priority)
    priority = priority or 1
    if not arcs[weapon] then return true, priority end
    local x, _, z = sp.GetUnitPosition(unit)
    local tx, _, tz = lontar.posisiUnit(unit, target)
    return x ~= nil and tx ~= nil and (tx - x)^2 + (tz - z)^2 >= lontar.jarakMin^2, priority
end

function gadget:ProjectileCreated(id, owner, weapon)
    local vx, vy, vz, speed = sp.GetProjectileVelocity(id)
    if not vx then return end
    if exact[weapon] then
        -- Engine mengurangi laju vertikal sebelum menggeser posisi tiap tick.
        -- Setengah langkah mengubah solusi meriam kontinu ke integrasi diskret.
        local gravity = sp.GetProjectileGravity(id)
        if gravity then sp.SetProjectileVelocity(id, vx, vy - gravity * .5, vz) end
        groundShots[id] = true
    elseif arcs[weapon] and owner then
        local tx, ty, tz = lontar.target(owner, 1)
        if not tx then return end
        local x, y, z = sp.GetProjectilePosition(id)
        local bx, _, bz = sp.GetUnitPosition(owner)
        local dx, dz = tx - x, tz - z
        local distance = math.sqrt(dx*dx + dz*dz)
        if distance < 1 then return end
        local pitch = lontar.sudut(math.sqrt((tx-bx)^2 + (tz-bz)^2))
        local horizontal = math.cos(pitch) * speed
        local vertical = math.sin(pitch) * speed
        local time = distance / horizontal
        local gravity = 2 * (ty - y - vertical * time) / (time * (time + 1))
        if gravity >= 0 then return end
        sp.SetProjectileVelocity(id, dx * horizontal / distance, vertical, dz * horizontal / distance)
        -- Konstruktor Cannon masih menulis gravitasi setelah ProjectileCreated.
        pendingGravity[id] = {y = ty, x = tx, z = tz}
        groundShots[id] = true
        sp.SetProjectileTimeToLive(id, math.ceil(time) + 12)
    end
end

function gadget:ProjectileDestroyed(id)
    groundShots[id], pendingGravity[id] = nil, nil
end

local function potongPermukaan(id)
    local x, y, z = sp.GetProjectilePosition(id)
    if not x or x < 0 or x > Game.mapSizeX or z < 0 or z > Game.mapSizeZ then return end
    local terrain = sp.GetGroundHeight(x, z)
    if terrain <= 0 or y >= terrain then return end
    local vx, vy, vz = sp.GetProjectileVelocity(id)
    local px, py, pz = x - vx, y - vy, z - vz
    if py <= sp.GetGroundHeight(px, pz) then return end

    -- Proyektil sudah melewati tanah pada langkah sebelumnya. Cari titik
    -- potong di segmen itu agar benturan jarak dekat tidak mundur satu tick.
    local above, below = 0, 1
    for _ = 1, 12 do
        local t = (above + below) * .5
        if py + vy * t > sp.GetGroundHeight(px + vx * t, pz + vz * t) then
            above = t
        else
            below = t
        end
    end
    local hitX, hitZ = px + vx * below, pz + vz * below
    sp.SetProjectilePosition(id, hitX, sp.GetGroundHeight(hitX, hitZ), hitZ)
    sp.SetProjectileCollision(id)
end

function gadget:GameFrame()
    for id, target in pairs(pendingGravity) do
        local x, y, z = sp.GetProjectilePosition(id)
        if x then
            local vx, vy, vz = sp.GetProjectileVelocity(id)
            local time = math.sqrt(((target.x - x)^2 + (target.z - z)^2) / (vx*vx + vz*vz))
            local gravity = 2 * (target.y - y - vy * time) / (time * (time + 1))
            if gravity < 0 then sp.SetProjectileGravity(id, gravity) end
        end
        pendingGravity[id] = nil
    end
    for id in pairs(groundShots) do potongPermukaan(id) end
end
