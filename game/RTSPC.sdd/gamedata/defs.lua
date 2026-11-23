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
