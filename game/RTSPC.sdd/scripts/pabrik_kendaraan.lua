local produksi, nano = piece("produksi", "nano")
local pabrikRobot = UnitDefs[Spring.GetUnitDefID(unitID)].name == "pabrik_robot"
local bagian = VFS.Include(pabrikRobot and "gamedata/pintu_pabrik_robot.lua" or "gamedata/pintu_pabrik.lua")
local frame = 1
local akhir = #bagian[1].pose
local sinyalPintu = 1
for _, slat in ipairs(bagian) do
    slat.piece = piece(slat.nama)
end

local function gerakkanPintu(tujuan)
    Signal(sinyalPintu)
    SetSignalMask(sinyalPintu)
    local langkah = tujuan > frame and 1 or -1
    while frame ~= tujuan do
        frame = frame + langkah
        for _, slat in ipairs(bagian) do
            local pose = slat.pose[frame]
            Move(slat.piece, y_axis, pose[1])
            Move(slat.piece, z_axis, pose[2])
            Turn(slat.piece, x_axis, pose[3])
        end
        Sleep(pabrikRobot and 12 or 42)
    end
    SetUnitValue(COB.INBUILDSTANCE, tujuan == akhir and 1 or 0)
end

function script.Create()
    Spring.SetUnitNanoPieces(unitID, {nano})
end

function script.QueryBuildInfo()
    return produksi
end

function script.Activate()
    StartThread(gerakkanPintu, akhir)
end

function script.Deactivate()
    SetUnitValue(COB.INBUILDSTANCE, 0)
    StartThread(gerakkanPintu, 1)
end
