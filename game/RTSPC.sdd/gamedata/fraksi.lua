-- Identitas lintas fraksi untuk gadget, AI, dan LuaUI (✅ user 2026-11-28: "kerjain semuanya", integrasi Fraksi 2).
-- Unit Fraksi 2 menyimpan kunci Fraksi 1 padanannya di customParams.dasar (mis. medium_tank_f2 -> medium_tank).
-- Aturan yang mengenali unit lewat nama memakai F.nama / F.dasar supaya berlaku untuk kedua fraksi.
-- Fraksi tim diatur modoption fraksi_<tim> ("2" = Fraksi 2; bawaan Fraksi 1).
local F = {}

-- defID -> defID dasar (Fraksi 1). Unit tanpa padanan (Heavy Tank) menunjuk dirinya sendiri.
F.dasar = {}
for id, ud in pairs(UnitDefs) do
    local d = ud.customParams.dasar
    F.dasar[id] = d and UnitDefNames[d] and UnitDefNames[d].id or id
end

-- Nama dasar sebuah def (nil kalau def tidak ada).
function F.nama(defID)
    local ud = UnitDefs[defID]
    return ud and (ud.customParams.dasar or ud.name)
end

-- Semua defID yang berdasar pada kunci Fraksi 1 `nama` (kunci itu sendiri dan versi Fraksi 2-nya).
function F.semua(nama)
    local hasil = {}
    for id in pairs(UnitDefs) do
        if F.nama(id) == nama then hasil[#hasil + 1] = id end
    end
    return hasil
end

-- Set {defID = true} dari F.semua.
function F.set(nama)
    local hasil = {}
    for _, id in ipairs(F.semua(nama)) do hasil[id] = true end
    return hasil
end

function F.tim(tim)
    return Spring.GetModOptions()["fraksi_" .. tim] == "2" and 2 or 1
end

-- Kunci dasar -> kunci Fraksi 2 (robot_insinyur -> tank_insinyur_f2, heavy_tank_f2 -> dirinya).
local versiF2 = {}
for _, ud in pairs(UnitDefs) do
    if ud.customParams.fraksi == "2" then versiF2[ud.customParams.dasar or ud.name] = ud.name end
end

-- Kunci unit yang dipakai tim untuk peran `nama`. Fraksi 2 memakai versinya kalau ada, selain itu unit bersama
-- (ekstraktor, pompa, radar, artileri). Unit khusus Fraksi 2 tidak tersedia untuk Fraksi 1 (nil).
function F.kunci(tim, nama)
    local ud = UnitDefNames[nama]
    if F.tim(tim) == 2 then return versiF2[nama] or (ud and nama) end
    if ud and ud.customParams.fraksi == "2" then return nil end
    return ud and nama
end

function F.versi(tim, nama)
    local kunci = F.kunci(tim, nama)
    return kunci and UnitDefNames[kunci] and UnitDefNames[kunci].id
end

return F
