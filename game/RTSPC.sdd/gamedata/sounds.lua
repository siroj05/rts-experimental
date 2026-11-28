local mesin = VFS.Include("gamedata/mesin_kendaraan.lua")
local items = {}
for _, profil in ipairs(mesin.profil) do
    for i = 1, mesin.segmen do
        local file = ("sounds/mesin/%s-%02d.wav"):format(profil.nama, i)
        items[file] = {file = file, preload = true, priority = -12, rolloff = 0, dopplerscale = 0}
    end
end
-- Suara tempur: rolloff 0 karena volume berjarak dihitung LuaRules/Configs/suara_tempur.lua (bug 2026-11-28).
for _, pola in ipairs({"*.wav", "*.ogg"}) do
    for _, file in ipairs(VFS.DirList("sounds/", pola) or {}) do
        file = file:gsub("\\", "/")
        items[file] = {file = file, rolloff = 0, dopplerscale = 0, maxconcurrent = 16}
    end
end
return {SoundItems = items}
