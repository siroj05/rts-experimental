local produksi, nano = piece("produksi", "nano")

function script.Create()
    Spring.SetUnitNanoPieces(unitID, {nano})
end

function script.QueryBuildInfo()
    return produksi
end

function script.Activate()
    SetUnitValue(COB.INBUILDSTANCE, 1)
end

function script.Deactivate()
    SetUnitValue(COB.INBUILDSTANCE, 0)
end
