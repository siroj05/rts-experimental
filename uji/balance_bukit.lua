function gadget:GetInfo()
    return {name = "Central Hill Balance Test", layer = 100, enabled = true}
end

if not gadgetHandler:IsSyncedCode() then return false end

local sp, defs = Spring, UnitDefNames
local pilihan = sp.GetModOptions().uji_balance
local peta = VFS.Include("gamedata/skenario.lua")
local function log(...) sp.Echo("BALANCE", ...) end

local function tempat(nama, x, z, team, facing)
    return assert(sp.CreateUnit(nama, x, sp.GetGroundHeight(x, z), z, facing, team))
end

local function cari(tim, nama)
    for _, id in ipairs(sp.GetTeamUnitsByDefs(tim, defs[nama].id)) do
        if not sp.GetUnitIsBeingBuilt(id) then return id end
    end
end

local function stok(tim)
    local besi, _, _, masukBesi = sp.GetTeamResources(tim, "metal")
    local energi, _, _, masukEnergi = sp.GetTeamResources(tim, "energy")
    return besi, energi, masukBesi, masukEnergi
end

local function mampu(nama, tim)
    local m, e = stok(tim)
    local def = defs[nama]
    return m >= def.metalCost and e >= def.energyCost
end

local function gerak(unit, cmd, x, z)
    sp.GiveOrderToUnit(unit, cmd, {x, sp.GetGroundHeight(x, z), z}, 0)
end

local kendaraan = "pabrik_kendaraan"
local robot = "pabrik_robot"
local ekstraktor = "ekstraktor_besi"
local pompa = "pompa_minyak"
local insinyur = "robot_insinyur"
local bangunan = {
    {kendaraan, 560, 1120}, {robot, 560, 912}, {ekstraktor, 240, 880},
    {pompa, 368, 1248}, {ekstraktor, 240, 1168},
}
local pembukaan = {
    kendaraan = {1, 3, 4, 5, 2},
    robot = {2, 5, 4, 3, 1},
    ekonomi = {5, 4, 3, 1, 2},
    ekonomi_paralel = {5, 4, 3, 2},
}

if pilihan == "peran" then
    local kasus = {}
    local function pasangan(nama, target, x, z, jarak)
        local penyerang = tempat(nama, x, z, 0, 1)
        local sasaran = tempat(target, x + jarak * 8, z, 1, 3)
        for _, id in ipairs({penyerang, sasaran}) do
            sp.GiveOrderToUnit(id, CMD.FIRE_STATE, {0}, 0)
            sp.GiveOrderToUnit(id, CMD.MOVE_STATE, {0}, 0)
        end
        kasus[penyerang] = {nama, target, sasaran, damage = 0, tembakan = 0}
        sp.GiveOrderToUnit(penyerang, CMD.ATTACK, {sasaran}, 0)
        return penyerang
    end

    function gadget:Initialize()
        for id in pairs(WeaponDefs) do Script.SetWatchProjectile(id, true) end
    end

    function gadget:ProjectileCreated(_, owner)
        local c = kasus[owner]
        if c then c.tembakan = c.tembakan + 1 end
    end

    function gadget:UnitDamaged(unit, _, _, damage, _, _, _, attacker)
        local c = kasus[attacker]
        if c and unit == c[3] then c.damage = c.damage + damage end
    end

    local artileri
    function gadget:GameFrame(f)
        if f == 10 then
            pasangan("pengintai", "medium_tank", 190, 260, 17)
            pasangan("tank_ringan", "medium_tank", 190, 410, 19)
            pasangan("medium_tank", "tank_ringan", 190, 580, 20)
            pasangan("medium_tank_destroyer", "medium_tank", 190, 760, 42)
            pasangan("robot_infanteri", "medium_tank", 165, 1300, 18)
            pasangan("robot_roket", "medium_tank", 165, 1460, 22)
            artileri = pasangan("artileri_ringan", "medium_tank", 190, 1740, 20)
        elseif f == 100 then
            assert(kasus[artileri].tembakan == 0, "Artileri menembak di bawah jarak minimum")
            local posisi = tempat("medium_tank", 750, 1740, 1, 3)
            sp.GiveOrderToUnit(posisi, CMD.FIRE_STATE, {0}, 0)
            sp.GiveOrderToUnit(posisi, CMD.MOVE_STATE, {0}, 0)
            local pengamat = tempat("pengintai", 710, 1820, 0, 1)
            sp.GiveOrderToUnit(pengamat, CMD.FIRE_STATE, {0}, 0)
            sp.GiveOrderToUnit(artileri, CMD.ATTACK, {posisi}, 0)
            kasus[artileri][3] = posisi
            log("MIN_RANGE", "artileri_ringan", "20m", 0)
        elseif f == 390 then
            for _, c in pairs(kasus) do
                assert(c.tembakan > 0 and c.damage > 0, "Tidak mengenai sasaran: " .. c[1])
                log("ROLE", c[1], c[2], c.tembakan, c.damage)
            end
            local pekerja = assert(cari(0, insinyur))
            assert(#UnitDefs[sp.GetUnitDefID(pekerja)].weapons == 0)
            assert(kasus[artileri].damage > 0, "Artileri gagal merusak sasaran 70 m")
            log("ROLE", insinyur, "construction", 0, 0)
            log("DONE", pilihan)
        end
    end
    return
end

if pilihan == "pulih" then
    local pekerjaHilang, pabrikHilang, robotHilang
    function gadget:GameFrame(f)
        if f == 1650 then
            local pekerja = assert(cari(1, insinyur))
            local pabrik = assert(cari(1, kendaraan))
            pekerjaHilang, pabrikHilang = f, f
            sp.DestroyUnit(pekerja, false, true)
            sp.DestroyUnit(pabrik, false, true)
            -- Tekanan uji terukur. Pemulihan harus memakai pemasukan pertandingan.
            sp.SetTeamResource(1, "metal", 60)
            log("LOSS", insinyur, f)
            log("LOSS", kendaraan, f)
        elseif f == 8100 then
            assert(cari(1, insinyur) and cari(1, kendaraan), "AI gagal memulihkan insinyur atau pabrik kendaraan")
            local bengkel = assert(cari(1, robot), "Pabrik robot belum ada untuk pengujian")
            robotHilang = f
            sp.DestroyUnit(bengkel, false, true)
            sp.SetTeamResource(1, "metal", 150)
            log("LOSS", robot, f)
        elseif f == 11100 then
            assert(cari(1, robot), "AI gagal memulihkan pabrik robot")
            log("RECOVERY", cari(1, insinyur) and 1 or 0, cari(1, kendaraan) and 1 or 0,
                cari(1, robot) and 1 or 0, f)
            log("DONE", pilihan)
        end
        if f % 900 == 0 then
            local m, e, masukM, masukE = stok(1)
            log("RECOVERY_STOCK", f, m, e, masukM, masukE)
        end
    end
    function gadget:UnitFinished(_, id, tim)
        if tim ~= 1 then return end
        local nama = UnitDefs[id].name
        local hilang = nama == insinyur and pekerjaHilang or (nama == kendaraan and pabrikHilang
            or (nama == robot and robotHilang))
        if hilang then log("REBUILT", nama, sp.GetGameFrame() - hilang) end
    end
    return
end

if pilihan == "taktik" then
    local artileri, bantuan, musuh
    local tugasArtileri, tugasBantuan
    local damageDukungan = 0
    local titik = peta.titik[2]
    local function dekat(params, jarak)
        return (params[1] - titik.x)^2 + (params[3] - titik.z)^2 < jarak^2
    end
    function gadget:AllowCommand(unit, _, _, cmd, params)
        if cmd == CMD.FIGHT then
            if unit == artileri then tugasArtileri = params end
            if unit == bantuan then tugasBantuan = params end
        end
        return true
    end
    function gadget:UnitDamaged(unit, _, _, damage, _, _, _, attacker)
        if unit == musuh and attacker == artileri then damageDukungan = damageDukungan + damage end
    end
    function gadget:GameFrame(f)
        if f == 10 then
            tempat("tank_ringan", 1392, 496, 1, 3)
            artileri = tempat("artileri_ringan", 1698, 496, 1, 3)
        elseif f == 120 then
            assert(tugasArtileri and not dekat(tugasArtileri, 320) and dekat(tugasArtileri, 440),
                "Artileri belum ditugaskan mendukung dari jarak aman")
            log("SUPPORT", tugasArtileri[1], tugasArtileri[3], f)
        elseif f == 330 then
            assert(sp.GetGameRulesParam("titik_B_pemilik") == 1, "AI belum mengambil B")
            musuh = tempat("medium_tank", 1224, 504, 0, 1)
            sp.GiveOrderToUnit(musuh, CMD.FIRE_STATE, {0}, 0)
            bantuan = tempat("tank_ringan", 1480, 1024, 1, 3)
        elseif f == 825 then
            assert(tugasBantuan and dekat(tugasBantuan, peta.radius), "AI tidak memperkuat titik yang diserang")
            assert(damageDukungan > 0, "Artileri tidak membantu titik yang diserang")
            log("DEFENSE", tugasBantuan[1], tugasBantuan[3], damageDukungan, f)
            log("DONE", pilihan)
        end
    end
    return
end

local urutan = assert(pembukaan[pilihan], tostring(pilihan))
local rencana = 1
local jumlahKeluar, jumlahDibuat = 0, 0
local penugasan = {}
local pertama = {}
local posisiLama = {}
local habisBesi, habisEnergi = 0, 0
local tertahanBesi, tertahanEnergi = 0, 0
local pekerjaAwal
local tapakParalel = {{560, 1120}, {560, 1192}, {544, 1056}}
local produksi = {
    {kendaraan, {"pengintai", "pengintai", "tank_ringan", "medium_tank", "medium_tank_destroyer",
        "artileri_ringan"}, 1},
    {robot, {"robot_infanteri", "robot_infanteri", "robot_roket", "robot_roket"}, 1},
}

local function bangun()
    local langkah = bangunan[urutan[rencana]]
    local pekerja = pekerjaAwal or cari(0, insinyur)
    if not langkah or not pekerja or sp.GetUnitCommandCount(pekerja) ~= 0 then return end
    local nama, x, z = langkah[1], langkah[2], langkah[3]
    if not mampu(nama, 0) then
        local m, e = stok(0)
        local def = defs[nama]
        if m < def.metalCost then tertahanBesi = tertahanBesi + 1 end
        if e < def.energyCost then tertahanEnergi = tertahanEnergi + 1 end
        return
    end
    local id = defs[nama].id
    local bx, y, bz = sp.Pos2BuildPos(id, x, 0, z, 1)
    assert(sp.TestBuildOrder(id, bx, y, bz, 1) == 2, "Tapak pengujian terhalang " .. nama)
    sp.GiveOrderToUnit(pekerja, -id, {bx, y, bz, 1}, 0)
    rencana = rencana + 1
end

local function bangunParalel()
    pekerjaAwal = pekerjaAwal or cari(0, insinyur)
    local markas = cari(0, "inti_komando")
    local pekerja = sp.GetTeamUnitsByDefs(0, defs[insinyur].id)
    if #pekerja == 1 and markas and sp.GetFactoryCommandCount(markas) == 0 and mampu(insinyur, 0) then
        sp.GiveOrderToUnit(markas, -defs[insinyur].id, {}, 0)
    end
    if sp.GetTeamUnitDefCount(0, defs[kendaraan].id) > 0 or not cari(0, ekstraktor)
        or not mampu(kendaraan, 0) then return end
    for _, unit in ipairs(pekerja) do
        if unit ~= pekerjaAwal and not sp.GetUnitIsBeingBuilt(unit) and sp.GetUnitCommandCount(unit) == 0 then
            local id = defs[kendaraan].id
            for _, tapak in ipairs(tapakParalel) do
                local x, y, z = sp.Pos2BuildPos(id, tapak[1], 0, tapak[2], 1)
                if sp.TestBuildOrder(id, x, y, z, 1) == 2 then
                    sp.GiveOrderToUnit(unit, -id, {x, y, z, 1}, 0)
                    log("PARALLEL_FACTORY", x, z)
                    return
                end
            end
        end
    end
end

local function buatPasukan()
    if #sp.GetTeamUnits(0) >= 20 then return end
    for _, daftar in ipairs(produksi) do
        local pabrik = cari(0, daftar[1])
        local jenis = daftar[2][daftar[3]]
        if pabrik and sp.GetFactoryCommandCount(pabrik) == 0 and mampu(jenis, 0) then
            sp.GiveOrderToUnit(pabrik, -defs[jenis].id, {}, 0)
            daftar[3] = daftar[3] % #daftar[2] + 1
        end
    end
end

function gadget:UnitFinished(unit, def, tim)
    if sp.GetGameFrame() <= 0 or tim > 1 then return end
    local data = UnitDefs[def]
    if data.customParams.duduki == "1" then
        if not pertama[tim] then
            pertama[tim] = true
            log("FIRST_UNIT", tim, data.name, sp.GetGameFrame())
        end
        if tim == 0 then
            jumlahDibuat = jumlahDibuat + 1
            penugasan[unit] = {pabrik = cari(0, data.name:find("^robot_") and robot or kendaraan)}
        end
    elseif tim == 0 and data.name ~= insinyur then
        log("BUILD", data.name, sp.GetGameFrame())
    end
end

local function kirim()
    local hitung = {}
    local ids = {}
    for unit in pairs(penugasan) do ids[#ids + 1] = unit end
    table.sort(ids)
    for _, unit in ipairs(ids) do
        local tugas = penugasan[unit]
        if tugas.titik then hitung[tugas.titik] = (hitung[tugas.titik] or 0) + 1 end
    end
    for _, unit in ipairs(ids) do
        local tugas = penugasan[unit]
        if not tugas.titik then
            local x, _, z = sp.GetUnitPosition(unit)
            local px, _, pz
            if tugas.pabrik then px, _, pz = sp.GetUnitPosition(tugas.pabrik) end
            if x and (not px or (x - px)^2 + (z - pz)^2 >= 80^2) then
                jumlahKeluar = jumlahKeluar + 1
                local terbaik, nilai
                for _, i in ipairs({1, 3, 2, 4}) do
                    local t = peta.titik[i]
                    local musuh = sp.GetGameRulesParam("titik_" .. t.nama .. "_pemilik") == 1
                    local skor = -(hitung[i] or 0) * 65
                        - math.sqrt((x - t.x)^2 + (z - t.z)^2) / 22 - (musuh and 15 or 0)
                    if not nilai or skor > nilai then terbaik, nilai = i, skor end
                end
                tugas.titik = terbaik
                hitung[terbaik] = (hitung[terbaik] or 0) + 1
                local t = peta.titik[terbaik]
                gerak(unit, CMD.FIGHT, t.x + (hitung[terbaik] - 1) % 3 * 20, t.z)
                log("EXIT", UnitDefs[sp.GetUnitDefID(unit)].name, sp.GetGameFrame(), t.nama)
            end
        end
    end
end

function gadget:UnitDestroyed(unit) penugasan[unit] = nil end

local selesai
function gadget:GameFrame(f)
    if selesai or f % 30 ~= 0 then return end
    local m, e, masukM, masukE = stok(0)
    if m < 5 then habisBesi = habisBesi + 1 end
    if e < 10 then habisEnergi = habisEnergi + 1 end
    for _, t in ipairs(peta.titik) do
        local owner = sp.GetGameRulesParam("titik_" .. t.nama .. "_pemilik")
        if owner ~= posisiLama[t.nama] then
            posisiLama[t.nama] = owner
            if owner >= 0 then log("POINT", t.nama, owner, f) end
        end
    end
    local biru = sp.GetGameRulesParam("titik_skor_0")
    local merah = sp.GetGameRulesParam("titik_skor_1")
    if f == 2700 or f == 3600 then log("CHECKPOINT", f, biru, merah, m, e, masukM, masukE) end
    local hasil = sp.GetGameRulesParam("titik_pemenang")
    if hasil ~= -1 or f >= 9000 then
        log("RESULT", hasil, f, biru, merah, jumlahDibuat, jumlahKeluar,
            habisBesi, habisEnergi, tertahanBesi, tertahanEnergi, masukM, masukE)
        log("DONE", pilihan)
        selesai = true
        return
    end
    bangun()
    if pilihan == "ekonomi_paralel" then bangunParalel() end
    buatPasukan()
    kirim()
end
