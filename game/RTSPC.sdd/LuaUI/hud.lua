local hud = {}
local sp = Spring
local minArtileri = VFS.Include("gamedata/lontar.lua").jarakMin
local elmoPerMeter = 8
-- Palet HUD = palet menu utama (LuaMenu/main.lua): olive gelap, krem "bone", aksen oranye (2026-11-26).
-- Aksen oranye hanya untuk yang interaktif/aktif; hijau zaitun untuk HP dan laju positif; besi baja, energi biru kabut.
local warna = {
    bingkai = {0.27, 0.29, 0.24, 1},
    garis = {0.20, 0.215, 0.18, 1},
    panel = {0.095, 0.102, 0.09, 0.94},
    lapis = {0.135, 0.145, 0.125, 1},
    sorot = {0.19, 0.20, 0.17, 1},
    gelap = {0.06, 0.064, 0.056, 1},
    putih = {0.95, 0.90, 0.79, 1},
    redup = {0.64, 0.64, 0.56, 1},
    aksen = {0.94, 0.65, 0.39, 1},
    sehat = {0.62, 0.76, 0.42, 1},
    besi = {0.74, 0.77, 0.78, 1},
    energi = {0.52, 0.74, 0.80, 1},
    merah = {0.88, 0.45, 0.33, 1},
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
-- Nama tipe kendaraan bernuansa militer Jerman (🟡 usulan Claude 2026-11-26, fiktif: bukan nama kendaraan sejarah
-- yang terkenal dan tanpa istilah yang lekat dengan Nazi). Judul kartu produksi = julukan; info hover = nama lengkap.
local sandi = {
    pengintai = {"Elster", "Spähwagen \"Elster\""},
    tank_ringan = {"Dachs", "Leichter Kampfwagen \"Dachs\""},
    medium_tank = {"Keiler", "Kampfwagen \"Keiler\""},
    medium_tank_destroyer = {"Habicht", "Jagdwagen \"Habicht\""},
    artileri_ringan = {"Donner", "Feldhaubitze \"Donner\""},
}
local namaArmor = {}
for nama, id in pairs(Game.armorTypes or {}) do namaArmor[id] = nama end

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

local S = 1 -- skala layar / 1280x720, diisi hud.Draw
local function px(v) return math.floor(v * S + .5) end

local fontIsi = gl.LoadFont("LuaUI/fonts/Barlow-Medium.ttf", 64, 0, 0)
local fontJudul = gl.LoadFont("LuaUI/fonts/BarlowCondensed-Bold.ttf", 64, 0, 0)

local function isi(c)
    gl.Color(c[1], c[2], c[3], c[4] or 1)
end

local function kotak(x, y, w, h, c)
    isi(c)
    local x0, y0 = px(x), px(y)
    gl.Rect(x0, y0, math.max(x0 + 1, px(x + w)), math.max(y0 + 1, px(y + h)))
end

local function sudut(x, y, w, h, cut, c)
    isi(c)
    local x0, y0, x1, y1, k = px(x), px(y), px(x + w), px(y + h), px(cut)
    gl.BeginEnd(GL.TRIANGLE_FAN, function()
        gl.Vertex(x0, y0)
        gl.Vertex(x1, y0)
        gl.Vertex(x1, y1 - k)
        gl.Vertex(x1 - k, y1)
        gl.Vertex(x0 + k, y1)
        gl.Vertex(x0, y1 - k)
    end)
end

local function panel(r)
    sudut(r.x, r.y - 2, r.w, r.h, 10, {0, 0, 0, .35})
    sudut(r.x, r.y, r.w, r.h, 10, warna.bingkai)
    sudut(r.x + 1, r.y + 1, r.w - 2, r.h - 2, 9, warna.panel)
    kotak(r.x + 10, r.y + r.h - 2, r.w - 20, 1, warna.garis)
end

local function lebarTeks(s, size, judul)
    local f = judul and fontJudul or fontIsi
    return (f and f:GetTextWidth(s) or gl.GetTextWidth(s)) * size
end

-- Teks tidak lagi dikecilkan otomatis (ukuran judul kartu dulu berbeda-beda); kepanjangan dipotong dengan "…".
local function teks(s, x, y, size, c, align, max, judul)
    s = tostring(s)
    if max and lebarTeks(s, size, judul) > max then
        size = math.max(size * .85, max / math.max(.1, lebarTeks(s, 1, judul)))
    end
    if max and lebarTeks(s, size, judul) > max then
        while #s > 1 and lebarTeks(s .. "…", size, judul) > max do s = s:sub(1, -2) end
        s = s:gsub("%s+$", "") .. "…"
    end
    local f = judul and fontJudul or fontIsi
    local c2 = c or warna.putih
    if f then
        f:SetTextColor(c2[1], c2[2], c2[3], c2[4] or 1)
        f:Print(s, px(x), px(y), size * S, align or "")
    else
        isi(c2)
        gl.Text(s, px(x), px(y), size * S, align or "")
    end
end

local function judul(s, x, y, size, c, align, max)
    teks(s, x, y, size, c, align, max, true)
end

local function bar(x, y, w, h, nilai, c)
    kotak(x, y, w, h, warna.gelap)
    local n = math.min(1, math.max(0, nilai))
    if n > 0 then kotak(x, y, w * n, h, c) end
end

local function angka(value)
    local s = tostring(math.floor(value + 0.5))
    return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function ringkas(value)
    if value >= 1000 then return (string.format("%.1fk", value / 1000):gsub("%.0k", "k")) end
    return tostring(math.floor(value + .5))
end

local function laju(value)
    return string.format("%+.1f/s", value)
end

local function dalam(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

local function tambahAksi(x, y, w, h, fungsi, petunjuk, def)
    aksi[#aksi + 1] = {x = x, y = y, w = w, h = h, fungsi = fungsi, petunjuk = petunjuk, def = def}
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

-- Cakram di tanah (cincin konsentris mengikuti tinggi tanah) untuk masker stencil dan isi tipis.
local CINCIN, RUAS = 5, 48
local sinR, cosR = {}, {}
for i = 0, RUAS do sinR[i], cosR[i] = math.sin(i / RUAS * 2 * math.pi), math.cos(i / RUAS * 2 * math.pi) end
local function cakram(x, z, r)
    local dalam = {}
    for i = 0, RUAS do dalam[i] = {x, sp.GetGroundHeight(x, z) + 4, z} end
    for k = 1, CINCIN do
        local rr = r * k / CINCIN
        local luar = {}
        for i = 0, RUAS do
            local px, pz = x + cosR[i] * rr, z + sinR[i] * rr
            luar[i] = {px, sp.GetGroundHeight(px, pz) + 4, pz}
        end
        gl.BeginEnd(GL.TRIANGLE_STRIP, function()
            for i = 0, RUAS do
                gl.Vertex(dalam[i][1], dalam[i][2], dalam[i][3])
                gl.Vertex(luar[i][1], luar[i][2], luar[i][3])
            end
        end)
        dalam = luar
    end
end

-- Jangkauan unit terpilih digabung seperti genre RTS sejenis: satu garis luar gabungan + isi tipis, busur di dalam
-- jangkauan unit lain disembunyikan (2026-11-26, ditulis sendiri dengan stencil):
-- 1. Cakram tiap unit (radius dikurangi sedikit) ditulis ke stencil, warna mati.
-- 2. Garis lingkaran penuh hanya digambar di luar stencil -> busur dalam hilang, garis luar tetap.
-- 3. Isi tipis sekali per piksel (stencil EQUAL lalu ZERO) supaya tumpukan tidak makin pekat.
-- Jarak minimum artileri tetap lingkaran merah terpisah.
function hud.DrawWeaponRanges()
    local daftar = {}
    for _, id in ipairs(unitTerpilih) do
        local defID = sp.GetUnitDefID(id)
        if defID then
            local maksimum, minimum = batasSenjata(UnitDefs[defID])
            if maksimum > 0 then
                local x, y, z = sp.GetUnitViewPosition(id)
                if x then daftar[#daftar + 1] = {x, y, z, maksimum, minimum} end
            end
        end
    end
    if #daftar == 0 then return end
    local susut = 6
    gl.Clear(GL.STENCIL_BUFFER_BIT, 0)
    gl.StencilTest(true)
    gl.StencilMask(1)
    -- 1. Masker
    gl.DepthTest(false)
    gl.ColorMask(false, false, false, false)
    gl.StencilFunc(GL.ALWAYS, 1, 1)
    gl.StencilOp(GL.KEEP, GL.KEEP, GL.REPLACE)
    for _, d in ipairs(daftar) do cakram(d[1], d[3], d[4] - susut) end
    gl.ColorMask(true, true, true, true)
    -- 2. Garis luar gabungan
    gl.StencilFunc(GL.NOTEQUAL, 1, 1)
    gl.StencilOp(GL.KEEP, GL.KEEP, GL.KEEP)
    gl.LineWidth(2.2)
    gl.Color(.48, .86, 1, .85)
    for _, d in ipairs(daftar) do gl.DrawGroundCircle(d[1], d[2], d[3], d[4], 128) end
    -- 3. Isi tipis
    gl.StencilFunc(GL.EQUAL, 1, 1)
    gl.StencilOp(GL.KEEP, GL.KEEP, GL.ZERO)
    gl.Color(.48, .86, 1, .07)
    for _, d in ipairs(daftar) do cakram(d[1], d[3], d[4] - susut) end
    gl.StencilTest(false)
    gl.LineWidth(1.6)
    gl.Color(1, .19, .14, .95)
    for _, d in ipairs(daftar) do
        if d[5] > 0 then gl.DrawGroundCircle(d[1], d[2], d[3], d[5], 96) end
    end
    gl.LineWidth(1)
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
    isi(warna.aksen)
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
    gl.TexRect(px(x), px(y), px(x + side), px(y + side))
    gl.Texture(false)
end

-- Simbol tipe = ikon strategis zoom jauh (icons/, tools/buat_ikon.py), jadi kartu dan peta memakai bahasa yang sama:
-- Medium Tank persegi + laras, Light Tank berongga, Destroyer segitiga, pengintai chevron, artileri bulat + busur.
local ikonUnit = VFS.Include("gamedata/ikon_unit.lua")
local function simbol(def, x, y, side, c)
    local nama = def and ikonUnit[def.name]
    if not nama then return end
    isi(c or warna.putih)
    gl.Texture("icons/" .. nama .. ".png")
    gl.TexRect(px(x), px(y), px(x + side), px(y + side))
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
    judul("SELECTION", x, y + 121, 11, warna.redup)
    if not data.unit then
        judul("Select a unit", x, y + 78, 22)
        teks("Click or drag to select.", x, y + 49, 12, warna.redup)
        return
    end

    local def, jumlah = data.def, data.jumlah
    if def then
        sudut(x, y + 24, 72, 77, 5, warna.gelap)
        for i = 1, 4 do kotak(x + 7, y + 31 + i * 13, 58, 1, warna.panel) end
        potret(def, x + 2, y + 26, 68)
        judul(def.humanName, x + 83, y + 83, 19, nil, nil, 132)
        teks(peran[def.name] or "", x + 83, y + 65, 12, warna.redup, nil, 132)
        teks(angka(data.hp) .. " / " .. angka(data.maks) .. " HP", x + 83, y + 48, 11, warna.putih)
        bar(x + 83, y + 33, 132, 6, data.hp / math.max(1, data.maks),
            data.hp < data.maks * 0.35 and warna.merah or warna.sehat)
        local rentang = rentangSenjata(def)
        local daya = sp.GetUnitRulesParam(data.unit, "daya_fraksi1")
        if daya == 0 then teks("No power", x + 83, y + 16, 11, warna.besi)
        elseif rentang then teks(rentang, x + 83, y + 16, 11, warna.aksen, nil, 132)
        elseif daya == 1 then teks("Powered", x + 83, y + 16, 11, warna.aksen) end
        return
    end

    judul(jumlah .. " units", x, y + 94, 22)
    teks(angka(data.hp) .. " / " .. angka(data.maks) .. " HP", x, y + 76, 11, warna.redup)
    bar(x, y + 65, 216, 4, data.hp / math.max(1, data.maks), warna.sehat)
    local jenis = {}
    for id in pairs(data.jenis) do jenis[#jenis + 1] = id end
    table.sort(jenis)
    local jarak = math.min(36, 216 / #jenis)
    for i, id in ipairs(jenis) do
        local bx = x + (i - 1) * jarak
        local item = {x = bx, y = y + 18, w = jarak - 3, h = 37}
        sudut(bx, item.y, item.w, item.h, 4, dalam(item, mx, my) and warna.sorot or warna.lapis)
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
    judul(nama, x + 10, y + 7, 13, tab == key and warna.aksen or warna.redup)
    if tab == key then kotak(x + 5, y, w - 10, 2, warna.aksen) end
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
        local lebar = math.min(tab == "bangun" and 210 or 110, (w - (kolom - 1) * 4) / kolom)
        local bx = x + ((i - 1) % kolom) * (lebar + 4)
        local by = dua and (i <= kolom and y + 68 or y + 33) or y + 34
        local tinggi = dua and 30 or 63
        local dipilih = cmdAktif == item.id
        local rBtn = {x = bx, y = by, w = lebar, h = tinggi}
        local sorot = dalam(rBtn, mx, my)
        local dasar = item.desc.disabled and warna.gelap or (sorot and warna.sorot or warna.lapis)
        sudut(bx, by, lebar, tinggi, 5, dasar)
        if dipilih then kotak(bx + 4, by, lebar - 8, 2, warna.aksen) end
        local bantuan = item.info
        if item.def and dua then
            local def = item.def
            potret(def, bx + 2, by + 3, 24)
            local adaSimbol = ikonUnit[def.name] and def.speed > 0
            judul(sandi[def.name] and sandi[def.name][1] or def.humanName, bx + 30, by + 16, 11.5, nil, nil,
                lebar - 33 - (adaSimbol and 15 or 0))
            if adaSimbol then simbol(def, bx + lebar - 16, by + 15, 12, warna.redup) end
            teks(ringkas(def.metalCost), bx + 30, by + 4, 9.5, warna.besi)
            teks(ringkas(def.energyCost), bx + 30 + lebarTeks(ringkas(def.metalCost), 9.5) + 6, by + 4, 9.5, warna.energi)
            bantuan = def.tooltip or def.humanName
        elseif item.def then
            local def = item.def
            sudut(bx + 5, by + 5, 51, tinggi - 10, 4, warna.gelap)
            potret(def, bx + 6, by + 6, 48)
            judul(sandi[def.name] and sandi[def.name][1] or def.humanName, bx + 62, by + 41, 15, nil, nil, lebar - 68)
            teks(angka(def.metalCost) .. " iron", bx + 62, by + 23, 11, warna.besi)
            teks(angka(def.energyCost) .. " energy", bx + 62, by + 9, 11, warna.energi)
            local count = data.antrean[-item.id]
            if count and count > 0 then
                kotak(bx + 35, by + 7, 19, 15, warna.aksen)
                teks(tostring(count), bx + 44.5, by + 10, 10, warna.gelap, "c")
            end
            bantuan = def.tooltip or def.humanName
        else
            teks(item.nama, bx + lebar / 2, by + (dua and (item.state and 15 or 10) or 36),
                13, item.desc.disabled and warna.redup or warna.putih, "c", lebar - 10)
            if item.state then
                teks(item.state, bx + lebar / 2, by + (dua and 4 or 18), 10, warna.aksen, "c")
            end
        end
        tambahAksi(bx, by, lebar, tinggi, function(button) klikPerintah(item, button) end, bantuan, item.def)
    end

    if aktivitas then
        local judul = aktivitas.sendiri and "Under construction" or aktivitas.nama
        teks(judul, x, y + 15, 12, nil, nil, w * .4)
        bar(x + w * .43, y + 13, w * .40, 6, aktivitas.progres, kekurangan and warna.besi or warna.aksen)
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
    local w = math.min(r.w, lebarTeks(pesan, 13) + 24)
    sudut(r.x, 168, w, 28, 5, warna.gelap)
    teks(pesan, r.x + 12, 177, 13, warna.besi, nil, w - 24)
end

local function gambarStok(dataStok, nama, x, y, w, c)
    kotak(x, y, w, 52, warna.lapis)
    kotak(x, y + 7, 2, 38, c)
    judul(nama, x + 9, y + 35, 13, c)
    teks(laju(dataStok.net), x + w - 7, y + 36, 10, dataStok.net < 0 and warna.merah or warna.sehat, "r")
    judul(angka(dataStok.stok), x + 9, y + 15, 18)
    teks("/ " .. angka(dataStok.muat), x + w - 7, y + 17, 10, warna.redup, "r")
    bar(x + 7, y + 6, w - 14, 4, dataStok.stok / math.max(1, dataStok.muat), c)
end

local function gambarKanan(r)
    panel(r)
    local x, y = r.x + 12, r.y
    judul("RESOURCES", x, y + 123, 11, warna.redup)
    judul("MAP", r.x + 158, y + 127, 11, warna.redup)
    gambarStok(data.besi, "Iron", x, y + 63, 134, warna.besi)
    gambarStok(data.energi, "Energy", x, y + 8, 134, warna.energi)
    local m = layout.peta
    kotak(m.x - 2, m.y - 2, m.w + 4, m.h + 4, warna.bingkai)
    kotak(m.x, m.y, m.w, m.h, warna.gelap)
end

-- Deathmatch (mode_hancur): jumlah Command Core tersisa per kubu, tanpa titik dan skor.
local function gambarDeathmatch(r, warnaTim)
    local x, y, w = r.x, r.y, r.w
    local tengah = x + w * .5
    local detik = math.floor(sp.GetGameFrame() / Game.gameSpeed)
    judul("DEATHMATCH", tengah, y + 62, 13, warna.putih, "c")
    teks(string.format("%02d:%02d", math.floor(detik / 60), detik % 60), tengah, y + 46, 11, warna.redup, "c")
    for tim = 0, 1 do
        local c = warnaTim[tim]
        local hidup = sp.GetGameRulesParam("markas_hidup_" .. tim) or 0
        local awal = math.max(1, sp.GetGameRulesParam("markas_awal_" .. tim) or 1)
        local kiri = tim == 0 and x + 13 or x + w - 127
        judul(tim == 0 and "BLUE" or "RED", kiri + 57, y + 66, 11, c, "c")
        judul(string.format("%d / %d", hidup, awal), kiri + 57, y + 45, 21, warna.putih, "c")
        bar(kiri, y + 38, 114, 3, hidup / awal, c)
    end
    teks("Destroy every enemy Command Core", tengah, y + 15, 11, warna.redup, "c")
end

local function gambarSkor(r, aturan, status, warnaTim)
    panel(r)
    if sp.GetGameRulesParam("mode_hancur") == 1 then return gambarDeathmatch(r, warnaTim) end
    local x, y, w = r.x, r.y, r.w
    local tengah = x + w * .5
    local detik = math.floor(sp.GetGameFrame() / Game.gameSpeed)
    judul("CONTROL POINTS", tengah, y + 62, 13, warna.putih, "c")
    teks(string.format("%02d:%02d · %s points", math.floor(detik / 60), detik % 60, angka(aturan.targetSkor)),
        tengah, y + 46, 11, warna.redup, "c")
    for tim = 0, 1 do
        local c = warnaTim[tim]
        local skor = sp.GetGameRulesParam("titik_skor_" .. tim) or 0
        local awal = tim == 0 and x + 13 or x + w - 127
        judul(tim == 0 and "BLUE" or "RED", awal + 57, y + 66, 11, c, "c")
        judul(angka(skor), awal + 57, y + 45, 21, warna.putih, "c")
        bar(awal, y + 38, 114, 3, math.min(1, skor / aturan.targetSkor), c)
    end
    local chip = (w - 31 - 3 * 7) / 4
    for i, t in ipairs(aturan.titik) do
        local bx = x + 15 + (i - 1) * (chip + 7)
        local c, label, nilai = status(t)
        kotak(bx, y + 9, chip, 22, warna.lapis)
        if nilai > 0 then bar(bx, y + 9, chip, 2, nilai, c) end
        judul(t.nama, bx + 8, y + 14, 14, c)
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
    judul(caption, x + 180, y + 103, 30, warnaTim[hasil] or warna.putih, "c")
    if sp.GetGameRulesParam("mode_hancur") == 1 then
        a = sp.GetGameRulesParam("markas_hidup_0") or 0
        b = sp.GetGameRulesParam("markas_hidup_1") or 0
        teks("Command Cores left  Blue " .. a .. "  /  " .. b .. " Red", x + 180, y + 77, 15, warna.redup, "c")
    else
        teks("Blue  " .. angka(a) .. "   /   " .. angka(b) .. "  Red", x + 180, y + 77, 15, warna.redup, "c")
    end
    if mulaiUlang then
        local bx = kembaliMenu and x + 23 or x + 111
        sudut(bx, y + 22, 138, 34, 4, warna.aksen)
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

-- Info kartu produksi (hover 1 detik, keputusan user 2026-11-26): nama, tipe, statistik singkat.
local hoverDef, hoverMulai
local function satu(v) return (string.format("%.1f", v):gsub("%.0$", "")) end
local function infoKartu(def, hit, lebarLayar)
    local baris = {}
    local function tambah(kiri, kanan, c) baris[#baris + 1] = {kiri, kanan, c} end
    local armor = namaArmor[def.armorType]
    tambah("HP", angka(def.health))
    tambah("Armor", armor == "berat" and "Heavy" or (armor == "bangunan" and "Structure" or "Light"))
    if def.speed and def.speed > 0 then tambah("Speed", satu(def.speed / elmoPerMeter) .. " m/s") end
    local w = def.weapons[1] and WeaponDefs[def.weapons[1].weaponDef]
    if w then
        local burst = (w.salvoSize or 1) > 1 and (" ×" .. w.salvoSize) or ""
        local ringan = w.damages[0] or 0
        local berat = Game.armorTypes and Game.armorTypes.berat and w.damages[Game.armorTypes.berat] or ringan
        tambah("Damage", angka(ringan) .. burst .. " light · " .. angka(berat) .. burst .. " heavy")
        tambah("Reload", satu(w.reload) .. " s")
        local maks, mini = batasSenjata(def)
        tambah("Range", (mini > 0 and (angka(mini / elmoPerMeter) .. "–") or "") .. angka(maks / elmoPerMeter) .. " m")
    end
    tambah("Cost", angka(def.metalCost) .. " iron · " .. angka(def.energyCost) .. " energy")
    tambah("Build time", satu(def.buildTime / 30) .. " s")
    local nama = sandi[def.name] and sandi[def.name][2] or def.humanName
    local w0, h = 236, 52 + #baris * 15
    local x = math.max(8, math.min(hit.x + hit.w / 2 - w0 / 2, lebarLayar - w0 - 8))
    local y = layout.tengah.y + layout.tengah.h + 10
    sudut(x, y - 2, w0, h, 6, {0, 0, 0, .35})
    sudut(x, y, w0, h, 6, warna.bingkai)
    sudut(x + 1, y + 1, w0 - 2, h - 2, 5, warna.panel)
    kotak(x + 1, y + h - 3, w0 - 2, 2, warna.aksen)
    local geser = ikonUnit[def.name] and 22 or 0
    simbol(def, x + 10, y + h - 25, 18, warna.aksen)
    judul(nama, x + 12 + geser, y + h - 22, 15, warna.putih, nil, w0 - 24 - geser)
    local tipe = (def.tooltip and def.tooltip ~= "" and def.tooltip ~= def.humanName) and def.tooltip or peran[def.name] or ""
    teks((sandi[def.name] and (def.humanName .. " · ") or "") .. tipe, x + 12, y + h - 38, 10.5,
        warna.redup, nil, w0 - 24)
    kotak(x + 12, y + h - 45, w0 - 24, 1, warna.garis)
    for i, b in ipairs(baris) do
        local by = y + h - 47 - i * 15
        teks(b[1], x + 12, by, 10.5, warna.redup)
        teks(b[2], x + w0 - 12, by, 10.5, b[3] or warna.putih, "r", w0 - 90)
    end
end

function hud.Draw(lebar, tinggi, aturan, status, warnaTim)
    if not aktif or not data or sp.IsGUIHidden() then return end
    panelPos(lebar, tinggi)
    local s = layout.skala
    S = s
    local mx, my = sp.GetMouseState()
    mx, my = mx / s, my / s
    aksi = {}
    gambarPilihan(layout.kiri, mx, my)
    gambarTombol(layout.tengah, mx, my)
    gambarKanan(layout.kanan)
    gambarSkor(layout.skor, aturan, status, warnaTim)
    gl.Color(1, 1, 1, 1)
    gl.DrawMiniMap()

    local m = layout.peta
    for _, titik in ipairs(aturan.titik) do
        local x = m.x + titik.x / Game.mapSizeX * m.w
        local y = m.y + (1 - titik.z / Game.mapSizeZ) * m.h
        kotak(x - 6, y - 6, 12, 12, warna.gelap)
        judul(titik.nama, x, y - 3.5, 10, status(titik), "c")
    end
    gambarHasil(sp.GetGameRulesParam("titik_pemenang"), warnaTim, lebar / s, tinggi / s)
    gambarPesan()
    gl.Color(1, 1, 1, 1)

    local adaHover
    for _, hit in ipairs(aksi) do
        if hit.def and dalam(hit, mx, my) then
            adaHover = true
            if hoverDef ~= hit.def.id then hoverDef, hoverMulai = hit.def.id, sp.GetTimer() end
            if sp.DiffTimers(sp.GetTimer(), hoverMulai) >= 1 then
                infoKartu(hit.def, hit, lebar / s)
                break
            end
        end
    end
    if not adaHover then hoverDef = nil end
    for _, hit in ipairs(aksi) do
        if not pesan and not (hoverDef and sp.DiffTimers(sp.GetTimer(), hoverMulai) >= 1)
            and hit.petunjuk and dalam(hit, mx, my) then
            local lebarTip = math.min(375, lebarTeks(hit.petunjuk, 12) + 22)
            local x = math.min(hit.x, lebar / s - lebarTip - 16)
            sudut(x, 168, lebarTip, 26, 4, warna.gelap)
            teks(hit.petunjuk, x + 10, 177, 12, warna.putih, nil, lebarTip - 20)
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
