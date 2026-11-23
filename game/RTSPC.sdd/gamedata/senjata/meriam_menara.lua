return {
    name = "Rapid-fire HE Cannon", weaponType = "Cannon", turret = true,
    range = 800, weaponVelocity = 720, reloadtime = 3, burst = 4, burstrate = .5,
    accuracy = 0.01, areaofeffect = 16, edgeeffectiveness = .35,
    damage = {default = 36, berat = 30, bangunan = 36},
    craterareaofeffect = 0, cratermult = 0, canattackground = true,
    avoidground = true, collideground = true, avoidfriendly = true, collidefriendly = false,
    rgbcolor = "1 .74 .35", size = 1.3, model = "fx-tracer-meriam.glb", castshadow = false,
    explosiongenerator = "custom:rts_medium_hit",
    customparams = {
        efek_benturan_tanah = "1", efek_benturan_baja = "1", kompensasi_tick = "1", jarak_min = "80", fx_jejak = "meriam",
        suara_tembak = "sounds/menara_tembak.ogg", volume_tembak = 7, volume_bentur = 6,
    },
}
