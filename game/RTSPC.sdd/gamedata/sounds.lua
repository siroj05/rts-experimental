local mesin = VFS.Include("gamedata/mesin_kendaraan.lua")
local items = {}
for _, profil in ipairs(mesin.profil) do
    for i = 1, mesin.segmen do
        local file = ("sounds/mesin/%s-%02d.wav"):format(profil.nama, i)
        items[file] = {file = file, preload = true, priority = -12, rolloff = 0, dopplerscale = 0}
    end
end
return {SoundItems = items}
