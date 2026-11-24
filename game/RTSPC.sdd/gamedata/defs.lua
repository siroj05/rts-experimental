local mediumTank = VFS.Include("gamedata/unit/medium_tank.lua")
local units = VFS.Include("gamedata/unit/markas.lua")
local fraksi = VFS.Include("gamedata/fraksi1.lua")
units.medium_tank = mediumTank
for key, def in pairs(fraksi.units) do units[key] = def end

local weapons, movement, wrecks = fraksi.weapons, fraksi.movement, {}
weapons.rts_meriam_medium = VFS.Include("gamedata/senjata/meriam_medium.lua")
weapons.rts_meriam_menara = VFS.Include("gamedata/senjata/meriam_menara.lua")
weapons.noweapon = {name = "No Weapon", damage = {default = 0}}
movement[#movement + 1] = {
    name = mediumTank.movementclass,
    footprintx = mediumTank.footprintx,
    footprintz = mediumTank.footprintz,
    speedmodclass = 0,
    maxslope = 28,
    maxwaterdepth = 0,
}
movement[#movement + 1] =
    {name = "robot_kerja", footprintx = 1, footprintz = 1, speedmodclass = 1, maxslope = 28, maxwaterdepth = 0}

local skenario = Spring.GetModOptions().skenario
if skenario == "sungai" or skenario == "pinus" then
    -- Arsip dasar memberi nama treetype0…15 dalam huruf kecil.
    local env = {lowerkeys = function(defs) return defs end}
    for name, def in pairs(VFS.Include("features/treetype.lua", env, VFS.BASE)) do
        wrecks[name] = def
    end
    -- Tepian yang dangkal bisa dilintasi. Bagian dalam masih ditutup typemap.
    for _, move in ipairs(movement) do move.maxwaterdepth = 8 end

    local lebarTrack = {medium_tank = 27, tank_ringan = 22, medium_tank_destroyer = 25,
        pengintai = 15, artileri_ringan = 17, robot_insinyur = 15}
    for nama, lebar in pairs(lebarTrack) do
        local unit = units[nama]
        unit.leaveTracks, unit.trackType = true, "StdTank"
        unit.trackWidth, unit.trackStrength, unit.trackStretch = lebar, 12, 1
    end

    for nama, diameter in pairs({rts_meriam_medium = 46, rts_tank_ringan = 34,
            rts_medium_tank_destroyer = 51, rts_artileri_ringan = 70,
            rts_robot_roket = 26, rts_meriam_menara = 37}) do
        local weapon = weapons[nama]
        weapon.explosionScar = true
        weapon.scarDiameter, weapon.scarAlpha, weapon.scarTtl = diameter, .86, 140
    end
end

for key, unit in pairs(units) do
    local model = key:gsub("_", "-") .. "-bangkai.glb"
    if VFS.FileExists("objects3d/" .. model) then
        local def = key .. "_bangkai"
        unit.corpse = def
        wrecks[def] = {
            name = unit.name .. " Wreck", description = unit.name .. " Wreck",
            object = model, blocking = false,
            footprintx = unit.footprintx, footprintz = unit.footprintz,
            metal = (unit.metalcost or unit.metalCost or 0) * .3, damage = 150,
            reclaimable = true, resurrectable = 0,
        }
    end
end
return {
    unitdefs = units, weapondefs = weapons, movedefs = movement,
    featuredefs = wrecks, armordefs = fraksi.armor,
}
