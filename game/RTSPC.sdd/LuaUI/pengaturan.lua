-- Menu pengaturan (tahap 9, 🟡 2026-11-24), dibuka dari menu jeda. Nilai disimpan ke springsettings.cfg lewat
-- Spring.SetConfig* sehingga bertahan antarsesi, dan langsung diterapkan:
-- volume (snd_volmaster, snd_volbattle), jarak ikon unit (disticon), bayangan (/shadows), kecepatan zoom kamera
-- (ScrollWheelSpeed), dan health bar di atas unit (RTSPCHealthBars, dibaca LuaUI/batang_hp.lua).
local sp = Spring
local p = {}

local function persen(v) return string.format("%d%%", v) end
local baris = {
    {label = "Master Volume", kunci = "snd_volmaster", jenis = "int", min = 0, maks = 100, langkah = 10, bawaan = 100, tampil = persen},
    {label = "Battle Volume", kunci = "snd_volbattle", jenis = "int", min = 0, maks = 100, langkah = 10, bawaan = 100, tampil = persen},
    {label = "Unit Icons", kunci = "UnitIconDist", jenis = "int", pilihan = {30, 50, 80, 120, 10000}, bawaan = 120, -- ✅ user 2026-11-26: Very Far (±411 m kamera-unit)
        tampil = function(v) return ({[30] = "Near", [50] = "Normal", [80] = "Far", [120] = "Very Far", [10000] = "Off"})[v] or tostring(v) end,
        terapkan = function(v) sp.SendCommands("disticon " .. v) end},
    {label = "Shadows", kunci = "Shadows", jenis = "int", pilihan = {0, 1}, bawaan = 1,
        tampil = function(v) return v > 0 and "On" or "Off" end,
        terapkan = function(v) sp.SendCommands("shadows " .. v) end},
    -- ScrollWheelSpeed bawaan Recoil -25: tanda menentukan arah zoom, jadi hanya besarnya yang diubah.
    {label = "Zoom Speed", kunci = "ScrollWheelSpeed", jenis = "float", pilihan = {12, 25, 40, 60}, bawaan = -25, bertanda = true,
        tampil = function(v) return ({[12] = "Slow", [25] = "Normal", [40] = "Fast", [60] = "Very Fast"})[v] or tostring(v) end},
    {label = "Health Bars", kunci = "RTSPCHealthBars", jenis = "int", pilihan = {0, 1}, bawaan = 1,
        tampil = function(v) return v > 0 and "On" or "Off" end},
}
p.baris = baris

local function baca(b)
    local v = b.jenis == "float" and sp.GetConfigFloat(b.kunci, b.bawaan) or sp.GetConfigInt(b.kunci, b.bawaan)
    if b.bertanda then v = math.abs(v) end
    if b.pilihan then
        -- Nilai di luar daftar dibulatkan ke pilihan terdekat untuk ditampilkan.
        local terbaik = b.pilihan[1]
        for _, c in ipairs(b.pilihan) do if math.abs(c - v) < math.abs(terbaik - v) then terbaik = c end end
        return terbaik
    end
    return v
end

local function tulis(b, v)
    if b.bertanda then
        local lama = sp.GetConfigFloat(b.kunci, b.bawaan)
        if lama < 0 then v = -v end
    end
    if b.jenis == "float" then sp.SetConfigFloat(b.kunci, v) else sp.SetConfigInt(b.kunci, v) end
    if b.terapkan then b.terapkan(v) end
end

-- arah: -1 kiri, +1 kanan
function p.Ubah(i, arah)
    local b = baris[i]
    if not b then return end
    local v = baca(b)
    if b.pilihan then
        local idx = 1
        for k, c in ipairs(b.pilihan) do if c == v then idx = k end end
        idx = math.max(1, math.min(#b.pilihan, idx + arah))
        v = b.pilihan[idx]
    else
        v = math.max(b.min, math.min(b.maks, v + arah * b.langkah))
    end
    tulis(b, v)
end

function p.Nilai(i)
    local b = baris[i]
    return b.tampil(baca(b))
end

function p.BarHidup() return sp.GetConfigInt("RTSPCHealthBars", 1) > 0 end

return p
