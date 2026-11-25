-- Skala 8 elmo/m. Satu petak tapak bangunan Recoil = 16 elmo.
local bangunan = {
    inti_komando = {
        name = "Command Core", description = "Headquarters and Engineer Bot production",
        objectname = "inti-komando.glb", script = "inti_komando.lua", category = "DARAT",
        health = 12000, power = 500, footprintx = 9, footprintz = 9, -- model 70% (2026-11-24)
        builder = true, workerTime = 30, buildOptions = {"robot_insinyur"},
        canMove = true, speed = 0, -- Recoil MOVE mengatur rally; bangunannya tetap statis.
        yardMap = ("o"):rep(81), -- Robot dibuat di depan pintu HQ, di luar tapak.
        sightDistance = 400, metalStorage = 2000, energyStorage = 3200,
        metalMake = 1, energyMake = 15, levelGround = false,
    },
    robot_insinyur = {
        name = "Engineer Bot", description = "Builds factories, extractors, and pumps",
        objectname = "robot-insinyur.glb", script = "unit_fraksi1.lua", buildPic = "robot-insinyur.png", category = "DARAT",
        health = 150, metalCost = 60, energyCost = 225, buildTime = 240,
        canMove = true, movementClass = "robot_kerja", footprintx = 1, footprintz = 1,
        speed = 36, maxAcc = 64 / (30 * 30), maxDec = 0.15, turnRate = 65536 / 30,
        sightDistance = 240,
        builder = true, workerTime = 30, buildDistance = 80,
        buildOptions = {"pabrik_kendaraan", "pabrik_robot", "ekstraktor_besi", "pompa_minyak",
            "tiang_relay", "gardu", "gudang", "radar", "menara_pertahanan"},
    },
    pabrik_kendaraan = {
        name = "Vehicle Factory", description = "Produces vehicles and artillery",
        objectname = "pabrik-kendaraan.glb", script = "pabrik_kendaraan.lua", buildPic = "pabrik-kendaraan.png", category = "DARAT",
        health = 3500, metalCost = 350, energyCost = 1200, buildTime = 1200,
        footprintx = 8, footprintz = 8, sightDistance = 240, levelGround = false, maxSlope = 8,
        builder = true, workerTime = 30,
        canMove = true, speed = 0,
        buildOptions = {"tank_ringan", "medium_tank", "medium_tank_destroyer", "pengintai", "artileri_ringan"},
        -- Jalur tengah terbuka saat garasi aktif. Sisi dan ujung belakang tetap padat.
        yardMap = "h" .. ("oooooooooooooooo"):rep(5) .. ("oooooccccccooooo"):rep(11),
    },
    pabrik_robot = {
        name = "Robot Factory", description = "Produces Engineer, Infantry and Rocket Robots",
        objectname = "pabrik-robot.glb", script = "pabrik_kendaraan.lua", buildPic = "pabrik-robot.png", category = "DARAT",
        health = 3000, metalCost = 250, energyCost = 900, buildTime = 900,
        footprintx = 8, footprintz = 8, sightDistance = 240, levelGround = false, maxSlope = 8,
        builder = true, workerTime = 30, buildOptions = {"robot_insinyur", "robot_infanteri", "robot_roket"},
        canMove = true, speed = 0,
        -- Kolom jalur yard map tercermin dari X soket model. Cocokkan dengan pintu di X +2,35 m.
        yardMap = "h" .. ("oooooooooooooooo"):rep(5) .. ("ooooccccoooooooo"):rep(11),
    },
    ekstraktor_besi = {
        name = "Iron Extractor", description = "Place on an iron deposit. Produces 2.5 iron per second while powered",
        objectname = "ekstraktor-besi.glb", script = "bangunan_statis.lua", buildPic = "ekstraktor-besi.png", category = "DARAT",
        health = 600, metalCost = 50, energyCost = 150, buildTime = 300,
        footprintx = 4, footprintz = 4, sightDistance = 200, levelGround = false, maxSlope = 8,
        onoffable = true, activateWhenBuilt = true, makesMetal = 2.5, energyUpkeep = 3,
    },
    pompa_minyak = {
        name = "Oil Pump", description = "Produces 10 energy per second",
        objectname = "pompa-minyak.glb", script = "bangunan_statis.lua", buildPic = "pompa-minyak.png", category = "DARAT",
        health = 800, metalCost = 80, energyCost = 0, buildTime = 300,
        footprintx = 4, footprintz = 4, sightDistance = 200, levelGround = false, maxSlope = 8,
        energyMake = 10,
    },
}

local pelengkap = {
    {"tiang_relay", "Relay Mast", "Extends power from the Command Core", 250, 15, 37, 3, 4, 20},
    {"gardu", "Substation", "Powers nearby buildings using 5 energy/s", 600, 60, 150, 8, 4, 20},
    {"gudang", "Depot", "Stores 3,000 iron and 500 energy", 1500, 100, 225, 12, 8, 25},
    {"radar", "Radar", "Reveals enemy radar contacts while powered", 600, 60, 375, 12, 4, 40},
    {"menara_pertahanan", "Defense Tower", "Fires HE bursts at ground targets while powered", 2000, 200, 600, 22, 4, 100},
}

for _, d in ipairs(pelengkap) do
    local key, name, description, hp, iron, energy, seconds, footprint, sight = unpack(d)
    local model = key:gsub("_", "-")
    bangunan[key] = {
        name = name, description = description, category = "DARAT",
        objectname = model .. ".glb", buildPic = model .. ".png", script = "bangunan_statis.lua",
        health = hp, metalCost = iron, energyCost = energy, buildTime = seconds * 30,
        footprintx = footprint, footprintz = footprint, sightDistance = sight * 8,
        levelGround = false, maxSlope = 8,
    }
end

bangunan.gudang.metalStorage = 3000
bangunan.gudang.energyStorage = 500
bangunan.radar.script = "radar.lua"
-- Recoil hanya memproses sensor radar pada unit aktif. Jangkauan tetap diatur jaringan daya.
bangunan.radar.activateWhenBuilt = true
bangunan.menara_pertahanan.script = "menara_pertahanan.lua"
bangunan.menara_pertahanan.canAttack = true
bangunan.menara_pertahanan.weapons = {{name = "rts_meriam_menara", onlyTargetCategory = "DARAT"}}
-- The lattice mast reserves its full footprint while keeping the outer paths open.
bangunan.tiang_relay.yardMap = "h" .. ("bbbbbbbb"):rep(2) .. ("bboooobb"):rep(4) .. ("bbbbbbbb"):rep(2)

return bangunan
