function gadget:GetInfo()
    return {name = "Iron Deposits", desc = "Limits each deposit to one Iron Extractor", layer = 0, enabled = true}
end

if not gadgetHandler:IsSyncedCode() then return end

local def = UnitDefNames.ekstraktor_besi.id
local skenario = VFS.Include("gamedata/skenario.lua")
if not skenario then return false end
local ladang = skenario.ladang

local function lokasiValid(x, y, z, hadap)
    if not x or not z then return false end
    local bx, _, bz = Spring.Pos2BuildPos(def, x, y, z, hadap or 0)
    for _, titik in ipairs(ladang) do
        local tx, _, tz = Spring.Pos2BuildPos(def, titik[1], 0, titik[2], hadap or 0)
        if tx == bx and tz == bz then
            for _, unit in ipairs(Spring.GetUnitsInCylinder(bx, bz, 8)) do
                if Spring.GetUnitDefID(unit) == def and not Spring.GetUnitIsDead(unit) then
                    return false
                end
            end
            return true
        end
    end
    return false
end

function gadget:AllowCommand(_, _, _, cmdID, params)
    return cmdID ~= -def or #params < 3 or lokasiValid(params[1], params[2], params[3], params[4])
end

function gadget:AllowUnitCreation(unitDefID, builder, _, x, y, z, hadap)
    if unitDefID == def and builder and not lokasiValid(x, y, z, hadap) then
        return false, true
    end
    return true
end
