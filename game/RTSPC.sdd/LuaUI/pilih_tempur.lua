-- Seleksi pintar (✅ user 2026-11-27: "saat gua select semuanya yang kepilih pasukan tempur doang, bangunan dan
-- insinyur ga kepilih"). Mirip "smart select" BAR, ditulis sendiri.
--
-- 🟡 Aturan: kalau satu aksi seleksi menambah dua unit atau lebih (drag kotak, Ctrl+A, klik ganda) dan di antaranya
-- ada unit tempur, bangunan dan unit pembangun yang baru ikut terpilih dibuang. Yang tetap bisa dipilih:
-- - klik satu bangunan atau satu insinyur;
-- - Shift+klik untuk menambah satu unit ke seleksi;
-- - drag kotak yang isinya hanya bangunan/insinyur (tidak ada unit tempur);
-- - klik ganda insinyur (memilih semua insinyur).
-- Engine tidak memberi callin seleksi ke LuaUI mentah ini, jadi perubahan seleksi dicek tiap Update.
local M = {}
local sp = Spring

local tempur = {}
for id, ud in pairs(UnitDefs) do
    tempur[id] = ud.canMove and not ud.isBuilding and not ud.isFactory and not ud.isBuilder
        and (ud.speed or 0) > 0 and #(ud.weapons or {}) > 0
end

local lama = {}

function M.Update()
    local pilih = sp.GetSelectedUnits()
    local baru, adaTempur = {}, false
    for _, u in ipairs(pilih) do
        if not lama[u] then
            baru[#baru + 1] = u
            if tempur[sp.GetUnitDefID(u)] then adaTempur = true end
        end
    end
    if #baru >= 2 and adaTempur then
        local buang = {}
        for _, u in ipairs(baru) do
            if not tempur[sp.GetUnitDefID(u)] then buang[u] = true end
        end
        if next(buang) then
            local sisa = {}
            for _, u in ipairs(pilih) do
                if not buang[u] then sisa[#sisa + 1] = u end
            end
            sp.SelectUnitArray(sisa)
            pilih = sisa
        end
    end
    lama = {}
    for _, u in ipairs(pilih) do lama[u] = true end
end

return M
