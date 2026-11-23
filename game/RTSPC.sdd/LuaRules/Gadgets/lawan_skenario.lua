function gadget:GetInfo()
    return {name = "Scenario Opponent", desc = "Builds and contests control points", layer = 3, enabled = true}
end

if not gadgetHandler:IsSyncedCode() then return end

local sp = Spring
local opsi = sp.GetModOptions()
local profil = VFS.Include("gamedata/profil_ai.lua")
local tingkat = profil[opsi.tingkat_ai] or profil.normal
local aturan = VFS.Include("gamedata/skenario.lua")
if not aturan or not aturan.lawan then return false end
local tim, hadap = aturan.lawan.tim, aturan.lawan.hadap
local hq = UnitDefNames.inti_komando.id
local insinyur = UnitDefNames.robot_insinyur.id
local pabrik = UnitDefNames.pabrik_kendaraan.id
local pabrikRobot = UnitDefNames.pabrik_robot.id
local ekstraktor = UnitDefNames.ekstraktor_besi.id
local pompa = UnitDefNames.pompa_minyak.id
local artileri = UnitDefNames.artileri_ringan.id
local lontar = VFS.Include("gamedata/lontar.lua")
local tempur = {}
for id, def in pairs(UnitDefs) do
    if def.customParams.duduki == "1" then tempur[#tempur + 1] = id end
end
local tempurSet = {}
for _, id in ipairs(tempur) do tempurSet[id] = true end
local kendaraan = {"medium_tank", "tank_ringan", "medium_tank_destroyer", "pengintai", "artileri_ringan"}
local robot = {"robot_infanteri", "robot_roket"}
local indeksKendaraan, indeksRobot = 1, 1
local batasPasukan = tingkat.batasPasukan
local interval = Game.gameSpeed * tingkat.interval
local posisi = {{0, 0}, {0, 48}, {0, -48}, {48, 0}, {-48, 0}}
local rencanaBangun = {}
for i, bangunan in ipairs(aturan.lawan.bangunan) do
    rencanaBangun[i] = {def = UnitDefNames[bangunan.unit].id, jumlah = bangunan.jumlah, tapak = bangunan.tapak}
end

local aktif, sekutu
local penugasan, pernahDikuasai = {}, {}
local pernahPunyaPabrik = {}

function gadget:GameStart()
    local _, _, _, timAI = sp.GetTeamInfo(tim, false)
    aktif = timAI and opsi.lawanuji == "1"
    sekutu = sp.GetTeamAllyTeamID(tim)
end

local function unitJadi(def)
    local hasil = {}
    for _, unit in ipairs(sp.GetTeamUnitsByDefs(tim, def)) do
        if not sp.GetUnitIsBeingBuilt(unit) then hasil[#hasil + 1] = unit end
    end
    table.sort(hasil)
    return hasil
end

local function mampu(def)
    local m = sp.GetTeamResources(tim, "metal")
    local e = sp.GetTeamResources(tim, "energy")
    local data = UnitDefs[def]
    return m >= data.metalCost and e >= data.energyCost
end

local function bisaProduksi(bangunan)
    return not sp.GetUnitIsBuilding(bangunan) and sp.GetFactoryCommandCount(bangunan) == 0
end

local function produksiCampur(produsen, daftar, indeks)
    if not produsen or not bisaProduksi(produsen) then return indeks end
    for i = 0, #daftar - 1 do
        local nextIndex = (indeks + i - 1) % #daftar + 1
        local def = UnitDefNames[daftar[nextIndex]].id
        if mampu(def) then
            sp.GiveOrderToUnit(produsen, -def, {}, 0)
            return nextIndex % #daftar + 1
        end
    end
    return indeks
end

local function urusEkonomi(pabrikJadi, robotJadi)
    local pekerja = unitJadi(insinyur)[1]
    if not pekerja then
        local markas = unitJadi(hq)[1]
        if markas and sp.GetTeamUnitDefCount(tim, insinyur) == 0
            and bisaProduksi(markas) and mampu(insinyur) then
            sp.GiveOrderToUnit(markas, -insinyur, {}, 0)
        end
        return
    end

    local pulih = pernahPunyaPabrik[pabrik] and not pabrikJadi[1] and pabrik
        or pernahPunyaPabrik[pabrikRobot] and not robotJadi[1] and pabrikRobot
    if sp.GetUnitCommandCount(pekerja) == 0 then
        for _, bangunan in ipairs(rencanaBangun) do
            local def = bangunan.def
            local bolehBangun = not pulih or def == pulih or def == ekstraktor or def == pompa
            local ada = sp.GetTeamUnitsByDefs(tim, def)
            if bolehBangun and #unitJadi(def) < bangunan.jumlah then
                table.sort(ada)
                for _, unit in ipairs(ada) do
                    if sp.GetUnitIsBeingBuilt(unit) then
                        sp.GiveOrderToUnit(pekerja, CMD.REPAIR, {unit}, 0)
                        return
                    end
                end
            end
            if bolehBangun and #ada < bangunan.jumlah and mampu(def) then
                for _, tapak in ipairs(bangunan.tapak) do
                    local x, y, z = sp.Pos2BuildPos(def, tapak[1], 0, tapak[2], hadap)
                    if sp.TestBuildOrder(def, x, y, z, hadap) == 2 then
                        sp.GiveOrderToUnit(pekerja, -def, {x, y, z, hadap}, 0)
                        return
                    end
                end
            end
        end
    end

    -- Pemasukan dipakai memulihkan pabrik. Ekstraktor dan pompa masih boleh
    -- dibangun ketika cadangan belum cukup agar pemulihan tidak terlalu lama.
    if pulih or #sp.GetTeamUnitsByDefs(tim, tempur) >= batasPasukan then return end
    indeksKendaraan = produksiCampur(pabrikJadi[1], kendaraan, indeksKendaraan)
    indeksRobot = produksiCampur(robotJadi[1], robot, indeksRobot)
end

local function nilaiTitik(titik, index)
    local key = "titik_" .. titik.nama
    local pemilik = sp.GetGameRulesParam(key .. "_pemilik")
    local penantang = sp.GetGameRulesParam(key .. "_penantang")
    local sengketa = sp.GetGameRulesParam(key .. "_rebutan") == 1
    local musuhTerlihat = 0
    for _, unit in ipairs(sp.GetUnitsInCylinder(titik.x, titik.z, aturan.radius + 55, 0)) do
        if tempurSet[sp.GetUnitDefID(unit)] and not sp.GetUnitIsBeingBuilt(unit) then
            local pandangan = sp.GetUnitLosState(unit, sekutu, false)
            if pandangan and pandangan.los then musuhTerlihat = musuhTerlihat + 1 end
        end
    end
    local terancam = sengketa or musuhTerlihat > 0 or penantang == 0
    if pemilik == tim then pernahDikuasai[index] = true end
    local bobot
    if terancam and pemilik == tim then bobot = 122
    elseif sengketa then bobot = 112
    elseif pemilik == tim then bobot = 22
    elseif pemilik == -1 then bobot = 96
    else bobot = pernahDikuasai[index] and 110 or 83 end
    local bantuan = sengketa or musuhTerlihat > 0 or (pemilik == tim and penantang == 0)
    local kapasitas = bantuan and math.max(2, math.min(3, musuhTerlihat + 1)) + tingkat.bantuan or 1
    return {bobot = bobot, kapasitas = kapasitas,
        ditugaskan = 0, slot = {}}
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
    local arahMarkas = hadap == 3 and 1 or -1
    for i, titik in ipairs(aturan.titik) do
        local bx = titik.x + arahMarkas * (lontar.jarakMin + 104)
        if tujuan[i].ditugaskan > 0 and bx > 80 and bx < Game.mapSizeX - 80 then
            for _, dz in ipairs(offsetArtileri) do
                local bz = titik.z + dz
                local jarak = math.sqrt((bx - x)^2 + (bz - z)^2)
                local nilai = tujuan[i].bobot - jarak / 23 + (lama and lama.titik == i and 20 or 0)
                if bz > 80 and bz < Game.mapSizeZ - 80 and (not terbaik or nilai > terbaik)
                    and sp.TestMoveOrder(artileri, bx, sp.GetGroundHeight(bx, bz), bz, 0, 0, 0, true, false) then
                    target, terbaik, tx, tz = i, nilai, bx, bz
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

local function urusPasukan(pabrikJadi)
    local tujuan = {}
    for index, titik in ipairs(aturan.titik) do
        tujuan[index] = nilaiTitik(titik, index)
    end

    local pasukan = unitJadi(tempur)
    local adaPerebut = false
    for _, unit in ipairs(pasukan) do
        if sp.GetUnitDefID(unit) ~= artileri then
            adaPerebut = true
            break
        end
    end
    local tugas, pendukung = {}, {}
    for _, unit in ipairs(pasukan) do
        local x, _, z = sp.GetUnitPosition(unit)
        local lama = penugasan[unit]
        if adaPerebut and sp.GetUnitDefID(unit) == artileri then
            if lama or sudahKeluar(x, z, pabrikJadi) then pendukung[#pendukung + 1] = unit end
        elseif lama or sudahKeluar(x, z, pabrikJadi) then
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

    for _, tugasTank in ipairs(tugas) do
        local titik = aturan.titik[tugasTank.titik]
        local slot = tugasTank.slot
        if not slot then
            local dipakai = tujuan[tugasTank.titik].slot
            for i = 1, #posisi do
                if not dipakai[i] then slot = i; break end
            end
            slot = slot or 1
            dipakai[slot] = true
        end

        local x, z = titik.x + posisi[slot][1], titik.z + posisi[slot][2]
        local perluBergerak = (x - tugasTank.x)^2 + (z - tugasTank.z)^2 > 28^2
        -- Leave active orders in place so a tank can follow its path or finish fighting.
        if not tugasTank.slot or (perluBergerak and sp.GetUnitCommandCount(tugasTank.unit) == 0) then
            sp.GiveOrderToUnit(tugasTank.unit, CMD.FIGHT, {x, sp.GetGroundHeight(x, z), z}, 0)
        end
        penugasan[tugasTank.unit] = {titik = tugasTank.titik, slot = slot}
    end
    for _, unit in ipairs(pendukung) do urusDukungan(unit, tujuan) end
end

function gadget:UnitFinished(_, def, pemilik)
    if pemilik == tim and (def == pabrik or def == pabrikRobot) then
        pernahPunyaPabrik[def] = true
    end
end

function gadget:UnitDestroyed(unit)
    penugasan[unit] = nil
end

function gadget:GameFrame(frame)
    if not aktif or frame == 0 or frame % interval ~= 0 or sp.IsGameOver()
        or sp.GetGameRulesParam("titik_pemenang") ~= -1 then return end
    local pabrikJadi = unitJadi(pabrik)
    if opsi.ekonomi == "1" then
        local robotJadi = unitJadi(pabrikRobot)
        urusEkonomi(pabrikJadi, robotJadi)
        for _, bangunan in ipairs(robotJadi) do pabrikJadi[#pabrikJadi + 1] = bangunan end
    end
    urusPasukan(pabrikJadi)
end
