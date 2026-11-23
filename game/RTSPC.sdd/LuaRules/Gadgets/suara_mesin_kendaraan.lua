function gadget:GetInfo()
    return {
        name = "Vehicle Engine Sound",
        desc = "Mixes nearby audible vehicle engines across three sound profiles",
        enabled = true,
    }
end

if gadgetHandler:IsSyncedCode() then return false end

local sp = Spring
local mesin = VFS.Include("gamedata/mesin_kendaraan.lua")
local elmoPerMeter = 8
local jarakMaks = 70 * elmoPerMeter
local jarakParuh = 14 * elmoPerMeter
local zoomDekat, zoomJauh = 45 * elmoPerMeter, 100 * elmoPerMeter
local profilUnit = {}
local elapsed = mesin.interval
local fase = 0
local lastUpdate

for _, profil in ipairs(mesin.profil) do
    profil.file = {}
    profil.volume = 0
    for i = 1, mesin.segmen do
        profil.file[i] = ("sounds/mesin/%s-%02d.wav"):format(profil.nama, i)
    end
    for _, nama in ipairs(profil.unit) do
        local def = UnitDefNames[nama]
        profilUnit[def.id] = {profil = profil, laju = def.speed / Game.gameSpeed}
    end
end

local function campur(x, z)
    local _, pandanganPenuh = sp.GetSpectatingState()
    local ally = sp.GetMyAllyTeamID()
    for _, id in ipairs(sp.GetUnitsInCylinder(x, z, jarakMaks) or {}) do
        local unit = profilUnit[sp.GetUnitDefID(id)]
        if unit and not sp.GetUnitIsDead(id) and not sp.GetUnitIsBeingBuilt(id) then
            local los = sp.GetUnitLosState(id, ally)
            if pandanganPenuh or (los and los.los) then
                local px, py, pz = sp.GetUnitPosition(id)
                local vx, _, vz = sp.GetUnitVelocity(id)
                if px and vx then
                    local d = math.sqrt((px - x)^2 + (pz - z)^2)
                    local jalan = math.min(1, math.sqrt(vx * vx + vz * vz) / unit.laju)
                    local bobot = (.32 + .68 * jalan) * math.max(0, 1 - d / jarakMaks) / (1 + d / jarakParuh)
                    local p = unit.profil
                    p.bobot = p.bobot + bobot
                    p.x, p.y, p.z = p.x + px * bobot, p.y + py * bobot, p.z + pz * bobot
                end
            end
        end
    end
end

local function fokus()
    local w, h = sp.GetViewGeometry()
    local _, p = sp.TraceScreenRay(math.floor(w / 2), math.floor(h / 2), true)
    if not p then return end
    local cx, cy, cz = sp.GetCameraPosition()
    local x, y, z = p[1], p[2], p[3]
    local d = math.sqrt((cx - x)^2 + (cy - y)^2 + (cz - z)^2)
    return x, z, math.max(0, math.min(1, (zoomJauh - d) / (zoomJauh - zoomDekat)))
end

function gadget:Update()
    local now = sp.GetTimer()
    local dt = lastUpdate and sp.DiffTimers(now, lastUpdate) or 0
    lastUpdate = now
    local _, speed, paused = sp.GetGameSpeed()
    if paused or sp.GetGameFrame() == 0 or sp.IsGameOver() then
        elapsed = mesin.interval
        for _, p in ipairs(mesin.profil) do p.volume = 0 end
        return
    end
    local pitchAdjust = sp.GetConfigInt("PitchAdjust", 0)
    local pitch = pitchAdjust == 2 and speed or (pitchAdjust == 1 and math.sqrt(speed) or 1)
    local interval = mesin.interval / pitch
    elapsed = elapsed + dt
    if elapsed < interval then return end
    fase = (fase + math.floor(elapsed / interval)) % mesin.segmen
    elapsed = elapsed % interval

    for _, p in ipairs(mesin.profil) do p.bobot, p.x, p.y, p.z = 0, 0, 0, 0 end
    local x, z, zoom = fokus()
    if x and zoom > 0 then campur(x, z) end
    for i, p in ipairs(mesin.profil) do
        local w = p.bobot
        if w > 0 then
            local target = p.gain * zoom * (1 - math.exp(-1.6 * w))
            p.volume = p.volume + (target - p.volume) * .80
            if p.volume > .001 then
                local segmen = (fase + (i - 1) * 5) % mesin.segmen + 1
                sp.PlaySoundFile(p.file[segmen], p.volume, p.x / w, p.y / w, p.z / w, "battle")
            end
        else
            p.volume = 0
        end
    end
end
