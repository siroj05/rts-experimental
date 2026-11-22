local shown = false
function Update()
    if shown or Spring.GetGameFrame() < 2 then return end
    local x, y, z = Spring.GetTeamStartPosition(Spring.GetMyTeamID())
    local view = {name = "ov", px = x + 115, py = y, pz = z, height = 1150, angle = 1.19}
    Spring.SetCameraState(view, 0)
    Spring.Echo("Klik kiri untuk pilih tank, klik kanan untuk jalan. Tekan A lalu klik tanah untuk uji tembak.")
    shown = true
end
