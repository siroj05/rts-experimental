-- Belajar dalam pertandingan untuk semua tingkat AI (✅ user 2026-11-26: "AI bisa belajar selama pertandingan",
-- pilihan "Semua tingkat AI"). Dipisah dari otak_brutal.lua supaya Easy, Normal, dan Hard di mode Control Points
-- (yang tidak memakai otak) ikut belajar.
--
-- Tiap jenis unit tempur milik tim dinilai dari:
--   beri = kerusakan yang ditimbulkannya, dalam biaya besi musuh;
--   rugi = biaya besi unit jenis itu yang hancur.
-- Rasio (beri + 150) / (rugi + 150) dibandingkan rata-rata semua jenis. Bobot produksi dikalikan rasio^(0,6 x k),
-- dibatasi 1 - 0,4k sampai 1 + 0,8k. k = kekuatan belajar per tingkat (gamedata/profil_ai.lua, kunci `belajar`):
-- Easy 0,35, Normal 0,6, Hard 0,85, Brutal 1 (sama dengan perilaku lama Brutal: 0,6-1,8x). Artileri tidak dinilai.
local M = {}

function M.baru(c)
    local k = tonumber(c.kekuatan) or (c.kekuatan == true and 1) or 0
    local efek = {}
    local o = {}

    local function catat(def)
        efek[def] = efek[def] or {beri = 0, rugi = 0}
        return efek[def]
    end

    function o.Rusak(def, team, damage, attackerDef, attackerTeam)
        if k <= 0 or attackerTeam ~= c.tim or not attackerDef or damage <= 0 then return end
        if Spring.AreTeamsAllied(team, c.tim) or not c.tempurSet[attackerDef] then return end
        local ud = UnitDefs[def]
        local e = catat(attackerDef)
        e.beri = e.beri + math.min(damage, ud.health) / math.max(1, ud.health) * ud.metalCost
    end

    function o.Hancur(def, team)
        if k <= 0 or team ~= c.tim or not c.tempurSet[def] then return end
        local e = catat(def)
        e.rugi = e.rugi + UnitDefs[def].metalCost
    end

    function o.Kali(def)
        if k <= 0 or def == c.artileri or not c.tempurSet[def] then return 1 end
        local e = efek[def]
        local jumlah, total = 0, 0
        for _, x in pairs(efek) do
            total = total + (x.beri + 150) / (x.rugi + 150)
            jumlah = jumlah + 1
        end
        if not e or jumlah < 2 then return 1 end
        local rasio = ((e.beri + 150) / (e.rugi + 150)) / (total / jumlah)
        return math.max(1 - .4 * k, math.min(1 + .8 * k, rasio ^ (.6 * k)))
    end

    -- Baris log `AI BELAJAR tim=<t> k=<k> <unit>=<pengali>(beri/rugi) ...` untuk uji dan penyetelan.
    function o.Laporan()
        local bagian = {}
        for def, e in pairs(efek) do
            bagian[#bagian + 1] = string.format("%s=%.2f(%d/%d)", UnitDefs[def].name, o.Kali(def), e.beri, e.rugi)
        end
        table.sort(bagian)
        return string.format("AI BELAJAR tim=%d k=%.2f %s", c.tim, k, table.concat(bagian, " "))
    end

    return o
end

return M
