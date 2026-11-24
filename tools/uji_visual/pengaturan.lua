-- Uji menu pengaturan: buka menu jeda, masuk Settings, ubah nilai, screenshot, keluar. Pakai --opsi kembali_menu=1.
SHOTS[1] = {f = 1e9, nama = "tahan", target = "tengah", jarak = 500} -- tahan dasar.lua supaya tidak keluar
local tahap, t0 = 0, nil
preUpdate = function()
    if not menuJeda then Spring.Echo("VISUAL, DEBUG, menuJeda=" .. tostring(menuJeda) .. " opsi=" .. tostring(Spring.GetModOptions().kembali_menu) .. " replay=" .. tostring(Spring.IsReplay())); Spring.Echo("VISUAL, SELESAI"); Spring.SendCommands("quitforce"); return end
    local f = Spring.GetGameFrame()
    if tahap == 0 and f >= 150 then
        menuJeda.Buka(function() end, function() end)
        menuJeda.KeyPress(Spring.GetKeyCode("down"), false)
        menuJeda.KeyPress(Spring.GetKeyCode("return"), false)
        Spring.Echo("VISUAL, ZOOM, " .. tostring(Spring.GetConfigFloat("ScrollWheelSpeed")))
        local sebelum = Spring.GetConfigInt("snd_volmaster", 100) .. "/" .. Spring.GetConfigInt("UnitIconDist", 50)
        menuJeda.KeyPress(Spring.GetKeyCode("left"), false)       -- Master Volume -10
        menuJeda.KeyPress(Spring.GetKeyCode("down"), false)
        menuJeda.KeyPress(Spring.GetKeyCode("down"), false)
        menuJeda.KeyPress(Spring.GetKeyCode("right"), false)      -- Unit Icons Normal -> Far
        Spring.Echo("VISUAL, CONFIG, sebelum=" .. sebelum .. " sesudah=" .. Spring.GetConfigInt("snd_volmaster", 100)
            .. "/" .. Spring.GetConfigInt("UnitIconDist", 50))
        tahap, t0 = 1, Spring.GetTimer()
    elseif tahap == 1 and Spring.DiffTimers(Spring.GetTimer(), t0) > 1.5 then
        Spring.SendCommands("screenshot png")
        Spring.Echo("VISUAL, SHOT, 1, settings, frame=" .. f .. ", fps=" .. Spring.GetFPS() .. ", unit=0, menu")
        tahap, t0 = 2, Spring.GetTimer()
    elseif tahap == 2 and Spring.DiffTimers(Spring.GetTimer(), t0) > 1 then
        -- Kembalikan nilai bawaan supaya cfg uji tidak berubah arah.
        menuJeda.KeyPress(Spring.GetKeyCode("left"), false)
        menuJeda.KeyPress(Spring.GetKeyCode("up"), false)
        menuJeda.KeyPress(Spring.GetKeyCode("up"), false)
        menuJeda.KeyPress(Spring.GetKeyCode("right"), false)
        menuJeda.KeyPress(Spring.GetKeyCode("escape"), false)
        Spring.Echo("VISUAL, CONFIG, pulih=" .. Spring.GetConfigInt("snd_volmaster", 100) .. "/" .. Spring.GetConfigInt("UnitIconDist", 50))
        Spring.Echo("VISUAL, SELESAI")
        Spring.SendCommands("quitforce")
        tahap = 3
    end
end
