local def = UnitDefs[Spring.GetUnitDefID(unitID)]
local data = VFS.Include("gamedata/" .. def.name:gsub("_", "-") .. "-pintu.lua")
local produksi, nano = piece("produksi", "nano")
local parts = Spring.GetUnitPieceMap(unitID)
local idle = parts.indikator_idle and piece("indikator_idle")
local active = parts.indikator_produksi and piece("indikator_produksi")
    or parts.nyala_produksi and piece("nyala_produksi")
local axes = {x_axis, y_axis, z_axis}
local pose, opened, signal = 1, #data.pose[1].gerak, 1
local slats = {}
for i, row in ipairs(data.pose) do
    slats[i] = {id = piece(row.nama), frames = row.gerak}
end

local function indikator(producing)
    if idle then
        if producing then Hide(idle) else Show(idle) end
    end
    if active then
        if producing then Show(active) else Hide(active) end
    end
end

local function gerakkan(tujuan)
    Signal(signal)
    SetSignalMask(signal)
    local awal = pose
    local beda = tujuan - awal
    local start = Spring.GetGameFrame()
    while pose ~= tujuan do
        local lewat = math.floor((Spring.GetGameFrame() - start) * data.fps / Game.gameSpeed)
        pose = awal + (beda > 0 and 1 or -1) * math.min(lewat, math.abs(beda))
        for _, slat in ipairs(slats) do
            local frame = slat.frames[pose]
            for i, axis in ipairs(axes) do
                Move(slat.id, axis, frame[i])
                Turn(slat.id, axis, frame[i + 3])
            end
        end
        if pose ~= tujuan then Sleep(1000 / Game.gameSpeed) end
    end
    SetUnitValue(COB.INBUILDSTANCE, tujuan == opened and 1 or 0)
end

function script.Create()
    Spring.SetUnitNanoPieces(unitID, {nano})
    indikator(false)
end

function script.QueryBuildInfo() return produksi end

function script.Activate()
    indikator(true)
    StartThread(gerakkan, opened)
end

function script.Deactivate()
    indikator(false)
    SetUnitValue(COB.INBUILDSTANCE, 0)
    StartThread(gerakkan, 1)
end

function script.Killed() return 1 end
