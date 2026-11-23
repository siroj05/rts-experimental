-- Pasangkan skenario dengan peta yang sesuai supaya koordinatnya tidak terbawa.
if Spring.GetModOptions().skenario == "bukit" and Game.mapName == "Central Hill 1v1 1.0" then
    return VFS.Include("gamedata/skenario/bukit.lua")
end
if Spring.GetModOptions().skenario == "sungai" and Game.mapName == "River Valley 1v1 1.0" then
    return VFS.Include("gamedata/skenario/sungai.lua")
end
