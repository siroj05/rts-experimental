-- Otak AI tingkat atas (Brutal, sebagian untuk Hard). 🟡 Rancangan Claude 2026-11-24, disetujui user ("gas", dengan
-- permintaan: "brutal, hasrat ingin menang bukan cuma puas point, mampu berfikir balas dendam", "bisa belajar").
--
-- Dipanggil dari LuaRules/Gadgets/lawan_skenario.lua untuk tim yang profilnya `otak = "brutal"`. Bagian:
-- 1. Ingatan: unit tempur musuh yang pernah terlihat (posisi, nilai, kapan) dan bangunan musuh yang pernah terlihat.
--    Hanya yang masuk LOS/radar sekutu, jadi AI tidak curang melihat peta.
-- 2. Keadaan: skor, laju skor, perkiraan waktu menang tiap pihak, kekuatan (biaya × sisa HP) → mode
--    ekspansi / rebut / tekan / nekat.
-- 3. Dendam: kerugian yang ditimbulkan tiap tim musuh (unit mati, bangunan dirusak, markas diserang) dengan peluruhan
--    lambat. Sasaran milik tim pendendam mendapat bobot lebih, jadi di 4v4 AI fokus membalas satu musuh.
-- 4. Sasaran: titik musuh, ekonomi musuh (ekstraktor, pompa), pabrik, markas (hancur = menang), dan kelompok pasukan
--    musuh. Pasukan utama berkumpul dulu lalu menyerbu sebagai satu gumpalan, hanya kalau unggul kekuatan di sana.
--    Serbuan yang gagal (kekuatan tinggal < 45%) diingat sebagai penalti sasaran itu.
-- 5. Mundur: unit HP < 30% pulang ke markas untuk diperbaiki insinyur, kembali setelah HP > 85%.
-- 6. Belajar dalam ronde: dipindah ke LuaRules/ai/belajar_unit.lua (2026-11-26) supaya semua tingkat ikut belajar.
--    Di sini tinggal pengali gaya main.
-- 7. Belajar antarronde: gaya main dipilih per peta dari statistik `gamedata/belajar_ai.lua` (UCB1). Statistik
--    diperbarui oleh tools/latih_ai.py dari hasil ronde headless. Baris log `AI GAYA tim=<t> gaya=<g>`.
-- Perbandingan def lintas fraksi (bug 2026-11-28): AI F1 tidak mengenali HQ/pabrik F2 karena membandingkan dengan def
-- fraksinya sendiri. sama(a, b) benar kalau kedua def berpadanan (gamedata/fraksi.lua).
local dasarDef = VFS.Include("gamedata/fraksi.lua").dasar
local function sama(a, b) return a ~= nil and b ~= nil and dasarDef[a] == dasarDef[b] end
local sp = Spring
local M = {}

M.gaya = {
    seimbang = {},
    serbu = {ambang = 1.15, gelombang = 4, robot = 1.4, ekstraktor = 6},
    ekonomi = {ambangAwal = 1.7, menitAwal = 7, ekstraktor = 10, pabrik = 2},
    lapis_baja = {berat = 1.7, robot = .7},
}
local urutanGaya = {"seimbang", "serbu", "ekonomi", "lapis_baja"}

-- Pilih gaya untuk tim ini: modoption ai_gaya_<tim> (latihan), lalu UCB1 dari statistik peta.
function M.pilihGaya(tim, opsi)
    local paksa = opsi["ai_gaya_" .. tim]
    if paksa and M.gaya[paksa] then return paksa end
    local ok, data = pcall(VFS.Include, "gamedata/belajar_ai.lua")
    local peta = ok and data and data.peta and data.peta[Game.mapName] or {}
    local total = 0
    for _, g in ipairs(urutanGaya) do total = total + ((peta[g] or {}).main or 0) end
    local terbaik, nilaiTerbaik
    for _, g in ipairs(urutanGaya) do
        local s = peta[g] or {}
        local main, menang = s.main or 0, s.menang or 0
        local nilai = (menang + 1) / (main + 2) + .35 * math.sqrt(math.log(total + 2) / (main + 1)) + math.random() * .04
        if not nilaiTerbaik or nilai > nilaiTerbaik then terbaik, nilaiTerbaik = g, nilai end
    end
    return terbaik
end

local function jarak(ax, az, bx, bz) return math.sqrt((ax - bx)^2 + (az - bz)^2) end

-- c: {tim, tingkat, gaya, aturan, tempurSet, artileri, lontar, hq, ekstraktor, pompa, pabrik, pabrikRobot}
function M.baru(c)
    local tim, tingkat, g = c.tim, c.tingkat, M.gaya[c.gaya] or {}
    local sekutu, bx, bz, maju
    local ingat, bangunan, dendam, gagal, efek, mundur = {}, {}, {}, {}, {}, {}
    local mode, sasaran, fase, kuatAwal = "ekspansi", nil, "kumpul", 0
    local kekuatanKita, kekuatanMusuh = 0, 0
    local pekerja = {} -- insinyur musuh yang diingat {x, z, f, t}
    local frameLalu = 0
    local awal = true
    local gerak, macetKali, paksaSampai = nil, 0, 0
    local o = {}

    local function nilaiUnit(u, def)
        local hp, maks = sp.GetUnitHealth(u)
        return UnitDefs[def].metalCost * ((hp and maks and maks > 0) and hp / maks or 1)
    end

    function o.Mulai(s, x, z, m)
        sekutu, bx, bz, maju = s, x, z, m
        sp.Echo(string.format("AI GAYA tim=%d gaya=%s", tim, c.gaya))
    end

    function o.Mode() return mode end
    -- Unit mundur kembali bertempur setelah HP > 85% atau 50 detik (tidak sempat dirawat).
    function o.Mundur(u)
        local m = mundur[u]
        if not m then return false end
        local hp, maks = sp.GetUnitHealth(u)
        if not hp or hp / maks > .85 or sp.GetGameFrame() - m > 50 * Game.gameSpeed then
            mundur[u] = nil
            return false
        end
        return true
    end

    -- 1–3. Ingatan, keadaan, peluruhan dendam. Dipanggil tiap keputusan.
    function o.Amati(frame)
        local dt = (frame - frameLalu) / Game.gameSpeed
        frameLalu = frame
        local luruh = .995 ^ dt
        for t, v in pairs(dendam) do dendam[t] = v * luruh end
        for k, v in pairs(gagal) do gagal[k] = v * (.99 ^ dt) end

        for _, t in ipairs(sp.GetTeamList()) do
            if t ~= sp.GetGaiaTeamID() and not sp.AreTeamsAllied(t, tim) then
                for _, u in ipairs(sp.GetTeamUnits(t)) do
                    local los = sp.GetUnitLosState(u, sekutu, false)
                    if los and (los.los or los.radar) then
                        local def = sp.GetUnitDefID(u)
                        local x, _, z = sp.GetUnitPosition(u)
                        if c.tempurSet[def] then
                            -- radar = hanya kontak radar (belum terlihat), untuk rencana dari radar di garis_depan.
                            ingat[u] = {x = x, z = z, n = nilaiUnit(u, def), f = frame, t = t, def = def, radar = not los.los}
                        elseif los.los and UnitDefs[def].speed == 0 then
                            bangunan[u] = {x = x, z = z, def = def, t = t, dibangun = sp.GetUnitIsBeingBuilt(u)}
                        elseif UnitDefs[def].isBuilder and UnitDefs[def].speed > 0 then
                            -- Insinyur musuh (terlihat atau kontak radar): sasaran serangan ganggu.
                            pekerja[u] = {x = x, z = z, f = frame, t = t}
                        end
                    end
                end
            end
        end
        for u, m in pairs(pekerja) do
            if frame - m.f > 20 * Game.gameSpeed or not sp.ValidUnitID(u) then pekerja[u] = nil end
        end
        for u, b in pairs(bangunan) do
            if b.dibangun and sp.ValidUnitID(u) then
                local los = sp.GetUnitLosState(u, sekutu, false)
                if los and los.los then b.dibangun = sp.GetUnitIsBeingBuilt(u) end
            end
        end
        kekuatanMusuh = 0
        for u, m in pairs(ingat) do
            if frame - m.f > 40 * Game.gameSpeed then ingat[u] = nil else kekuatanMusuh = kekuatanMusuh + m.n end
        end
        -- Kekuatan kita = semua tim sekutu (di 4v4 dulu hanya tim sendiri dibanding gabungan 4 tim musuh, sehingga mode
        -- tekan tidak pernah aktif walau kubu unggul 3x).
        kekuatanKita = 0
        for _, t in ipairs(sp.GetTeamList()) do
            if sp.AreTeamsAllied(t, tim) then
                for _, u in ipairs(sp.GetTeamUnitsByDefs(t, c.tempur)) do
                    if not sp.GetUnitIsBeingBuilt(u) then kekuatanKita = kekuatanKita + nilaiUnit(u, sp.GetUnitDefID(u)) end
                end
            end
        end

        local a = c.aturan
        local rk, rm = 0, 0
        for _, t in ipairs(a.titik) do
            local p = sp.GetGameRulesParam("titik_" .. t.nama .. "_pemilik") or -1
            if p == sekutu then rk = rk + 1 elseif p >= 0 then rm = rm + 1 end
        end
        local skorKita = sp.GetGameRulesParam("titik_skor_" .. sekutu) or 0
        local skorMusuh = sp.GetGameRulesParam("titik_skor_" .. (1 - sekutu)) or 0
        local pps = a.poinPerDetik or 1
        local tKita = rk > 0 and (a.targetSkor - skorKita) / (rk * pps) or math.huge
        local tMusuh = rm > 0 and (a.targetSkor - skorMusuh) / (rm * pps) or math.huge
        awal = frame < (g.menitAwal or 2.5) * 60 * Game.gameSpeed
        if frame < 150 * Game.gameSpeed then mode = "ekspansi"
        elseif tMusuh < tKita and (tMusuh < 300 or skorMusuh - skorKita > .12 * a.targetSkor) then mode = "nekat"
        elseif kekuatanKita > 1.6 * kekuatanMusuh and kekuatanKita > 1500 then mode = "tekan"
        else mode = "rebut" end
    end

    local function catatEfek(def)
        efek[def] = efek[def] or {beri = 0, rugi = 0}
        return efek[def]
    end

    function o.Rusak(unit, def, team, damage, attackerDef, attackerTeam)
        if not attackerTeam or damage <= 0 then return end
        local ud = UnitDefs[def]
        local porsi = math.min(damage, ud.health) / math.max(1, ud.health)
        if team == tim and not sp.AreTeamsAllied(attackerTeam, tim) then
            local kali = def == c.hq and 3 or (ud.speed == 0 and 2 or 1)
            dendam[attackerTeam] = (dendam[attackerTeam] or 0) + porsi * ud.metalCost * kali
        elseif attackerTeam == tim and attackerDef and not sp.AreTeamsAllied(team, tim) then
            local e = catatEfek(attackerDef)
            e.beri = e.beri + porsi * ud.metalCost
        end
    end

    function o.Hancur(unit, def, team, attackerTeam)
        ingat[unit], bangunan[unit], mundur[unit], pekerja[unit] = nil, nil, nil, nil
        if team ~= tim then return end
        local ud = UnitDefs[def]
        if c.tempurSet[def] then
            local e = catatEfek(def)
            e.rugi = e.rugi + ud.metalCost
        end
        if attackerTeam and not sp.AreTeamsAllied(attackerTeam, tim) then
            dendam[attackerTeam] = (dendam[attackerTeam] or 0) + ud.metalCost * (ud.speed == 0 and 2 or 1)
        end
    end

    -- 6. Pengali bobot produksi dari gaya main (efektivitas unit ada di belajar_unit.lua).
    function o.KaliProduksi(def)
        local k = 1
        if def == c.artileri or not c.tempurSet[def] then k = 1
        elseif c.berat[def] then k = g.berat or 1
        else k = (UnitDefs[def].name:find("^robot") and (g.robot or 1)) or 1 end
        return k  -- efektivitas unit: belajar_unit.lua
    end

    local function kekuatanDekat(x, z, r, frame)
        local n = 0
        for _, m in pairs(ingat) do
            if frame - m.f < 30 * Game.gameSpeed and (m.x - x)^2 + (m.z - z)^2 < r * r then n = n + m.n end
        end
        return n
    end

    local function bobotDendam(t)
        if not t then return 1 end
        local maks = 0
        for _, v in pairs(dendam) do maks = math.max(maks, v) end
        if maks < 1 then return 1 end
        return 1 + .8 * (dendam[t] or 0) / maks
    end

    -- Kandidat sasaran pasukan utama.
    local function kandidat(frame, bela, kita)
        local daftar = {}
        -- Bela markas hanya kalau penyerangnya berbobot (bukan pengintai yang lewat).
        if bela and kekuatanDekat(bela.x, bela.z, 600, frame) >= 250 then
            daftar[#daftar + 1] = {x = bela.x, z = bela.z, nilai = 220, kunci = "bela", wajib = true}
        end
        for i, t in ipairs(c.aturan.titik) do
            local p = sp.GetGameRulesParam("titik_" .. t.nama .. "_pemilik") or -1
            if p >= 0 and p ~= sekutu then
                daftar[#daftar + 1] = {x = t.x, z = t.z, nilai = mode == "nekat" and 180 or 140, kunci = "t" .. i,
                    titik = i}
            end
        end
        -- Bangunan musuh hanya diserang saat unggul jauh (mode tekan); selain itu pasukan fokus ke titik.
        for u, b in pairs(mode == "tekan" and bangunan or {}) do
            local nilai
            if sama(b.def, c.hq) then nilai = mode == "tekan" and 210 or (mode == "nekat" and 40 or 70)
            elseif sama(b.def, c.pabrik) or sama(b.def, c.pabrikRobot) then nilai = 80
            elseif sama(b.def, c.ekstraktor) or sama(b.def, c.pompa) then nilai = 62
            else nilai = 30 end
            if mode == "ekspansi" then nilai = nilai * .5 end
            daftar[#daftar + 1] = {x = b.x, z = b.z, nilai = nilai * bobotDendam(b.t), kunci = "b" .. u, unit = u, t = b.t}
        end
        -- Kelompok pasukan musuh per tim (balas dendam ke pelakunya), terutama yang mendekati wilayah kita.
        local kelompok = {}
        for _, m in pairs(ingat) do
            if frame - m.f < 15 * Game.gameSpeed then
                local k = kelompok[m.t] or {x = 0, z = 0, n = 0, jml = 0}
                k.x, k.z, k.n, k.jml = k.x + m.x * m.n, k.z + m.z * m.n, k.n + m.n, k.jml + 1
                kelompok[m.t] = k
            end
        end
        -- Diburu hanya kalau mendekati markas atau titik milik sendiri, atau saat mode tekan (unggul jauh).
        local function dekatMilik(x, z)
            if jarak(x, z, bx, bz) < 1100 then return true end
            for _, t in ipairs(c.aturan.titik) do
                if sp.GetGameRulesParam("titik_" .. t.nama .. "_pemilik") == sekutu and jarak(x, z, t.x, t.z) < 500 then
                    return true
                end
            end
        end
        for t, k in pairs(kelompok) do
            local x, z = k.n > 0 and k.x / k.n or 0, k.n > 0 and k.z / k.n or 0
            local dekat = k.jml >= 2 and dekatMilik(x, z)
            if k.jml >= 2 and k.n >= math.max(400, .2 * kita) and (dekat or mode == "tekan") then
                local dekatKita = dekat and 60 or 0
                daftar[#daftar + 1] = {x = x, z = z, nilai = (45 + dekatKita) * bobotDendam(t), kunci = "p" .. t, t = t,
                    kelompok = t}
            end
        end
        return daftar
    end

    local function masihSah(s)
        if not s then return false end
        if s.kunci == "bela" then return true end
        if s.titik then
            local p = sp.GetGameRulesParam("titik_" .. c.aturan.titik[s.titik].nama .. "_pemilik") or -1
            return p >= 0 and p ~= sekutu
        end
        if s.unit then return bangunan[s.unit] ~= nil end
        return s.kelompok ~= nil
    end

    -- 4–5. Kendali pasukan utama (unit yang tidak menjaga titik). `bela`: {x, z} bangunan sendiri diserang.
    -- Mundur untuk diperbaiki: unit HP < 30% dikirim ke depan markas; mengembalikan unit yang tidak sedang mundur.
    function o.Rawat(pasukan, frame)
        local aktif = {}
        local adaInsinyur = sp.GetTeamUnitDefCount(tim, c.insinyur) > 0
        for _, u in ipairs(pasukan) do
            local hp, maks = sp.GetUnitHealth(u)
            local r = hp and maks and hp / maks or 1
            -- Ambang mundur: 30% (titik), 45% di Deathmatch (retreat fighter CircuitAI 0,45).
            local batasHP = tingkat.mundurHP or (c.aturan.mode == "hancur" and .45 or .3)
            if not mundur[u] and r < batasHP and adaInsinyur and tingkat.mundur then
                mundur[u] = frame
                local x, z = bx + maju[1] * 120, bz + maju[2] * 120
                sp.GiveOrderToUnit(u, CMD.MOVE, {x, sp.GetGroundHeight(x, z), z}, 0)
            end
            if not o.Mundur(u) then aktif[#aktif + 1] = u end
        end
        return aktif
    end

    -- Ambang keberanian serbu dari mode (dipakai logika titik lama untuk Brutal).
    function o.Ambang()
        return mode == "nekat" and .9 or (mode == "tekan" and 1.1 or (tingkat.ambang or g.ambang or 1.3))
    end

    function o.Pasukan(pasukan, frame, bela)
        local aktif = o.Rawat(pasukan, frame)
        if #aktif == 0 then return end

        local cx, cz, kita = 0, 0, 0
        for _, u in ipairs(aktif) do
            local x, _, z = sp.GetUnitPosition(u)
            local n = nilaiUnit(u, sp.GetUnitDefID(u))
            cx, cz, kita = cx + x * n, cz + z * n, kita + n
        end
        cx, cz = cx / kita, cz / kita

        local ambang = mode == "nekat" and .9 or (mode == "tekan" and 1.1 or (tingkat.ambang or g.ambang or 1.35))
        -- Sasaran gagal dibuang; sasaran berjalan dipertahankan dengan bonus supaya tidak bolak-balik.
        if sasaran and fase == "serbu" and kita < .45 * kuatAwal and not sasaran.wajib then
            gagal[sasaran.kunci] = (gagal[sasaran.kunci] or 0) + 1
            sasaran, fase = nil, "kumpul"
        end
        if not masihSah(sasaran) then sasaran, fase = nil, "kumpul" end

        local terbaik, nilaiTerbaik
        for _, k in ipairs(kandidat(frame, bela, kita)) do
            local musuh = kekuatanDekat(k.x, k.z, 700, frame)
            -- Titik dan pasukan musuh selalu memakai ambang biasa (maks 1,25) supaya balapan titik awal tidak kalah;
            -- serangan ke bangunan di masa awal gaya ekonomi memakai ambangAwal.
            local a = (k.titik or k.kelompok) and math.min(ambang, 1.25) or (awal and g.ambangAwal or ambang)
            local layak = k.wajib or (#aktif >= 3 and kita >= a * musuh)
            if layak then
                -- Titik: biaya jarak dari markas sendiri juga (rebut yang dekat rumah dulu; kandang musuh paling akhir).
                local dariRumah = k.titik and jarak(bx, bz, k.x, k.z) / 30 or 0
                local nilai = k.nilai - jarak(cx, cz, k.x, k.z) / 40 - dariRumah - (gagal[k.kunci] or 0) * 25
                    + (sasaran and sasaran.kunci == k.kunci and 25 or 0)
                if not nilaiTerbaik or nilai > nilaiTerbaik then terbaik, nilaiTerbaik = k, nilai end
            end
        end
        if terbaik and (not sasaran or terbaik.kunci ~= sasaran.kunci) then
            sasaran, fase = terbaik, terbaik.wajib and "serbu" or "kumpul"
            gerak, macetKali, paksaSampai = nil, 0, 0
        elseif sasaran and terbaik and sasaran.kelompok then
            sasaran.x, sasaran.z = terbaik.x, terbaik.z -- kelompok musuh bergerak
        end
        if not terbaik then sasaran, fase = nil, "kumpul" end

        -- Kumpul: serbu setelah 70% kekuatan berada dalam 450 elmo dari pusat pasukan.
        if sasaran and fase == "kumpul" then
            local dekat = 0
            for _, u in ipairs(aktif) do
                local x, _, z = sp.GetUnitPosition(u)
                if (x - cx)^2 + (z - cz)^2 < 450^2 then dekat = dekat + nilaiUnit(u, sp.GetUnitDefID(u)) end
            end
            if dekat >= .7 * kita then fase, kuatAwal = "serbu", kita end
        end

        -- Macet: pusat pasukan tidak bergerak 150 elmo dalam 20 detik dan belum sampai. Pertama kali: paksa MOVE
        -- 12 detik (keluar dari tembak-menembak yang terhalang medan); kedua kali: sasaran dianggap tak terjangkau.
        if sasaran and fase == "serbu" and not sasaran.wajib then
            if not gerak or jarak(cx, cz, gerak.x, gerak.z) > 150 then gerak = {x = cx, z = cz, f = frame}
            elseif frame - gerak.f > 20 * Game.gameSpeed and jarak(cx, cz, sasaran.x, sasaran.z) > 250 then
                macetKali = macetKali + 1
                gerak = nil
                if macetKali == 1 then
                    paksaSampai, o.kunci = frame + 12 * Game.gameSpeed, nil
                else
                    gagal[sasaran.kunci] = (gagal[sasaran.kunci] or 0) + 3
                    sp.Echo(string.format("AI tim %d: sasaran %s tak terjangkau", tim, sasaran.kunci))
                    sasaran, fase, macetKali = nil, "kumpul", 0
                end
            end
        end

        local tx, tz
        if sasaran and fase == "serbu" then tx, tz = sasaran.x, sasaran.z
        elseif sasaran then tx, tz = cx, cz
        else
            -- Tidak ada sasaran layak: tunggu di depan titik sendiri yang paling dekat ke musuh, atau depan markas.
            tx, tz = bx + maju[1] * 300, bz + maju[2] * 300
            local terjauh
            for _, t in ipairs(c.aturan.titik) do
                if sp.GetGameRulesParam("titik_" .. t.nama .. "_pemilik") == sekutu then
                    local d = jarak(t.x, t.z, bx, bz)
                    if not terjauh or d > terjauh then terjauh, tx, tz = d, t.x, t.z end
                end
            end
        end
        local kunciPerintah = string.format("%d:%d", math.floor(tx / 64), math.floor(tz / 64))
        for _, u in ipairs(aktif) do
            local x, _, z = sp.GetUnitPosition(u)
            local ux, uz = tx, tz
            if sp.GetUnitDefID(u) == c.artileri and fase == "serbu" then
                -- Artileri berhenti di belakang sasaran, sejauh jarak minimum + cadangan ke arah pusat pasukan.
                local dx, dz = cx - tx, cz - tz
                local p = math.max(1, math.sqrt(dx * dx + dz * dz))
                local mundurJarak = c.lontar.jarakMin + 104
                ux, uz = tx + dx / p * mundurJarak, tz + dz / p * mundurJarak
            end
            local cmds = sp.GetUnitCommandCount(u)
            local jauh = (x - ux)^2 + (z - uz)^2 > 90^2
            if o.kunci ~= kunciPerintah or (jauh and cmds == 0) then
                local cmd = frame < paksaSampai and CMD.MOVE or CMD.FIGHT
                sp.GiveOrderToUnit(u, cmd, {ux, sp.GetGroundHeight(ux, uz), uz}, 0)
            end
        end
        o.kunci = kunciPerintah
        if paksaSampai > 0 and frame >= paksaSampai then paksaSampai, o.kunci = 0, nil end
        o.posisi = string.format("pusat=%d,%d tuju=%d,%d n=%d", cx, cz, tx, tz, #aktif)
    end

    -- Insinyur perawat: unit mundur yang sudah sampai dekat markas (500 elmo). Mendahului pekerjaan lain; true juga
    -- kalau insinyur sedang merawat.
    function o.TugasPerbaikan(kerja)
        local c1 = sp.GetUnitCommands(kerja, 1)
        if c1 and c1[1] and c1[1].id == CMD.REPAIR and mundur[c1[1].params[1]] then return true end
        local x, _, z = sp.GetUnitPosition(kerja)
        local terdekat, d0
        for u in pairs(mundur) do
            if sp.ValidUnitID(u) then
                local ux, _, uz = sp.GetUnitPosition(u)
                local d = (ux - x)^2 + (uz - z)^2
                if (ux - bx)^2 + (uz - bz)^2 < 500^2 and (not d0 or d < d0) then terdekat, d0 = u, d end
            else mundur[u] = nil end
        end
        if terdekat then
            sp.GiveOrderToUnit(kerja, CMD.REPAIR, {terdekat}, 0)
            return true
        end
    end

    function o.Ingatan() return ingat, bangunan, pekerja end
    function o.Kekuatan() return kekuatanKita, kekuatanMusuh end
    function o.BobotDendam(t) return bobotDendam(t) end

    -- Bela markas hanya kalau penyerang berbobot (bukan pengintai lewat).
    function o.BelaBerbobot(bela, frame)
        if bela and kekuatanDekat(bela.x, bela.z, 600, frame) >= 250 then return bela end
    end

    function o.Laporan()
        return string.format("mode=%s sasaran=%s fase=%s kita=%.0f musuh=%.0f", mode, sasaran and sasaran.kunci or "-",
            fase, kekuatanKita, kekuatanMusuh) .. " " .. (o.posisi or "") .. " " .. (o.hitungan or "")
    end
    return o
end

return M
