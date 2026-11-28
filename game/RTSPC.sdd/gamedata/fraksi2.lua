-- Fraksi 2 (✅ user 2026-11-28: "kerjain semuanya, tekstur jadi prioritas"). Model dari batch Fraksi 2 yang lulus uji
-- (tools/pasang_fraksi2.py).
--
-- 🟡 Statistik: cermin Fraksi 1. Tiap unit Fraksi 2 menyalin def padanannya (HP, biaya, kecepatan, senjata),
-- jadi kedua fraksi seimbang secara angka dan beda di tampilan. Yang berbeda hanya:
-- - ukuran fisik: volume tumbukan dari lambung model (model Fraksi 2 lebih besar), tapak HQ 11 (model 21 m);
-- - Engineer Tank menggantikan Engineer Bot (statistik sama, tapak tank 3x3), dibuat di HQ dan Vehicle Factory;
-- - Heavy Tank: unit khusus Fraksi 2, meriam tiga laras;
-- - Fraksi 2 memakai Iron Extractor, Oil Pump, dan Radar bersama (belum ada model Fraksi 2). Light Artillery Fraksi 2
--   masuk 2026-11-28.
local ukuran = VFS.Include("gamedata/ukuran_fraksi2.lua")

local padanan = {
    pengintai_f2 = "pengintai", tank_ringan_f2 = "tank_ringan", medium_tank_f2 = "medium_tank",
    medium_tank_destroyer_f2 = "medium_tank_destroyer", tank_insinyur_f2 = "robot_insinyur",
    robot_infanteri_f2 = "robot_infanteri", robot_roket_f2 = "robot_roket",
    inti_komando_f2 = "inti_komando", pabrik_kendaraan_f2 = "pabrik_kendaraan", pabrik_robot_f2 = "pabrik_robot",
    menara_pertahanan_f2 = "menara_pertahanan", gudang_f2 = "gudang", tiang_relay_f2 = "tiang_relay",
    gardu_f2 = "gardu", artileri_ringan_f2 = "artileri_ringan",
}
local versi = {}
for kunci, dasar in pairs(padanan) do versi[dasar] = kunci end

local skrip = {
    medium_tank_f2 = "unit_fraksi1.lua", tank_insinyur_f2 = "tank_insinyur_f2.lua",
    pabrik_kendaraan_f2 = "pabrik_fraksi2.lua", pabrik_robot_f2 = "pabrik_fraksi2.lua",
}

local function salin(t)
    if type(t) ~= "table" then return t end
    local hasil = {}
    for k, v in pairs(t) do hasil[k] = salin(v) end
    return hasil
end

-- Kunci def Recoil tidak peka huruf besar; def Fraksi 1 memakai dua gaya. Hapus semua ejaan sebelum menimpa.
local function setel(def, kunci, nilai)
    local kecil = kunci:lower()
    for k in pairs(def) do
        if type(k) == "string" and k:lower() == kecil then def[k] = nil end
    end
    def[kunci] = nilai
end

local function ambil(def, kunci)
    local kecil = kunci:lower()
    for k, v in pairs(def) do
        if type(k) == "string" and k:lower() == kecil then return v end
    end
end

local function opsiBangun(daftar)
    local hasil = {}
    for _, nama in ipairs(daftar or {}) do
        if nama ~= "robot_insinyur" then hasil[#hasil + 1] = versi[nama] or nama end
    end
    return hasil
end

local function tumbukan(def, kunci)
    local u = ukuran[kunci]
    local w, l, h = u.lambung[1], u.lambung[2], u.lambung[3]
    setel(def, "collisionVolumeType", "box")
    setel(def, "collisionVolumeScales", string.format("%.0f %.0f %.0f", w * .9, h * .8, l * .9))
    setel(def, "collisionVolumeOffsets", string.format("0 %.0f 0", h * .4))
end

return function(units, weapons, movement, armor)
    for kunci, dasar in pairs(padanan) do
        local def = salin(assert(units[dasar], dasar))
        local model = kunci:gsub("_", "-")
        setel(def, "objectName", model .. ".glb")
        setel(def, "buildPic", model .. ".png")
        if skrip[kunci] then setel(def, "script", skrip[kunci]) end
        local opsi = ambil(def, "buildOptions")
        if opsi then setel(def, "buildOptions", opsiBangun(opsi)) end
        local cp = salin(ambil(def, "customParams") or {})
        cp.dasar, cp.fraksi = dasar, "2"
        setel(def, "customParams", cp)
        local bergerak = (tonumber(ambil(def, "speed") or 0) or 0) > 0
        if bergerak then tumbukan(def, kunci) end
        units[kunci] = def
    end

    -- Tapak: bangunan yang modelnya melebihi tapak Fraksi 1 diperbesar (HQ 167 elmo -> 11 x 16 elmo).
    for kunci in pairs(padanan) do
        local def, u = units[kunci], ukuran[kunci]
        if (tonumber(ambil(def, "speed") or 0) or 0) == 0 then
            local tapak = math.ceil(math.max(u.model[1], u.model[2]) / 16)
            if tapak > (ambil(def, "footprintx") or 0) then
                setel(def, "footprintx", tapak)
                setel(def, "footprintz", tapak)
                local yard = ambil(def, "yardMap")
                if yard and not yard:find("[^o]") then setel(def, "yardMap", ("o"):rep(tapak * tapak)) end
            end
        end
    end

    -- Tapak tank Fraksi 2 (bug user 2026-11-28: "tank berebut jalan"; tank F2 saling menumpuk). Model F2 lebih besar
    -- dari F1 (lambung Medium 3,9 x 8 m, Destroyer 3,7 x 7,1 m), tetapi tapak gerak masih tapak F1 (2x2 sampai 2x3).
    -- 🟡 Semua tank F2 memakai kelas gerak 3x3 (6 x 6 m) sesuai rata-rata lebar dan panjang lambung.
    movement[#movement + 1] = {name = "tank_f2", footprintx = 3, footprintz = 3, speedmodclass = 0,
        maxslope = 28, maxwaterdepth = 0}
    for _, kunci in ipairs({"pengintai_f2", "tank_ringan_f2", "medium_tank_f2", "medium_tank_destroyer_f2",
            "artileri_ringan_f2"}) do
        setel(units[kunci], "movementClass", "tank_f2")
        setel(units[kunci], "footprintx", 3)
        setel(units[kunci], "footprintz", 3)
    end

    -- Engineer Tank: tapak tank 3x3 (model 4,7 x 5,1 m), dibuat HQ dan Vehicle Factory.
    local insinyur = units.tank_insinyur_f2
    setel(insinyur, "name", "Engineer Tank")
    setel(insinyur, "movementClass", "tank_insinyur_f2")
    setel(insinyur, "footprintx", 3)
    setel(insinyur, "footprintz", 3)
    movement[#movement + 1] = {name = "tank_insinyur_f2", footprintx = 3, footprintz = 3, speedmodclass = 0,
        maxslope = 28, maxwaterdepth = 0}
    units.inti_komando_f2.buildOptions = {"tank_insinyur_f2"}
    setel(units.inti_komando_f2, "description", "Headquarters and Engineer Tank production")
    setel(units.pabrik_kendaraan_f2, "description", "Produces vehicles, Engineer Tanks and artillery")
    setel(units.pabrik_robot_f2, "description", "Produces Infantry and Rocket Robots")
    local pabrik = units.pabrik_kendaraan_f2.buildOptions
    table.insert(pabrik, 1, "tank_insinyur_f2")
    table.insert(pabrik, 4, "heavy_tank_f2")

    -- 🟡 Heavy Tank: 1,5x biaya Medium, 1,67x HP, 1,36x DPS, lebih lambat. Tiga laras menembak bergantian.
    local berat = salin(units.medium_tank)
    berat.name, berat.description = "Heavy Tank", "Slow triple-barrel assault tank"
    berat.objectname, berat.buildPic, berat.script = "heavy-tank-f2.glb", "heavy-tank-f2.png", "unit_fraksi1.lua"
    berat.movementclass = "heavy_tank_f2"
    berat.maxdamage, berat.metalcost, berat.energycost, berat.buildtime = 2000, 450, 1575, 1050
    berat.footprintx, berat.footprintz = 3, 3
    berat.speed = 32                    -- 4 m/detik
    berat.turnrate = 65536 / 5 / 30     -- 72°/detik
    berat.customparams = {duduki = "1", fraksi = "2", turret_speed = "100", ganti_moncong = "tembak"}
    berat.weapons = {{name = "rts_meriam_berat", onlytargetcategory = "DARAT"}}
    tumbukan(berat, "heavy_tank_f2")
    units.heavy_tank_f2 = berat
    movement[#movement + 1] = {name = "heavy_tank_f2", footprintx = 3, footprintz = 3, speedmodclass = 0,
        maxslope = 28, maxwaterdepth = 0}
    local meriam = salin(weapons.rts_meriam_medium)
    meriam.name = "Heavy Triple Cannon"
    meriam.damage = {default = 70}
    meriam.burst, meriam.burstrate, meriam.reloadtime = 3, .2, 3.5
    meriam.areaofeffect = 24
    weapons.rts_meriam_berat = meriam

    -- Rocket Pods Robot Roket Fraksi 2 (✅ user 2026-11-28: "8 kali nembak, 4 kiri 4 kanan roketnya lebih kecil asepnya
    -- lebih tipis tpi kekuatanya ada pada attack speed"). 🟡 Sekali tembak 8 roket kecil bergantian kiri-kanan dalam
    -- ±0,85 detik; damage per roket 1/8 Rocket Launcher Fraksi 1 sehingga DPS sama (cermin), bedanya ritme.
    local pods = salin(weapons.rts_robot_roket)
    pods.name = "Rocket Pods"
    for k, v in pairs(pods.damage) do pods.damage[k] = v / 8 end
    pods.burst, pods.burstrate = 8, .12
    -- Roket kecil lebih cepat 1,25x (✅ user 2026-11-28: "kecepatan peluru roket naikin 1.25x"): 45 -> 56,25 m/detik.
    pods.weaponVelocity = pods.weaponVelocity * 1.25
    pods.startvelocity = pods.startvelocity * 1.25
    pods.areaofeffect = pods.areaofeffect * .6
    pods.model = "fx-tracer-roket-kecil.glb"
    pods.customparams.fx_jejak = "roket_kecil"
    pods.customparams.skala_benturan = ".4"
    pods.customparams.volume_tembak = 4
    pods.customparams.volume_bentur = 3
    weapons.rts_robot_roket_f2 = pods
    local roket = units.robot_roket_f2
    roket.weapons[1].name = "rts_robot_roket_f2"
    roket.customParams.ganti_moncong = "tembak"

    -- Kelas armor mengikuti padanannya.
    for _, kelas in pairs(armor) do
        local tambah = {}
        for _, nama in ipairs(kelas) do
            if versi[nama] then tambah[#tambah + 1] = versi[nama] end
        end
        for _, nama in ipairs(tambah) do kelas[#kelas + 1] = nama end
    end
    table.insert(armor.berat, "heavy_tank_f2")
    return padanan
end
