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
if skenario == "sungai" or skenario == "pinus" or skenario == "hijau" or skenario == "kapur" then
    -- Arsip dasar memberi nama treetype0…15 dalam huruf kecil.
    local env = {lowerkeys = function(defs) return defs end}
    for name, def in pairs(VFS.Include("features/treetype.lua", env, VFS.BASE)) do
        wrecks[name] = def
    end
    -- Batu kapur buatan sendiri (tools/buat_batu.py; ✅ user 2026-11-26 "batunya acak"). Bongkah besar
    -- menghalangi jalan, batu kecil tidak. Nilai reklamasi kecil dan sama untuk kedua kubu karena sebarannya
    -- simetris.
    for i, d in ipairs({{tapak = 1, halang = true, besi = 6}, {tapak = 2, halang = true, besi = 9},
            {tapak = 1, halang = false, besi = 3}}) do
        wrecks["batu_kapur_" .. i] = {
            description = "Limestone", object = "batu-kapur-" .. i .. ".glb",
            footprintx = d.tapak, footprintz = d.tapak, blocking = d.halang, upright = false,
            reclaimable = true, metal = d.besi, energy = 0, damage = 4000, flammable = false,
            autoreclaimable = false,
        }
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

    -- Bekas kawah: decal Lua permanen dari gadget kawah_bekas.lua. Bekas ledakan bawaan dimatikan karena
    -- warnanya dikalikan minimap. Ukuran (elmo) = diameter kawah x ±2,2, termasuk tanah yang terlempar.
    for nama, diameter in pairs({rts_meriam_medium = 62, rts_tank_ringan = 48,
            rts_medium_tank_destroyer = 66, rts_artileri_ringan = 106,
            rts_robot_roket = 44, rts_meriam_menara = 48}) do
        local weapon = weapons[nama]
        weapon.explosionScar = false
        weapon.customparams = weapon.customparams or {}
        weapon.customparams.kawah_ukuran = diameter
    end
end

-- Kawah permanen (✅ user 2026-11-26: "map bisa berlubang permanen jika terkena tembakan atau ledakan").
-- Recoil mengubah heightmap secara permanen. Peta mengaktifkannya dengan notDeformable = false.
-- Senjata kecil tidak membuat kawah. Nilai {diameter elmo, pengali kedalaman} disetel lewat pengukuran
-- (🟡 tahap 6 Limestone Valley).
-- Target kedalaman: Light 0,25 m, Medium 0,4, Destroyer 0,55, Rocket 0,25, Artillery 0,7, Tower 0,2 per peluru.
-- Kedalaman Recoil sebanding dengan (damage x mult)^0,6, jadi pengali disetel dari hasil ukur uji kawah.
for nama, k in pairs({rts_meriam_medium = {28, 3.2}, rts_tank_ringan = {22, 5.5},
        rts_medium_tank_destroyer = {30, 1.3}, rts_artileri_ringan = {48, 10},
        rts_robot_roket = {20, 2.1}, rts_meriam_menara = {22, 3}}) do
    local weapon = weapons[nama]
    weapon.craterareaofeffect, weapon.cratermult, weapon.craterboost = k[1], k[2], 0
end

-- Tapak tanah di bawah bangunan (✅ user 2026-11-26). Tekstur dari tools/buat_decal.py. Ukurannya tapak ditambah
-- 2 m (satu petak) di tiap sisi.
for _, key in ipairs(fraksi.armor.bangunan) do
    local unit = units[key]
    -- Kunci def: buildingGroundDecal*. Di UnitDefs Lua namanya jadi buildingDecal*.
    unit.useBuildingGroundDecal, unit.buildingGroundDecalType = true, "tapak_tanah.tga"
    unit.buildingGroundDecalSizeX = unit.footprintx + 2
    unit.buildingGroundDecalSizeY = unit.footprintz + 2
    unit.buildingGroundDecalDecaySpeed = .02
end

-- Ikon strategis zoom jauh (tools/buat_ikon.py, gamedata/icontypes.lua).
local ikon = VFS.Include("gamedata/ikon_unit.lua")
for key, unit in pairs(units) do
    unit.iconType = ikon[key] or "bangunan"
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
