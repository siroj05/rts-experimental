-- Militer AI mode Deathmatch (🟡 Claude 2026-11-25, user: "tiru mekanismenya (A)"). Mekanisme dari CircuitAI
-- (rlcevg, GPL v2: MilitaryManager, AttackTask, DefendTask, RaidTask) dibaca sebagai referensi lalu ditulis ulang:
-- - Peran per jenis unit -> tugas: scout, raider (RAID), riot/assault/anti-heavy (DEFEND lalu ATTACK), artileri
--   (ikut ATTACK dari belakang).
-- - DEFEND: berkumpul di depan pangkalan sampai kekuatan >= max(minSerang, grup musuh terkuat x ambangBela), atau
--   langsung bergabung kalau sudah ada tugas ATTACK.
-- - ATTACK: musuh dikelompokkan (grup radius 600). Grup dilewati kalau kekuatan kita <= pengaruh grup x ambangSerang
--   x faktor jarak (grup dekat markas kita lebih rela dilawan). Sasaran = unit musuh terdekat dari grup yang layak;
--   dalam jangkauan -> CMD.ATTACK unit itu; tidak ada sasaran -> markas musuh yang diketahui.
-- - RAID: berkumpul sampai `raidMin`, lalu sasaran musuh (ekonomi dulu) dengan panas musuh < kekuatan raid (2x dekat
--   markas sendiri); kabur ke pangkalan kalau panas di posisinya >= kekuatannya.
-- - Bangunan bersenjata dihitung 4,25x (static thr_mod CircuitAI).
local sp = Spring
local M = {}

local PERAN = {
    pengintai = "scout", tank_ringan = "raider", robot_infanteri = "riot", medium_tank = "assault",
    robot_roket = "assault", medium_tank_destroyer = "ah", artileri_ringan = "arty",
}

function M.baru(c)
    -- c: {tim, tingkat, otak, garis, hq, ekstraktor, pompa, pabrik, pabrikRobot, artileri, lontar}
    local t = c.tingkat
    local ambangSerang = t.ambangSerang or .45
    local ambangBela = t.ambangBela or .8
    local minSerang = t.minSerang or 900
    local raidMin = t.raidMin or 400
    local sekutu, bx, bz, maju
    local tugas = {}      -- daftar tugas {jenis, anggota = {unit = true}, ...}
    local tugasUnit = {}  -- unit -> tugas
    local perintah = {}   -- unit -> kunci perintah terakhir
    local markasMusuh = {}
    local grup = {}
    local o = {}

    local function nilai(u)
        local def = sp.GetUnitDefID(u)
        local hp, maks = sp.GetUnitHealth(u)
        if not def or not hp then return 0 end
        return UnitDefs[def].metalCost * hp / math.max(1, maks)
    end
    local function jarak2(ax, az, bx2, bz2) return (ax - bx2)^2 + (az - bz2)^2 end
    local function peran(u)
        local def = sp.GetUnitDefID(u)
        return def and PERAN[UnitDefs[def].name] or "assault"
    end

    function o.Mulai(s, x, z, m)
        sekutu, bx, bz, maju = s, x, z, m
        for _, tm in ipairs(sp.GetTeamList()) do
            if tm ~= sp.GetGaiaTeamID() and not sp.AreTeamsAllied(tm, c.tim) then
                local ex, _, ez = sp.GetTeamStartPosition(tm)
                if ex and ex >= 0 then markasMusuh[#markasMusuh + 1] = {x = ex, z = ez} end
            end
        end
    end

    -- Grup musuh: pengelompokan rakus radius 600 atas ingatan (unit 30 detik terakhir + bangunan).
    local musuhGerak = 0
    local function susunGrup(frame)
        grup = {}
        musuhGerak = 0
        local ingat, bangunan = c.otak.Ingatan()
        local daftar = {}
        for u, m in pairs(ingat) do
            if frame - m.f < 30 * Game.gameSpeed then
                daftar[#daftar + 1] = {u = u, x = m.x, z = m.z, n = m.n * 1.075, gerak = true}
                musuhGerak = musuhGerak + m.n * 1.075
            end
        end
        for u, b in pairs(bangunan) do
            local ud = UnitDefs[b.def]
            local senjata = ud.weapons and #ud.weapons > 0
            daftar[#daftar + 1] = {u = u, x = b.x, z = b.z, n = senjata and ud.metalCost * 4.25 or 0, def = b.def}
        end
        for _, e in ipairs(daftar) do
            local masuk
            for _, g in ipairs(grup) do
                if jarak2(e.x, e.z, g.x, g.z) < 600^2 then masuk = g break end
            end
            if not masuk then
                masuk = {x = e.x, z = e.z, n = 0, anggota = {}}
                grup[#grup + 1] = masuk
            end
            masuk.n = masuk.n + e.n
            masuk.anggota[#masuk.anggota + 1] = e
        end
    end

    local function kekuatan(tg)
        local n, x, z, jml = 0, 0, 0, 0
        for u in pairs(tg.anggota) do
            local v = nilai(u)
            local ux, _, uz = sp.GetUnitPosition(u)
            if ux then
                n, x, z, jml = n + v, x + ux, z + uz, jml + 1
            end
        end
        if jml == 0 then return 0, bx, bz end
        return n, x / jml, z / jml
    end

    local function beri(u, cmd, param, kunci)
        if perintah[u] == kunci and sp.GetUnitCommandCount(u) > 0 then return end
        sp.GiveOrderToUnit(u, cmd, param, 0)
        perintah[u] = kunci
    end

    local function lepas(u)
        local tg = tugasUnit[u]
        if tg then tg.anggota[u] = nil end
        tugasUnit[u], perintah[u] = nil, nil
    end

    local function tugasBaru(jenis)
        local tg = {jenis = jenis, anggota = {}}
        tugas[#tugas + 1] = tg
        return tg
    end

    local function cari(jenis)
        for _, tg in ipairs(tugas) do if tg.jenis == jenis then return tg end end
    end

    local function tetapkan(u)
        local p = peran(u)
        local tg
        if p == "scout" then
            local n = 0
            for _, x in ipairs(tugas) do if x.jenis == "scout" then n = n + 1 end end
            if n < 1 then tg = tugasBaru("scout") else p = "raider" end
        end
        if p == "raider" then
            -- Batasi porsi raid ±35% pasukan; sisanya ikut regu utama.
            local nRaid, nSemua = 0, 0
            for u2, x in pairs(tugasUnit) do
                nSemua = nSemua + 1
                if x.jenis == "raid" then nRaid = nRaid + 1 end
            end
            if nRaid >= 4 and nRaid > nSemua * .35 then p = "assault" end
        end
        if p == "raider" then
            for _, x in ipairs(tugas) do if x.jenis == "raid" and x.kumpul then tg = x end end
            tg = tg or tugasBaru("raid")
            if tg.kumpul == nil then tg.kumpul = true end
        elseif p == "arty" then
            tg = cari("attack") or cari("defend") or tugasBaru("defend")
        elseif not tg then
            -- DEFEND -> ATTACK: bergabung langsung hanya kalau tugas serang masih dekat pangkalan;
            -- kalau sudah jauh, kumpul dulu jadi rombongan bala bantuan (hindari dicicil satu-satu).
            local a = cari("attack")
            if a then
                local _, ax, az = kekuatan(a)
                if jarak2(ax, az, bx, bz) > 1500^2 then a = nil end
            end
            tg = a or cari("defend") or tugasBaru("defend")
        end
        tg.anggota[u] = true
        tugasUnit[u] = tg
    end

    local function panasMusuh(x, z)
        return c.garis.Panas(x, z)
    end

    -- ATTACK: sasaran unit musuh terdekat dari grup yang layak.
    local function sasaranSerang(x, z, kuat)
        local terbaik, d0, cadangan, dc
        local dOB = math.max(1, jarak2(x, z, bx, bz))
        local ingat, bangunan = c.otak.Ingatan()
        for _, g in ipairs(grup) do
            local skala = math.min(jarak2(g.x, g.z, bx, bz) / dOB, 1)
            local layak = kuat > g.n * ambangSerang * skala
            if layak then
                local lemah = kuat * .125 > g.n
                for _, e in ipairs(g.anggota) do
                    if ingat[e.u] or bangunan[e.u] then
                        local d = jarak2(x, z, e.x, e.z) * skala
                        if lemah then
                            if not dc or d < dc then cadangan, dc = e, d end
                        elseif not d0 or d < d0 then terbaik, d0 = e, d end
                    end
                end
            end
        end
        return terbaik or cadangan
    end

    -- Bangunan musuh terdekat berbobot: markas x.35, pabrik x.6, lainnya x1; lewati yang dijaga lebih kuat dari regu.
    local function sasaranDorong(x, z, kuat)
        local _, bangunan = c.otak.Ingatan()
        local terbaik, d0
        for u, b in pairs(bangunan) do
            if panasMusuh(b.x, b.z) < kuat then
                local w = b.def == c.hq and .35 or ((b.def == c.pabrik or b.def == c.pabrikRobot) and .6 or 1)
                local d = jarak2(x, z, b.x, b.z) * w * w
                if not d0 or d < d0 then terbaik, d0 = {u = u, x = b.x, z = b.z, def = b.def}, d end
            end
        end
        return terbaik
    end

    local function markasTerdekat(x, z)
        local m0, d0
        for _, m in ipairs(markasMusuh) do
            if not m.hilang then
                local d = jarak2(x, z, m.x, m.z)
                if not d0 or d < d0 then m0, d0 = m, d end
            end
        end
        return m0
    end

    local function perbaruiMarkas()
        local _, bangunan = c.otak.Ingatan()
        for _, m in ipairs(markasMusuh) do
            if not m.hilang and sp.IsPosInLos(m.x, sp.GetGroundHeight(m.x, m.z), m.z, sekutu) then
                local ada = false
                for _, b in pairs(bangunan) do
                    if b.def == c.hq and jarak2(b.x, b.z, m.x, m.z) < 400^2 then ada = true end
                end
                if not ada then m.hilang = true end
            end
        end
    end

    local function serbuUnit(tg, e, kunci)
        for u in pairs(tg.anggota) do
            local ux, _, uz = sp.GetUnitPosition(u)
            local jangkau = UnitDefs[sp.GetUnitDefID(u)].maxWeaponRange or 300
            if sp.GetUnitDefID(u) == c.artileri then
                -- Artileri: tembak dari jarak; FIGHT ke titik di belakang sasaran arah pusat regu.
                local dx, dz = ux - e.x, uz - e.z
                local p = math.max(1, math.sqrt(dx * dx + dz * dz))
                local r = math.max(c.lontar.jarakMin + 60, jangkau * .8)
                local ax, az = e.x + dx / p * r, e.z + dz / p * r
                beri(u, CMD.FIGHT, {ax, sp.GetGroundHeight(ax, az), az}, kunci .. "a")
            elseif jarak2(ux, uz, e.x, e.z) < (jangkau + 250)^2 and sp.ValidUnitID(e.u) then
                beri(u, CMD.ATTACK, {e.u}, kunci .. "s")
            else
                beri(u, CMD.FIGHT, {e.x, sp.GetGroundHeight(e.x, e.z), e.z}, kunci .. "f")
            end
        end
    end

    local function pindah(tg, x, z, kunci, cmd)
        for u in pairs(tg.anggota) do
            beri(u, cmd or CMD.FIGHT, {x, sp.GetGroundHeight(x, z), z}, kunci)
        end
    end

    -- pasukan: unit tempur di luar pabrik dan tidak sedang mundur. bela: {x, z} bangunan diserang (berbobot).
    function o.Perintah(pasukan, frame, bela)
        if not sekutu then return end
        perbaruiMarkas()
        susunGrup(frame)
        local ada = {}
        for _, u in ipairs(pasukan) do
            ada[u] = true
            if not tugasUnit[u] then tetapkan(u) end
        end
        for u in pairs(tugasUnit) do if not ada[u] then lepas(u) end end

        local maxGrup = 0
        for _, g in ipairs(grup) do maxGrup = math.max(maxGrup, g.n) end
        local kumpulX, kumpulZ = bx + maju[1] * 350, bz + maju[2] * 350

        -- Regu serang utama (terkuat); regu serang lain yang jauh menyusul ke sana dulu.
        local utama, kUtama, uX, uZ = nil, 0
        for _, tg in ipairs(tugas) do
            if tg.jenis == "attack" then
                local k, ax, az = kekuatan(tg)
                if k > kUtama then utama, kUtama, uX, uZ = tg, k, ax, az end
            end
        end

        local hidup = {}
        for _, tg in ipairs(tugas) do
            local kuat, x, z = kekuatan(tg)
            if next(tg.anggota) then
                hidup[#hidup + 1] = tg
                if tg.jenis == "defend" then
                    if bela then
                        pindah(tg, bela.x, bela.z, "bela" .. math.floor(bela.x / 64) .. ":" .. math.floor(bela.z / 64))
                    elseif kuat >= math.max(minSerang, maxGrup * ambangBela)
                        or (cari("attack") and kuat >= minSerang * .5) then
                        -- Rombongan bala bantuan cukup besar: berangkat, nanti digabung dengan regu serang (merge).
                        tg.jenis, tg.awal = "attack", kuat
                    else
                        pindah(tg, kumpulX, kumpulZ, "kumpul")
                    end
                end
                if tg.jenis == "attack" then
                    local e = sasaranSerang(x, z, kuat)
                    -- Unggul jauh atas semua unit gerak musuh yang diketahui: dorong ke bangunan (markas paling diutamakan).
                    if not e or kuat >= musuhGerak * 1.5 then
                        local b = sasaranDorong(x, z, kuat)
                        if b then e = b end
                    end
                    tg.sasaran = e and (e.def and UnitDefs[e.def].name or "unit") or "-"
                    if utama and tg ~= utama and jarak2(x, z, uX, uZ) > 1000^2 and panasMusuh(x, z) < kuat then
                        tg.sasaran = "susul"
                        pindah(tg, uX, uZ, "susul" .. math.floor(uX / 128) .. ":" .. math.floor(uZ / 128))
                    elseif e then
                        serbuUnit(tg, e, "e" .. e.u)
                    else
                        local m = markasTerdekat(x, z)
                        if m then pindah(tg, m.x, m.z, "m" .. math.floor(m.x)) else pindah(tg, kumpulX, kumpulZ, "kumpul") end
                    end
                    -- Pertarungan kalah (panas musuh di posisi regu > kaburSerang x kekuatan): kabur, berkumpul ulang.
                    if t.kaburSerang and jarak2(x, z, bx, bz) > 1200^2 and panasMusuh(x, z) > kuat * t.kaburSerang then
                        tg.jenis, tg.awal, tg.sasaran = "defend", nil, "kabur"
                        pindah(tg, kumpulX, kumpulZ, "kumpul", CMD.MOVE)
                    end
                    -- Kalah telak (sisa < 25% kekuatan awal): kembali berkumpul.
                    if tg.awal and kuat < tg.awal * .25 and kuat < minSerang * .5 then tg.jenis, tg.awal = "defend", nil end
                elseif tg.jenis == "raid" then
                    if tg.kumpul then
                        if kuat >= raidMin then tg.kumpul = false else pindah(tg, kumpulX, kumpulZ, "rkumpul") end
                    end
                    -- Raid tinggal sisa: pulang berkumpul, digabung dengan raid lain.
                    if not tg.kumpul and kuat < raidMin * .5 then
                        tg.kumpul = true
                        pindah(tg, kumpulX, kumpulZ, "rkumpul", CMD.MOVE)
                    end
                    if not tg.kumpul then
                        local panasDiSini = panasMusuh(x, z)
                        local dekatRumah = jarak2(x, z, bx, bz) < 1200^2
                        if panasDiSini >= kuat * (dekatRumah and 2 or 1) then
                            tg.kumpul = true -- kabur
                            pindah(tg, kumpulX, kumpulZ, "rkumpul", CMD.MOVE)
                        else
                            local _, bangunan = c.otak.Ingatan()
                            local terbaik, d0
                            for u2, b in pairs(bangunan) do
                                if panasMusuh(b.x, b.z) < kuat then
                                    local w = (b.def == c.ekstraktor or b.def == c.pompa) and .5 or 1
                                    local d = jarak2(x, z, b.x, b.z) * w
                                    if not d0 or d < d0 then terbaik, d0 = {u = u2, x = b.x, z = b.z}, d end
                                end
                            end
                            if terbaik then serbuUnit(tg, terbaik, "r" .. terbaik.u)
                            else
                                local m = markasTerdekat(x, z)
                                if m then pindah(tg, m.x, m.z, "rm" .. math.floor(m.x)) end
                            end
                        end
                    end
                elseif tg.jenis == "scout" then
                    -- Intai markas musuh yang belum terlihat; kalau semua terlihat, keliling ke markas terjauh.
                    local tujuan
                    for _, m in ipairs(markasMusuh) do
                        if not tujuan and not m.hilang and not sp.IsPosInLos(m.x, 0, m.z, sekutu) then tujuan = m end
                    end
                    tujuan = tujuan or markasTerdekat(x, z)
                    if tujuan then pindah(tg, tujuan.x, tujuan.z, "s" .. math.floor(tujuan.x), CMD.MOVE) end
                end
            end
        end
        tugas = hidup
        -- Gabung tugas serang yang berdekatan (merge CircuitAI).
        for i = #tugas, 2, -1 do
            local a = tugas[i]
            for j = 1, i - 1 do
                local b = tugas[j]
                local sama = (a.jenis == "attack" and b.jenis == "attack") or (a.jenis == "raid" and b.jenis == "raid" and a.kumpul and b.kumpul)
                if sama then
                    local _, ax, az = kekuatan(a)
                    local _, bx2, bz2 = kekuatan(b)
                    if jarak2(ax, az, bx2, bz2) < 1000^2 or a.jenis == "raid" then
                        for u in pairs(a.anggota) do b.anggota[u], tugasUnit[u] = true, b end
                        table.remove(tugas, i)
                        break
                    end
                end
            end
        end
        local r = {}
        for _, tg in ipairs(tugas) do
            local n = 0
            for _ in pairs(tg.anggota) do n = n + 1 end
            r[#r + 1] = tg.jenis .. n .. (tg.jenis == "attack" and ("@" .. (tg.sasaran or "-")) or "")
        end
        o.laporan = "tugas=" .. table.concat(r, ",") .. " grupMusuh=" .. #grup .. string.format(" maxGrup=%.0f", maxGrup)
    end

    function o.Hancur(u) lepas(u) end
    return o
end

return M
