-- Garis depan AI (🟡 Claude 2026-11-25, disetujui user: "GASSSSSS"). Konsep dari C.R.A.I.G (AI Lua Spring:1944,
-- GPL v2, Tobi Vollebregt & Jose Luis Cercos-Pita) dibaca sebagai referensi lalu ditulis ulang untuk game ini:
-- - Grid sel 256 elmo di atas peta; sel dapat dilalui diuji dengan TestMoveOrder Medium Tank.
-- - Peta panas daya tembak: tiap unit tempur kita dan musuh yang diingat (LOS/radar) menyebar nilainya (biaya × sisa
--   HP) sejauh jangkauan senjatanya.
-- - Wilayah: pengaruh kita (unit, bangunan, titik milik) dikurangi pengaruh musuh. Garis depan = sel milik kita yang
--   bertetangga dengan sel bukan milik kita; arah normal menunjuk ke luar.
-- - Nilai strategis sel: 1 + jumlah bobot titik / jarak² (titik musuh dan netral lebih berbobot).
-- - Regu tempur menuju sel garis depan dengan nilai strategis / jarak² terbesar, maju satu sel searah normal, lalu
--   mundur sampai 3 sel kalau daya tembak musuh di sana melebihi ambang × kekuatan regu ("takut").
-- - Regu perebut (pengintai + sampai `perebut` unit tempur pertama) terpisah: masing-masing menuju titik bukan milik
--   kita yang terdekat dan belum dituju perebut lain; kalau semua titik milik kita, menjaga titik terdekat garis depan.
-- Perbandingan def lintas fraksi (bug 2026-11-28): AI F1 tidak mengenali HQ/pabrik F2 karena membandingkan dengan def
-- fraksinya sendiri. sama(a, b) benar kalau kedua def berpadanan (gamedata/fraksi.lua).
local dasarDef = VFS.Include("gamedata/fraksi.lua").dasar
local function sama(a, b) return a ~= nil and b ~= nil and dasarDef[a] == dasarDef[b] end
local sp = Spring
local M = {}
local S = 256
-- Rencana serbu markas per kubu (allyTeam), dipakai bersama semua AI sekutu dalam gadget yang sama.
local rencanaKubu = {}

function M.baru(c)
    -- c: {tim, tingkat, aturan, otak, pengintai, artileri, lontar, bx, bz (diisi Mulai), sekutu}
    local nx, nz = math.ceil(Game.mapSizeX / S), math.ceil(Game.mapSizeZ / S)
    local lewat
    local panasKita, panasMusuh, wilayah, relevan = {}, {}, {}, {}
    local depan = {} -- daftar {k, i, j, ni, nj}
    local perebut, tujuanRebut = {}, {}
    local tujuanUnit = {}
    local sekutu, bx, bz
    local hancur = c.aturan.mode == "hancur"
    local markasMusuh = {} -- Deathmatch: posisi awal markas musuh {x, z, t, hilang}
    local o = {}

    local function idx(i, j) return j * nx + i end
    local function pusat(i, j) return (i + .5) * S, (j + .5) * S end
    local function sel(x, z)
        return math.max(0, math.min(nx - 1, math.floor(x / S))), math.max(0, math.min(nz - 1, math.floor(z / S)))
    end
    local function nilaiUnit(u, def)
        local hp, maks = sp.GetUnitHealth(u)
        return UnitDefs[def].metalCost * ((hp and maks and maks > 0) and hp / maks or 1)
    end
    local function jangkau(def)
        return math.max(250, (UnitDefs[def].maxWeaponRange or 0)) + S * .5
    end
    local function sebar(t, x, z, n, r)
        local i0, j0 = sel(x - r, z - r)
        local i1, j1 = sel(x + r, z + r)
        for j = j0, j1 do
            for i = i0, i1 do
                local cx, cz = pusat(i, j)
                local d = math.sqrt((cx - x)^2 + (cz - z)^2)
                if d < r then
                    local k = idx(i, j)
                    t[k] = (t[k] or 0) + n * (1 - .5 * d / r)
                end
            end
        end
    end

    function o.Mulai(s, x, z)
        sekutu, bx, bz = s, x, z
        for _, t in ipairs(sp.GetTeamList()) do
            if t ~= sp.GetGaiaTeamID() and not sp.AreTeamsAllied(t, c.tim) then
                local ex, _, ez = sp.GetTeamStartPosition(t)
                if ex and ex >= 0 then markasMusuh[#markasMusuh + 1] = {x = ex, z = ez, t = t} end
            end
        end
    end

    local function siapkanGrid()
        lewat = {}
        local uji = UnitDefNames.medium_tank.id
        for j = 0, nz - 1 do
            for i = 0, nx - 1 do
                local x, z = pusat(i, j)
                lewat[idx(i, j)] = sp.TestMoveOrder(uji, x, sp.GetGroundHeight(x, z), z, 0, 0, 0, true, false) and true
            end
        end
    end

    local function pemilikTitik(t) return sp.GetGameRulesParam("titik_" .. t.nama .. "_pemilik") or -1 end

    -- Peta panas, wilayah, garis depan, nilai strategis. Dipanggil tiap 2 detik.
    function o.Amati(frame)
        if not lewat then siapkanGrid() end
        panasKita, panasMusuh = {}, {}
        local pengaruhKita, pengaruhMusuh = {}, {}
        for _, t in ipairs(sp.GetTeamList()) do
            if sp.AreTeamsAllied(t, c.tim) then
                for _, u in ipairs(sp.GetTeamUnits(t)) do
                    local def = sp.GetUnitDefID(u)
                    local x, _, z = sp.GetUnitPosition(u)
                    if c.tempurSet[def] then
                        local n = nilaiUnit(u, def)
                        sebar(panasKita, x, z, n, jangkau(def))
                        sebar(pengaruhKita, x, z, n, jangkau(def))
                    elseif UnitDefs[def].speed == 0 then
                        sebar(pengaruhKita, x, z, 300, 520)
                    end
                end
            end
        end
        local ingat, bangunan = c.otak.Ingatan()
        for _, m in pairs(ingat) do
            if frame - m.f < 30 * Game.gameSpeed then
                local r = jangkau(m.def or UnitDefNames.medium_tank.id)
                sebar(panasMusuh, m.x, m.z, m.n, r)
                sebar(pengaruhMusuh, m.x, m.z, m.n, r)
            end
        end
        for _, b in pairs(bangunan) do
            sebar(pengaruhMusuh, b.x, b.z, 300, 520)
            -- Bangunan bersenjata (menara pertahanan) ikut peta panas: regu kecil tidak bunuh diri ke pangkalan.
            local ud = UnitDefs[b.def]
            if ud.weapons and #ud.weapons > 0 then sebar(panasMusuh, b.x, b.z, ud.metalCost * 3, jangkau(b.def)) end
        end
        -- Markas awal musuh dicoret kalau posisinya terlihat dan tidak ada markas di ingatan dekat situ.
        for _, m in ipairs(markasMusuh) do
            if not m.hilang and sp.IsPosInLos(m.x, sp.GetGroundHeight(m.x, m.z), m.z, sekutu) then
                local ada = false
                for _, b in pairs(bangunan) do
                    if sama(b.def, c.hq) and (b.x - m.x)^2 + (b.z - m.z)^2 < 400^2 then ada = true end
                end
                if not ada then m.hilang = true end
            end
        end
        for _, t in ipairs(c.aturan.titik) do
            local p = pemilikTitik(t)
            if p == sekutu then sebar(pengaruhKita, t.x, t.z, 600, 420)
            elseif p >= 0 then sebar(pengaruhMusuh, t.x, t.z, 600, 420) end
        end
        sebar(pengaruhKita, bx, bz, 2000, 700) -- markas selalu wilayah kita

        for j = 0, nz - 1 do
            for i = 0, nx - 1 do
                local k = idx(i, j)
                wilayah[k] = (pengaruhKita[k] or 0) - (pengaruhMusuh[k] or 0)
                local x, z = pusat(i, j)
                local r = 1
                for _, t in ipairs(c.aturan.titik) do
                    local p = pemilikTitik(t)
                    local w = p == sekutu and .8 or (p == -1 and 1.3 or 1.6)
                    r = r + 4 * w * 300^2 / math.max((t.x - x)^2 + (t.z - z)^2, 300^2)
                end
                relevan[k] = r
            end
        end
        depan = {}
        for j = 0, nz - 1 do
            for i = 0, nx - 1 do
                local k = idx(i, j)
                if lewat[k] and wilayah[k] > 0 then
                    local ni, nj, ada = 0, 0, false
                    for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
                        local ii, jj = i + d[1], j + d[2]
                        if ii >= 0 and jj >= 0 and ii < nx and jj < nz then
                            local kk = idx(ii, jj)
                            if lewat[kk] and wilayah[kk] <= 0 then ni, nj, ada = ni + d[1], nj + d[2], true end
                        end
                    end
                    if ada then depan[#depan + 1] = {k = k, i = i, j = j, ni = ni, nj = nj} end
                end
            end
        end
    end

    local function langkah(i, j, di, dj)
        local ii, jj = i + (di > .35 and 1 or (di < -.35 and -1 or 0)), j + (dj > .35 and 1 or (dj < -.35 and -1 or 0))
        if ii >= 0 and jj >= 0 and ii < nx and jj < nz and lewat[idx(ii, jj)] then return ii, jj end
        return i, j
    end

    -- Sasaran regu dari pusat (x, z) berkekuatan `kuat`.
    local function sasaranRegu(x, z, kuat)
        local terbaik, skor
        for _, d in ipairs(depan) do
            local cx, cz = pusat(d.i, d.j)
            local s = relevan[d.k] / ((cx - x)^2 + (cz - z)^2 + 600^2)
            if not skor or s > skor then terbaik, skor = d, s end
        end
        if not terbaik then return nil end
        local p = math.max(.01, math.sqrt(terbaik.ni^2 + terbaik.nj^2))
        local ni, nj = terbaik.ni / p, terbaik.nj / p
        local i, j = langkah(terbaik.i, terbaik.j, ni, nj)
        local ambang = c.otak.Ambang()
        for _ = 1, 3 do
            local k = idx(i, j)
            if (panasMusuh[k] or 0) <= ambang * (kuat + .5 * (panasKita[k] or 0)) then break end
            i, j = langkah(i, j, -ni, -nj) -- takut: mundur ke arah wilayah sendiri
        end
        local cx, cz = pusat(i, j)
        -- Serbu titik: titik bukan milik kita dalam 2 sel dari sasaran, dan daya tembak musuh di titik itu jauh di bawah
        -- kekuatan regu. Tanpa ini regu berhenti di garis depan (titik musuh sendiri menahan garis depan).
        local ambangSerbu = ambang * 1.2
        for _, t in ipairs(c.aturan.titik) do
            if pemilikTitik(t) ~= sekutu and (t.x - cx)^2 + (t.z - cz)^2 < (2.2 * S)^2 then
                local ti, tj = sel(t.x, t.z)
                if (panasMusuh[idx(ti, tj)] or 0) * ambangSerbu <= kuat then return t.x, t.z, ni, nj end
            end
        end
        return cx, cz, ni, nj
    end

    -- Sasaran titik (dipakai lebih dulu; garis depan jadi cadangan). Garis depan murni terlalu lambat di peta besar
    -- (Verdant Ridge: titik 3.100 elmo dari markas, regu maju sel demi sel, kalah 0/6). Bobot: titik musuh 1,6,
    -- netral 1,3, milik sendiri yang ada musuh di sekitarnya 1,5; regu lain yang sudah menuju titik itu mengurangi
    -- nilainya supaya regu menyebar. Takut: titik terlalu panas -> berhenti 2–5 sel sebelum titik di jalurnya.
    local function sasaranTitik(x, z, kuat, dituju, lamaKunci)
        local ambang = c.otak.Ambang()
        local terbaik, skor
        for i, t in ipairs(c.aturan.titik) do
            local p = pemilikTitik(t)
            local ti, tj = sel(t.x, t.z)
            local panas = panasMusuh[idx(ti, tj)] or 0
            local w = p == sekutu and (panas > 0 and 1.5 or 0) or (p == -1 and 1.3 or 1.6)
            if w > 0 then
                local d = math.sqrt((t.x - x)^2 + (t.z - z)^2)
                -- Komitmen: sasaran yang sedang dituju +0,6 (dulu regu berbalik tiap titik berganti pemilik dan tidak
                -- pernah sampai: regu 29 unit menuju D lalu semenit kemudian ke B, 7 sel jauhnya).
                local kunciTitik = string.format("%d:%d", ti, tj)
                local s = w * 1500 / (d + 1500) - (dituju[i] or 0) * .1 + (kunciTitik == lamaKunci and .6 or 0)
                if not skor or s > skor then terbaik, skor = i, s end
            end
        end
        if not terbaik then return nil end
        dituju[terbaik] = (dituju[terbaik] or 0) + 1
        local t = c.aturan.titik[terbaik]
        local kunciPilih = string.format("%d:%d", sel(t.x, t.z))
        local dx, dz = t.x - x, t.z - z
        local p = math.max(1, math.sqrt(dx * dx + dz * dz))
        local ni, nj = dx / p, dz / p
        -- Aman: daya tembak musuh di sel itu <= ambang x (regu + unit sekutu di sel itu). Satu sel saja: panas tiap unit
        -- tersebar ke banyak sel, jadi menjumlah area 3x3 menghitung satu unit musuh sampai 9 kali (regu menunggu di
        -- luar titik walau unggul, terlihat di screenshot Verdant Ridge menit 10). Mode tekan: tidak takut.
        local function aman(px, pz)
            if c.otak.Mode() == "tekan" then return true end
            local k = idx(sel(px, pz))
            -- ×2: hadir di titik saja sudah membuatnya sengketa (skor musuh berhenti), jadi hanya mundur kalau jauh kalah.
            return (panasMusuh[k] or 0) <= 2 * ambang * (kuat + (panasKita[k] or 0))
        end
        -- Takut di titik dimatikan kecuali profil `takutTitik`: di 4v4 empat tim Brutal menunggu di titik tunggu yang
        -- berbeda-beda sehingga kekuatannya tidak pernah terjumlah, sementara Normal (tanpa takut) menang.
        if c.tingkat.takutTitik and not aman(t.x, t.z) then
            for _, n in ipairs({2, 3, 4}) do
                local sx, sz = t.x - ni * n * S, t.z - nj * n * S
                if lewat[idx(sel(sx, sz))] and aman(sx, sz) then return sx, sz, ni, nj, kunciPilih end
            end
            for n = 5, 9 do
                local sx, sz = t.x - ni * n * S, t.z - nj * n * S
                if lewat[idx(sel(sx, sz))] then return sx, sz, ni, nj, kunciPilih end
            end
            return t.x, t.z, ni, nj, kunciPilih
        end
        return t.x, t.z, ni, nj, kunciPilih
    end

    -- Perebut: titik bukan milik kita terdekat yang belum dituju perebut lain (netral lebih dekat dihitung).
    -- Deathmatch: sasaran regu dari bangunan musuh yang diingat dan posisi awal markas musuh. Bobot markas 1,4
    -- (2,2 saat mode tekan; markas habis = menang), pabrik 1,2, ekstraktor/pompa 1,0, lainnya 0,7, dikali dendam ke
    -- pemiliknya. Komitmen +0,6. Takut aktif: sasaran terlalu panas -> tunggu 2–4 sel sebelum sasaran.
    -- Lebih dekat ke markas sendiri daripada ke markas musuh mana pun.
    local function dekatRumah(x, z)
        local d = (x - bx)^2 + (z - bz)^2
        for _, m in ipairs(markasMusuh) do
            if (x - m.x)^2 + (z - m.z)^2 < d then return false end
        end
        return true
    end

    -- Ladang besi di luar separuh sendiri tanpa ekstraktor sendiri/sekutu dan tanpa bangunan musuh yang diingat.
    local ladangCache, ladangFrame = {}, -999
    local function ladangKosong()
        local f = sp.GetGameFrame()
        if f - ladangFrame < 90 then return ladangCache end
        ladangFrame, ladangCache = f, {}
        local _, bangunan = c.otak.Ingatan()
        for _, l in ipairs(c.aturan.ladang or {}) do
            if not dekatRumah(l[1], l[2]) then
                local isi = false
                for _, u in ipairs(sp.GetUnitsInCylinder(l[1], l[2], 60)) do
                    if sp.GetUnitDefID(u) == c.ekstraktor and sp.AreTeamsAllied(sp.GetUnitTeam(u), c.tim) then isi = true end
                end
                for _, b in pairs(bangunan) do
                    if (b.x - l[1])^2 + (b.z - l[2])^2 < 80^2 then isi = true end
                end
                if not isi then ladangCache[#ladangCache + 1] = l end
            end
        end
        return ladangCache
    end

    -- Batas tunggu (bug user 2026-11-28, Limestone Valley Deathmatch: "mereka berkumpul tanpa tujuan jelas"). Regu yang
    -- takut (menunggu di depan sasaran panas) atau menahan garis di depan musuh tidak punya batas waktu, jadi dua pihak
    -- bisa saling menunggu selamanya (uji 2026-11-28: satu laga buntu 30 menit). 🟡 Kalau sasaran yang sama ditunggu
    -- lebih dari 45 detik, regu menuju sasaran itu nekat menyerang selama 30 detik tanpa takut dan tanpa menahan garis.
    local TUNGGU_MAKS, NEKAT_LAMA = 45 * Game.gameSpeed, 30 * Game.gameSpeed
    local tungguSejak, nekatSampai = {}, {}
    local function nekat(kunci)
        return kunci ~= nil and (nekatSampai[kunci] or -1) > sp.GetGameFrame()
    end
    local function catatTunggu(kunci, menunggu)
        local f = sp.GetGameFrame()
        if not menunggu then
            tungguSejak[kunci] = nil
            return
        end
        tungguSejak[kunci] = tungguSejak[kunci] or f
        if f - tungguSejak[kunci] > TUNGGU_MAKS then
            nekatSampai[kunci], tungguSejak[kunci] = f + NEKAT_LAMA, nil
        end
    end

    local ladangSejak, ladangLarang = {}, {}
    local function sasaranBangunan(x, z, kuat, dituju, lamaKunci)
        local _, bangunan = c.otak.Ingatan()
        local tekan = c.otak.Mode() == "tekan"
        local calon = {}
        for u, b in pairs(bangunan) do
            local w = sama(b.def, c.hq) and (tekan and 2.2 or 1.4)
                or ((sama(b.def, c.pabrik) or sama(b.def, c.pabrikRobot)) and 1.2)
                or (sama(b.def, c.ekstraktor) and 1.6) or (sama(b.def, c.pompa) and 1.0) or .7
            calon[#calon + 1] = {x = b.x, z = b.z, w = w * c.otak.BobotDendam(b.t), unit = u}
        end
        -- Incar sumber mineral (keputusan user 2026-11-26: "buat ai itu mengincar sumber mineral"): ekstraktor musuh
        -- 1,6 (di atas pabrik dan markas kecuali mode tekan), ladang besi kosong 0,9 supaya regu mengamankannya untuk
        -- insinyur (ekspansi Deathmatch di lawan_skenario boleh melewati separuh peta sendiri).
        local f = sp.GetGameFrame()
        for _, l in ipairs(ladangKosong()) do
            local kk = string.format("%d:%d", sel(l[1], l[2]))
            if (ladangLarang[kk] or -1) < f then calon[#calon + 1] = {x = l[1], z = l[2], w = .9, ladang = kk} end
        end
        for _, m in ipairs(markasMusuh) do
            if not m.hilang then
                local sudah = false
                for _, k in ipairs(calon) do if (k.x - m.x)^2 + (k.z - m.z)^2 < 400^2 then sudah = true end end
                if not sudah then
                    calon[#calon + 1] = {x = m.x, z = m.z, w = (tekan and 2.2 or 1.4) * c.otak.BobotDendam(m.t)}
                end
            end
        end
        local terbaik, skor
        for _, k in ipairs(calon) do
            k.kunci = string.format("%d:%d", sel(k.x, k.z))
            local d = math.sqrt((k.x - x)^2 + (k.z - z)^2)
            local s = k.w * 1500 / (d + 1500) - (dituju[k.kunci] or 0) * .1 + (k.kunci == lamaKunci and .6 or 0)
            if not skor or s > skor then terbaik, skor = k, s end
        end
        if not terbaik then return nil end
        -- Ladang kosong yang sudah dijaga regu > 40 detik (insinyur tidak datang) dicoret 2 menit, supaya regu tidak
        -- parkir di ladang selamanya (uji Limestone 2026-11-28: 29 unit diam di satu ladang dari menit 27 sampai 35).
        if terbaik.ladang then
            local kk = terbaik.ladang
            if (terbaik.x - x)^2 + (terbaik.z - z)^2 < 300^2 then
                ladangSejak[kk] = ladangSejak[kk] or f
                if f - ladangSejak[kk] > 40 * Game.gameSpeed then
                    ladangLarang[kk], ladangSejak[kk] = f + 120 * Game.gameSpeed, nil
                end
            else
                ladangSejak[kk] = nil
            end
        end
        dituju[terbaik.kunci] = (dituju[terbaik.kunci] or 0) + 1
        local dx, dz = terbaik.x - x, terbaik.z - z
        local p = math.max(1, math.sqrt(dx * dx + dz * dz))
        local ni, nj = dx / p, dz / p
        local ambang = c.otak.Ambang()
        local function aman(px, pz)
            if tekan then return true end
            local k = idx(sel(px, pz))
            return (panasMusuh[k] or 0) <= ambang * (kuat + (panasKita[k] or 0))
        end
        if not nekat(terbaik.kunci) and not aman(terbaik.x, terbaik.z) then
            for _, n in ipairs({2, 3, 4}) do
                local sx, sz = terbaik.x - ni * n * S, terbaik.z - nj * n * S
                if lewat[idx(sel(sx, sz))] and aman(sx, sz) then return sx, sz, ni, nj, terbaik.kunci, nil, true end
            end
            for n = 5, 9 do
                local sx, sz = terbaik.x - ni * n * S, terbaik.z - nj * n * S
                if lewat[idx(sel(sx, sz))] then return sx, sz, ni, nj, terbaik.kunci, nil, true end
            end
            -- Tidak ada sel tunggu yang bisa dilalui: maju ke sasaran (diam di tempat dulu membuat 4v4 berakhir seri).
            local depan = math.min(p, 160)
            return terbaik.x - ni * depan, terbaik.z - nj * depan, ni, nj, terbaik.kunci, terbaik.unit
        end
        -- Bangunan yang diketahui ID-nya diserang langsung (CMD.ATTACK) saat regu dekat; titik tujuan di depan bangunan
        -- (bukan di tengah tapaknya yang tidak bisa dicapai: dulu 50 unit nyangkut 500 elmo dari markas musuh).
        local depan = math.min(p, 160)
        return terbaik.x - ni * depan, terbaik.z - nj * depan, ni, nj, terbaik.kunci, terbaik.unit
    end

    -- Deathmatch: perebut menjadi perampok. Sasaran: ekstraktor/pompa musuh yang diingat dengan panas musuh rendah
    -- (paling banyak 2 perampok per sasaran); kalau tidak ada, mengintai posisi markas musuh yang belum terlihat.
    local function urusPerampok(unit)
        local x, _, z = sp.GetUnitPosition(unit)
        local _, bangunan, pekerja = c.otak.Ingatan()
        -- Serangan ganggu (keputusan user 2026-11-26: "menghancurkan mineral musuh atau menghambat pembangunan musuh").
        -- Faktor jarak (kecil = didahulukan): bangunan musuh yang masih dibangun .15, insinyur musuh .2, ekstraktor .25,
        -- pompa 1, lainnya tidak. Hanya sasaran dengan panas musuh < 300, paling banyak 2 perampok per sasaran.
        local terbaik, d0, tb
        local function nilai(u, b, faktor)
            if (tujuanRebut[u] or 0) >= 2 then return end
            if (panasMusuh[idx(sel(b.x, b.z))] or 0) >= 300 then return end
            local d = ((b.x - x)^2 + (b.z - z)^2) * faktor
            if not d0 or d < d0 then terbaik, d0, tb = u, d, b end
        end
        for u, b in pairs(bangunan) do
            if b.dibangun then nilai(u, b, .15)
            elseif sama(b.def, c.ekstraktor) then nilai(u, b, .25)
            elseif sama(b.def, c.pompa) then nilai(u, b, 1) end
        end
        for u, b in pairs(pekerja or {}) do nilai(u, b, .2) end
        local tx, tz, kunci
        if terbaik then
            tujuanRebut[terbaik] = (tujuanRebut[terbaik] or 0) + 1
            tx, tz, kunci = tb.x, tb.z, "p" .. terbaik
        end
        if not tx then
            -- Tidak ada tambang musuh yang diketahui: intai ladang besi di luar separuh sendiri yang tidak terlihat.
            for i, l in ipairs(c.aturan.ladang or {}) do
                if not tx and (tujuanRebut["l" .. i] or 0) < 1 and not dekatRumah(l[1], l[2])
                    and not sp.IsPosInLos(l[1], sp.GetGroundHeight(l[1], l[2]), l[2], sekutu) then
                    tujuanRebut["l" .. i] = 1
                    tx, tz, kunci = l[1], l[2], "l" .. i
                end
            end
        end
        if not tx then
            for i, m in ipairs(markasMusuh) do
                if not m.hilang and not tx then tx, tz, kunci = m.x, m.z, "i" .. i end
            end
        end
        if not tx then return end
        local lama = tujuanUnit[unit]
        if not lama or lama.k ~= kunci or sp.GetUnitCommandCount(unit) == 0 then
            sp.GiveOrderToUnit(unit, CMD.FIGHT, {tx, sp.GetGroundHeight(tx, tz), tz}, 0)
            tujuanUnit[unit] = {k = kunci}
        end
    end

    local function urusPerebut(unit)
        local x, _, z = sp.GetUnitPosition(unit)
        local terbaik, jarak0
        for i, t in ipairs(c.aturan.titik) do
            local p = pemilikTitik(t)
            -- Berpasangan: paling banyak 2 perebut per titik (perebut tunggal kalah duel dengan pasangan Normal).
            if p ~= sekutu and (tujuanRebut[i] or 0) < 2 then
                local d = math.sqrt((t.x - x)^2 + (t.z - z)^2) * (p == -1 and 1 or 1.4)
                if not jarak0 or d < jarak0 then terbaik, jarak0 = i, d end
            end
        end
        if not terbaik then
            -- Semua titik milik kita / sudah dituju: jaga titik milik kita yang paling dekat musuh (wilayah terkecil).
            local w0
            for i, t in ipairs(c.aturan.titik) do
                local ii, jj = sel(t.x, t.z)
                local w = wilayah[idx(ii, jj)] or 0
                if pemilikTitik(t) == sekutu and (not w0 or w < w0) then terbaik, w0 = i, w end
            end
        end
        if not terbaik then return end
        tujuanRebut[terbaik] = (tujuanRebut[terbaik] or 0) + 1
        local t = c.aturan.titik[terbaik]
        local lama = tujuanUnit[unit]
        if not lama or lama.k ~= "r" .. terbaik or sp.GetUnitCommandCount(unit) == 0 then
            sp.GiveOrderToUnit(unit, CMD.FIGHT, {t.x, sp.GetGroundHeight(t.x, t.z), t.z}, 0)
            tujuanUnit[unit] = {k = "r" .. terbaik}
        end
    end

    -- Mode serang Deathmatch (keputusan user 2026-11-26: AI memutuskan kapan menyerang dalam grup atau acak/ganggu).
    -- - grup: kekuatan kita >= 1,15x musuh yang diingat, atau mode tekan. Perampok = profil `perebut`.
    -- - ganggu: kita < 0,85x musuh, atau tentara utama musuh (gugus terbesar, terlihat/radar) sedang di separuh peta
    --   kita sehingga ekonominya terbuka. Sampai separuh unit cepat menjadi perampok yang menyebar ke tambang,
    --   insinyur, dan bangunan musuh yang sedang dibangun; regu utama bertahan.
    -- Rencana dari radar: gugus musuh (kontak radar maupun terlihat) bernilai >= 250 di separuh kita = peringatan dini,
    -- regu dalam 1500 elmo bergerak mencegat sebelum bangunan diserang.
    local cepat = {}
    for _, n in ipairs({"pengintai", "tank_ringan", "robot_infanteri"}) do
        for id, ud in pairs(UnitDefs) do
            if (ud.customParams.dasar or ud.name) == n then cepat[id] = true end
        end
    end
    local modeSerang = "grup"
    local gantiMode = -99999
    local function rencanaSerang(pasukan, frame)
        local ingat = c.otak.Ingatan()
        local gugus = {}
        for _, m in pairs(ingat) do
            if frame - m.f < 6 * Game.gameSpeed then
                local k = string.format("%d:%d", math.floor(m.x / (2 * S)), math.floor(m.z / (2 * S)))
                local g = gugus[k] or {x = 0, z = 0, n = 0, radar = 0}
                g.x, g.z, g.n = g.x + m.x * m.n, g.z + m.z * m.n, g.n + m.n
                if m.radar then g.radar = g.radar + 1 end
                gugus[k] = g
            end
        end
        local besar, peringatan
        for _, g in pairs(gugus) do
            g.x, g.z = g.x / math.max(1, g.n), g.z / math.max(1, g.n)
            if not besar or g.n > besar.n then besar = g end
            if g.n >= 250 and dekatRumah(g.x, g.z) and (not peringatan or g.n > peringatan.n) then peringatan = g end
        end
        local kita, musuh = c.otak.Kekuatan()
        -- Belum ada musuh terlihat (awal ronde): anggap unggul, jangan langsung ganggu.
        local rasio = musuh < 50 and 2 or kita / musuh
        local musuhKeluar = besar and besar.n >= 400 and dekatRumah(besar.x, besar.z)
        local baru = modeSerang
        if c.otak.Mode() == "tekan" then baru = "grup"
        elseif rasio < .85 or musuhKeluar then baru = "ganggu"
        elseif rasio > 1.15 then baru = "grup" end
        -- Jeda 30 detik antar-ganti supaya perampok tidak bolak-balik.
        if baru ~= modeSerang and frame - gantiMode > 30 * Game.gameSpeed then
            modeSerang, gantiMode = baru, frame
            sp.Echo(string.format("AI tim %d: mode serang %s (kita %.0f, musuh %.0f%s)", c.tim, baru, kita, musuh,
                musuhKeluar and ", tentara musuh di wilayah kita" or ""))
        end
        local kuota = c.tingkat.perebut or 4
        if modeSerang == "ganggu" then
            local nCepat = 0
            for _, u in ipairs(pasukan) do if cepat[sp.GetUnitDefID(u)] then nCepat = nCepat + 1 end end
            kuota = math.max(kuota, math.floor(nCepat * .5))
        end
        return kuota, peringatan and {x = peringatan.x, z = peringatan.z}
    end

    function o.Panas(x, z) return panasMusuh[idx(sel(x, z))] or 0 end

    function o.Hancur(unit)
        perebut[unit], tujuanUnit[unit] = nil, nil
    end

    -- pasukan: unit tempur yang sudah dilepas (tidak sedang mundur). bela: {x, z} bangunan diserang (berbobot).
    -- ===== Rencana serbu markas (Deathmatch) =====
    -- User 2026-11-28 (✅): "cek referrensi biar AI punya rencana nyerang base". Pola dari CircuitAI (BARb,
    -- src/circuit/module/MilitaryManager.cpp dan task/fighter/AttackTask.cpp, dibaca sebagai referensi): regu serang
    -- minimal 8 unit, kumpul ulang dengan batas 60 detik, sasaran = kelompok musuh yang paling lemah dibobot jarak,
    -- kekuatan regu dibandingkan pengaruh musuh di sasaran. 🟡 Tambahan sendiri karena CircuitAI tidak menjamin
    -- serbuan ke markas:
    -- - Eskalasi waktu: syarat kekuatan kubu / panas pertahanan markas sasaran turun dari 1,6 (menit 8) ke 0,7
    --   (menit 26), jadi kubu yang imbang tetap menyerbu.
    -- - Koordinasi: semua AI satu kubu memakai satu rencana (rencanaKubu[allyTeam]); 80% pasukan tempur tiap tim ikut.
    -- - Fase: siap -> kumpul (titik ±1 km di depan markas sasaran; serbu saat 70% hadir atau 60 detik) -> serbu
    --   (CMD.ATTACK ke HQ, tanpa takut dan tanpa tahan garis) -> pulih 60 detik kalau kekuatan < 40%.
--   Batas kumpul mengikuti jarak tempuh (60-240 detik).
    local MENIT = 60 * Game.gameSpeed
    local function panasDi(x, z, r)
        local n = 0
        local i0, j0 = sel(x - r, z - r)
        local i1, j1 = sel(x + r, z + r)
        for j = j0, j1 do for i = i0, i1 do n = n + (panasMusuh[idx(i, j)] or 0) end end
        return n
    end
    local function kekuatanKubu()
        local n, jumlah = 0, 0
        for _, t in ipairs(sp.GetTeamList()) do
            if sp.AreTeamsAllied(t, c.tim) then
                for _, u in ipairs(sp.GetTeamUnits(t)) do
                    local def = sp.GetUnitDefID(u)
                    if c.tempurSet[def] and not sp.GetUnitIsBeingBuilt(u) then
                        n, jumlah = n + nilaiUnit(u, def), jumlah + 1
                    end
                end
            end
        end
        return n, jumlah
    end
    local function markasHidup(r)
        if r.unit then return sp.ValidUnitID(r.unit) and not sp.GetUnitIsDead(r.unit) end
        for _, m in ipairs(markasMusuh) do
            if m.x == r.x and m.z == r.z then return not m.hilang end
        end
        return false
    end
    -- Markas musuh paling lemah dan dekat: HQ yang diingat, atau posisi awal markas yang belum dicoret.
    local function pilihMarkas()
        local _, bangunan = c.otak.Ingatan()
        local calon = {}
        for u, b in pairs(bangunan) do
            if sama(b.def, c.hq) then calon[#calon + 1] = {x = b.x, z = b.z, unit = u} end
        end
        for _, m in ipairs(markasMusuh) do
            if not m.hilang then
                local ada = false
                for _, k in ipairs(calon) do if (k.x - m.x)^2 + (k.z - m.z)^2 < 600^2 then ada = true end end
                if not ada then calon[#calon + 1] = {x = m.x, z = m.z} end
            end
        end
        local terbaik, skor
        for _, k in ipairs(calon) do
            local d = math.sqrt((k.x - bx)^2 + (k.z - bz)^2)
            local s = d + 2 * panasDi(k.x, k.z, 2 * S)
            if not skor or s < skor then terbaik, skor = k, s end
        end
        return terbaik
    end
    local function titikKumpul(t)
        local dx, dz = t.x - bx, t.z - bz
        local p = math.max(1, math.sqrt(dx * dx + dz * dz))
        for _, mundur in ipairs({1000, 1200, 800, 1400, 600}) do
            local m = math.min(mundur, p * .6)
            local x, z = t.x - dx / p * m, t.z - dz / p * m
            if lewat[idx(sel(x, z))] then return x, z end
        end
        local m = math.min(1000, p * .6)
        return t.x - dx / p * m, t.z - dz / p * m
    end
    local function urusRencana(frame)
        local r = rencanaKubu[sekutu]
        if not r then
            r = {fase = "siap", anggota = {}}
            rencanaKubu[sekutu] = r
        end
        if r.frame == frame then return r end
        r.frame = frame
        local kuat, jumlah = kekuatanKubu()
        if r.fase == "siap" then
            local menit = frame / MENIT
            local syarat = math.max(.7, 1.6 - math.max(0, menit - 8) * .05)
            if menit >= 6 and jumlah >= 8 then
                local t = pilihMarkas()
                if t and kuat >= syarat * math.max(300, panasDi(t.x, t.z, 2 * S)) then
                    r.x, r.z, r.unit = t.x, t.z, t.unit
                    r.kx, r.kz = titikKumpul(t)
                    r.fase, r.mulai, r.anggota = "kumpul", frame, {}
                    -- Batas kumpul = perkiraan waktu tempuh (5 m/detik) x 1,3, 60-240 detik. Batas tetap 60 detik dari
                    -- CircuitAI terlalu pendek untuk peta 12 km (uji Limestone: serbu dengan 0 unit di titik kumpul).
                    local jarak = math.sqrt((r.kx - bx)^2 + (r.kz - bz)^2)
                    r.batasKumpul = math.max(MENIT, math.min(4 * MENIT, jarak / 40 * 1.3 * Game.gameSpeed))
                    sp.Echo(string.format("AI kubu %d: rencana serbu markas (%d, %d), kekuatan %.0f, syarat %.2f",
                        sekutu, r.x, r.z, kuat, syarat))
                end
            end
        elseif r.fase == "kumpul" or r.fase == "serbu" then
            if not markasHidup(r) then
                -- Sasaran hancur: langsung ke markas berikutnya, tetap menyerbu.
                local t = pilihMarkas()
                if t then
                    r.x, r.z, r.unit = t.x, t.z, t.unit
                    r.kx, r.kz = titikKumpul(t)
                else
                    r.fase = "siap"
                    return r
                end
            end
            local n, dekat, kuatAnggota = 0, 0, 0
            for u in pairs(r.anggota) do
                if sp.ValidUnitID(u) and not sp.GetUnitIsDead(u) then
                    local x, _, z = sp.GetUnitPosition(u)
                    n = n + 1
                    kuatAnggota = kuatAnggota + nilaiUnit(u, sp.GetUnitDefID(u))
                    if (x - r.kx)^2 + (z - r.kz)^2 < 600^2 then dekat = dekat + 1 end
                else
                    r.anggota[u] = nil
                end
            end
            if r.fase == "kumpul" and n > 0 and (dekat >= .7 * n or frame - r.mulai > (r.batasKumpul or MENIT)) then
                r.fase, r.kuatAwal = "serbu", kuatAnggota
                sp.Echo(string.format("AI kubu %d: serbu markas, %d unit (%d di titik kumpul)", sekutu, n, dekat))
            elseif r.fase == "serbu" and kuatAnggota < .4 * (r.kuatAwal or 0) then
                r.fase, r.sampai, r.anggota = "pulih", frame + MENIT, {}
                sp.Echo(string.format("AI kubu %d: serbuan gagal, pulih 60 detik", sekutu))
            end
        elseif r.fase == "pulih" and frame >= r.sampai then
            r.fase = "siap"
        end
        return r
    end
    -- Ambil 80% unit tempur tim ini untuk rencana; sisanya kembali ke logika regu biasa.
    local function ikutRencana(tempur, frame, bela)
        local r = urusRencana(frame)
        if r.fase ~= "kumpul" and r.fase ~= "serbu" then return tempur end
        if bela and r.fase == "kumpul" and (bela.x - bx)^2 + (bela.z - bz)^2 < 900^2 then return tempur end
        local sisa, milik = {}, {}
        for _, u in ipairs(tempur) do
            if r.anggota[u] then milik[#milik + 1] = u else sisa[#sisa + 1] = u end
        end
        local target = math.floor(#tempur * .8 + .5)
        while #milik < target and #sisa > 0 do
            local u = table.remove(sisa)
            r.anggota[u] = true
            milik[#milik + 1] = u
        end
        local dx, dz = r.x - bx, r.z - bz
        local p = math.max(1, math.sqrt(dx * dx + dz * dz))
        for n, u in ipairs(milik) do
            local lama = tujuanUnit[u]
            local geser = ((n - 1) % 7 - 3) * 60
            local gx, gz = -dz / p * geser, dx / p * geser
            if r.fase == "kumpul" then
                local k = "kumpul" .. r.mulai
                if not lama or lama.k ~= k or sp.GetUnitCommandCount(u) == 0 then
                    local x, z = r.kx + gx, r.kz + gz
                    sp.GiveOrderToUnit(u, CMD.FIGHT, {x, sp.GetGroundHeight(x, z), z}, 0)
                    tujuanUnit[u] = {k = k, cmd = CMD.FIGHT}
                end
            else
                local k = string.format("serbu%d:%d", r.x, r.z)
                if not lama or lama.k ~= k or sp.GetUnitCommandCount(u) == 0 then
                    if r.unit and sp.ValidUnitID(r.unit) then
                        sp.GiveOrderToUnit(u, CMD.ATTACK, {r.unit}, 0)
                    else
                        local x, z = r.x + gx, r.z + gz
                        sp.GiveOrderToUnit(u, CMD.FIGHT, {x, sp.GetGroundHeight(x, z), z}, 0)
                    end
                    tujuanUnit[u] = {k = k, cmd = CMD.ATTACK}
                end
            end
        end
        return sisa
    end
    function o.Rencana() local r = rencanaKubu[sekutu] return r and r.fase or "-" end

    function o.Perintah(pasukan, frame, bela)
        if not lewat then return end
        tujuanRebut = {}
        local kuotaPerebut = c.tingkat.perebut or 4
        local peringatan
        if hancur then
            kuotaPerebut, peringatan = rencanaSerang(pasukan, frame)
            -- Mode grup: perampok berlebih (sisa mode ganggu) kembali ke regu, pengintai tetap perampok.
            local n = 0
            for u in pairs(perebut) do
                if sp.ValidUnitID(u) then
                    n = n + 1
                    if n > kuotaPerebut and sp.GetUnitDefID(u) ~= c.pengintai then perebut[u], tujuanUnit[u] = nil, nil end
                end
            end
        end
        local jumlahPerebut = 0
        for u in pairs(perebut) do
            if sp.ValidUnitID(u) then jumlahPerebut = jumlahPerebut + 1 else o.Hancur(u) end
        end
        if bela == nil and peringatan then bela = peringatan end
        local tempur = {}
        -- Mode ganggu memilih unit cepat dulu (pengintai, tank ringan, robot infanteri).
        local urut = pasukan
        if modeSerang == "ganggu" then
            urut = {}
            for _, u in ipairs(pasukan) do if cepat[sp.GetUnitDefID(u)] then urut[#urut + 1] = u end end
            for _, u in ipairs(pasukan) do if not cepat[sp.GetUnitDefID(u)] then urut[#urut + 1] = u end end
        end
        for _, u in ipairs(urut) do
            local def = sp.GetUnitDefID(u)
            local boleh = modeSerang ~= "ganggu" or cepat[def]
            if not perebut[u] and def ~= c.artileri and boleh and (def == c.pengintai or jumlahPerebut < kuotaPerebut) then
                perebut[u] = true
                jumlahPerebut = jumlahPerebut + 1
            end
            if perebut[u] then
                if hancur then urusPerampok(u) else urusPerebut(u) end
            else tempur[#tempur + 1] = u end
        end

        if hancur then tempur = ikutRencana(tempur, frame, bela) end
        -- Regu: unit yang menuju sasaran sama (kunci sel) dihitung bersama; unit baru membentuk regu sendiri.
        local regu, dituju = {}, {}
        for _, u in ipairs(tempur) do
            local lama = tujuanUnit[u]
            local kunci = lama and lama.k or "baru"
            regu[kunci] = regu[kunci] or {}
            table.insert(regu[kunci], u)
        end
        for kunciRegu, anggota in pairs(regu) do
            local x, z, kuat = 0, 0, 0
            for _, u in ipairs(anggota) do
                local ux, _, uz = sp.GetUnitPosition(u)
                local n = nilaiUnit(u, sp.GetUnitDefID(u))
                x, z, kuat = x + ux * n, z + uz * n, kuat + n
            end
            x, z = x / kuat, z / kuat
            local tx, tz, ni, nj, kunciT, sasaranUnit, menunggu
            if bela and (bela.x - x)^2 + (bela.z - z)^2 < 1500^2 then
                tx, tz, ni, nj = bela.x, bela.z, 0, 0
            else
                if hancur then
                    tx, tz, ni, nj, kunciT, sasaranUnit, menunggu = sasaranBangunan(x, z, kuat, dituju, kunciRegu)
                else
                    tx, tz, ni, nj, kunciT = sasaranTitik(x, z, kuat, dituju, kunciRegu)
                end
                if not tx then tx, tz, ni, nj = sasaranRegu(x, z, kuat) end
            end
            -- Deathmatch: kontak dengan tentara musuh -> tahan di jarak tembak (±85% jangkauan terpendek regu) dan bentuk
            -- barisan menghadap musuh, kecuali regu jauh lebih kuat (> 2x panas musuh di sana). Bangunan baru diserang
            -- langsung setelah tidak ada tentara musuh di dekat regu.
            local tahan
            if hancur and tx and not nekat(kunciT) and (sp.GetModOptions().ai_tahan or "1") ~= "0" then
                local ingat = c.otak.Ingatan()
                local e, de
                for _, m in pairs(ingat) do
                    if frame - m.f < 5 * Game.gameSpeed then
                        local d = (m.x - x)^2 + (m.z - z)^2
                        if not de or d < de then e, de = m, d end
                    end
                end
                local jangkau = math.huge
                for _, u in ipairs(anggota) do
                    local def = sp.GetUnitDefID(u)
                    if def ~= c.artileri then jangkau = math.min(jangkau, UnitDefs[def].maxWeaponRange or 300) end
                end
                if jangkau == math.huge then jangkau = 300 end
                if e and de < (jangkau + 350)^2 then
                    sasaranUnit = nil
                    if kuat < 2 * (panasMusuh[idx(sel(e.x, e.z))] or 0) then
                        local dx, dz = x - e.x, z - e.z
                        local p = math.max(1, math.sqrt(dx * dx + dz * dz))
                        local r = jangkau * .85
                        tx, tz, ni, nj = e.x + dx / p * r, e.z + dz / p * r, -dx / p, -dz / p
                        tahan = string.format("tahan%d:%d", math.floor(tx / S), math.floor(tz / S))
                    end
                end
            end
            if hancur and kunciT then catatTunggu(kunciT, menunggu or tahan ~= nil) end
            if tx then
                -- Kunci regu = sel titik tujuan (juga saat menunggu di titik tunggu), supaya komitmen tidak hilang.
                local kunci = tahan or kunciT or string.format("%d:%d", math.floor(tx / S), math.floor(tz / S))
                -- Barisan melebar tegak lurus normal (±150 elmo), artileri di belakang sejauh jarak minimum.
                local tgx, tgz = -nj, ni
                for n, u in ipairs(anggota) do
                    local lama = tujuanUnit[u]
                    -- Di titik: rapat ±60 elmo supaya semua unit di dalam radius rebut (88); di garis depan ±150.
                    local diTitik = false
                    for _, t in ipairs(c.aturan.titik) do
                        if (t.x - tx)^2 + (t.z - tz)^2 < 40^2 then diTitik = true end
                    end
                    local geser = ((n - 1) % 5 - 2) * (diTitik and 30 or 75)
                    local ux, uz = tx + tgx * geser, tz + tgz * geser
                    if sp.GetUnitDefID(u) == c.artileri then
                        local mundur = c.lontar.jarakMin + 104
                        ux, uz = ux - ni * mundur, uz - nj * mundur
                    end
                    -- Masuk titik: dalam 450 elmo dari titik pakai MOVE (tetap menembak sambil jalan). Dengan FIGHT unit
                    -- berhenti menembak dari luar radius dan tidak pernah menduduki titik (log: 0 unit di dalam radius).
                    local px, _, pz = sp.GetUnitPosition(u)
                    local masuk = diTitik and sp.GetUnitDefID(u) ~= c.artileri and (px - tx)^2 + (pz - tz)^2 < 450^2
                    local cmd = masuk and CMD.MOVE or CMD.FIGHT
                    local serang = sasaranUnit and sp.ValidUnitID(sasaranUnit) and (px - tx)^2 + (pz - tz)^2 < 900^2
                    if serang then cmd = CMD.ATTACK end
                    if not lama or lama.k ~= kunci or lama.cmd ~= cmd or sp.GetUnitCommandCount(u) == 0 then
                        if serang then
                            sp.GiveOrderToUnit(u, CMD.ATTACK, {sasaranUnit}, 0)
                        else
                            sp.GiveOrderToUnit(u, cmd, {ux, sp.GetGroundHeight(ux, uz), uz}, 0)
                        end
                        tujuanUnit[u] = {k = kunci, cmd = cmd}
                    end
                end
            end
        end
        local ringkas = {}
        for kunci, anggota in pairs(regu) do
            local dalam, diam, jauh, cx, cz = 0, 0, 0, 0, 0
            for _, u in ipairs(anggota) do
                local ux, _, uz = sp.GetUnitPosition(u)
                cx, cz = cx + ux / #anggota, cz + uz / #anggota
                local dekat = math.huge -- Deathmatch: tidak ada titik
                for _, t in ipairs(c.aturan.titik) do
                    local d = (ux - t.x)^2 + (uz - t.z)^2
                    if not dekat or d < dekat then dekat = d end
                end
                if dekat < (c.aturan.radius or 88)^2 then dalam = dalam + 1 elseif dekat < 400^2 then jauh = jauh + 1 end
                if sp.GetUnitCommandCount(u) == 0 then diam = diam + 1 end
            end
            ringkas[#ringkas + 1] = string.format("%sx%d(in%d,near%d,idle%d,@%d:%d)", kunci, #anggota, dalam, jauh, diam,
                cx / S, cz / S)
        end
        table.sort(ringkas)
        o.laporan = string.format("serang=%s depan=%d perebut=%d tempur=%d regu=%s", modeSerang, #depan, jumlahPerebut, #tempur,
            table.concat(ringkas, ","))
    end

    return o
end

return M
