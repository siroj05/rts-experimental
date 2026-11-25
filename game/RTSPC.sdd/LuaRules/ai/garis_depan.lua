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
local sp = Spring
local M = {}
local S = 256

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
                    if b.def == c.hq and (b.x - m.x)^2 + (b.z - m.z)^2 < 400^2 then ada = true end
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
            return x, z, ni, nj, kunciPilih
        end
        return t.x, t.z, ni, nj, kunciPilih
    end

    -- Perebut: titik bukan milik kita terdekat yang belum dituju perebut lain (netral lebih dekat dihitung).
    -- Deathmatch: sasaran regu dari bangunan musuh yang diingat dan posisi awal markas musuh. Bobot markas 1,4
    -- (2,2 saat mode tekan; markas habis = menang), pabrik 1,2, ekstraktor/pompa 1,0, lainnya 0,7, dikali dendam ke
    -- pemiliknya. Komitmen +0,6. Takut aktif: sasaran terlalu panas -> tunggu 2–4 sel sebelum sasaran.
    local function sasaranBangunan(x, z, kuat, dituju, lamaKunci)
        local _, bangunan = c.otak.Ingatan()
        local tekan = c.otak.Mode() == "tekan"
        local calon = {}
        for u, b in pairs(bangunan) do
            local w = b.def == c.hq and (tekan and 2.2 or 1.4)
                or ((b.def == c.pabrik or b.def == c.pabrikRobot) and 1.2)
                or ((b.def == c.ekstraktor or b.def == c.pompa) and 1.0) or .7
            calon[#calon + 1] = {x = b.x, z = b.z, w = w * c.otak.BobotDendam(b.t), unit = u}
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
        if not aman(terbaik.x, terbaik.z) then
            for _, n in ipairs({2, 3, 4}) do
                local sx, sz = terbaik.x - ni * n * S, terbaik.z - nj * n * S
                if lewat[idx(sel(sx, sz))] and aman(sx, sz) then return sx, sz, ni, nj, terbaik.kunci end
            end
            for n = 5, 9 do
                local sx, sz = terbaik.x - ni * n * S, terbaik.z - nj * n * S
                if lewat[idx(sel(sx, sz))] then return sx, sz, ni, nj, terbaik.kunci end
            end
            return x, z, ni, nj, terbaik.kunci -- tidak ada sel tunggu yang bisa dilalui: tetap di tempat
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
        local _, bangunan = c.otak.Ingatan()
        local terbaik, d0
        for u, b in pairs(bangunan) do
            if (b.def == c.ekstraktor or b.def == c.pompa) and (tujuanRebut[u] or 0) < 2 then
                local k = idx(sel(b.x, b.z))
                if (panasMusuh[k] or 0) < 300 then
                    local d = (b.x - x)^2 + (b.z - z)^2
                    if not d0 or d < d0 then terbaik, d0 = u, d end
                end
            end
        end
        local tx, tz, kunci
        if terbaik then
            tujuanRebut[terbaik] = (tujuanRebut[terbaik] or 0) + 1
            tx, tz, kunci = bangunan[terbaik].x, bangunan[terbaik].z, "p" .. terbaik
        else
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

    function o.Hancur(unit)
        perebut[unit], tujuanUnit[unit] = nil, nil
    end

    -- pasukan: unit tempur yang sudah dilepas (tidak sedang mundur). bela: {x, z} bangunan diserang (berbobot).
    function o.Perintah(pasukan, frame, bela)
        if not lewat then return end
        tujuanRebut = {}
        local jumlahPerebut = 0
        for u in pairs(perebut) do
            if sp.ValidUnitID(u) then jumlahPerebut = jumlahPerebut + 1 else o.Hancur(u) end
        end
        local tempur = {}
        for _, u in ipairs(pasukan) do
            local def = sp.GetUnitDefID(u)
            if not perebut[u] and def ~= c.artileri and (def == c.pengintai or jumlahPerebut < (c.tingkat.perebut or 4)) then
                perebut[u] = true
                jumlahPerebut = jumlahPerebut + 1
            end
            if perebut[u] then
                if hancur then urusPerampok(u) else urusPerebut(u) end
            else tempur[#tempur + 1] = u end
        end

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
            local tx, tz, ni, nj, kunciT, sasaranUnit
            if bela and (bela.x - x)^2 + (bela.z - z)^2 < 1500^2 then
                tx, tz, ni, nj = bela.x, bela.z, 0, 0
            else
                if hancur then
                    tx, tz, ni, nj, kunciT, sasaranUnit = sasaranBangunan(x, z, kuat, dituju, kunciRegu)
                else
                    tx, tz, ni, nj, kunciT = sasaranTitik(x, z, kuat, dituju, kunciRegu)
                end
                if not tx then tx, tz, ni, nj = sasaranRegu(x, z, kuat) end
            end
            if tx then
                -- Kunci regu = sel titik tujuan (juga saat menunggu di titik tunggu), supaya komitmen tidak hilang.
                local kunci = kunciT or string.format("%d:%d", math.floor(tx / S), math.floor(tz / S))
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
        o.laporan = string.format("depan=%d perebut=%d tempur=%d regu=%s", #depan, jumlahPerebut, #tempur,
            table.concat(ringkas, ","))
    end

    return o
end

return M
