-- Formasi untuk perintah gerak grup (user 2026-11-27: "ketika bergerak bersama ke suatu titik tuh unit kaya
-- rebutan jalan"). Tanpa ini Recoil mengirim semua unit terpilih ke titik yang sama, sehingga unit saling dorong di
-- jalan dan berdesakan di tujuan.
--
-- 🟡 Cara kerja: klik Move / Fight / Patrol dengan dua unit atau lebih memberi tiap unit slot tujuan sendiri.
-- - Unit disusun dalam blok yang lebih lebar daripada dalamnya dan menghadap arah gerak, berjarak tapak terbesar
--   + ±35%. Unit paling depan mengisi baris depan, dan dalam satu baris diurut dari kiri ke kanan, jadi urutan
--   kiri-kanan dan depan-belakang grup tetap dan jalurnya tidak saling silang.
-- - Susunan asli grup sengaja tidak disalin: grup yang menumpuk (mis. di titik rally) akan tetap berdesakan.
-- - Slot yang tidak bisa dicapai (lereng, air, bangunan) digeser ke arah titik klik.
-- Drag kanan (formasi garis bawaan engine) tidak diubah.
local M = {}

local CMD_GRUP = {[CMD.MOVE] = true, [CMD.FIGHT] = true, [CMD.PATROL] = true}
local sp = Spring

local function bisaGerak(def)
    local ud = UnitDefs[def]
    return ud and ud.canMove and not ud.isBuilding and not ud.isFactory and (ud.speed or 0) > 0
end

local function dalamPeta(x, z)
    return math.max(16, math.min(Game.mapSizeX - 16, x)), math.max(16, math.min(Game.mapSizeZ - 16, z))
end

-- Hitung slot tujuan untuk daftar unit. Hasil: {{unit, x, y, z}, ...}
function M.Slot(units, tx, tz)
    local daftar, cx, cz, jarak = {}, 0, 0, 0
    for _, u in ipairs(units) do
        local def = sp.GetUnitDefID(u)
        local x, _, z = sp.GetUnitPosition(u)
        if def and x and bisaGerak(def) then
            local ud = UnitDefs[def]
            daftar[#daftar + 1] = {u = u, def = def, x = x, z = z}
            cx, cz = cx + x, cz + z
            -- xsize/zsize dalam petak 8 elmo. Jarak slot = tapak terbesar + ±35% ruang.
            jarak = math.max(jarak, math.max(ud.xsize, ud.zsize) * 8 * 1.35 + 6)
        end
    end
    local n = #daftar
    if n < 2 then return nil end
    cx, cz = cx / n, cz / n

    local dx, dz = tx - cx, tz - cz
    local panjang = math.sqrt(dx * dx + dz * dz)
    if panjang < 1 then dx, dz, panjang = 0, 1, 1 end
    dx, dz = dx / panjang, dz / panjang -- arah depan
    local lx, lz = dz, -dx              -- arah samping

    local kolom = math.ceil(math.sqrt(n * 2))
    local baris = math.ceil(n / kolom)
    local hasil = {}
    for _, d in ipairs(daftar) do
        d.maju = (d.x - cx) * dx + (d.z - cz) * dz
        d.samping = (d.x - cx) * lx + (d.z - cz) * lz
    end
    table.sort(daftar, function(a, b) return a.maju > b.maju end)
    local i = 1
    for r = 0, baris - 1 do
        local isi = math.min(kolom, n - i + 1)
        local row = {}
        for k = i, i + isi - 1 do row[#row + 1] = daftar[k] end
        table.sort(row, function(a, b) return a.samping < b.samping end)
        local maju = ((baris - 1) / 2 - r) * jarak
        for c, d in ipairs(row) do
            local samping = (c - 1 - (isi - 1) / 2) * jarak
            hasil[#hasil + 1] = {d, tx + dx * maju + lx * samping, tz + dz * maju + lz * samping}
        end
        i = i + isi
    end

    -- TestMoveOrder di LuaUI bisa menolak titik yang sebenarnya bisa dicapai (diukur: tujuan datar di luar LOS
    -- ditolak). Jadi slot hanya diperiksa kalau titik kliknya sendiri lolos.
    local uji = sp.TestMoveOrder(daftar[1].def, tx, sp.GetGroundHeight(tx, tz), tz)
    local slot = {}
    for _, h in ipairs(hasil) do
        local d, x, z = h[1], h[2], h[3]
        -- Slot tak terjangkau: geser bertahap ke titik klik.
        for _, t in ipairs({1, .6, .3, 0}) do
            local sx, sz = dalamPeta(tx + (x - tx) * t, tz + (z - tz) * t)
            local sy = sp.GetGroundHeight(sx, sz)
            if t == 0 or not uji or sp.TestMoveOrder(d.def, sx, sy, sz) then
                slot[#slot + 1] = {d.u, sx, sy, sz}
                break
            end
        end
    end
    return slot
end

-- Dipanggil dari CommandNotify. true = perintah sudah dikirim per unit.
function M.CommandNotify(cmd, params, options)
    if not CMD_GRUP[cmd] or #params ~= 3 then return false end
    local terpilih = sp.GetSelectedUnits()
    local slot = M.Slot(terpilih, params[1], params[3])
    if not slot then return false end
    local opsi = options and options.coded or 0
    local dapat = {}
    for _, s in ipairs(slot) do
        dapat[s[1]] = true
        sp.GiveOrderToUnit(s[1], cmd, {s[2], s[3], s[4]}, opsi)
    end
    -- Unit lain yang ikut terpilih (mis. pabrik untuk titik rally) tetap memakai titik klik.
    for _, u in ipairs(terpilih) do
        if not dapat[u] then sp.GiveOrderToUnit(u, cmd, params, opsi) end
    end
    return true
end

return M
