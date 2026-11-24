-- Gadget pencatat uji ronde (tools/uji_ronde.py). Hanya dipasang di salinan uji, bukan bagian game.
-- Tiap 60 detik game: per tim jumlah unit tempur/bangunan/insinyur, stok dan pemasukan, skor, pemilik titik.
-- Juga mencatat unit yang mati per tim, waktu pertempuran pertama, dan hasil akhir.
function gadget:GetInfo()
    return {name = "Uji Ronde Catat", desc = "Logs match statistics for tools/uji_ronde.py", layer = 99, enabled = true}
end
if not gadgetHandler:IsSyncedCode() then return end

local sp = Spring
local opsi = sp.GetModOptions()
local batasMenit = tonumber(opsi.uji_menit or "30")
local aturan = VFS.Include("gamedata/skenario.lua")
local mati, rusakPertama = {}, nil
local tempur = {}
for id, def in pairs(UnitDefs) do
    if def.customParams.duduki == "1" then tempur[id] = true end
end

local function log(...) sp.Echo("RONDE, " .. table.concat({...}, ", ")) end

function gadget:UnitDamaged(unit, def, tim, damage, para, weapon, attacker)
    if not rusakPertama and attacker and damage > 0 and tempur[def] then
        rusakPertama = sp.GetGameFrame()
        log("KONTAK", string.format("%.0f", rusakPertama / 30))
    end
end

function gadget:UnitDestroyed(unit, def, tim)
    if tempur[def] then mati[tim] = (mati[tim] or 0) + 1 end
end

local function ringkas(frame)
    local detik = frame / 30
    for _, tim in ipairs(sp.GetTeamList()) do
        if tim ~= sp.GetGaiaTeamID() then
            local nTempur, nBangun, nKerja, jenis = 0, 0, 0, {}
            for _, u in ipairs(sp.GetTeamUnits(tim)) do
                local def = UnitDefs[sp.GetUnitDefID(u)]
                if not sp.GetUnitIsBeingBuilt(u) then
                    if tempur[def.id] then
                        nTempur = nTempur + 1
                        jenis[def.name] = (jenis[def.name] or 0) + 1
                    elseif def.isBuilding or def.speed == 0 then nBangun = nBangun + 1
                    else nKerja = nKerja + 1 end
                end
            end
            local m, _, _, mIn = sp.GetTeamResources(tim, "metal")
            local e, _, _, eIn = sp.GetTeamResources(tim, "energy")
            local daftar = {}
            for k, v in pairs(jenis) do daftar[#daftar + 1] = k .. "=" .. v end
            table.sort(daftar)
            log("TIM", string.format("%.0f", detik), tim, "tempur=" .. nTempur, "bangunan=" .. nBangun,
                "insinyur=" .. nKerja, "mati=" .. (mati[tim] or 0), string.format("besi=%.0f+%.1f", m, mIn),
                string.format("energi=%.0f+%.1f", e, eIn), table.concat(daftar, " "))
        end
    end
    if aturan and aturan.titik then
        local pemilik = {}
        for _, t in ipairs(aturan.titik) do
            pemilik[#pemilik + 1] = t.nama .. "=" .. tostring(sp.GetGameRulesParam("titik_" .. t.nama .. "_pemilik"))
        end
        log("SKOR", string.format("%.0f", detik), tostring(sp.GetGameRulesParam("titik_skor_0")),
            tostring(sp.GetGameRulesParam("titik_skor_1")), table.concat(pemilik, " "))
    end
end

local insinyur = UnitDefNames.robot_insinyur.id
local function lacakInsinyur(frame)
    for _, tim in ipairs(sp.GetTeamList()) do
        for _, u in ipairs(sp.GetTeamUnitsByDefs(tim, insinyur)) do
            local x, _, z = sp.GetUnitPosition(u)
            local cmds = sp.GetUnitCommands(u, 1)
            local c = cmds and cmds[1]
            log("INSINYUR", string.format("%.0f", frame / 30), tim, string.format("%.0f,%.0f", x, z),
                c and (tostring(c.id) .. "@" .. table.concat(c.params, "/")) or "diam")
        end
    end
end

function gadget:GameFrame(frame)
    if frame > 0 and frame % 1800 == 0 then ringkas(frame) end
    if opsi.uji_lacak == "1" and frame > 0 and frame % 900 == 0 then lacakInsinyur(frame) end
    local menang = sp.GetGameRulesParam("titik_pemenang")
    local selesai = (menang and menang ~= -1) or sp.IsGameOver()
    if selesai or frame >= batasMenit * 1800 then
        ringkas(frame)
        log("HASIL", string.format("%.0f", frame / 30), "pemenang=" .. tostring(menang), "kontak=" .. tostring(rusakPertama and rusakPertama / 30))
        log("SELESAI")
        gadgetHandler:RemoveGadget(self)
    end
end
