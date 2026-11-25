-- Pasangkan skenario dengan peta yang sesuai supaya koordinatnya tidak terbawa.
local opsi = Spring.GetModOptions()
local berkas = {
    bukit = {"Central Hill 1v1 1.0", "gamedata/skenario/bukit.lua"},
    sungai = {"River Valley 1v1 1.0", "gamedata/skenario/sungai.lua"},
    pinus = {"Pine Crossing 4v4 1.0", "gamedata/skenario/pinus.lua"},
    hijau = {"Verdant Ridge 4v4 1.0", "gamedata/skenario/hijau.lua"},
}
local pilihan = berkas[opsi.skenario]
if not pilihan or Game.mapName ~= pilihan[1] then return nil end
local aturan = VFS.Include(pilihan[2])
-- Mode Deathmatch (✅ user 2026-11-25: "gua pengen ada dua mode nanti, rebut point sama saling menghancurkan";
-- "pindah ke mode deathmatch"): modoption mode=hancur. Titik dikosongkan sehingga tidak ada skor; pertandingan
-- berakhir saat semua markas satu kubu hancur (LuaRules/Gadgets/perebutan_titik.lua). Daftar titik asli disimpan di
-- `titikAsli` untuk keperluan lain (mis. AI).
if aturan and opsi.mode == "hancur" then
    aturan.mode = "hancur"
    aturan.titikAsli = aturan.titik
    aturan.titik = {}
end
return aturan
