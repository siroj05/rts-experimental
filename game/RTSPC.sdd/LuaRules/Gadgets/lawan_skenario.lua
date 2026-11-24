function gadget:GetInfo()
    return {name = "Scenario Opponent", desc = "Builds and contests control points", layer = 3, enabled = true}
end

if not gadgetHandler:IsSyncedCode() then return end

-- AI skenario. Tiap tim yang dikendalikan AI (TeamInfo isAI) mendapat satu pengendali:
-- - ekonomi: rencana bangun skenario (`aturan.lawan[].bangunan`, tapak tulisan tangan dicoba dulu) lalu rencana
--   bawaan; tapak dicari otomatis di sekitar markas bila tapak skenario terhalang, ekstraktor ke ladang kosong
--   terdekat di separuh peta sendiri. Beberapa Engineer Bot (profil `insinyur`) membagi tugas.
-- - produksi: campuran berbobot yang condong ke counter dari komposisi musuh yang terlihat.
-- - pasukan: dikumpulkan di titik kumpul dan dilepas bergelombang ke titik perebutan (logika bobot titik lama),
--   dan membela bangunan sendiri yang diserang.
local sp = Spring
local opsi = sp.GetModOptions()
local profil = VFS.Include("gamedata/profil_ai.lua")
local tingkat = profil[opsi.tingkat_ai] or profil.normal
local aturan = VFS.Include("gamedata/skenario.lua")
if not aturan or not aturan.titik then return false end
local hq = UnitDefNames.inti_komando.id
local insinyur = UnitDefNames.robot_insinyur.id
local pabrik = UnitDefNames.pabrik_kendaraan.id
local pabrikRobot = UnitDefNames.pabrik_robot.id
local ekstraktor = UnitDefNames.ekstraktor_besi.id
local pompa = UnitDefNames.pompa_minyak.id
local artileri = UnitDefNames.artileri_ringan.id
local pengintai = UnitDefNames.pengintai.id
local lontar = VFS.Include("gamedata/lontar.lua")
local tempur = {}
for id, def in pairs(UnitDefs) do
    if def.customParams.duduki == "1" then tempur[#tempur + 1] = id end
end
local tempurSet = {}
for _, id in ipairs(tempur) do tempurSet[id] = true end
local berat = {}
for _, n in ipairs({"medium_tank", "tank_ringan", "medium_tank_destroyer"}) do berat[UnitDefNames[n].id] = true end

-- Bobot dasar produksi dan tambahan per unit musuh berat/ringan yang terlihat (counter).
local bobotKendaraan = {
    {nama = "medium_tank", dasar = 3, lawanBerat = .15, lawanRingan = .1},
    {nama = "tank_ringan", dasar = 3, lawanBerat = 0, lawanRingan = .25},
    {nama = "medium_tank_destroyer", dasar = 1, lawanBerat = .45, lawanRingan = 0},
    {nama = "pengintai", dasar = 1, lawanBerat = 0, lawanRingan = .1, maks = 2},
    {nama = "artileri_ringan", dasar = 1, lawanBerat = .05, lawanRingan = .05, maks = 4},
}
local bobotRobot = {
    {nama = "robot_infanteri", dasar = 2, lawanBerat = 0, lawanRingan = .3},
    {nama = "robot_roket", dasar = 1.5, lawanBerat = .4, lawanRingan = 0},
}
for _, daftar in ipairs({bobotKendaraan, bobotRobot}) do
    for _, b in ipairs(daftar) do b.def = UnitDefNames[b.nama].id end
end

-- Rencana bawaan (jumlah kumulatif). Dipakai sesudah rencana skenario, jadi ekspansi tetap berlanjut.
local rencanaBawaan = {
    {unit = "pabrik_kendaraan", jumlah = 1},
    {unit = "ekstraktor_besi", jumlah = 1},
    {unit = "pompa_minyak", jumlah = 1},
    {unit = "ekstraktor_besi", jumlah = 3},
    {unit = "pabrik_robot", jumlah = 1},
    {unit = "pompa_minyak", jumlah = 2},
    {unit = "ekstraktor_besi", jumlah = 5},
    {unit = "pompa_minyak", jumlah = 3},
    {unit = "pabrik_kendaraan", jumlah = 2},
    {unit = "ekstraktor_besi", jumlah = 8},
    {unit = "pompa_minyak", jumlah = 4},
}

local function jarak2(ax, az, bx, bz) return (ax - bx)^2 + (az - bz)^2 end

local function buatPengendali(tim, rencana)
    local hadap = rencana and rencana.hadap
    local interval = math.max(1, math.floor(Game.gameSpeed * tingkat.interval))
    local offset = (tim * 7) % interval
    local posisi = {{0, 0}, {0, 48}, {0, -48}, {48, 0}, {-48, 0}}
    local rencanaBangun = {}
    for _, b in ipairs(rencana and rencana.bangunan or {}) do
        rencanaBangun[#rencanaBangun + 1] = {def = UnitDefNames[b.unit].id, jumlah = b.jumlah, tapak = b.tapak}
    end
    for _, b in ipairs(rencanaBawaan) do
        local def = UnitDefNames[b.unit].id
        local jumlah = b.jumlah
        if def == pabrik then jumlah = math.min(jumlah, tingkat.pabrik) end
        if def == ekstraktor then jumlah = math.min(jumlah, tingkat.ekstraktor) end
        rencanaBangun[#rencanaBangun + 1] = {def = def, jumlah = jumlah}
    end

    local aktif, sekutu
    local bx, bz, maju = 0, 0, {1, 0}
    local musuhAwal = {}
    local penugasan, pernahDikuasai, dilepas = {}, {}, {}
    local pernahPunyaPabrik = {}
    local serangan -- {x, z, frame} bangunan sendiri terakhir diserang
    local diproduksi = {}

    local function GameStart()
        local _, _, _, timAI = sp.GetTeamInfo(tim, false)
        aktif = timAI and opsi.lawanuji == "1"
        sekutu = sp.GetTeamAllyTeamID(tim)
        local x, _, z = sp.GetTeamStartPosition(tim)
        bx, bz = x, z
        local cx, cz = Game.mapSizeX / 2, Game.mapSizeZ / 2
        local dx, dz = cx - x, cz - z
        -- Arah maju: sumbu dominan ke tengah peta (markas di tepi barat/timur maju ke X, utara/selatan ke Z).
        if math.abs(dx) >= math.abs(dz) then maju = {dx >= 0 and 1 or -1, 0} else maju = {0, dz >= 0 and 1 or -1} end
        if not hadap then
            hadap = maju[1] > 0 and 1 or (maju[1] < 0 and 3 or (maju[2] > 0 and 0 or 2))
        end
        for _, t in ipairs(sp.GetTeamList()) do
            if t ~= sp.GetGaiaTeamID() and not sp.AreTeamsAllied(t, tim) then
                local ex, _, ez = sp.GetTeamStartPosition(t)
                if ex and ex >= 0 then musuhAwal[#musuhAwal + 1] = {ex, ez} end
            end
        end
    end

    local function unitJadi(def)
        local hasil = {}
        for _, unit in ipairs(sp.GetTeamUnitsByDefs(tim, def)) do
            if not sp.GetUnitIsBeingBuilt(unit) then hasil[#hasil + 1] = unit end
        end
        table.sort(hasil)
        return hasil
    end

    -- Cukup sumber daya untuk memulai (Recoil membelanjakan bertahap selama pembangunan).
    local function mampu(def, bagian)
        local m = sp.GetTeamResources(tim, "metal")
        local e = sp.GetTeamResources(tim, "energy")
        local data = UnitDefs[def]
        bagian = bagian or 1
        return m >= data.metalCost * bagian and e >= data.energyCost * bagian
    end

    local function bisaProduksi(bangunan)
        return not sp.GetUnitIsBuilding(bangunan) and sp.GetFactoryCommandCount(bangunan) == 0
    end

    -- Separuh peta sendiri: lebih dekat ke markas sendiri daripada ke markas musuh mana pun.
    local function wilayahSendiri(x, z)
        local d = jarak2(x, z, bx, bz)
        for _, m in ipairs(musuhAwal) do
            if jarak2(x, z, m[1], m[2]) < d then return false end
        end
        return true
    end

    local function lahanBebas(def, x, z, jarakTepi)
        local data = UnitDefs[def]
        local hx, hz = data.xsize * 4 + jarakTepi, data.zsize * 4 + jarakTepi
        -- Pohon di tapak harus di-reclaim dulu oleh insinyur dan bisa menahannya lama; pilih lahan tanpa fitur.
        if #sp.GetFeaturesInRectangle(x - hx, z - hz, x + hx, z + hz) > 0 then return false end
        for _, u in ipairs(sp.GetUnitsInRectangle(x - hx, z - hz, x + hx, z + hz)) do
            local ud = UnitDefs[sp.GetUnitDefID(u)]
            if ud and (ud.isBuilding or ud.speed == 0) then return false end
        end
        for _, l in ipairs(aturan.ladang or {}) do
            if jarak2(x, z, l[1], l[2]) < (hx + 40)^2 then return false end
        end
        return true
    end

    local function cobaTapak(def, x, z, jarakTepi)
        local px, py, pz = sp.Pos2BuildPos(def, x, 0, z, hadap)
        if px < 64 or pz < 64 or px > Game.mapSizeX - 64 or pz > Game.mapSizeZ - 64 then return end
        if sp.TestBuildOrder(def, px, py, pz, hadap) ~= 2 then return end
        if jarakTepi and not lahanBebas(def, px, pz, jarakTepi) then return end
        if not jarakTepi then
            local data = UnitDefs[def]
            local hx, hz = data.xsize * 4, data.zsize * 4
            if #sp.GetFeaturesInRectangle(px - hx, pz - hz, px + hx, pz + hz) > 0 then return end
        end
        return px, py, pz
    end

    local function cariEkstraktor()
        local calon = {}
        for _, l in ipairs(aturan.ladang or {}) do
            if wilayahSendiri(l[1], l[2]) then calon[#calon + 1] = l end
        end
        table.sort(calon, function(a, b) return jarak2(a[1], a[2], bx, bz) < jarak2(b[1], b[2], bx, bz) end)
        for _, l in ipairs(calon) do
            local terancam = false
            for _, u in ipairs(sp.GetUnitsInCylinder(l[1], l[2], 160)) do
                if not sp.AreTeamsAllied(sp.GetUnitTeam(u), tim) then terancam = true break end
            end
            if not terancam then
                local x, y, z = cobaTapak(ekstraktor, l[1], l[2])
                if x then return x, y, z end
            end
        end
    end

    -- Cincin persegi di sekitar jangkar di depan markas, langkah 48 elmo.
    local function cariLahan(def)
        local jarakTepi = (def == pabrik or def == pabrikRobot) and 40 or 20
        local ax, az = bx + maju[1] * 170, bz + maju[2] * 170
        for r = 0, 14 do
            for i = -r, r do
                for _, o in ipairs(r == 0 and {{0, 0}} or {{i, -r}, {i, r}, {-r, i}, {r, i}}) do
                    local x, z = ax + o[1] * 48, az + o[2] * 48
                    if wilayahSendiri(x, z) then
                        local px, py, pz = cobaTapak(def, x, z, jarakTepi)
                        if px then return px, py, pz end
                    end
                end
            end
        end
    end

    local gagalDilapor = {}
    local function tempatBangun(b)
        for _, t in ipairs(b.tapak or {}) do
            local x, y, z = cobaTapak(b.def, t[1], t[2])
            if x then return x, y, z end
        end
        local x, y, z
        if b.def == ekstraktor then x, y, z = cariEkstraktor() else x, y, z = cariLahan(b.def) end
        if not x and not gagalDilapor[b.def] then
            gagalDilapor[b.def] = true
            sp.Echo(string.format("AI tim %d: tidak ada tapak untuk %s di sekitar (%d, %d)", tim, UnitDefs[b.def].name, bx, bz))
        end
        return x, y, z
    end

    local function produksiBerbobot(produsen, daftar, terlihat)
        if not produsen or not bisaProduksi(produsen) then return end
        local terbaik, nilaiTerbaik
        for _, b in ipairs(daftar) do
            local hidup = sp.GetTeamUnitDefCount(tim, b.def)
            if (not b.maks or hidup < b.maks) and mampu(b.def) then
                local bobot = b.dasar + b.lawanBerat * terlihat.berat + b.lawanRingan * terlihat.ringan
                local nilai = bobot / (1 + (diproduksi[b.def] or 0) * .35)
                if not nilaiTerbaik or nilai > nilaiTerbaik then terbaik, nilaiTerbaik = b.def, nilai end
            end
        end
        if terbaik then
            sp.GiveOrderToUnit(produsen, -terbaik, {}, 0)
            diproduksi[terbaik] = (diproduksi[terbaik] or 0) + 1
        end
    end

    local function musuhTerlihat()
        local hasil = {berat = 0, ringan = 0}
        for _, t in ipairs(sp.GetTeamList()) do
            if not sp.AreTeamsAllied(t, tim) then
                for _, u in ipairs(sp.GetTeamUnitsByDefs(t, tempur)) do
                    local p = sp.GetUnitLosState(u, sekutu, false)
                    if p and p.los then
                        if berat[sp.GetUnitDefID(u)] then hasil.berat = hasil.berat + 1 else hasil.ringan = hasil.ringan + 1 end
                    end
                end
            end
        end
        return hasil
    end

    local macet = {}
    -- Insinyur yang terlalu lama di perintah yang sama (reclaim pohon, jalur buntu) dihentikan agar memilih ulang.
    local function periksaMacet(kerja, frame)
        local cmds = sp.GetUnitCommands(kerja, 1)
        local c = cmds and cmds[1]
        if not c then macet[kerja] = nil return end
        local kunci = c.id .. ":" .. table.concat(c.params, ",")
        local m = macet[kerja]
        if not m or m.kunci ~= kunci then macet[kerja] = {kunci = kunci, frame = frame} return end
        local batas = (c.id == CMD.RECLAIM and 20 or 75) * Game.gameSpeed
        if frame - m.frame > batas then
            sp.GiveOrderToUnit(kerja, CMD.STOP, {}, 0)
            macet[kerja] = nil
        end
    end

    local function urusEkonomi(pabrikJadi, robotJadi)
        local markas = unitJadi(hq)[1]
        local pekerja = unitJadi(insinyur)
        if markas and sp.GetTeamUnitDefCount(tim, insinyur) < tingkat.insinyur
            and bisaProduksi(markas) and mampu(insinyur) then
            sp.GiveOrderToUnit(markas, -insinyur, {}, 0)
        end
        local pulih = pernahPunyaPabrik[pabrik] and not pabrikJadi[1] and pabrik
            or pernahPunyaPabrik[pabrikRobot] and not robotJadi[1] and pabrikRobot
        local dipesan = {}
        local frame = sp.GetGameFrame()
        for _, kerja in ipairs(pekerja) do
            periksaMacet(kerja, frame)
            if sp.GetUnitCommandCount(kerja) == 0 then
                local selesai = false
                -- Bantu bangunan sendiri yang belum jadi.
                for _, u in ipairs(sp.GetTeamUnits(tim)) do
                    local ud = UnitDefs[sp.GetUnitDefID(u)]
                    if ud.speed == 0 and sp.GetUnitIsBeingBuilt(u) then
                        sp.GiveOrderToUnit(kerja, CMD.REPAIR, {u}, 0)
                        selesai = true
                        break
                    end
                end
                -- Sadar energi: stok menipis dan pemasukan bersih kecil, pompa didahulukan dari rencana.
                local e, _, _, eIn, eOut = sp.GetTeamResources(tim, "energy")
                if not selesai and e < 600 and (eIn - (eOut or 0)) < 12
                    and #sp.GetTeamUnitsByDefs(tim, pompa) + (dipesan[pompa] or 0) < 6 and mampu(pompa) then
                    local x, y, z = cariLahan(pompa)
                    if x then
                        sp.GiveOrderToUnit(kerja, -pompa, {x, y, z, hadap}, 0)
                        dipesan[pompa] = (dipesan[pompa] or 0) + 1
                        selesai = true
                    end
                end
                if not selesai then
                    for _, b in ipairs(rencanaBangun) do
                        local boleh = not pulih or b.def == pulih or b.def == ekstraktor or b.def == pompa
                        local ada = #sp.GetTeamUnitsByDefs(tim, b.def) + (dipesan[b.def] or 0)
                        if boleh and ada < b.jumlah then
                            if mampu(b.def, .5) then
                                local x, y, z = tempatBangun(b)
                                if x then
                                    sp.GiveOrderToUnit(kerja, -b.def, {x, y, z, hadap}, 0)
                                    dipesan[b.def] = (dipesan[b.def] or 0) + 1
                                    selesai = true
                                end
                            end
                            -- Rencana berurutan: item yang belum terpenuhi dan belum mampu menahan item sesudahnya,
                            -- kecuali tidak ada tempat (lanjut ke item berikutnya).
                            if selesai or mampu(b.def, .5) == false then break end
                        end
                    end
                end
            end
        end

        if pulih or #sp.GetTeamUnitsByDefs(tim, tempur) >= tingkat.batasPasukan then return end
        local terlihat = musuhTerlihat()
        for _, f in ipairs(pabrikJadi) do produksiBerbobot(f, bobotKendaraan, terlihat) end
        -- Robot cepat diproduksi; batasi bagiannya supaya kuota pasukan tidak habis untuk infanteri.
        local robotHidup = 0
        for _, b in ipairs(bobotRobot) do robotHidup = robotHidup + sp.GetTeamUnitDefCount(tim, b.def) end
        if robotHidup < tingkat.batasPasukan * .45 then
            for _, f in ipairs(robotJadi) do produksiBerbobot(f, bobotRobot, terlihat) end
        end
    end

    local function nilaiTitik(titik, index)
        local key = "titik_" .. titik.nama
        local pemilik = sp.GetGameRulesParam(key .. "_pemilik")
        local penantang = sp.GetGameRulesParam(key .. "_penantang")
        local sengketa = sp.GetGameRulesParam(key .. "_rebutan") == 1
        local jumlahMusuh = 0
        for _, unit in ipairs(sp.GetUnitsInCylinder(titik.x, titik.z, aturan.radius + 55)) do
            if tempurSet[sp.GetUnitDefID(unit)] and not sp.AreTeamsAllied(tim, sp.GetUnitTeam(unit))
                and not sp.GetUnitIsBeingBuilt(unit) then
                local pandangan = sp.GetUnitLosState(unit, sekutu, false)
                if pandangan and pandangan.los then jumlahMusuh = jumlahMusuh + 1 end
            end
        end
        local terancam = sengketa or jumlahMusuh > 0 or (penantang >= 0 and penantang ~= sekutu)
        if pemilik == sekutu then pernahDikuasai[index] = true end
        local bobot
        if terancam and pemilik == sekutu then bobot = 122
        elseif sengketa then bobot = 112
        elseif pemilik == sekutu then bobot = 22
        elseif pemilik == -1 then bobot = 96
        else bobot = pernahDikuasai[index] and 110 or 83 end
        local bantuan = sengketa or jumlahMusuh > 0 or (pemilik == sekutu and (penantang >= 0 and penantang ~= sekutu))
        local kapasitas = bantuan and math.max(2, math.min(4, jumlahMusuh + 1)) + tingkat.bantuan
            or (pemilik == sekutu and 1 or 3)
        return {bobot = bobot, kapasitas = kapasitas, ditugaskan = 0, slot = {}, musuh = pemilik >= 0 and pemilik ~= sekutu,
            jumlahMusuh = jumlahMusuh}
    end

    local function sudahKeluar(x, z, pabrikJadi)
        for _, bangunan in ipairs(pabrikJadi) do
            local px, _, pz = sp.GetUnitPosition(bangunan)
            if (x - px)^2 + (z - pz)^2 < 90^2 then return false end
        end
        return true
    end

    local offsetArtileri = {0, -104, 104, -192, 192}
    local function urusDukungan(unit, tujuan)
        local x, _, z = sp.GetUnitPosition(unit)
        local lama = penugasan[unit]
        local target, terbaik, tx, tz
        for i, titik in ipairs(aturan.titik) do
            -- Mundur dari titik ke arah markas sendiri sejauh jarak minimum artileri + cadangan.
            local ux, uz = bx - titik.x, bz - titik.z
            local panjang = math.max(1, math.sqrt(ux * ux + uz * uz))
            local mx, mz = titik.x + ux / panjang * (lontar.jarakMin + 104), titik.z + uz / panjang * (lontar.jarakMin + 104)
            if tujuan[i].ditugaskan > 0 and mx > 80 and mx < Game.mapSizeX - 80 then
                for _, d in ipairs(offsetArtileri) do
                    local ax, az = mx - uz / panjang * d, mz + ux / panjang * d
                    local jarak = math.sqrt((ax - x)^2 + (az - z)^2)
                    local nilai = tujuan[i].bobot - jarak / 23 + (lama and lama.titik == i and 20 or 0)
                    if az > 80 and az < Game.mapSizeZ - 80 and (not terbaik or nilai > terbaik)
                        and sp.TestMoveOrder(artileri, ax, sp.GetGroundHeight(ax, az), az, 0, 0, 0, true, false) then
                        target, terbaik, tx, tz = i, nilai, ax, az
                    end
                end
            end
        end
        if not target then return end
        local berubah = not lama or lama.x ~= tx or lama.z ~= tz
        local jauh = (x - tx)^2 + (z - tz)^2 > 28^2
        if berubah or (jauh and sp.GetUnitCommandCount(unit) == 0) then
            sp.GiveOrderToUnit(unit, CMD.FIGHT, {tx, sp.GetGroundHeight(tx, tz), tz}, 0)
        end
        penugasan[unit] = {titik = target, x = tx, z = tz}
    end

    local function urusPasukan(pabrikJadi, frame)
        local tujuan = {}
        for index, titik in ipairs(aturan.titik) do
            tujuan[index] = nilaiTitik(titik, index)
        end
        local kx, kz = bx + maju[1] * 300, bz + maju[2] * 300
        local pasukan = unitJadi(tempur)

        -- Serbuan: satu titik milik musuh yang paling menguntungkan (terdekat dari markas sendiri, sedikit penjaga)
        -- menampung semua unit yang tidak menjaga titik sendiri. Titik musuh lain tidak didatangi.
        local serbu, nilaiSerbu
        for index, titik in ipairs(aturan.titik) do
            local t = tujuan[index]
            if t.musuh then
                local nilai = -math.sqrt((titik.x - bx)^2 + (titik.z - bz)^2) / 23 - t.jumlahMusuh * 6
                if not nilaiSerbu or nilai > nilaiSerbu then serbu, nilaiSerbu = index, nilai end
            end
        end
        for index, t in ipairs(tujuan) do
            if t.musuh then
                if index == serbu then t.kapasitas, t.bobot = 99, 118 else t.kapasitas, t.bobot = 0, 0 end
            end
        end

        -- Bela markas: bangunan sendiri diserang dalam 12 detik terakhir.
        local bela = serangan and frame - serangan.frame < 12 * Game.gameSpeed and serangan

        -- Gelombang: unit baru menunggu di titik kumpul sampai jumlahnya cukup. Menit pembuka dilepas langsung
        -- supaya titik kosong cepat direbut. Pengintai selalu dilepas.
        local menunggu = {}
        for _, unit in ipairs(pasukan) do
            local x, _, z = sp.GetUnitPosition(unit)
            if not dilepas[unit] and sudahKeluar(x, z, pabrikJadi) then
                if sp.GetUnitDefID(unit) == pengintai then dilepas[unit] = true
                else menunggu[#menunggu + 1] = unit end
            end
        end
        -- Menit pembuka: dilepas berpasangan supaya titik kosong cepat direbut tanpa unit tunggal yang mudah habis.
        local ambang = frame < 150 * Game.gameSpeed and 2 or tingkat.gelombang
        -- Titik sendiri sedang diserang (bobot 122): unit yang menunggu langsung dilepas untuk memperkuatnya.
        local titikTerancam = false
        for _, t in ipairs(tujuan) do if t.bobot == 122 then titikTerancam = true end end
        if #menunggu >= ambang or (titikTerancam and #menunggu > 0) then
            for _, unit in ipairs(menunggu) do dilepas[unit] = true end
            menunggu = {}
        end
        for _, unit in ipairs(menunggu) do
            local x, _, z = sp.GetUnitPosition(unit)
            if bela then
                sp.GiveOrderToUnit(unit, CMD.FIGHT, {bela.x, sp.GetGroundHeight(bela.x, bela.z), bela.z}, 0)
            elseif (x - kx)^2 + (z - kz)^2 > 120^2 and sp.GetUnitCommandCount(unit) == 0 then
                sp.GiveOrderToUnit(unit, CMD.FIGHT, {kx, sp.GetGroundHeight(kx, kz), kz}, 0)
            end
        end

        local adaPerebut = false
        for _, unit in ipairs(pasukan) do
            if dilepas[unit] and sp.GetUnitDefID(unit) ~= artileri then adaPerebut = true break end
        end
        local tugas, pendukung = {}, {}
        for _, unit in ipairs(pasukan) do
            if dilepas[unit] then
                local x, _, z = sp.GetUnitPosition(unit)
                local lama = penugasan[unit]
                if adaPerebut and sp.GetUnitDefID(unit) == artileri then
                    pendukung[#pendukung + 1] = unit
                else
                    local terbaik, nilaiTerbaik
                    for index, titik in ipairs(aturan.titik) do
                        local calon = tujuan[index]
                        local jarak = math.sqrt((x - titik.x)^2 + (z - titik.z)^2)
                        local kelebihan = math.max(0, calon.ditugaskan - calon.kapasitas + 1)
                        local bonus = lama and lama.titik == index and 20 or 0
                        local nilai = calon.bobot - jarak / 23 - calon.ditugaskan * 12 - kelebihan * 85 + bonus
                        if not nilaiTerbaik or nilai > nilaiTerbaik then terbaik, nilaiTerbaik = index, nilai end
                    end
                    local calon = tujuan[terbaik]
                    calon.ditugaskan = calon.ditugaskan + 1
                    local slot = lama and lama.titik == terbaik and lama.slot
                    if slot then calon.slot[slot] = true end
                    tugas[#tugas + 1] = {unit = unit, titik = terbaik, slot = slot, x = x, z = z}
                end
            end
        end

        for _, t in ipairs(tugas) do
            local titik = aturan.titik[t.titik]
            local slot = t.slot
            if not slot then
                local dipakai = tujuan[t.titik].slot
                for i = 1, #posisi do
                    if not dipakai[i] then slot = i; break end
                end
                slot = slot or 1
                dipakai[slot] = true
            end
            local x, z = titik.x + posisi[slot][1], titik.z + posisi[slot][2]
            local perluBergerak = (x - t.x)^2 + (z - t.z)^2 > 28^2
            local dekatBela = bela and (t.x - bela.x)^2 + (t.z - bela.z)^2 < 700^2
            if dekatBela then
                sp.GiveOrderToUnit(t.unit, CMD.FIGHT, {bela.x, sp.GetGroundHeight(bela.x, bela.z), bela.z}, 0)
            elseif not t.slot or (perluBergerak and sp.GetUnitCommandCount(t.unit) == 0) then
                -- Biarkan perintah aktif supaya unit menuntaskan jalur atau pertempurannya.
                sp.GiveOrderToUnit(t.unit, CMD.FIGHT, {x, sp.GetGroundHeight(x, z), z}, 0)
            end
            penugasan[t.unit] = {titik = t.titik, slot = slot}
        end
        for _, unit in ipairs(pendukung) do urusDukungan(unit, tujuan) end
    end

    local function UnitFinished(_, def, pemilik)
        if pemilik == tim and (def == pabrik or def == pabrikRobot) then
            pernahPunyaPabrik[def] = true
        end
    end

    local function UnitDestroyed(unit)
        penugasan[unit] = nil
        dilepas[unit] = nil
    end

    local function UnitDamaged(unit, def, pemilik, attackerTeam)
        if pemilik ~= tim or not attackerTeam or sp.AreTeamsAllied(attackerTeam, tim) then return end
        if UnitDefs[def].speed == 0 then
            local x, _, z = sp.GetUnitPosition(unit)
            serangan = {x = x, z = z, frame = sp.GetGameFrame()}
        end
    end

    local function GameFrame(frame)
        if not aktif or frame == 0 or (frame + offset) % interval ~= 0 or sp.IsGameOver()
            or sp.GetGameRulesParam("titik_pemenang") ~= -1 then return end
        local pabrikJadi = unitJadi(pabrik)
        if opsi.ekonomi == "1" then
            local robotJadi = unitJadi(pabrikRobot)
            urusEkonomi(pabrikJadi, robotJadi)
            for _, bangunan in ipairs(robotJadi) do pabrikJadi[#pabrikJadi + 1] = bangunan end
        end
        urusPasukan(pabrikJadi, frame)
    end
    return {GameStart = GameStart, UnitFinished = UnitFinished, UnitDestroyed = UnitDestroyed,
        UnitDamaged = UnitDamaged, GameFrame = GameFrame}
end

-- Satu pengendali per tim di skenario. Rencana tulisan tangan dipakai bila ada untuk tim itu; tim lain memakai
-- rencana bawaan. Pengendali hanya aktif untuk tim yang dikendalikan AI.
local rencanaTim = {}
if aturan.lawan then
    for _, data in ipairs(aturan.lawan.tim and {aturan.lawan} or aturan.lawan) do rencanaTim[data.tim] = data end
end
local pengendali = {}
for i in ipairs(aturan.awal) do
    pengendali[#pengendali + 1] = buatPengendali(i - 1, rencanaTim[i - 1])
end

for _, nama in ipairs({"GameStart", "UnitFinished", "UnitDestroyed", "GameFrame"}) do
    gadget[nama] = function(_, ...)
        for _, ai in ipairs(pengendali) do ai[nama](...) end
    end
end
function gadget:UnitDamaged(unit, def, pemilik, _, _, _, _, attackerID, _, attackerTeam)
    for _, ai in ipairs(pengendali) do ai.UnitDamaged(unit, def, pemilik, attackerTeam) end
end
