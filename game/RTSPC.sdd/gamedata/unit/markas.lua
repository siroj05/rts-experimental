-- Skala 8 elmo/m. Satu petak tapak bangunan Recoil = 16 elmo.
return {
    inti_komando = {
        name = "Command Core", description = "Headquarters and Engineer Bot production",
        objectname = "inti-komando.glb", script = "inti_komando.lua", category = "DARAT",
        health = 12000, power = 500, footprintx = 12, footprintz = 12,
        builder = true, workerTime = 30, buildOptions = {"robot_insinyur"},
        canMove = true, speed = 0, -- Recoil MOVE mengatur rally; bangunannya tetap statis.
        yardMap = ("o"):rep(144), -- Robot dibuat di depan pintu HQ, di luar tapak.
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
        buildOptions = {"pabrik_kendaraan", "pabrik_robot", "ekstraktor_besi", "pompa_minyak"},
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
        yardMap = "h" .. ("oooooooooooooooo"):rep(5) .. ("ooooooooccccoooo"):rep(11),
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
