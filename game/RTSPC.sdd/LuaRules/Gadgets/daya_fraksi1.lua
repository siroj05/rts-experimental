function gadget:GetInfo()
    return {name = "Faction 1 Power", desc = "Powers radar and defense using relays and substations", enabled = true}
end
if not gadgetHandler:IsSyncedCode() then return false end

local sp, defs = Spring, UnitDefNames
local markas, relay, gardu = defs.inti_komando.id, defs.tiang_relay.id, defs.gardu.id
local radar, menara = defs.radar.id, defs.menara_pertahanan.id
local cakupan = {[markas] = 46 * 8, [relay] = 24 * 8, [gardu] = 19 * 8}
local biaya = {[gardu] = 5, [radar] = 4, [menara] = 5}
local jaringan, aktif = {}, {}

local function dekat(a, b, radius)
    return (a.x - b.x)^2 + (a.z - b.z)^2 <= radius^2
end

local function status(unit, nyala)
    if aktif[unit.id] == nyala then return end
    aktif[unit.id] = nyala
    sp.SetUnitRulesParam(unit.id, "daya_fraksi1", nyala and 1 or 0, {allied = true})
    if unit.def == radar then sp.SetUnitSensorRadius(unit.id, "radar", nyala and 800 * 8 or 0) end
end

local function dayaTim(units)
    local sumber, relays, beban, tersambung = {}, {}, {}, {}
    for _, unit in ipairs(units) do
        local def = unit.def
        if def == markas then
            sumber[#sumber + 1] = unit
        elseif def == relay then
            relays[#relays + 1] = unit
        elseif def == gardu then
            local nyala = sp.UseUnitResource(unit.id, "e", biaya[def])
            status(unit, nyala)
            if nyala then beban[#beban + 1] = unit end
        else
            beban[#beban + 1] = unit
        end
    end

    -- Relay hanya meneruskan jaringan dari markas. Gardu memberi jangkauan lokal.
    local i = 1
    while i <= #sumber do
        local a = sumber[i]
        for _, b in ipairs(relays) do
            local jarak = math.max(cakupan[a.def], (25 + (a.def == markas and 12 or 4) + 4) * 8)
            if not tersambung[b.id] and dekat(a, b, jarak) then
                tersambung[b.id] = true
                sumber[#sumber + 1] = b
            end
        end
        i = i + 1
    end
    for _, unit in ipairs(relays) do status(unit, tersambung[unit.id] == true) end
    for _, unit in ipairs(beban) do
        if unit.def == gardu then sumber[#sumber + 1] = unit end
    end
    for _, unit in ipairs(beban) do
        if unit.def ~= gardu then
            local nyala = false
            for _, a in ipairs(sumber) do
                if dekat(a, unit, cakupan[a.def]) then
                    nyala = sp.UseUnitResource(unit.id, "e", biaya[unit.def])
                    break
                end
            end
            status(unit, nyala)
        end
    end
end

function gadget:UnitFinished(id, def)
    if cakupan[def] or biaya[def] then jaringan[id] = def end
end

function gadget:UnitDestroyed(id)
    jaringan[id], aktif[id] = nil, nil
end

function gadget:GameFrame(frame)
    if frame % Game.gameSpeed ~= 0 then return end
    local perTim = {}
    for id, def in pairs(jaringan) do
        local team = sp.GetUnitTeam(id)
        local x, _, z = sp.GetUnitPosition(id)
        perTim[team] = perTim[team] or {}
        local units = perTim[team]
        units[#units + 1] = {id = id, def = def, x = x, z = z}
    end
    for _, units in pairs(perTim) do
        -- Urutan stabil saat beberapa bangunan berebut sisa energi.
        table.sort(units, function(a, b) return a.id < b.id end)
        dayaTim(units)
    end
end
