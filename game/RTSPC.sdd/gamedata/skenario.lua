-- Pasangkan skenario dengan peta yang sesuai supaya koordinatnya tidak terbawa.
if Spring.GetModOptions().skenario == "bukit" and Game.mapName == "Central Hill 1v1 1.0" then
    return VFS.Include("gamedata/skenario/bukit.lua")
end
if Spring.GetModOptions().skenario == "sungai" and Game.mapName == "River Valley 1v1 1.0" then
    return VFS.Include("gamedata/skenario/sungai.lua")
end
if Spring.GetModOptions().skenario == "pinus" and Game.mapName == "Pine Crossing 4v4 1.0" then
    return VFS.Include("gamedata/skenario/pinus.lua")
end
if Spring.GetModOptions().skenario == "hijau" and Game.mapName == "Verdant Ridge 4v4 1.0" then return VFS.Include("gamedata/skenario/hijau.lua") end
