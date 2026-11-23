-- Statistik dari daftar aktif V2. Jarak, laju dan tapak dikonversi di sini.
local records = {
    tank_ringan = {
        nama = "Light Tank", peran = "Fast frontline tank",
        hp = 600, besi = 150, energi = 525, detik = 15, laju = 6, aksel = 4, putar = 120, los = 40,
        tapak = {2, 2}, collider = {23, 19, 33}, armor = "berat",
        senjata = {nama = "Light Cannon", damage = 50, jeda = 2, jarak = 32, laju = 70, bidik = .8},
    },
    medium_tank_destroyer = {
        nama = "Tank Destroyer", peran = "Long-range fixed-mount anti-tank gun",
        hp = 800, besi = 280, energi = 980, detik = 24, laju = 5, aksel = 3, putar = 80, los = 45,
        tapak = {2, 3}, collider = {32, 18, 48}, armor = "berat", tetap = true,
        senjata = {nama = "Destroyer Cannon", damage = 170, jeda = 4, jarak = 48, laju = 90,
            lawanBerat = 1, bidik = .85},
    },
    pengintai = {
        nama = "Scout Halftrack", peran = "Fast reconnaissance vehicle",
        hp = 180, besi = 60, energi = 187, detik = 6, laju = 9, aksel = 12, putar = 240, los = 60,
        tapak = {1, 2}, collider = {17, 19, 34},
        senjata = {nama = "Scout Autocannon", damage = 6, jeda = .3, jarak = 20, laju = 120, bidik = .75, kecil = true},
    },
    artileri_ringan = {
        nama = "Light Artillery", peran = "Long-range indirect fire. Minimum range: 30 m",
        hp = 300, besi = 200, energi = 675, detik = 20, laju = 3, aksel = 2.5, putar = 90, los = 35,
        tapak = {2, 2}, collider = {23, 16, 34}, tetap = true,
        senjata = {nama = "Artillery Cannon", damage = 70, jeda = 4, jarak = 120, laju = 35, area = 6, artileri = true},
    },
    robot_infanteri = {
        nama = "Infantry Robot", peran = "Burst-fire infantry. Captures control points",
        hp = 120, besi = 40, energi = 112, detik = 5, laju = 4, aksel = 10, putar = 400, los = 35,
        tapak = {1, 1}, collider = {10, 14, 10}, robot = true,
        senjata = {nama = "Burst Carbine", damage = 8, jeda = 2, laras = 4, jarak = 22, laju = 120, bidik = .8, kecil = true},
    },
    robot_roket = {
        nama = "Rocket Robot", peran = "Anti-armor infantry. Captures control points",
        hp = 110, besi = 70, energi = 225, detik = 7, laju = 3.6, aksel = 8, putar = 360, los = 35,
        tapak = {1, 1}, collider = {12, 16, 12}, robot = true,
        senjata = {nama = "Rocket Launcher", damage = 45, jeda = 2.5, jarak = 30, laju = 45,
            lawanBerat = 1.25, area = 2, roket = true, bidik = .7},
    },
}

local skala, fps = 8, 30
local units, weapons, movement = {}, {}, {}
local armor = {
    ringan = {"robot_insinyur"},
    berat = {"medium_tank"},
    bangunan = {"inti_komando", "pabrik_kendaraan", "pabrik_robot", "ekstraktor_besi", "pompa_minyak"},
}

for key, r in pairs(records) do
    local stem = key:gsub("_", "-")
    local weaponkey = "rts_" .. key
    local w = r.senjata
    local area = (w.area or (w.kecil and .7 or 2.75)) * skala
    local damage = w.area and {default = w.damage * 1.2, berat = w.damage, bangunan = w.damage * 1.2}
        or {default = w.damage, berat = w.damage * .6, bangunan = w.damage * .5}
    if w.lawanBerat then damage.berat = w.damage * w.lawanBerat end
    weapons[weaponkey] = {
        name = w.nama, weaponType = w.roket and "MissileLauncher" or "Cannon", turret = true,
        range = w.jarak * skala, weaponVelocity = w.laju * skala, reloadtime = w.jeda,
        damage = damage, areaofeffect = area, edgeeffectiveness = .35,
        craterareaofeffect = 0, cratermult = 0, canattackground = true,
        avoidground = not w.artileri, collideground = true, avoidfriendly = true, collidefriendly = false,
        predictboost = w.bidik or 1, burst = w.laras or 1, burstrate = .1,
        rgbcolor = w.kecil and "1 .81 .52" or "1 .71 .32", size = w.kecil and .7 or 1.7,
        explosiongenerator = "custom:rts_medium_hit",
        cegtag = w.artileri and "rts_artileri_trail" or "rts_medium_trail",
        soundstart = "sounds/" .. key .. "_tembak.wav",
        soundhit = "sounds/ledakan-permukaan.wav",
        soundstartvolume = w.kecil and 3 or 8, soundhitvolume = w.kecil and 2 or 7,
        customparams = {
            efek_benturan_tanah = not w.kecil and "1" or "0",
            efek_benturan_baja = "1", skala_baja = w.kecil and ".42" or "1",
            skala_benturan = w.artileri and "1.7" or (w.roket and ".72" or "1"),
            lintasan_artileri = w.artileri and "1" or "0",
            kompensasi_tick = not (w.artileri or w.roket) and "1" or "0",
        },
    }
    local weapon = weapons[weaponkey]
    if w.roket then
        weapon.startvelocity = weapon.weaponVelocity
        weapon.weaponacceleration = 0
        weapon.tracks, weapon.turnrate = true, 22000
        weapon.flighttime = 2
        weapon.smoketrail = false
    elseif w.artileri then
        -- Jaga pemeriksaan jangkauan bawaan. Arah lontar dan gravitasi tembakan
        -- dibentuk per jarak oleh gadget, sementara tumbukan tetap milik Recoil.
        weapon.mygravity = .065
    end

    local slot = {name = weaponkey, onlytargetcategory = "DARAT"}
    if r.tetap or (r.robot and not w.roket) then
        -- Kerucut Recoil dihitung 3D. Script membatasi yaw terpisah.
        slot.mainDir, slot.maxAngleDif = "0 0 1", w.artileri and 110 or (r.tetap and 48 or 40)
    end
    units[key] = {
        name = r.nama, description = r.peran, objectname = stem .. ".glb",
        buildpic = stem .. ".png", script = "unit_fraksi1.lua", category = "DARAT",
        health = r.hp, metalcost = r.besi, energycost = r.energi, buildtime = r.detik * fps,
        canmove = true, canattack = true, movementstate = 1, movementclass = key,
        footprintx = r.tapak[1], footprintz = r.tapak[2],
        collisionvolumetype = "box", collisionvolumescales = table.concat(r.collider, " "),
        collisionvolumeoffsets = "0 " .. r.collider[2] / 2 .. " 0",
        speed = r.laju * skala, maxacc = r.aksel * skala / (fps * fps), maxdec = .13,
        turnrate = r.putar * 65536 / (360 * fps), sightdistance = r.los * skala,
        weapons = {slot},
        customparams = {duduki = "1", turret_speed = r.robot and "143" or "125"},
    }
    movement[#movement + 1] = {
        name = key, footprintx = r.tapak[1], footprintz = r.tapak[2],
        speedmodclass = r.robot and 1 or 0, maxslope = 28, maxwaterdepth = 0,
    }
    local class = armor[r.armor or "ringan"]
    class[#class + 1] = key
end

-- MoveDef menyumbang ID dalam urutan ini sehingga harus stabil.
table.sort(movement, function(a, b) return a.name < b.name end)
return {units = units, weapons = weapons, movement = movement, armor = armor}
