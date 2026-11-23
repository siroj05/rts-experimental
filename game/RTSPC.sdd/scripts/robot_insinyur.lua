local nano = piece("nano")

function script.Create()
    Spring.SetUnitNanoPieces(unitID, {nano})
end

function script.StartBuilding()
    SetUnitValue(COB.INBUILDSTANCE, 1)
end

function script.StopBuilding()
    SetUnitValue(COB.INBUILDSTANCE, 0)
end
