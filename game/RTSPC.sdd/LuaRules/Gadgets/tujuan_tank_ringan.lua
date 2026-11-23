function gadget:GetInfo()
    return {name = "Light Tank Arrival", desc = "Finishes reachable Move destinations after an early stop", enabled = true}
end
if not gadgetHandler:IsSyncedCode() then return false end

local sp = Spring
local tankRingan = UnitDefNames.tank_ringan.id
local toleransi = 32 -- 4 m. Sisakan ruang berhenti untuk panjang badan tank.
local pending = {}

function gadget:UnitCmdDone(id, def, _, cmd, params, opts)
    if def ~= tankRingan or cmd ~= CMD.MOVE or opts.internal or sp.GetUnitCurrentCommand(id) then return end
    local tx, ty, tz = unpack(params)
    if not tz then return end
    local x, _, z = sp.GetUnitPosition(id)
    if (tx - x)^2 + (tz - z)^2 <= toleransi^2 then return end
    local move = sp.GetUnitMoveTypeData(id)
    if move.progressState ~= "done" or move.goalx ~= tx or move.goalz ~= tz then return end
    pending[id] = {x = tx, y = ty, z = tz, batas = sp.GetGameFrame() + Game.gameSpeed * 2}
end

function gadget:UnitCommand(id)
    pending[id] = nil
end

function gadget:UnitDestroyed(id)
    pending[id] = nil
end

function gadget:GameFrame(frame)
    for id, tujuan in pairs(pending) do
        local x, _, z = sp.GetUnitPosition(id)
        local _, _, _, laju = sp.GetUnitVelocity(id)
        if frame >= tujuan.batas or sp.GetUnitCurrentCommand(id)
            or (tujuan.x - x)^2 + (tujuan.z - z)^2 <= toleransi^2 then
            pending[id] = nil
        elseif laju < 0.1 then
            pending[id] = nil
            -- Minta path baru sekali setelah tank berhenti. Waypoint dan antrean tetap milik Recoil.
            if sp.TestMoveOrder(tankRingan, tujuan.x, tujuan.y, tujuan.z) then
                sp.SetUnitMoveGoal(id, tujuan.x, tujuan.y, tujuan.z, Game.squareSize)
            end
        end
    end
end
