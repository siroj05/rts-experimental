-- Health bar di atas unit (tahap 8, 🟡 2026-11-24). Tampil untuk unit yang rusak, yang dipilih, dan yang sedang
-- dibangun (bar biru = progres). Tidak tampil saat unit digambar sebagai ikon zoom jauh. Bar menghadap kamera dan
-- lebarnya mengikuti ukuran unit.
local sp = Spring
local batang = {}

local tinggi, lebarCache = {}, {}
local function ukuran(def)
    if not lebarCache[def] then
        local ud = UnitDefs[def]
        lebarCache[def] = math.max(12, math.min(40, ud.radius * .85))
        tinggi[def] = ud.height + 6
    end
    return lebarCache[def], tinggi[def]
end

local function warnaHp(f)
    if f > .6 then return .35, .86, .38 end
    if f > .3 then return .95, .78, .25 end
    return .95, .32, .24
end

local function gambar(w, f, r, g, b, bangun)
    local h = 2.6
    gl.Color(.05, .06, .06, .78)
    gl.Rect(-w / 2 - 1, -1, w / 2 + 1, h + 1)
    gl.Color(r, g, b, .95)
    gl.Rect(-w / 2, 0, -w / 2 + w * f, h)
    if bangun then
        gl.Color(.35, .65, 1, .95)
        gl.Rect(-w / 2, h + 1.5, -w / 2 + w * bangun, h + 3.2)
    end
end

function batang.DrawWorld()
    if sp.GetConfigInt("RTSPCHealthBars", 1) <= 0 then return end
    local dipilih = {}
    for _, u in ipairs(sp.GetSelectedUnits()) do dipilih[u] = true end
    gl.DepthTest(true)
    for _, u in ipairs(sp.GetVisibleUnits(-1, 30, false)) do
        local hp, maks, _, _, progres = sp.GetUnitHealth(u)
        if hp and maks and maks > 0 and not sp.IsUnitIcon(u) then
            local f = hp / maks
            local bangun = progres and progres < 1 and progres or nil
            if f < .999 or dipilih[u] or bangun then
                local def = sp.GetUnitDefID(u)
                local w, y = ukuran(def)
                local r, g, b = warnaHp(f)
                gl.DrawFuncAtUnit(u, false, function()
                    gl.Translate(0, y, 0)
                    gl.Billboard()
                    gambar(w, f, r, g, b, bangun)
                end)
            end
        end
    end
    gl.Color(1, 1, 1, 1)
end

return batang
