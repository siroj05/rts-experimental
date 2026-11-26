-- Kerangka hook uji visual (tools/uji_visual.py). Ditempel ke akhir LuaUI/main.lua salinan uji, lalu file hook
-- spesifik menambah SHOTS (dan opsional preUpdate). Tiap shot: {f = frame, nama = "...", target = "markas" |
-- "tengah" | "panas" | "titik", x =, z = (untuk "titik"), jarak = tinggi kamera elmo}.
SHOTS = {}
preUpdate = nil
local updateAsli = Update
local idx, fase, tunggu, mulai = 1, "jalan", nil, false

local function titikPanas()
    local best, bx, bz = -1, Game.mapSizeX / 2, Game.mapSizeZ / 2
    local units = Spring.GetAllUnits()
    local step = math.max(1, math.floor(#units / 300))
    for k = 1, #units, step do
        local u = units[k]
        local x, _, z = Spring.GetUnitPosition(u)
        local ally = Spring.GetUnitAllyTeam(u)
        if x then
            local n = 0
            for _, v in ipairs(Spring.GetUnitsInCylinder(x, z, 260)) do
                if Spring.GetUnitAllyTeam(v) ~= ally then n = n + 1 end
            end
            if n > best then best, bx, bz = n, x, z end
        end
    end
    return bx, bz, best
end

local function arahKamera(shot)
    local x, z, info
    if shot.target == "markas" then
        local sx, _, sz = Spring.GetTeamStartPosition(shot.tim or 0)
        x, z, info = sx, sz, "markas"
    elseif shot.target == "titik" then
        x, z, info = shot.x, shot.z, "titik"
    elseif shot.target == "tengah" then
        x, z, info = Game.mapSizeX / 2, Game.mapSizeZ / 2, "tengah"
    else
        local n
        x, z, n = titikPanas()
        info = "musuh-dekat=" .. n
    end
    local s = Spring.GetCameraState()
    s.px, s.py, s.pz = x, Spring.GetGroundHeight(x, z), z
    if s.dist then s.dist = shot.jarak end
    if s.height then s.height = shot.jarak end
    if shot.rx and s.rx then s.rx = shot.rx end
    if shot.ry and s.ry then s.ry = shot.ry end
    Spring.SetCameraState(s, 0)
    return info
end

function Update(...)
    if updateAsli then updateAsli(...) end
    if preUpdate then preUpdate() end
    local frame = Spring.GetGameFrame()
    if frame < 3 then return end
    if not mulai then
        mulai = true
        Spring.SendCommands("viewspring")
        Spring.SendCommands("setspeed 10")
    end
    local shot = SHOTS[idx]
    if not shot then
        Spring.Echo("VISUAL, SELESAI")
        Spring.SendCommands("quitforce")
        return
    end
    if fase == "jalan" and frame >= shot.f then
        Spring.SendCommands("setspeed 1")
        shot.info = arahKamera(shot)
        fase, tunggu = "tunggu", Spring.GetTimer()
    elseif fase == "tunggu" and Spring.DiffTimers(Spring.GetTimer(), tunggu) > 2.5 then
        Spring.SendCommands("screenshot png")
        Spring.Echo(string.format("VISUAL, SHOT, %d, %s, frame=%d, fps=%d, unit=%d, %s", idx, shot.nama, frame,
            Spring.GetFPS(), #Spring.GetAllUnits(), shot.info or ""))
        fase, tunggu = "jeda", Spring.GetTimer()
    elseif fase == "jeda" and Spring.DiffTimers(Spring.GetTimer(), tunggu) > 0.6 then
        idx = idx + 1
        fase = "jalan"
        if SHOTS[idx] and SHOTS[idx].f > frame + 30 then Spring.SendCommands("setspeed 10") end
    end
end
