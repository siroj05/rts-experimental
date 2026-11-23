function gadget:GetInfo()
    return {name = "Central Hill Controls Test", layer = -5, enabled = true}
end
if not gadgetHandler:IsSyncedCode() then return false end

local sp, defs = Spring, UnitDefNames
local kasus = sp.GetModOptions().uji_kontrol
if not kasus then return false end

local function catat(...) sp.Echo("KONTROL", ...) end
local function arah(unit, cmd, x, z, opsi)
    sp.GiveOrderToUnit(unit, cmd, {x, sp.GetGroundHeight(x, z), z}, opsi or 0)
end

local function buat(key, x, z, hadap)
    return assert(sp.CreateUnit(key, x, sp.GetGroundHeight(x, z), z, hadap or 1, 0), key)
end

local function jarak(x, z, gx, gz)
    return math.sqrt((x - gx)^2 + (z - gz)^2)
end

local function selesai() catat("SELESAI", kasus) end

local function koridor()
    local jenis = {"tank_ringan", "medium_tank", "medium_tank_destroyer", "pengintai",
        "artileri_ringan", "robot_insinyur", "robot_infanteri", "robot_roket"}
    local unit, tankSelatan, perintahBerhenti = {}, nil, nil
    local function mulai()
        for _, sisi in ipairs({"utara", "selatan"}) do
            local function cermin(z) return sisi == "utara" and z or Game.mapSizeZ - z end
            local depo = cermin(304)
            assert(sp.TestBuildOrder(defs.gudang.id, 1024, sp.GetGroundHeight(1024, depo), depo, 1) > 0)
            buat("gudang", 1024, depo)
            for i, key in ipairs(jenis) do
                local x, z = 575 + ((i - 1) % 2) * 60, cermin(355 + math.floor((i - 1) / 2) * 36)
                local gx, gz = 1395 + ((i - 1) % 2) * 45, cermin(420 + math.floor((i - 1) / 2) * 45)
                local id = buat(key, x, z)
                sp.GiveOrderToUnit(id, CMD.FIRE_STATE, {0}, 0)
                unit[#unit + 1] = {id = id, key = key, sisi = sisi, gx = gx, gz = gz,
                    x = x, z = z, diam = 0, terlama = 0, dekatWaypoint = 0, jedaWaypoint = 0}
                if sisi == "selatan" and key == "tank_ringan" then tankSelatan = unit[#unit] end
                arah(id, CMD.MOVE, 790, cermin(417))
                arah(id, CMD.MOVE, 1030, cermin(412), CMD.OPT_SHIFT)
                arah(id, CMD.MOVE, gx, gz, CMD.OPT_SHIFT)
                catat("RUTE", sisi, key, x, z, gx, gz)
            end
        end
    end
    if kasus == "koridor-stop" then
        function gadget:UnitCmdDone(id, _, _, cmd, params)
            if not tankSelatan or id ~= tankSelatan.id or cmd ~= CMD.MOVE then return end
            if params[1] == tankSelatan.gx and params[3] == tankSelatan.gz then
                perintahBerhenti = sp.GetGameFrame() + 1
            end
        end
    end
    return function(frame)
        if frame == 5 then mulai() end
        if frame == perintahBerhenti then sp.GiveOrderToUnit(tankSelatan.id, CMD.STOP, {}, 0) end
        if frame < 6 or frame % 6 ~= 0 then return end
        for _, p in ipairs(unit) do
            local x, _, z = sp.GetUnitPosition(p.id)
            if not p.lintas and x >= 1024 then p.lintas = z end
            local sisa = jarak(x, z, p.gx, p.gz)
            if not p.tiba and sisa <= 32 then p.tiba = frame end
            local cmd, _, _, tx, _, tz = sp.GetUnitCurrentCommand(p.id)
            if p.tiba and sisa > 40 and not p.menjauh then
                p.menjauh = frame
                catat("MENJAUH", p.sisi, p.key, frame, x, z, cmd or 0, tx or 0, tz or 0)
            end
            if p.lintas and not p.tiba and not cmd and not p.berhenti then
                p.berhenti = frame
                catat("BERHENTI", p.sisi, p.key, frame, x, z, sisa)
            end
            local pelan = jarak(x, z, p.x, p.z) < 1
            if cmd == CMD.MOVE and tx and tz and jarak(x, z, tx, tz) > 24 and pelan then
                p.diam = p.diam + 6
                if p.diam > p.terlama then
                    p.terlama, p.macX, p.macZ = p.diam, x, z
                    p.sasaranX, p.sasaranZ = tx, tz
                end
            else
                p.diam = 0
            end
            if cmd == CMD.MOVE and (tx == 790 or tx == 1030) and jarak(x, z, tx, tz) <= 24 and pelan then
                p.dekatWaypoint = p.dekatWaypoint + 6
                p.jedaWaypoint = math.max(p.jedaWaypoint, p.dekatWaypoint)
            else
                p.dekatWaypoint = 0
            end
            p.x, p.z = x, z
        end
        if frame == 2700 then
            for _, p in ipairs(unit) do
                catat("TIBA", p.sisi, p.key, p.tiba or 0, math.floor(jarak(p.x, p.z, p.gx, p.gz) + .5),
                    p.lintas or -1, p.terlama, p.jedaWaypoint)
                if p.terlama >= 60 then
                    catat("MACET", p.sisi, p.key, p.macX, p.macZ, p.sasaranX, p.sasaranZ, p.terlama)
                end
                if p == tankSelatan and kasus == "koridor-stop" then
                    catat("STOP", perintahBerhenti or 0, p.tiba or 0)
                    if not perintahBerhenti or p.tiba then catat("GAGAL", "Stop harus membatalkan pendekatan") end
                elseif not p.tiba then
                    catat("GAGAL", "tujuan", p.sisi, p.key, p.x, p.z, p.gx, p.gz)
                elseif jarak(p.x, p.z, p.gx, p.gz) > 40 then
                    catat("GAGAL", "posisi akhir", p.sisi, p.key, p.x, p.z, p.gx, p.gz)
                end
            end
            selesai()
        end
    end
end

local function rally()
    local hadap = kasus == "rally-barat" and 3 or 1
    local arahKeluar = hadap == 1 and 1 or -1
    local function cermin(x) return hadap == 1 and x or Game.mapSizeX - x end
    local pesanan = {
        {"pabrik_kendaraan", cermin(560), 1120, cermin(700), 1120, {"pengintai", "medium_tank", "medium_tank_destroyer"}},
        {"pabrik_robot", cermin(560), 912, cermin(705), 880, {"robot_insinyur", "robot_infanteri", "robot_roket"}},
    }
    local pabrik, produk = {}, {}
    function gadget:UnitFromFactory(id, def, _, factory, _, userOrders)
        local p = pabrik[factory]
        if not p then return end
        local x, _, z = sp.GetUnitPosition(id)
        local frame = sp.GetGameFrame()
        produk[id] = {key = UnitDefs[def].name, pabrik = p, lahir = frame}
        sp.GiveOrderToUnit(id, CMD.FIRE_STATE, {0}, 0)
        catat("KELUAR", p[1], UnitDefs[def].name, frame, x, z, userOrders)
    end
    return function(frame)
        if frame == 5 then
            for _, r in ipairs({"ms", "es", "metal", "energy"}) do sp.SetTeamResource(0, r, 20000) end
            for _, p in ipairs(pesanan) do
                local id = buat(p[1], p[2], p[3], hadap)
                pabrik[id] = p
                local y = sp.GetGroundHeight(p[4], p[5])
                arah(id, CMD.MOVE, p[4], p[5])
                local cmd, _, _, xRally, _, zRally = sp.GetUnitCurrentCommand(id, -1)
                catat("TITIK_RALLY", p[1], cmd, xRally, zRally)
                for _, key in ipairs(p[6]) do
                    assert(sp.TestMoveOrder(defs[key].id, p[4], y, p[5], 0, 0, 0, true, false), key)
                    sp.GiveOrderToUnit(id, -defs[key].id, {}, 0)
                end
            end
        end
        if frame % 6 ~= 0 then return end
        for id, p in pairs(produk) do
            local x, _, z = sp.GetUnitPosition(id)
            if x then
                if not p.lewat and (x - p.pabrik[2]) * arahKeluar > 64 then p.lewat = frame - p.lahir end
                local sisa = jarak(x, z, p.pabrik[4], p.pabrik[5])
                if not p.tiba and sisa <= 36 then p.tiba = frame - p.lahir end
                p.x, p.z, p.terdekat = x, z, math.min(p.terdekat or sisa, sisa)
                local cmd, opsi, tag, tx, _, tz = sp.GetUnitCurrentCommand(id)
                if p.key == "robot_insinyur" and (p.tag ~= tag or not p.tercatat) then
                    p.tercatat, p.tag = true, tag
                    catat("PERINTAH_INSINYUR", frame, x, z, cmd or 0, tx or 0, tz or 0, opsi or 0)
                end
            elseif not p.hilang then
                p.hilang = frame
                catat("GAGAL", "produk hilang", p.pabrik[1], p.key, frame)
            end
        end
        if frame == 2700 then
            local total = 0
            for _, p in pairs(produk) do
                total = total + 1
                catat("RALLY", p.pabrik[1], p.key, p.lewat or 0, p.tiba or 0)
                if not p.lewat or not p.tiba then
                    catat("GAGAL", "rally", p.pabrik[1], p.key, p.x, p.z, p.terdekat)
                end
            end
            if total ~= 6 then catat("GAGAL", "jumlah produksi", total) end
            selesai()
        end
    end
end

local function lereng()
    local kasusTembak = {
        {"datar", "medium_tank", 385, 570, 497, 570},
        {"kaki_bukit", "medium_tank", 565, 720, 806, 720},
        {"lereng_miring", "medium_tank", 585, 1340, 817, 1320},
        {"lereng_curam", "medium_tank", 570, 1140, 835, 1140},
        {"arah_puncak", "medium_tank", 727, 1024, 994, 1024},
        {"artileri_terlalu_dekat", "artileri_ringan", 410, 1545, 570, 1545},
        {"artileri_lereng", "artileri_ringan", 390, 1490, 980, 1490},
    }
    local pelaku = {}
    function gadget:Initialize()
        for _, key in ipairs({"rts_meriam_medium", "rts_artileri_ringan"}) do
            local id = WeaponDefNames[key].id
            Script.SetWatchProjectile(id, true)
            Script.SetWatchExplosion(id, true)
        end
    end
    function gadget:ProjectileCreated(_, owner)
        local c = pelaku[owner]
        if c then c.tembak = c.tembak + 1 end
    end
    function gadget:Explosion(_, x, _, z, owner)
        local c = pelaku[owner]
        if c then
            c.bentur = c.bentur + 1
            c.meleset = math.max(c.meleset, jarak(x, z, c.gx, c.gz))
        end
        return false
    end
    return function(frame)
        if frame == 5 then
            for _, item in ipairs(kasusTembak) do
                local nama, key, x, z, gx, gz = unpack(item)
                local id = buat(key, x, z)
                pelaku[id] = {nama = nama, gx = gx, gz = gz, tembak = 0, bentur = 0, meleset = 0}
                arah(id, CMD.ATTACK, gx, gz)
                catat("BIDIK", nama, x, z, gx, gz, sp.GetGroundHeight(gx, gz) - sp.GetGroundHeight(x, z))
            end
        elseif frame == 420 then
            for _, c in pairs(pelaku) do
                catat("TEMBAK", c.nama, c.tembak, c.bentur, c.meleset)
                if c.nama == "lereng_curam" or c.nama == "arah_puncak" or c.nama == "artileri_terlalu_dekat" then
                    if c.tembak > 0 then catat("GAGAL", "tembakan semestinya tertahan", c.nama) end
                elseif c.bentur == 0 or c.meleset > 4 then
                    catat("GAGAL", "benturan di luar toleransi", c.nama, c.bentur, c.meleset)
                end
            end
            selesai()
        end
    end
end

local function artileri()
    local jenis = defs.artileri_ringan.id
    local senjata = WeaponDefNames.rts_artileri_ringan.id
    local pabrik, unit, proyektil, benturan
    local targetX, targetZ = 980, 1740

    function gadget:Initialize()
        Script.SetWatchProjectile(senjata, true)
        Script.SetWatchExplosion(senjata, true)
    end

    function gadget:UnitFromFactory(id, def, _, factory)
        if def ~= jenis or factory ~= pabrik then return end
        unit = id
        catat("ARTILERI_KELUAR", sp.GetGameFrame(), id)
        arah(id, CMD.MOVE, 360, 1490)
        arah(id, CMD.MOVE, 445, 1490, CMD.OPT_SHIFT)
        arah(id, CMD.ATTACK, targetX, targetZ, CMD.OPT_SHIFT)
    end

    function gadget:ProjectileCreated(id, owner, weapon)
        if owner ~= unit or weapon ~= senjata or proyektil then return end
        proyektil = id
        local x, _, z = sp.GetUnitPosition(owner)
        local hadap = sp.GetUnitHeading(owner)
        local beda = (sp.GetHeadingFromVector(targetX - x, targetZ - z) - hadap + 32768) % 65536 - 32768
        catat("ARTILERI_TEMBAK", sp.GetGameFrame(), x, z, math.abs(beda) * 360 / 65536)
        if jarak(x, z, 445, 1490) > 32 or math.abs(beda) * 360 / 65536 > 3 then
            catat("GAGAL", "Artileri menembak sebelum tiba dan menghadap sasaran")
        end
    end

    function gadget:Explosion(weapon, x, _, z, owner, id)
        if weapon == senjata and owner == unit and id == proyektil then
            benturan = jarak(x, z, targetX, targetZ)
            catat("ARTILERI_BENTUR", sp.GetGameFrame(), benturan)
        end
        return false
    end

    return function(frame)
        if frame == 5 then
            pabrik = buat("pabrik_kendaraan", 560, 1120)
            sp.GiveOrderToUnit(pabrik, -jenis, {}, 0)
        elseif frame == 2100 then
            if not benturan or benturan > 4 then
                catat("GAGAL", "Tembakan artileri dari pabrik gagal mencapai sasaran", benturan)
            end
            selesai()
        end
    end
end

local function radar()
    local lontar = VFS.Include("gamedata/lontar.lua")
    local x, z = 565, 720
    local lawan, artileriUji, pemindai, pengintai
    local tembakRadar, tembakVisual = false, false
    local senjata = WeaponDefNames.rts_artileri_ringan.id

    function gadget:Initialize() Script.SetWatchProjectile(senjata, true) end

    function gadget:ProjectileCreated(_, owner, weapon)
        if owner ~= artileriUji or weapon ~= senjata then return end
        local los = sp.GetUnitLosState(lawan, 0)
        if los.los then tembakVisual = true
        elseif los.radar then tembakRadar = true
        else catat("GAGAL", "Artileri masih menembak setelah kontak hilang") end
    end

    local function cek(nama, los, blip, kunci)
        local status = sp.GetUnitLosState(lawan, 0)
        local jenis, _, target = sp.GetUnitWeaponTarget(artileriUji, 1)
        local terkunci = jenis == 1 and target == lawan
        local tx, _, tz = lontar.posisiUnit(artileriUji, lawan)
        local _, _, _, _, _, _, asliX, _, asliZ = sp.GetUnitPosition(lawan, true, true)
        local selisih = tx and jarak(tx, tz, asliX, asliZ)
        catat("RADAR", nama, status.los or false, status.radar or false, terkunci, selisih or "nil")
        if (status.los or false) ~= los or (status.radar or false) ~= blip or terkunci ~= kunci then
            catat("GAGAL", "Status sensor atau kunci", nama)
        end
        if (los and (not selisih or selisih > .01)) or (blip and not los and (not selisih or selisih < 1))
            or (not blip and not los and tx) then
            catat("GAGAL", "Posisi bidik tidak sesuai visibilitas", nama)
        end
    end

    return function(frame)
        if frame == 5 then
            local markas = sp.GetTeamUnitsByDefs(0, defs.inti_komando.id)[1]
            sp.SetUnitSensorRadius(markas, "los", 100)
            local gardu = buat("gardu", 360, 545)
            pemindai = buat("radar", 405, 555)
            artileriUji = buat("artileri_ringan", 220, z)
            for _, id in ipairs({gardu, pemindai, artileriUji}) do sp.SetUnitSensorRadius(id, "los", 0) end
            lawan = assert(sp.CreateUnit("medium_tank", x, sp.GetGroundHeight(x, z), z, 1, 1))
            sp.SetUnitHealth(lawan, {health = 1000})
            for _, id in ipairs({lawan, artileriUji}) do sp.GiveOrderToUnit(id, CMD.FIRE_STATE, {0}, 0) end
        elseif frame == 90 then
            sp.GiveOrderToUnit(artileriUji, CMD.ATTACK, {lawan}, 0)
        elseif frame == 210 then
            cek("kontak", false, true, true)
            pengintai = buat("robot_insinyur", x + 100, z + 25)
        elseif frame == 390 then
            cek("terlihat", true, true, true)
            sp.DestroyUnit(pengintai, false, true)
            sp.DestroyUnit(pemindai, false, true)
        elseif frame == 510 then
            cek("hilang", false, false, false)
            if not tembakRadar or not tembakVisual then catat("GAGAL", "Tembakan pada radar dan LOS wajib terjadi") end
            selesai()
        end
    end
end

local siapkan = ({koridor = koridor, ["koridor-stop"] = koridor,
    rally = rally, ["rally-barat"] = rally, lereng = lereng, artileri = artileri, radar = radar})[kasus]
local jalankan = siapkan()
function gadget:GameFrame(frame) jalankan(frame) end
