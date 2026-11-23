function gadget:GetInfo()
    return {name = "Control Points", desc = "Scores control points for the 1v1 scenario", layer = 2, enabled = true}
end

if not gadgetHandler:IsSyncedCode() then
    return
end

local aturan = VFS.Include("gamedata/skenario.lua")
if not aturan then return false end
local langkah = Game.gameSpeed / 2
local durasi = aturan.detikRebut * Game.gameSpeed
local penangkap = {}
for id, def in pairs(UnitDefs) do
    if def.customParams.duduki == "1" then penangkap[id] = true end
end
local pakaiMarkas = Spring.GetModOptions().ekonomi == "1"
local markas = UnitDefNames.inti_komando.id
local skor = {[0] = 0, [1] = 0}
local titik = aturan.titik
local selesai = false

local function umumkan(t)
    Spring.SetGameRulesParam(t.kunci .. "_pemilik", t.pemilik)
    Spring.SetGameRulesParam(t.kunci .. "_penantang", t.penantang)
    Spring.SetGameRulesParam(t.kunci .. "_progres", t.progres / durasi)
    Spring.SetGameRulesParam(t.kunci .. "_rebutan", t.rebutan and 1 or 0)
end

function gadget:GameStart()
    for _, t in ipairs(titik) do
        t.kunci = "titik_" .. t.nama
        t.pemilik, t.penantang, t.progres, t.rebutan = -1, -1, 0, false
        umumkan(t)
    end
    Spring.SetGameRulesParam("titik_skor_0", 0)
    Spring.SetGameRulesParam("titik_skor_1", 0)
    Spring.SetGameRulesParam("titik_pemenang", -1)
end

local function periksa(t)
    local barat, timur = false, false
    for _, unit in ipairs(Spring.GetUnitsInCylinder(t.x, t.z, aturan.radius)) do
        if penangkap[Spring.GetUnitDefID(unit)] and not Spring.GetUnitIsDead(unit)
            and not Spring.GetUnitIsBeingBuilt(unit) then
            local tim = Spring.GetUnitTeam(unit)
            barat = barat or tim == 0
            timur = timur or tim == 1
        end
    end

    t.rebutan = barat and timur
    if not t.rebutan then
        local tim = barat and 0 or (timur and 1 or -1)
        if tim == -1 or tim == t.pemilik then
            t.penantang, t.progres = -1, 0
        else
            if tim ~= t.penantang then
                t.penantang, t.progres = tim, 0
            else
                t.progres = t.progres + langkah
            end
            if t.progres >= durasi then
                t.pemilik, t.penantang, t.progres = tim, -1, 0
            end
        end
    end
    umumkan(t)
end

local function akhiri(pemenang)
    selesai = true
    Spring.SetGameRulesParam("titik_pemenang", pemenang)
    if pemenang == -2 then
        Spring.GameOver({Spring.GetTeamAllyTeamID(0), Spring.GetTeamAllyTeamID(1)})
    else
        Spring.GameOver({Spring.GetTeamAllyTeamID(pemenang)})
    end
end

function gadget:GameFrame(frame)
    if selesai or frame == 0 or frame % langkah ~= 0 then return end
    if pakaiMarkas then
        local baratHancur = Spring.GetTeamUnitDefCount(0, markas) == 0
        local timurHancur = Spring.GetTeamUnitDefCount(1, markas) == 0
        if baratHancur or timurHancur then
            akhiri(baratHancur and timurHancur and -2 or (baratHancur and 1 or 0))
            return
        end
    end

    for _, t in ipairs(titik) do
        periksa(t)
    end
    if frame % Game.gameSpeed ~= 0 then return end

    for _, t in ipairs(titik) do
        if t.pemilik >= 0 and not t.rebutan and t.penantang == -1 then
            skor[t.pemilik] = math.min(aturan.targetSkor, skor[t.pemilik] + aturan.poinPerDetik)
        end
    end
    for tim = 0, 1 do
        Spring.SetGameRulesParam("titik_skor_" .. tim, skor[tim])
    end

    local baratMenang = skor[0] == aturan.targetSkor
    local timurMenang = skor[1] == aturan.targetSkor
    if baratMenang and timurMenang then
        akhiri(-2)
    elseif baratMenang or timurMenang then
        akhiri(baratMenang and 0 or 1)
    elseif Spring.GetTeamUnitCount(0) == 0 and Spring.GetTeamUnitCount(1) == 0 then
        akhiri(-2)
    end
end
