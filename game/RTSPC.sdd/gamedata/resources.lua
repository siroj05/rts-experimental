local resources = VFS.Include("gamedata/resources.lua", nil, VFS.BASE)
-- Bekas kawah buatan sendiri (tools/buat_decal.py, tahap 6): pusat gosong + tanah teraduk, pasangan _normal.tga.
resources.graphics.scars = {"scars/kawah1.tga", "scars/kawah2.tga"}
return resources
