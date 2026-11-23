-- Statistik awal dari Medium Tank v2. Skala peta uji 8 elmo/m, simulasi 30 frame/detik.
return {
    name = "Medium Tank",
    description = "Frontline tank",
    objectname = "medium-tank.glb",
    buildPic = "medium-tank.png",
    script = "medium_tank.lua",
    movementclass = "tank_sedang",
    category = "DARAT",
    canmove = true,
    canattack = true,
    movementstate = 1,
    maxdamage = 1200,
    metalcost = 300,
    energycost = 1050,
    buildtime = 750,
    footprintx = 2,
    footprintz = 3,
    collisionvolumetype = "box",
    collisionvolumescales = "33 18 42",
    collisionvolumeoffsets = "0 9 0",
    speed = 44,              -- 5,5 m/detik
    maxacc = 24 / (30 * 30), -- 3 m/detik²
    maxdec = 0.10,           -- Rem prototipe agar responsif di sekitar titik.
    turnrate = 65536 / 4 / 30, -- 90°/detik
    sightdistance = 360,     -- 45 m
    customparams = {duduki = "1"},
    weapons = {{name = "rts_meriam_medium", onlytargetcategory = "DARAT"}},
}
