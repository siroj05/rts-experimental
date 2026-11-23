local resources = VFS.Include("gamedata/resources.lua", nil, VFS.BASE)
-- Paket Recoil 2026.09.03 menyediakan .tga dan pasangan normal map untuk bekas ledakan.
resources.graphics.scars = {"scars/scar1.tga", "scars/scar2.tga"}
return resources
