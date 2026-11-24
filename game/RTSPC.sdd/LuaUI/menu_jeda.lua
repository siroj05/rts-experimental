local sp = Spring
local menu = {terbuka = false}
local pilihan = {"Resume", "Settings", "Restart Match", "Back to Skirmish"}
local atur = VFS.Include("LuaUI/pengaturan.lua")
local kiri, kanan = sp.GetKeyCode("left"), sp.GetKeyCode("right")
local modeAtur = false
local arang = {0.095, 0.102, 0.09, 1}
local garis = {0.27, 0.29, 0.24, 1}
local kertas = {0.95, 0.90, 0.79, 1}
local redup = {0.72, 0.73, 0.65, 1}
local jingga = {0.94, 0.65, 0.39, 1}
local esc, atas, bawah, enter, enterNumpad = sp.GetKeyCode("escape"), sp.GetKeyCode("up"),
    sp.GetKeyCode("down"), sp.GetKeyCode("return"), sp.GetKeyCode("numpad_enter")
local lebar, tinggiMenu, tinggiAtur = 396, 332, 420
local tinggi = tinggiMenu
local fokus, konfirmasi, ditekan, ditekanSisi
local mulaiUlang, kembali

local function kotak(x, y, w, h, warna)
    gl.Color(warna)
    gl.Rect(x, y, x + w, y + h)
end

local function teks(s, x, y, ukuran, warna, rata)
    gl.Color(warna)
    gl.Text(s, x, y, ukuran, rata or "")
end

local function posisi()
    local w, h = sp.GetViewGeometry()
    local skala = math.min(w / 1280, h / 720, 2.5)
    return skala, (w - lebar * skala) / 2, (h - tinggi * skala) / 2, w, h
end

local function jumlahBaris()
    if modeAtur then return #atur.baris + 1 end
    return konfirmasi and 2 or #pilihan
end

local function dasarBaris(i)
    if modeAtur then return tinggi - 128 - (i - 1) * 40 end
    return tinggi - 128 - (i - 1) * 48
end

-- Mengembalikan indeks baris dan sisi (-1 kiri / +1 kanan pada kolom nilai pengaturan).
local function tombolPada(x, y)
    local skala, ox, oy = posisi()
    x, y = (x - ox) / skala, (y - oy) / skala
    if x < 24 or x >= lebar - 24 then return end
    for i = 1, jumlahBaris() do
        local dasar = dasarBaris(i)
        if y >= dasar and y < dasar + (modeAtur and 36 or 42) then
            return i, x < lebar - 110 and -1 or 1
        end
    end
end

local function tutup()
    menu.terbuka, ditekan = false, nil
    sp.SendCommands("pause 0")
end

local function bukaAtur(buka)
    modeAtur, fokus, konfirmasi = buka, buka and 1 or 2, nil
    tinggi = buka and tinggiAtur or tinggiMenu
end

local function pilih(i, sisi)
    ditekan = nil
    if modeAtur then
        if i > #atur.baris then bukaAtur(false) else atur.Ubah(i, sisi or 1) end
        return
    end
    if konfirmasi then
        if i == 2 then
            local tindakan = konfirmasi == 3 and mulaiUlang or kembali
            menu.terbuka = false
            tindakan()
        else
            fokus, konfirmasi = konfirmasi, nil
        end
    elseif i == 1 then
        tutup()
    elseif i == 2 then
        bukaAtur(true)
    else
        konfirmasi, fokus = i, 1
    end
end

function menu.Buka(restart, back)
    mulaiUlang, kembali = restart, back
    menu.terbuka, fokus, konfirmasi, ditekan = true, 1, nil, nil
    modeAtur, tinggi = false, tinggiMenu
    sp.SendCommands("pause 1")
end

function menu.KeyPress(key, ulang)
    if key == esc and not ulang then
        if modeAtur then bukaAtur(false) elseif konfirmasi then pilih(1) else tutup() end
    elseif key == atas or key == bawah then
        fokus = math.max(1, math.min(jumlahBaris(), fokus + (key == atas and -1 or 1)))
    elseif modeAtur and (key == kiri or key == kanan) and fokus <= #atur.baris then
        atur.Ubah(fokus, key == kiri and -1 or 1)
    elseif (key == enter or key == enterNumpad) and not ulang then
        pilih(fokus)
    end
    return true
end

function menu.MousePress(x, y, button)
    if button == 1 then ditekan, ditekanSisi = tombolPada(x, y) end
    return true
end

function menu.MouseRelease(x, y, button)
    if button == 1 then
        if ditekan and ditekan == tombolPada(x, y) then pilih(ditekan, ditekanSisi) end
        ditekan = nil
    end
    return true
end

function menu.Draw()
    local skala, ox, oy, w, h = posisi()
    local hover = tombolPada(sp.GetMouseState())
    kotak(0, 0, w, h, {0.033, 0.038, 0.029, 0.73})
    gl.PushMatrix()
    gl.Translate(ox, oy, 0)
    gl.Scale(skala, skala, 1)
    kotak(5, -5, lebar, tinggi, {0.018, 0.021, 0.017, 0.8})
    kotak(0, 0, lebar, tinggi, arang)
    kotak(0, tinggi - 2, lebar, 2, jingga)

    if modeAtur then
        teks("Settings", 24, tinggi - 58, 32, kertas)
        teks("Left/Right or click to change", 24, tinggi - 80, 13, redup)
        for i = 1, jumlahBaris() do
            local y = dasarBaris(i)
            local aktif = i == fokus or i == hover
            if aktif then kotak(24, y, lebar - 48, 36, {0.25, 0.24, 0.18, 1}) end
            kotak(24, y, lebar - 48, 1, aktif and jingga or garis)
            if i <= #atur.baris then
                teks(atur.baris[i].label, 37, y + 12, 15, aktif and kertas or redup)
                teks("<  " .. atur.Nilai(i) .. "  >", lebar - 37, y + 12, 15, aktif and jingga or kertas, "r")
            else
                teks("Back", 37, y + 12, 15, aktif and kertas or redup)
            end
        end
        teks("Esc  Back", lebar - 24, 18, 13, redup, "r")
        gl.PopMatrix()
        gl.Color(1, 1, 1, 1)
        return
    end
    local judul = konfirmasi and (konfirmasi == 3 and "Restart Match?" or "Leave Match?") or "Match Paused"
    teks(judul, 24, tinggi - 58, 32, kertas)
    if konfirmasi then teks("Progress in this match will be lost.", 24, tinggi - 81, 14, redup) end
    local daftar = konfirmasi and {"Cancel", pilihan[konfirmasi]} or pilihan
    for i, label in ipairs(daftar) do
        local y = dasarBaris(i)
        local aktif = i == fokus or i == hover
        if aktif then kotak(24, y, lebar - 48, 42, {0.25, 0.24, 0.18, 1}) end
        kotak(24, y, lebar - 48, 1, aktif and jingga or garis)
        teks(label, 37, y + 14, 17, aktif and kertas or redup)
    end
    teks(konfirmasi and "Esc  Cancel" or "Esc  Resume", lebar - 24, 18, 13, redup, "r")
    gl.PopMatrix()
    gl.Color(1, 1, 1, 1)
end

return menu
