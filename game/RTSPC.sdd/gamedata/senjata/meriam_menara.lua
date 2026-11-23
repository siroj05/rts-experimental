return {
    name = "Rapid-fire HE Cannon", weaponType = "Cannon", turret = true,
    range = 800, weaponVelocity = 720, reloadtime = 3, burst = 4, burstrate = .5,
    accuracy = 0.01, areaofeffect = 16, edgeeffectiveness = .35,
    damage = {default = 36, berat = 30, bangunan = 36},
    craterareaofeffect = 0, cratermult = 0, canattackground = true,
    avoidground = true, collideground = true, avoidfriendly = true, collidefriendly = false,
    rgbcolor = "1 .74 .35", size = 1.3, cegtag = "rts_medium_trail",
    explosiongenerator = "custom:rts_medium_hit", soundstart = "sounds/menara_tembak.ogg",
    soundhit = "sounds/ledakan-permukaan.wav", soundstartvolume = 7, soundhitvolume = 6,
    customparams = {efek_benturan_tanah = "1", efek_benturan_baja = "1", kompensasi_tick = "1", jarak_min = "80"},
}
