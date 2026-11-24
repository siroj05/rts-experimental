local hud = {}
local sp = Spring
local minArtileri = VFS.Include("gamedata/lontar.lua").jarakMin
local elmoPerMeter = 8
local warna = {
    bingkai = {0.30, 0.36, 0.36, 1},
    panel = {0.071, 0.103, 0.117, 0.98},
    lapis = {0.111, 0.153, 0.169, 1},
    gelap = {0.046, 0.067, 0.075, 1},
    putih = {0.93, 0.95, 0.92, 1},
    redup = {0.64, 0.72, 0.72, 1},
    teal = {0.38, 0.84, 0.76, 1},
    besi = {0.91, 0.70, 0.42, 1},
    energi = {0.46, 0.76, 0.92, 1},
    merah = {0.97, 0.53, 0.45, 1},
}
local peran = {
    medium_tank = "Combat vehicle", robot_insinyur = "Construction unit",
    tank_ringan = "Light armor", medium_tank_destroyer = "Anti-tank",
    pengintai = "Reconnaissance", artileri_ringan = "Indirect fire",
    robot_infanteri = "Burst-fire infantry", robot_roket = "Anti-armor infantry",
    inti_komando = "Headquarters", pabrik_kendaraan = "Vehicle production",
    pabrik_robot = "Robot production",
    ekstraktor_besi = "Iron production", pompa_minyak = "Energy generation",
    tiang_relay = "Power relay", gardu = "Local power supply", gudang = "Resource storage",
    radar = "Early warning", menara_pertahanan = "Ground defense",
}
local order = {
    {CMD.MOVE, "Move", "Click a destination."},
    {CMD.ATTACK, "Attack", "Choose a target. Shortcut A."},
    {CMD.FIGHT, "Attack Move", "Move while engaging enemies."},
    {CMD.PATROL, "Patrol", "Choose a patrol point."},
    {CMD.GUARD, "Guard", "Choose a unit to guard."},
    {CMD.REPAIR, "Repair", "Choose a damaged unit."},
    {CMD.RECLAIM, "Reclaim", "Choose an object to reclaim."},
    {CMD.STOP, "Stop", "Clear current orders."},
    {CMD.WAIT, "Wait", "Pause or resume orders."},
    {CMD.ONOFF, "Power", "Turn the building on or off.", {"Off", "On"}},
    {CMD.FIRE_STATE, "Fire Stance", "Set when the unit fires.", {"Hold Fire", "Return Fire", "Fire at Will"}},
    {CMD.MOVE_STATE, "Move Stance", "Set how freely the unit moves.", {"Hold", "Maneuver", "Roam"}},
    {CMD.REPEAT, "Repeat", "Repeat queued orders.", {"Off", "On"}},
}

local layout, data, pilihan, aktivitas, kekurangan, rally
local unitTerpilih, deskripsiPerintah = {}, {}
local tab = "perintah"
local targetPabrik, progresTerakhir, frameGerak
local pesan, waktuPesan
local aksi = {}
local waktuCek = 0
local lebarLama, tinggiLama
local aktif = false
local mulaiUlang, kembaliMenu

local function isi(c)
    gl.Color(c[1], c[2], c[3], c[4] or 1)
end

local function kotak(x, y, w, h, c)
    isi(c)
    gl.Rect(x, y, x + w, y + h)
end

local function sudut(x, y, w, h, cut, c)
    isi(c)
    gl.BeginEnd(GL.TRIANGLE_FAN, function()
        gl.Vertex(x, y)
        gl.Vertex(x + w, y)
        gl.Vertex(x + w, y + h - cut)
        gl.Vertex(x + w - cut, y + h)
        gl.Vertex(x + cut, y + h)
        gl.Vertex(x, y + h - cut)
    end)
end

local function panel(r)
    sudut(r.x, r.y - 2, r.w, r.h, 10, warna.gelap)
    sudut(r.x, r.y, r.w, r.h, 10, warna.bingkai)
    sudut(r.x + 1, r.y + 1, r.w - 2, r.h - 2, 9, warna.panel)
    kotak(r.x + 8, r.y + 4, r.w - 16, 1, warna.lapis)
end

local function teks(s, x, y, size, c, align, max)
    if max then
        size = math.min(size, max / math.max(.1, gl.GetTextWidth(s)))
    end
    isi(c or warna.putih)
    gl.Text(s, x, y, size, align or "")
end

local function bar(x, y, w, h, nilai, c)
    kotak(x, y, w, h, warna.gelap)
    kotak(x, y, w * math.min(1, math.max(0, nilai)), h, c)
end

local function angka(value)
    local s = tostring(math.floor(value + 0.5))
    return s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function laju(value)
    return string.format("%+.1f/s", value)
end

local function dalam(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

local function tambahAksi(x, y, w, h, fungsi, petunjuk)
    aksi[#aksi + 1] = {x = x, y = y, w = w, h = h, fungsi = fungsi, petunjuk = petunjuk}
end

local function panelPos(lebar, tinggi)
    if lebar == lebarLama and tinggi == tinggiLama then return end
    lebarLama, tinggiLama = lebar, tinggi
    local skala = math.min(lebar / 1280, tinggi / 720, 2.5)
    local w, h = lebar / skala, tinggi / skala
    local petaW = 111 * math.min(1, Game.mapSizeX / Game.mapSizeZ)
    local petaH = 111 * math.min(1, Game.mapSizeZ / Game.mapSizeX)
    layout = {
        skala = skala,
        kiri = {x = 16, y = 14, w = 244, h = 144},
        tengah = {x = 270, y = 14, w = w - 576, h = 144},
        kanan = {x = w - 296, y = 14, w = 280, h = 144},
        skor = {x = (w - 494) / 2, y = h - 100, w = 494, h = 84},
        peta = {x = w - 139 + (111 - petaW) / 2, y = 26 + (111 - petaH) / 2, w = petaW, h = petaH},
    }
    local m = layout.peta
    gl.ConfigMiniMap(math.floor(m.x * skala), math.floor(m.y * skala),
        math.floor(m.w * skala), math.floor(m.h * skala))
end

function hud.Initialize(restart, back)
    aktif = true
    mulaiUlang = restart
    kembaliMenu = back
    sp.SendCommands({"resbar 0", "tooltip 0", "clock 0", "console 0", "info 0", "minimap min 0", "minimap max 0",
        "endgraph 0"})
    sp.SetDrawSelectionInfo(false)
    gl.SlaveMiniMap(true)
    hud.Update()
end

function hud.Shutdown()
    gl.SlaveMiniMap(false)
    sp.SetDrawSelectionInfo(true)
end

function hud.Pesan(teksPesan)
    pesan, waktuPesan = teksPesan, sp.GetTimer()
end

function hud.AttackFeedback(params, options)
    if options and options.shift then return end
    local tx, tz
    if #params >= 3 then
        tx, tz = params[1], params[3]
    elseif #params == 1 and sp.ValidUnitID(params[1]) then
        local x, _, z = sp.GetUnitPosition(params[1])
        tx, tz = x, z
    end
    if not tx then return end
    local dipilih = sp.GetSelectedUnits()
    for _, id in ipairs(dipilih) do
        local def = UnitDefs[sp.GetUnitDefID(id)]
        if def and def.name == "artileri_ringan" then
            local x, _, z = sp.GetUnitPosition(id)
            if x and (tx - x)^2 + (tz - z)^2 < minArtileri^2 then
                local teks = #dipilih == 1 and "Target is inside artillery minimum range (%d m)."
                    or "Artillery in this group needs at least %d m to fire."
                hud.Pesan(teks:format(minArtileri / elmoPerMeter))
                return
            end
        end
    end
end

local function batasSenjata(def)
    local jarak, jarakMin = 0, def.name == "artileri_ringan" and minArtileri or 0
    for _, slot in ipairs(def.weapons) do
        local weapon = WeaponDefs[slot.weaponDef]
        jarak = math.max(jarak, weapon.range)
        jarakMin = math.max(jarakMin, tonumber(weapon.customParams.jarak_min) or 0)
    end
    return jarak, jarakMin
end

function hud.DrawWeaponRanges()
    for _, id in ipairs(unitTerpilih) do
        local defID = sp.GetUnitDefID(id)
        if defID then
            local maksimum, minimum = batasSenjata(UnitDefs[defID])
            if maksimum > 0 then
                local x, y, z = sp.GetUnitViewPosition(id)
                if x then
                    gl.Color(.48, .86, 1, .82)
                    gl.DrawGroundCircle(x, y, z, maksimum, 128)
                    if minimum > 0 then
                        gl.Color(1, .19, .14, .95)
                        gl.DrawGroundCircle(x, y, z, minimum, 96)
                    end
                end
            end
        end
    end
end

local function rentangSenjata(def)
    local jarak, jarakMin = batasSenjata(def)
    if jarak == 0 then return end
    if jarakMin > 0 then
        return string.format("Range %d–%d m", jarakMin / elmoPerMeter, jarak / elmoPerMeter)
    end
    return string.format("Range %d m", jarak / elmoPerMeter)
end

local function bacasumber(tim, resource)
    local stok, muat, pull, masuk, keluar = sp.GetTeamResources(tim, resource)
    return {stok = stok or 0, muat = muat or 0, net = (masuk or 0) - (keluar or 0),
        perlu = math.max(0, (pull or 0) - (masuk or 0))}
end

local function bacaAktivitas(unit, inBuild, frame)
    local target = unit and (inBuild and unit or sp.GetUnitIsBuilding(unit))
    if not target then
        targetPabrik, aktivitas, kekurangan = nil, nil, nil
        return
    end
    local def = UnitDefs[sp.GetUnitDefID(target)]
    local _, _, _, _, progres = sp.GetUnitHealth(target)
    if not def or not progres or progres >= 1 then
        targetPabrik, aktivitas, kekurangan = nil, nil, nil
        return
    end
    if target ~= targetPabrik or progresTerakhir ~= progres then
        frameGerak = frame
    end
    targetPabrik, progresTerakhir = target, progres
    aktivitas = {nama = def.humanName, progres = progres, sendiri = inBuild}
    kekurangan = nil
    if not inBuild then
        local m, e = data.besi, data.energi
        local kurangBesi = def.metalCost > 0 and m.perlu > .05 and m.stok < math.max(1, m.perlu * .5)
        local kurangEnergi = def.energyCost > 0 and e.perlu > .05 and e.stok < math.max(1, e.perlu * .5)
        if kurangBesi or kurangEnergi then
            local bahan = kurangBesi and (kurangEnergi and "iron and energy" or "iron") or "energy"
            local status = frame - frameGerak >= .7 * Game.gameSpeed and "Waiting for " or "Low "
            kekurangan = status .. bahan
        end
    end
end

function hud.LayoutCommands(perintah)
    -- Recoil menyediakan daftar perintah baru bersamaan dengan pilihan yang melahirkannya.
    unitTerpilih = sp.GetSelectedUnits()
    deskripsiPerintah = perintah
    waktuCek = 0
    if aktif then hud.Update() end
end

function hud.Update()
    local t = sp.GetTimer()
    if waktuCek ~= 0 and sp.DiffTimers(t, waktuCek) < .10 then return end
    waktuCek = t
    local unit = unitTerpilih
    local pertama = unit[1]
    local tim = sp.GetMyTeamID()
    data = {unit = pertama, jumlah = #unit, hp = 0, maks = 0, jenis = {}, perintah = {},
        bangun = {}, antrean = {}, besi = bacasumber(tim, "metal"), energi = bacasumber(tim, "energy")}
    for _, id in ipairs(unit) do
        local defID = sp.GetUnitDefID(id)
        local hp, maks = sp.GetUnitHealth(id)
        if defID and hp then
            data.jenis[defID] = (data.jenis[defID] or 0) + 1
            data.hp, data.maks = data.hp + hp, data.maks + maks
        end
    end
    rally = nil
    if pertama and #unit == 1 then
        data.def = UnitDefs[sp.GetUnitDefID(pertama)]
        if data.def and data.def.isFactory and sp.GetUnitTeam(pertama) == tim then
            local cmd, _, _, x, y, z = sp.GetUnitCurrentCommand(pertama, -1)
            if x and y and z and (cmd == CMD.MOVE or cmd == CMD.PATROL or cmd == CMD.FIGHT) then
                rally = {x, y, z}
            end
        end
        for _, kelompok in pairs(sp.GetFactoryCounts(pertama) or {}) do
            if type(kelompok) == "table" then
                for id, jumlah in pairs(kelompok) do
                    data.antrean[id] = (data.antrean[id] or 0) + jumlah
                end
            end
        end
    end
    local descs = {}
    for _, desc in ipairs(deskripsiPerintah) do
        descs[desc.id] = desc
        if desc.id < 0 and UnitDefs[-desc.id] then
            local def = UnitDefs[-desc.id]
            data.bangun[#data.bangun + 1] = {id = desc.id, def = def, desc = desc}
            data.pabrik = data.pabrik or desc.type == CMDTYPE.ICON
        end
    end
    for _, item in ipairs(order) do
        local desc = descs[item[1]]
        if desc then
            local state = item[4] and item[4][(tonumber(desc.params[1]) or 0) + 1]
            local aturRally = data.def and data.def.isFactory and item[1] == CMD.MOVE
            local nama = aturRally and "Rally Point" or item[2]
            local info = aturRally and "Choose where new units will move." or item[3]
            data.perintah[#data.perintah + 1] = {id = item[1], nama = nama, info = info, state = state, desc = desc}
        end
    end
    if pilihan ~= pertama or (#data.bangun == 0 and tab == "bangun") then
        pilihan = pertama
        tab = #data.bangun > 0 and "bangun" or "perintah"
    end
    bacaAktivitas(#unit == 1 and pertama, data.def and sp.GetUnitIsBeingBuilt(pertama), sp.GetGameFrame())
end

function hud.DrawRally()
    if not rally or sp.IsGUIHidden() then return end
    local x, y, z = rally[1], rally[2], rally[3]
    isi(warna.teal)
    gl.DrawGroundCircle(x, y + 3, z, 15, 4)
    gl.BeginEnd(GL.LINES, function()
        gl.Vertex(x, y + 3, z)
        gl.Vertex(x, y + 34, z)
        gl.Vertex(x, y + 34, z)
        gl.Vertex(x + 15, y + 28, z)
        gl.Vertex(x + 15, y + 28, z)
        gl.Vertex(x, y + 21, z)
    end)
end

local function potret(def, x, y, side)
    if not def or not peran[def.name] then return end
    local name = def.name:gsub("_", "-")
    gl.Color(1, 1, 1, 1)
    gl.Texture("LuaUI/potret/" .. name .. ".png")
    gl.TexRect(x, y, x + side, y + side)
    gl.Texture(false)
end

local function pilihTipe(id)
    local daftar = {}
    for _, u in ipairs(sp.GetSelectedUnits()) do
        if sp.GetUnitDefID(u) == id then daftar[#daftar + 1] = u end
    end
    sp.SelectUnitArray(daftar)
    waktuCek = 0
end

local function gambarPilihan(r, mx, my)
    panel(r)
    local x, y = r.x + 14, r.y
    teks("SELECTION", x, y + 120, 11, warna.redup)
    if not data.unit then
        teks("Select a unit", x, y + 78, 22)
        teks("Click or drag to select.", x, y + 49, 12, warna.redup)
        return
    end

    local def, jumlah = data.def, data.jumlah
    if def then
        sudut(x, y + 24, 72, 77, 5, warna.gelap)
        for i = 1, 4 do kotak(x + 7, y + 31 + i * 13, 58, 1, warna.panel) end
        potret(def, x + 2, y + 26, 68)
        teks(def.humanName, x + 83, y + 83, 18, nil, nil, 132)
        teks(peran[def.name] or "", x + 83, y + 65, 12, warna.redup, nil, 132)
        teks(angka(data.hp) .. " / " .. angka(data.maks) .. " HP", x + 83, y + 48, 11, warna.putih)
        bar(x + 83, y + 33, 132, 6, data.hp / math.max(1, data.maks),
            data.hp < data.maks * 0.35 and warna.merah or warna.teal)
        local rentang = rentangSenjata(def)
        local daya = sp.GetUnitRulesParam(data.unit, "daya_fraksi1")
        if daya == 0 then teks("No power", x + 83, y + 16, 11, warna.besi)
        elseif rentang then teks(rentang, x + 83, y + 16, 11, warna.teal, nil, 132)
        elseif daya == 1 then teks("Powered", x + 83, y + 16, 11, warna.teal) end
        return
    end

    teks(jumlah .. " units", x, y + 96, 20)
    teks(angka(data.hp) .. " / " .. angka(data.maks) .. " HP", x, y + 76, 11, warna.redup)
    bar(x, y + 65, 216, 5, data.hp / math.max(1, data.maks), warna.teal)
    local jenis = {}
    for id in pairs(data.jenis) do jenis[#jenis + 1] = id end
    table.sort(jenis)
    local jarak = math.min(36, 216 / #jenis)
    for i, id in ipairs(jenis) do
        local bx = x + (i - 1) * jarak
        local item = {x = bx, y = y + 18, w = jarak - 3, h = 37}
        sudut(bx, item.y, item.w, item.h, 4, dalam(item, mx, my) and warna.bingkai or warna.lapis)
        potret(UnitDefs[id], bx + 1, item.y + 7, item.w - 3)
        teks(tostring(data.jenis[id]), bx + item.w - 4, y + 22, 10, nil, "ro")
        local def = UnitDefs[id]
        local rentang = rentangSenjata(def)
        local detail = def.humanName .. (rentang and (" · " .. rentang) or "")
        tambahAksi(bx, item.y, item.w, item.h, function() pilihTipe(id) end, detail)
    end
end

local function klikPerintah(item, button)
    local index = sp.GetCmdDescIndex(item.id)
    if not index or item.desc.disabled then return end
    if button == 3 and not (item.def and data.pabrik) then return end
    local alt, ctrl, meta, shift = sp.GetModKeyState()
    sp.SetActiveCommand(index, button, button == 1, button == 3, alt, ctrl, meta, shift)
    waktuCek = 0
end

local function tombolTab(x, y, w, nama, key, mx, my)
    local area = {x = x, y = y, w = w, h = 24}
    sudut(x, y, w, 24, 4, tab == key and warna.lapis or (dalam(area, mx, my) and warna.lapis or warna.panel))
    teks(nama, x + 10, y + 7, 12, tab == key and warna.teal or warna.redup)
    if tab == key then kotak(x + 5, y, w - 10, 2, warna.teal) end
    tambahAksi(x, y, w, 24, function() tab = key end)
end

local function gambarTombol(r, mx, my)
    if not data.unit then return end
    panel(r)
    local x, y, w = r.x + 13, r.y, r.w - 26
    tombolTab(x, y + 110, 98, "Orders", "perintah", mx, my)
    if #data.bangun > 0 then
        tombolTab(x + 105, y + 110, 106, data.pabrik and "Production" or "Build", "bangun", mx, my)
    end
    kotak(x, y + 106, w, 1, warna.bingkai)

    local list = (tab == "bangun") and data.bangun or data.perintah
    local dua = #list > 7
    local kolom = dua and math.ceil(#list / 2) or math.max(1, #list)
    local _, cmdAktif = sp.GetActiveCommand()
    for i, item in ipairs(list) do
        local lebar = math.min(tab == "bangun" and 210 or 110, (w - (kolom - 1) * 6) / kolom)
        local bx = x + ((i - 1) % kolom) * (lebar + 6)
        local by = dua and (i <= kolom and y + 68 or y + 33) or y + 34
        local tinggi = dua and 30 or 63
        local dipilih = cmdAktif == item.id
        local rBtn = {x = bx, y = by, w = lebar, h = tinggi}
        local sorot = dalam(rBtn, mx, my)
        local dasar = item.desc.disabled and warna.gelap or (sorot and warna.bingkai or warna.lapis)
        sudut(bx, by, lebar, tinggi, 5, dasar)
        if dipilih then kotak(bx + 4, by, lebar - 8, 2, warna.teal) end
        local bantuan = item.info
        if item.def and dua then
            local def = item.def
            potret(def, bx + 3, by + 2, 26)
            teks(def.humanName, bx + 33, by + 16, 12, nil, nil, lebar - 37)
            teks(angka(def.metalCost) .. " I  /  " .. angka(def.energyCost) .. " E",
                bx + 33, by + 4, 10, warna.redup, nil, lebar - 37)
            bantuan = def.tooltip or def.humanName
        elseif item.def then
            local def = item.def
            sudut(bx + 5, by + 5, 51, tinggi - 10, 4, warna.gelap)
            potret(def, bx + 6, by + 6, 48)
            teks(def.humanName, bx + 62, by + 41, 14, nil, nil, lebar - 68)
            teks(angka(def.metalCost) .. " iron", bx + 62, by + 23, 11, warna.besi)
            teks(angka(def.energyCost) .. " energy", bx + 62, by + 9, 11, warna.energi)
            local count = data.antrean[-item.id]
            if count and count > 0 then
                kotak(bx + 35, by + 7, 19, 15, warna.teal)
                teks(tostring(count), bx + 44.5, by + 10, 10, warna.gelap, "c")
            end
            bantuan = def.tooltip or def.humanName
        else
            teks(item.nama, bx + lebar / 2, by + (dua and (item.state and 15 or 10) or 36),
                13, item.desc.disabled and warna.redup or warna.putih, "c", lebar - 10)
            if item.state then
                teks(item.state, bx + lebar / 2, by + (dua and 4 or 18), 10, warna.teal, "c")
            end
        end
        tambahAksi(bx, by, lebar, tinggi, function(button) klikPerintah(item, button) end, bantuan)
    end

    if aktivitas then
        local judul = aktivitas.sendiri and "Under construction" or aktivitas.nama
        teks(judul, x, y + 15, 12, nil, nil, w * .4)
        bar(x + w * .43, y + 13, w * .40, 6, aktivitas.progres, kekurangan and warna.besi or warna.teal)
        teks(string.format("%d%%", aktivitas.progres * 100), x + w * .975, y + 12, 11, warna.putih, "r")
    elseif #list == 0 then
        teks("No orders available for this unit.", x, y + 66, 13, warna.redup)
    elseif tab == "bangun" then
        local bantuan = data.pabrik and "Click to queue · Right-click card to remove · Right-click ground to rally"
            or "Select a building, then choose a site · [ ] Rotate"
        teks(bantuan, x, y + 15, 11, warna.redup)
    end
    local total = 0
    for _, jumlah in pairs(data.antrean) do total = total + jumlah end
    if kekurangan or total > 0 then
        local label = kekurangan or ("Queue " .. total)
        teks(label, x + w - 4, y + 118, 12, kekurangan and warna.besi or warna.redup, "r", w * .55)
    end
end

local function gambarPesan()
    if not pesan then return end
    if sp.DiffTimers(sp.GetTimer(), waktuPesan) >= 4 then
        pesan = nil
        return
    end
    local r = layout.tengah
    local w = math.min(r.w, gl.GetTextWidth(pesan) * 13 + 24)
    sudut(r.x, 168, w, 28, 5, warna.gelap)
    teks(pesan, r.x + 12, 177, 13, warna.besi, nil, w - 24)
end

local function gambarStok(dataStok, nama, x, y, w, c)
    kotak(x, y, w, 52, warna.lapis)
    kotak(x, y + 7, 2, 38, c)
    teks(nama, x + 9, y + 36, 12, c)
    teks(laju(dataStok.net), x + w - 7, y + 36, 10, dataStok.net < 0 and warna.merah or warna.teal, "r")
    teks(angka(dataStok.stok), x + 9, y + 16, 16)
    teks("/ " .. angka(dataStok.muat), x + w - 7, y + 17, 10, warna.redup, "r")
    bar(x + 7, y + 6, w - 14, 4, dataStok.stok / math.max(1, dataStok.muat), c)
end

local function gambarKanan(r)
    panel(r)
    local x, y = r.x + 12, r.y
    teks("RESOURCES", x, y + 122, 10, warna.redup)
    teks("MAP", r.x + 158, y + 127, 10, warna.redup)
    gambarStok(data.besi, "Iron", x, y + 63, 134, warna.besi)
    gambarStok(data.energi, "Energy", x, y + 8, 134, warna.energi)
    local m = layout.peta
    kotak(m.x - 2, m.y - 2, m.w + 4, m.h + 4, warna.bingkai)
    kotak(m.x, m.y, m.w, m.h, warna.gelap)
end

local function gambarSkor(r, aturan, status, warnaTim)
    panel(r)
    local x, y, w = r.x, r.y, r.w
    local tengah = x + w * .5
    local detik = math.floor(sp.GetGameFrame() / Game.gameSpeed)
    teks("CONTROL POINTS", tengah, y + 62, 12, warna.putih, "c")
    teks(string.format("%02d:%02d · %s points", math.floor(detik / 60), detik % 60, angka(aturan.targetSkor)),
        tengah, y + 46, 11, warna.redup, "c")
    for tim = 0, 1 do
        local c = warnaTim[tim]
        local skor = sp.GetGameRulesParam("titik_skor_" .. tim) or 0
        local awal = tim == 0 and x + 13 or x + w - 127
        teks(tim == 0 and "BLUE" or "RED", awal + 57, y + 66, 10, c, "c")
        teks(angka(skor), awal + 57, y + 46, 19, warna.putih, "c")
        bar(awal, y + 38, 114, 3, math.min(1, skor / aturan.targetSkor), c)
    end
    local chip = (w - 31 - 3 * 7) / 4
    for i, t in ipairs(aturan.titik) do
        local bx = x + 15 + (i - 1) * (chip + 7)
        local c, label, nilai = status(t)
        kotak(bx, y + 9, chip, 22, warna.lapis)
        if nilai > 0 then bar(bx, y + 9, chip, 2, nilai, c) end
        teks(t.nama, bx + 8, y + 15, 13, c)
        teks(label, bx + 25, y + 15, 10, warna.putih, nil, chip - 30)
    end
end

local function gambarHasil(hasil, warnaTim, w, h)
    layout.hasil = nil
    if not hasil or hasil == -1 then return end
    local x, y = w * .5 - 180, h * .54 - 71
    local r = {x = x, y = y, w = 360, h = 146}
    layout.hasil = r
    panel(r)
    local caption = hasil == -2 and "Match drawn" or (hasil == 0 and "Blue wins" or "Red wins")
    local a = sp.GetGameRulesParam("titik_skor_0") or 0
    local b = sp.GetGameRulesParam("titik_skor_1") or 0
    teks(caption, x + 180, y + 105, 26, warnaTim[hasil] or warna.putih, "c")
    teks("Blue  " .. angka(a) .. "   /   " .. angka(b) .. "  Red", x + 180, y + 77, 15, warna.redup, "c")
    if mulaiUlang then
        local bx = kembaliMenu and x + 23 or x + 111
        sudut(bx, y + 22, 138, 34, 4, warna.teal)
        teks("Play Again", bx + 69, y + 33, 15, warna.gelap, "c")
        tambahAksi(bx, y + 22, 138, 34, function(button)
            if button == 1 then mulaiUlang() end
        end)
    end
    if kembaliMenu then
        sudut(x + 173, y + 22, 164, 34, 4, warna.lapis)
        teks("Back to Skirmish", x + 255, y + 33, 15, warna.putih, "c")
        tambahAksi(x + 173, y + 22, 164, 34, function(button)
            if button == 1 then kembaliMenu() end
        end)
    end
end

function hud.Draw(lebar, tinggi, aturan, status, warnaTim)
    if not aktif or not data or sp.IsGUIHidden() then return end
    panelPos(lebar, tinggi)
    local s = layout.skala
    local mx, my = sp.GetMouseState()
    mx, my = mx / s, my / s
    aksi = {}
    gl.PushMatrix()
    gl.Scale(s, s, 1)
    gambarPilihan(layout.kiri, mx, my)
    gambarTombol(layout.tengah, mx, my)
    gambarKanan(layout.kanan)
    gambarSkor(layout.skor, aturan, status, warnaTim)
    gl.PopMatrix()
    gl.Color(1, 1, 1, 1)
    gl.DrawMiniMap()

    gl.PushMatrix()
    gl.Scale(s, s, 1)
    local m = layout.peta
    for _, titik in ipairs(aturan.titik) do
        local x = m.x + titik.x / Game.mapSizeX * m.w
        local y = m.y + (1 - titik.z / Game.mapSizeZ) * m.h
        kotak(x - 6, y - 6, 12, 12, warna.gelap)
        teks(titik.nama, x, y - 3.5, 9.5, status(titik), "c")
    end
    gambarHasil(sp.GetGameRulesParam("titik_pemenang"), warnaTim, lebar / s, tinggi / s)
    gambarPesan()
    gl.PopMatrix()
    gl.Color(1, 1, 1, 1)

    for _, hit in ipairs(aksi) do
        if not pesan and hit.petunjuk and dalam(hit, mx, my) then
            gl.PushMatrix()
            gl.Scale(s, s, 1)
            local lebarTip = math.min(375, gl.GetTextWidth(hit.petunjuk) * 12 + 22)
            local x = math.min(hit.x, lebar / s - lebarTip - 16)
            sudut(x, 168, lebarTip, 26, 4, warna.gelap)
            teks(hit.petunjuk, x + 10, 177, 12, warna.putih, nil, lebarTip - 20)
            gl.PopMatrix()
            break
        end
    end
end

function hud.IsAbove(x, y)
    if not layout or sp.IsGUIHidden() then return false end
    x, y = x / layout.skala, y / layout.skala
    if layout.hasil and dalam(layout.hasil, x, y) then return true end
    return not dalam(layout.peta, x, y) and (dalam(layout.kiri, x, y)
        or (data.unit and dalam(layout.tengah, x, y)) or dalam(layout.kanan, x, y) or dalam(layout.skor, x, y))
end

function hud.MousePress(x, y, button)
    if not hud.IsAbove(x, y) then return false end
    x, y = x / layout.skala, y / layout.skala
    if button == 1 or button == 3 then
        for _, hit in ipairs(aksi) do
            if dalam(hit, x, y) then
                hit.fungsi(button)
                break
            end
        end
    end
    return true
end

return hud
