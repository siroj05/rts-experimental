local aturan = VFS.Include("gamedata/skenario.lua")
if not aturan then return end
local hud = VFS.Include("LuaUI/hud.lua")
local batangHp = VFS.Include("LuaUI/batang_hp.lua")
local fogPerang = VFS.Include("LuaUI/fog_perang.lua")
local baca = Spring.GetGameRulesParam
local warnaTim = {
    [-1] = {0.68, 0.72, 0.70},
    [0] = {0.40, 0.76, 1.00},
    [1] = {1.00, 0.52, 0.43},
}
local namaTim = {[-1] = "Neutral", [0] = "Blue", [1] = "Red"}
local warnaRebutan = {1.00, 0.79, 0.42}
local tinggiTiang = 45
-- Kursor buatan sendiri ada di anims/ (tools/buat_kursor.py). Attack Move (Fight) dipetakan eksplisit ke
-- cursorfight; kursor lain dimuat engine menurut nama file.
if Spring.AssignMouseCursor then
    Spring.AssignMouseCursor("Fight", "cursorfight", true)
    Spring.AssignMouseCursor("Area attack", "cursorareaattack", true)
end
-- Zona Command Core (daya + heal): lingkaran di tanah untuk Command Core sendiri dan sekutu.
local defMarkas, radiusZona
for id, ud in pairs(UnitDefs) do
    if ud.name == "inti_komando" then defMarkas, radiusZona = id, tonumber(ud.customParams.radius_zona) end
end
local opsi = Spring.GetModOptions()
local ekonomi = opsi.ekonomi == "1"
local function kembaliSkirmish() Spring.Reload("") end
local dariSkirmish = opsi.kembali_menu == "1" and not Spring.IsReplay()
local menuJeda = dariSkirmish and VFS.Include("LuaUI/menu_jeda.lua")
local esc = Spring.GetKeyCode("escape")
local profiles = VFS.Include("gamedata/profil_ai.lua")
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
    local start = VFS.LoadFile(aturan.startScript or "gamedata/skenario/bukit-start.txt")
    if profiles[opsi.tingkat_ai] then
        start = start:gsub("ekonomi=1;", "ekonomi=1;tingkat_ai=" .. opsi.tingkat_ai .. ";")
    end
    if opsi.kembali_menu == "1" then
        start = start:gsub("ekonomi=1;", "ekonomi=1;kembali_menu=1;")
    end
    if opsi.mode == "hancur" then start = start:gsub("ekonomi=1;", "ekonomi=1;mode=hancur;") end
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
        view.height = 660
        view.angle = math.rad(37) -- Sudut dari vertikal pada kamera overhead Recoil.
        Spring.SetCameraState(view, 0)
    else
        local view = {name = "ov", px = Game.mapSizeX * 0.5, py = 0, pz = Game.mapSizeZ * 0.5}
        Spring.SetCameraState(view, 0)
    end
    hud.Initialize(mulaiUlang, dariSkirmish and kembaliSkirmish)
    fogPerang.Initialize()
    shown = true
end

function Shutdown()
    if shown then
        hud.Shutdown()
        fogPerang.Shutdown()
    end
end

function LayoutButtons(_, _, _, perintah)
    hud.LayoutCommands(perintah)
    -- Sisakan deskripsi dan pintasan Recoil. Semua tombol visual digambar di HUD.
    return "", 2, 2, {}, {}, {}, {}, {}, {}, {}, {}
end

function IsAbove(x, y)
    return (menuJeda and menuJeda.terbuka) or hud.IsAbove(x, y)
end

function MousePress(x, y, button)
    if menuJeda and menuJeda.terbuka then return menuJeda.MousePress(x, y, button) end
    return hud.MousePress(x, y, button)
end

function MouseRelease(x, y, button)
    if menuJeda and menuJeda.terbuka then return menuJeda.MouseRelease(x, y, button) end
end

function MouseWheel()
    return menuJeda and menuJeda.terbuka or false
end

function KeyPress(key, _, ulang)
    if not menuJeda or not shown then return false end
    if menuJeda.terbuka then return menuJeda.KeyPress(key, ulang) end
    if key ~= esc or baca("titik_pemenang") ~= -1 then return false end
    if not ulang then menuJeda.Buka(mulaiUlang, kembaliSkirmish) end
    return true
end

function CommandNotify(cmd, params, options)
    if menuJeda and menuJeda.terbuka then return true end
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
    if defMarkas and radiusZona then
        gl.Color(0.30, 0.85, 0.78, 0.45)
        for _, t in ipairs(Spring.GetTeamList(Spring.GetMyAllyTeamID()) or {}) do
            for _, u in ipairs(Spring.GetTeamUnitsByDefs(t, defMarkas) or {}) do
                local x, y, z = Spring.GetUnitPosition(u)
                if x then gl.DrawGroundCircle(x, y, z, radiusZona, 96) end
            end
        end
    end
    hud.DrawRally()
    hud.DrawWeaponRanges()
    batangHp.DrawWorld()
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
    if menuJeda and menuJeda.terbuka then menuJeda.Draw() end
    gl.Color(1, 1, 1, 1)
end
