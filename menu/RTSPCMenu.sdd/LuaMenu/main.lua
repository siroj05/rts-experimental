local sp = Spring
local root = "LuaMenu/"
local map = VFS.Include(root .. "bukit.lua", nil, VFS.MENU)
local mapinfo = VFS.Include(root .. "mapinfo.lua", nil, VFS.MENU)
local profiles = VFS.Include(root .. "profil_ai.lua", nil, VFS.MENU)
local start = assert(VFS.LoadFile(root .. "bukit-start.txt", VFS.MENU))
local levels = {"easy", "normal", "hard"}
local setting = "RTSPCSkirmishDifficulty"
local ink = {0.17, 0.18, 0.15, 1}
local mutedInk = {0.35, 0.34, 0.27, 1}
local background = {0.095, 0.102, 0.09, 1}
local line = {0.27, 0.29, 0.24, 1}
local paper = {0.87, 0.81, 0.68, 1}
local bone = {0.95, 0.90, 0.79, 1}
local subdued = {0.72, 0.73, 0.65, 1}
local orange = {0.94, 0.65, 0.39, 1}
local blue = {0.25, 0.43, 0.48, 1}
local red = {0.61, 0.30, 0.20, 1}
local mine = {0.47, 0.38, 0.25, 1}
local plot = {x = 68, y = 126, w = 690, h = 690 * 1416 / 2048}
local exit = {x = 1154, y = 657, w = 78, h = 36}
local deploy = {x = 819, y = 122, w = 413, h = 64}
local rows = {
    {x = 819, y = 360, w = 413, h = 49},
    {x = 819, y = 308, w = 413, h = 49},
    {x = 819, y = 256, w = 413, h = 49},
}
local display, body
local onMenu, pending = false, false
local selected = 2
local pressed
local keys = {}

local function inside(x, y, r)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

local function rect(x, y, w, h, color)
    gl.Color(color)
    gl.Rect(x, y, x + w, y + h)
end

local function segment(x, y, a, b, color)
    gl.Color(color)
    gl.BeginEnd(GL.LINES, function()
        gl.Vertex(x, y)
        gl.Vertex(a, b)
    end)
end

local function diamond(x, y, r, color)
    gl.Color(color)
    gl.BeginEnd(GL.TRIANGLE_FAN, function()
        gl.Vertex(x, y - r)
        gl.Vertex(x + r, y)
        gl.Vertex(x, y + r)
        gl.Vertex(x - r, y)
    end)
end

local function printText(font, message, x, y, size, color, align)
    font:SetTextColor(color)
    font:Print(message, x, y, size, align or "")
end

local function letter(message, x, y, size, color, align)
    printText(body, message, x, y, size, color, align)
end

local function title(message, x, y, size, color, align)
    printText(display, message, x, y, size, color, align)
end

local function viewport()
    local w, h = sp.GetViewGeometry()
    local s = math.min(w / 1280, h / 720)
    return s, (w - 1280 * s) / 2, (h - 720 * s) / 2, w, h
end

local function boardPoint(x, y)
    local s, ox, oy = viewport()
    return (x - ox) / s, (y - oy) / s
end

local function coord(x, z)
    return plot.x + x * plot.w / 2048, plot.y + plot.h - (z - 316) * plot.h / 1416
end

local function terrain()
    rect(53, 83, 731, 538, {0.052, 0.058, 0.048, 1})
    rect(47, 89, 731, 538, paper)
    gl.Color(1, 1, 1, 1)
    gl.Texture(root .. "bukit.jpg")
    gl.TexRect(plot.x, plot.y, plot.x + plot.w, plot.y + plot.h)
    gl.Texture(false)

    local grid = {0.35, 0.34, 0.27, 0.20}
    for x = 0, 2048, 256 do
        local px = coord(x, 316)
        segment(px, plot.y, px, plot.y + plot.h, grid)
        segment(px, plot.y + plot.h, px, plot.y + plot.h + 5, mutedInk)
        if x % 512 == 0 then letter(tostring(x / 8), px, 611, 10, mutedInk, "c") end
    end
    for z = 512, 1728, 256 do
        local _, py = coord(0, z)
        segment(plot.x, py, plot.x + plot.w, py, grid)
        segment(plot.x - 5, py, plot.x, py, mutedInk)
    end

    -- Relief, flags, and mineral sites share the same world-to-chart transform.
    for _, deposit in ipairs(map.ladang) do
        local x, y = coord(deposit[1], deposit[2])
        diamond(x, y, 3.5, mine)
    end
    for _, point in ipairs(map.titik) do
        local x, y = coord(point.x, point.z)
        local r = map.radius * plot.w / 2048
        gl.Color({ink[1], ink[2], ink[3], 0.60})
        gl.BeginEnd(GL.LINE_LOOP, function()
            for i = 0, 35 do
                local a = i * math.pi / 18
                gl.Vertex(x + r * math.cos(a), y + r * math.sin(a))
            end
        end)
        rect(x - 10, y - 11, 20, 22, ink)
        title(point.nama, x, y - 6, 17, bone, "c")
    end

    for team = 0, 1 do
        local startPos = mapinfo.teams[team].startPos
        local x, y = coord(startPos.x, startPos.z)
        local color = team == 0 and blue or red
        diamond(x, y, 15, color)
        title("HQ", x, y - 5, 13, bone, "c")
        letter(team == 0 and "YOUR HQ" or "ENEMY HQ", x, y - 39, 12, ink, "c")
    end
    local x, y = 734, 570
    title("N", x, y + 13, 15, ink, "c")
    gl.Color(ink)
    gl.BeginEnd(GL.TRIANGLES, function()
        gl.Vertex(x, y + 7)
        gl.Vertex(x - 5, y - 9)
        gl.Vertex(x + 5, y - 9)
    end)
    segment(x, y - 9, x, y - 16, ink)

    local scale = plot.w * 512 / 2048
    segment(68, 113, 68 + scale, 113, ink)
    for i = 0, 4 do
        local tick = 68 + scale * i / 4
        segment(tick, 109, tick, 116, ink)
    end
    letter("64 m", 78 + scale, 109, 11, ink)
    diamond(563, 109, 3.5, mine)
    letter("Iron", 574, 104, 14, ink)
    rect(631, 102, 13, 14, ink)
    title("A", 637.5, 104, 12, bone, "c")
    letter("Control point", 653, 104, 14, ink)
end

local function startMatch()
    if pending then return end
    pending = true
end

function ActivateMenu()
    if not display then
        display = assert(gl.LoadFont(root .. "fonts/BarlowCondensed-Bold.ttf", 84, 0, 0))
        body = assert(gl.LoadFont(root .. "fonts/Barlow-Medium.ttf", 38, 0, 0))
        keys = {up = sp.GetKeyCode("up"), down = sp.GetKeyCode("down"),
            enter = sp.GetKeyCode("return"), numpadEnter = sp.GetKeyCode("numpad_enter"),
            escape = sp.GetKeyCode("escape")}
    end
    onMenu, pending, pressed = true, false, nil
    sp.SetWMCaption("RTS PC | Skirmish")
    local previous = sp.GetConfigString(setting, "normal")
    for i, key in ipairs(levels) do if key == previous then selected = i end end
end

function ActivateGame()
    onMenu, pending = false, false
    sp.SetWMCaption("RTS PC")
end

function Shutdown()
    if display then gl.DeleteFont(display) end
    if body then gl.DeleteFont(body) end
end

function Update()
    if not onMenu or not pending then return end
    local key = levels[selected]
    local script, found = start:gsub("ekonomi=1;", "ekonomi=1;tingkat_ai=" .. key .. ";kembali_menu=1;")
    assert(found == 1, "Skirmish start script is missing its economy setting")
    sp.SetConfigString(setting, key)
    onMenu, pending = false, false
    sp.Reload(script)
end

function DrawScreen()
    if not onMenu then return end
    local scale, ox, oy, w, h = viewport()
    rect(0, 0, w, h, background)
    local mx, my = boardPoint(sp.GetMouseState())
    gl.PushMatrix()
    gl.Translate(ox, oy, 0)
    gl.Scale(scale, scale, 1)

    title("RTS PC", 47, 662, 32, bone)
    segment(143, 661, 143, 686, line)
    letter("OFFLINE SKIRMISH", 160, 668, 15, subdued)
    rect(47, 642, 1185, 1, line)
    letter("Exit", 1211, 668, 17, inside(mx, my, exit) and orange or bone, "r")
    segment(1220, 673, 1230, 683, subdued)
    segment(1220, 683, 1230, 673, subdued)

    terrain()
    title("CENTRAL HILL", 818, 564, 68, bone)
    letter("Control Points  /  1 vs 1", 821, 530, 20, subdued)
    rect(819, 512, 413, 1, line)
    letter(("Reach %s points or destroy the"):format(map.targetSkor == 1000 and "1,000" or map.targetSkor),
        821, 482, 20, bone)
    letter("enemy Command Core.", 821, 456, 20, bone)
    letter("AI DIFFICULTY", 821, 423, 14, subdued)
    for i, r in ipairs(rows) do
        local profile = profiles[levels[i]]
        local current, hover = i == selected, inside(mx, my, r)
        local fill = current and {0.25, 0.24, 0.18, 1} or hover and {0.16, 0.18, 0.14, 1}
        if fill then rect(r.x, r.y, r.w, r.h, fill) end
        rect(r.x, r.y, r.w, 1, current and orange or line)
        diamond(r.x + 18, r.y + 24, 5, current and orange or line)
        title(profile.nama, r.x + 36, r.y + 15, 24, current and bone or subdued)
        letter(profile.ringkas, r.x + 135, r.y + 17, 16, current and bone or subdued)
    end
    rect(deploy.x, deploy.y - 4, deploy.w, deploy.h, ink)
    local hovered = inside(mx, my, deploy)
    rect(deploy.x, deploy.y, deploy.w, deploy.h, hovered and {1.0, 0.75, 0.48, 1} or orange)
    title("START MATCH", deploy.x + 18, deploy.y + 19, 34, ink)
    letter("ENTER", deploy.x + deploy.w - 46, deploy.y + 24, 14, ink, "r")
    local x, y = deploy.x + deploy.w - 24, deploy.y + 31
    segment(x - 9, y, x + 6, y, ink)
    segment(x + 6, y, x, y + 6, ink)
    segment(x + 6, y, x, y - 6, ink)

    rect(47, 66, 1185, 1, line)
    letter("256 × 256 m", 47, 39, 14, subdued)
    letter("↑ ↓  Change difficulty", 1232, 39, 14, subdued, "r")
    gl.PopMatrix()
    gl.Color(1, 1, 1, 1)
end

local function actionAt(x, y)
    x, y = boardPoint(x, y)
    for i, r in ipairs(rows) do if inside(x, y, r) then return i end end
    if inside(x, y, deploy) then return "start" end
    if inside(x, y, exit) then return "exit" end
end

function IsAbove()
    return onMenu
end

function MousePress(x, y, button)
    if not onMenu or button ~= 1 then return false end
    pressed = actionAt(x, y)
    return pressed ~= nil
end

function MouseRelease(x, y, button)
    local action = pressed
    pressed = nil
    if not onMenu or button ~= 1 or not action or action ~= actionAt(x, y) then return end
    if action == "start" then startMatch()
    elseif action == "exit" then sp.Quit()
    else selected = action end
end

function KeyPress(key, _, repeatKey)
    if not onMenu then return false end
    if key == keys.up or key == keys.down then
        selected = math.max(1, math.min(#levels, selected + (key == keys.up and -1 or 1)))
    elseif (key == keys.enter or key == keys.numpadEnter) and not repeatKey then
        startMatch()
    elseif key == keys.escape and not repeatKey then
        sp.Quit()
    else
        return false
    end
    return true
end
