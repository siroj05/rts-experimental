-- Skrip unit kandidat. Rig ditempatkan di gamedata bersama skrip dan model.
include("unit_fraksi1.lua")

local arm = VFS.Include("gamedata/tank_insinyur_f2-rig.lua").lengan_kerja
local base, boom, lamp = piece(arm.pangkal, arm.boom, arm.lampu)
local create, startBuilding, stopBuilding = script.Create, script.StartBuilding, script.StopBuilding
local yawSpeed, pitchSpeed = math.rad(100), math.rad(80)

function script.Create()
    Hide(lamp)
    create()
end

function script.StartBuilding(heading)
    local yaw = math.max(-math.rad(arm.yaw_max_deg), math.min(-math.rad(arm.yaw_min_deg), heading or 0))
    Turn(base, y_axis, yaw, yawSpeed)
    Turn(boom, x_axis, -math.rad(arm.elevasi_min_deg), pitchSpeed)
    Show(lamp)
    startBuilding()
end

function script.StopBuilding()
    stopBuilding()
    Hide(lamp)
    Turn(boom, x_axis, 0, pitchSpeed)
    Turn(base, y_axis, 0, yawSpeed)
end
