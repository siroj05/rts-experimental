local aturan = VFS.Include("gamedata/skenario.lua")
if not aturan then return end
local hud = VFS.Include("LuaUI/hud.lua")
local baca = Spring.GetGameRulesParam
local warnaTim = {
    [-1] = {0.68, 0.72, 0.70},
    [0] = {0.40, 0.76, 1.00},
    [1] = {1.00, 0.52, 0.43},
}
local namaTim = {[-1] = "Neutral", [0] = "Blue", [1] = "Red"}
local warnaRebutan = {1.00, 0.79, 0.42}
local tinggiTiang = 45
local ekonomi = Spring.GetModOptions().ekonomi == "1"
local ekstraktor
for id, def in pairs(UnitDefs) do
    if def.name == "ekstraktor_besi" then
        ekstraktor = id
        break
    end
end
local ladang = aturan.ladang
local siapKamera = false
local shown = false

local function mulaiUlang()
    local start = VFS.LoadFile("gamedata/skenario/bukit-start.txt")
    if not ekonomi then start = start:gsub("ekonomi=1;", "") end
    Spring.Reload(start)
end

function Update()
    if shown then
        hud.Update()
        return
    end
    if Spring.GetGameFrame() < 2 then return end
    if ekonomi and not Spring.GetSpectatingState() then
        if not siapKamera then
            Spring.SendCommands("viewta")
            siapKamera = true
            return
        end
        local tim = Spring.GetMyTeamID()
        local x, y, z = Spring.GetTeamStartPosition(tim)
        local view = Spring.GetCameraState()
        local offset = aturan.awal[tim + 1].kamera
        view.px, view.py, view.pz = x + offset[1], y, z + offset[2]
        view.height, view.angle = 510, 1.12
        Spring.SetCameraState(view, 0)
    else
        local view = {name = "ov", px = Game.mapSizeX * 0.5, py = 0, pz = Game.mapSizeZ * 0.5}
        Spring.SetCameraState(view, 0)
    end
    hud.Initialize(mulaiUlang)
    shown = true
end

function Shutdown()
    if shown then hud.Shutdown() end
end

function LayoutButtons()
    -- Sisakan deskripsi dan pintasan Recoil. Semua tombol visual digambar di HUD.
    return "", 2, 2, {}, {}, {}, {}, {}, {}, {}, {}
end

function IsAbove(x, y)
    return hud.IsAbove(x, y)
end

function MousePress(x, y, button)
    return hud.MousePress(x, y, button)
end

function CommandNotify(cmd, params, options)
    if cmd == CMD.ATTACK then hud.AttackFeedback(params, options) end
    if not ekonomi or cmd ~= -ekstraktor or #params < 3 then return false end
    local x, z, hadap = params[1], params[3], params[4] or 0
    for _, t in ipairs(ladang) do
        local bx, y, bz = Spring.Pos2BuildPos(ekstraktor, t[1], 0, t[2], hadap)
        if (bx - x)^2 + (bz - z)^2 <= 32^2 then
            if Spring.TestBuildOrder(ekstraktor, bx, y, bz, hadap) == 0 then
                hud.Pesan("This iron deposit is blocked.")
                return true
            end
            Spring.GiveOrder(cmd, {bx, y, bz, hadap}, options and options.coded or 0)
            return true
        end
    end
    hud.Pesan("Place the Iron Extractor on a yellow deposit marker.")
    return true
end

local function status(t)
    local kunci = "titik_" .. t.nama
    local pemilik = baca(kunci .. "_pemilik") or -1
    local penantang = baca(kunci .. "_penantang") or -1
    local progres = baca(kunci .. "_progres") or 0
    if baca(kunci .. "_rebutan") == 1 then
        return warnaRebutan, "Contested", 0
    end
    if penantang >= 0 then
        return warnaTim[penantang], namaTim[penantang] .. " capturing", progres
    end
    return warnaTim[pemilik], namaTim[pemilik], pemilik >= 0 and 1 or 0
end

function DrawWorld()
    if not shown then return end
    gl.DepthTest(true)
    gl.LineWidth(2)
    for _, t in ipairs(aturan.titik) do
        local x, z = t.x, t.z
        local y = Spring.GetGroundHeight(x, z)
        local warna = status(t)

        gl.Color(warna[1], warna[2], warna[3], 0.85)
        gl.DrawGroundCircle(x, y + 3, z, aturan.radius, 64)
        gl.DrawGroundCircle(x, y + 3, z, 12, 16)

        gl.Color(0.82, 0.85, 0.82, 1)
        gl.BeginEnd(GL.LINES, function()
            gl.Vertex(x, y, z)
            gl.Vertex(x, y + tinggiTiang, z)
        end)
        gl.Color(warna[1], warna[2], warna[3], 1)
        gl.BeginEnd(GL.TRIANGLES, function()
            gl.Vertex(x, y + tinggiTiang, z)
            gl.Vertex(x + 23, y + tinggiTiang - 7, z)
            gl.Vertex(x, y + tinggiTiang - 15, z)
        end)
    end
    if ekonomi then
        gl.Color(0.95, 0.72, 0.30, 0.95)
        for _, t in ipairs(ladang) do
            local x, y, z = Spring.Pos2BuildPos(ekstraktor, t[1], 0, t[2], 0)
            gl.DrawGroundCircle(x, y + 3, z, 19, 4)
        end
    end
    hud.DrawRally()
    gl.LineWidth(1)
    gl.DepthTest(false)
    gl.Color(1, 1, 1, 1)
end

function DrawScreen(lebar, tinggi)
    if not shown then return end
    for _, t in ipairs(aturan.titik) do
        local y = Spring.GetGroundHeight(t.x, t.z) + tinggiTiang + 10
        if Spring.IsSphereInView(t.x, y, t.z, 20) then
            local xLayar, yLayar = Spring.WorldToScreenCoords(t.x, y, t.z)
            local warna = status(t)
            gl.Color(warna[1], warna[2], warna[3], 1)
            gl.Text(t.nama, xLayar, yLayar, 18, "oc")
        end
    end

    hud.Draw(lebar, tinggi, aturan, status, warnaTim)
    gl.Color(1, 1, 1, 1)
end
