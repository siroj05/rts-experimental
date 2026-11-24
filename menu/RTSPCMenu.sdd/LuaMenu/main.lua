local sp = Spring
local root = "LuaMenu/"
local profiles = VFS.Include(root .. "profil_ai.lua", nil, VFS.MENU)
local maps = {
    {key = "bukit", name = "Central Hill", info = "mapinfo-bukit-tengah.lua", size = 2048, z = 316, depth = 1416},
    {key = "sungai", name = "River Valley", info = "mapinfo-lembah-sungai.lua", size = 4096, z = 0, depth = 4096},
    {key = "pinus", name = "Pine Crossing", info = "mapinfo-lintasan-pinus-4v4.lua", size = 4096, z = 0, depth = 3072},
}
local mapPicker = {x = 819, y = 602, w = 413, h = 32}
local mapOptions = {}
for i = 1, #maps do
    mapOptions[i] = {x = mapPicker.x, y = mapPicker.y - 4 - i * mapPicker.h, w = mapPicker.w, h = mapPicker.h}
end
local chartHeight = 690 * 1416 / 2048
for _, entry in ipairs(maps) do
    entry.scenario = VFS.Include(root .. entry.key .. ".lua", nil, VFS.MENU)
    entry.mapinfo = VFS.Include(root .. entry.info, nil, VFS.MENU)
    entry.start = assert(VFS.LoadFile(root .. entry.key .. "-start.txt", VFS.MENU))
    local width = chartHeight * entry.size / entry.depth
    entry.plot = {x = 68 + (690 - width) / 2, y = 126, w = width, h = chartHeight}
end
local levels = {"easy", "normal", "hard"}
local setting = "RTSPCSkirmishDifficulty"
local mapSetting = "RTSPCSkirmishMap"
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
local selectedMap = 1
local mapFocus
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

local function scoreText(value)
    return (tostring(value):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
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

local function coord(entry, x, z)
    local plot = entry.plot
    return plot.x + x * plot.w / entry.size, plot.y + plot.h - (z - entry.z) * plot.h / entry.depth
end

local function terrain(entry)
    local plot, map = entry.plot, entry.scenario
    rect(53, 83, 731, 538, {0.052, 0.058, 0.048, 1})
    rect(47, 89, 731, 538, paper)
    gl.Color(1, 1, 1, 1)
    gl.Texture(root .. entry.key .. ".jpg")
    gl.TexRect(plot.x, plot.y, plot.x + plot.w, plot.y + plot.h)
    gl.Texture(false)

    local grid = {0.35, 0.34, 0.27, 0.20}
    local step = entry.size / 8
    for x = 0, entry.size, step do
        local px = coord(entry, x, entry.z)
        segment(px, plot.y, px, plot.y + plot.h, grid)
        segment(px, plot.y + plot.h, px, plot.y + plot.h + 5, mutedInk)
        if x % (2 * step) == 0 then letter(tostring(x / 8), px, 611, 10, mutedInk, "c") end
    end
    for z = math.ceil((entry.z + 1) / step) * step, entry.z + entry.depth - 1, step do
        local _, py = coord(entry, 0, z)
        segment(plot.x, py, plot.x + plot.w, py, grid)
        segment(plot.x - 5, py, plot.x, py, mutedInk)
    end

    -- Relief, flags, and mineral sites share the same world-to-chart transform.
    for _, deposit in ipairs(map.ladang) do
        local x, y = coord(entry, deposit[1], deposit[2])
        diamond(x, y, 3.5, mine)
    end
    for _, point in ipairs(map.titik) do
        local x, y = coord(entry, point.x, point.z)
        local r = map.radius * plot.w / entry.size
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

    for team = 0, #map.awal - 1 do
        local startPos = entry.mapinfo.teams[team].startPos
        local x, y = coord(entry, startPos.x, startPos.z)
        local color = team < #map.awal / 2 and blue or red
        diamond(x, y, 15, color)
        title("HQ", x, y - 5, 13, bone, "c")
        if #map.awal == 2 or team == 0 then
            letter(team == 0 and "YOUR HQ" or "ENEMY HQ", x, y - 34, 12, ink, "c")
        end
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

    local scale = plot.w / 4
    segment(68, 113, 68 + scale, 113, ink)
    for i = 0, 4 do
        local tick = 68 + scale * i / 4
        segment(tick, 109, tick, 116, ink)
    end
    letter((entry.size / 32) .. " m", 78 + scale, 109, 11, ink)
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

local function drawMapPicker(mx, my)
    local r = mapPicker
    local active = mapFocus or inside(mx, my, r)
    rect(r.x, r.y, r.w, r.h, active and {0.25, 0.24, 0.18, 1} or {0.16, 0.18, 0.14, 1})
    rect(r.x, r.y, r.w, 1, active and orange or line)
    letter("MAP", r.x + 13, r.y + 10, 14, subdued)
    segment(r.x + 56, r.y + 8, r.x + 56, r.y + r.h - 8, line)
    letter(maps[selectedMap].name, r.x + 69, r.y + 9, 17, bone)
    local x, y = r.x + r.w - 17, r.y + r.h / 2
    local d = mapFocus and -1 or 1
    segment(x - 5, y + 2 * d, x, y - 3 * d, bone)
    segment(x, y - 3 * d, x + 5, y + 2 * d, bone)
    if not mapFocus then return end

    local bottom = mapOptions[#mapOptions].y
    rect(r.x - 1, bottom - 1, r.w + 2, r.y - 2 - bottom, line)
    for i, option in ipairs(mapOptions) do
        local hover = inside(mx, my, option)
        local fill = hover and {0.30, 0.28, 0.20, 1} or i == mapFocus and {0.25, 0.24, 0.18, 1} or background
        rect(option.x, option.y, option.w, option.h, fill)
        rect(option.x, option.y, option.w, 1, line)
        letter(maps[i].name, option.x + 69, option.y + 9, 17, bone)
        if i == selectedMap then diamond(x, option.y + option.h / 2, 4, orange) end
    end
end

function ActivateMenu()
    if not display then
        display = assert(gl.LoadFont(root .. "fonts/BarlowCondensed-Bold.ttf", 84, 0, 0))
        body = assert(gl.LoadFont(root .. "fonts/Barlow-Medium.ttf", 38, 0, 0))
        keys = {up = sp.GetKeyCode("up"), down = sp.GetKeyCode("down"),
            left = sp.GetKeyCode("left"), right = sp.GetKeyCode("right"),
            enter = sp.GetKeyCode("return"), numpadEnter = sp.GetKeyCode("numpad_enter"),
            escape = sp.GetKeyCode("escape"), space = sp.GetKeyCode("space")}
    end
    onMenu, pending, pressed = true, false, nil
    mapFocus = nil
    sp.SetWMCaption("RTS PC | Skirmish")
    local previous = sp.GetConfigString(setting, "normal")
    for i, key in ipairs(levels) do if key == previous then selected = i end end
    local lastMap = sp.GetConfigString(mapSetting, maps[1].key)
    selectedMap = 1
    for i, entry in ipairs(maps) do if entry.key == lastMap then selectedMap = i end end
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
    local entry = maps[selectedMap]
    local script, found = entry.start:gsub("ekonomi=1;", "ekonomi=1;tingkat_ai=" .. key .. ";kembali_menu=1;")
    assert(found == 1, "Skirmish start script is missing its economy setting")
    sp.SetConfigString(setting, key)
    sp.SetConfigString(mapSetting, entry.key)
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

    local entry = maps[selectedMap]
    terrain(entry)
    title(entry.name:upper(), 818, 541, 63, bone)
    local sisi = #entry.scenario.awal / 2
    letter(("Control Points  /  %d vs %d"):format(sisi, sisi), 821, 510, 20, subdued)
    rect(819, 493, 413, 1, line)
    letter(("Reach %s points or destroy"):format(scoreText(entry.scenario.targetSkor)),
        821, 469, 19, bone)
    letter(sisi > 1 and "all enemy Command Cores." or "the enemy Command Core.", 821, 446, 19, bone)
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
    local metres = entry.size / 8
    letter(("%d × %d m"):format(metres, entry.key == "pinus" and entry.depth / 8 or metres), 47, 39, 14, subdued)
    letter("Space  Map list     ← →  Change map     ↑ ↓  Change difficulty", 1232, 39, 14, subdued, "r")
    drawMapPicker(mx, my)
    gl.PopMatrix()
    gl.Color(1, 1, 1, 1)
end

local function actionAt(x, y)
    x, y = boardPoint(x, y)
    if inside(x, y, mapPicker) then return "map" end
    if mapFocus then
        for i, r in ipairs(mapOptions) do if inside(x, y, r) then return maps[i].key end end
        return "dismiss-map"
    end
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
    if action == "map" then
        if mapFocus then mapFocus = nil else mapFocus = selectedMap end
    elseif action == "dismiss-map" then mapFocus = nil
    elseif action == "start" then startMatch()
    elseif action == "exit" then sp.Quit()
    elseif type(action) == "number" then selected = action
    else
        for i, entry in ipairs(maps) do if entry.key == action then selectedMap = i end end
        mapFocus = nil
    end
end

function KeyPress(key, _, repeatKey)
    if not onMenu then return false end
    if mapFocus then
        if key == keys.up or key == keys.down then
            mapFocus = math.max(1, math.min(#maps, mapFocus + (key == keys.up and -1 or 1)))
        elseif not repeatKey then
            if key == keys.enter or key == keys.numpadEnter then
                selectedMap, mapFocus = mapFocus, nil
            elseif key == keys.escape or key == keys.space then
                mapFocus = nil
            end
        end
        return true
    end
    if key == keys.up or key == keys.down then
        selected = math.max(1, math.min(#levels, selected + (key == keys.up and -1 or 1)))
    elseif key == keys.left or key == keys.right then
        selectedMap = math.max(1, math.min(#maps, selectedMap + (key == keys.left and -1 or 1)))
    elseif key == keys.space and not repeatKey then
        mapFocus = selectedMap
    elseif (key == keys.enter or key == keys.numpadEnter) and not repeatKey then
        startMatch()
    elseif key == keys.escape and not repeatKey then
        sp.Quit()
    else
        return false
    end
    return true
end
