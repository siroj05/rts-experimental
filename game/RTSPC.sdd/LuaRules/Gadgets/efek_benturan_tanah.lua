function gadget:GetInfo()
    return {name = "Impact FX", desc = "Baked impact effects with 3D fragments", layer = 0, enabled = true}
end

local sp = Spring
local aksi = "rts_benturan"
local audio = "rts_suara_benturan"
local tanahAtlas = "bitmaps/fx/ledakan-tanah.png"
local bajaAtlas = "bitmaps/fx/benturan-baja.png"

if gadgetHandler:IsSyncedCode() then
    local tanahAda = VFS.FileExists(tanahAtlas)
    local bajaAda = VFS.FileExists(bajaAtlas)
    function gadget:Initialize()
        for id, def in pairs(WeaponDefs) do
            local params = def.customParams
            if params.efek_benturan_tanah == "1" or params.efek_benturan_baja == "1" or params.volume_bentur then
                Script.SetWatchExplosion(id, true)
            end
        end
    end

    function gadget:Explosion(weapon, x, y, z, owner, proyektil)
        local params = WeaponDefs[weapon].customParams
        if params.volume_bentur then
            SendToUnsynced(audio, x, y, z, tonumber(params.volume_bentur))
        end
        local tanah = sp.GetGroundHeight(x, z)
        if tanah >= 0 and math.abs(y - tanah) <= 1.5 then
            if tanahAda and params.efek_benturan_tanah == "1" then
                SendToUnsynced(aksi, "tanah", x, tanah, z, proyektil, sp.GetGameFrame(),
                    tonumber(params.skala_benturan) or 1, 0, 0)
                return true
            end
        elseif bajaAda and params.efek_benturan_baja == "1" then
            for _, unit in ipairs(sp.GetUnitsInSphere(x, y, z, 48)) do
                if unit ~= owner and not sp.GetUnitIsDead(unit) then
                    local vx, _, vz = sp.GetProjectileVelocity(proyektil)
                    SendToUnsynced(aksi, "baja", x, y, z, proyektil, sp.GetGameFrame(),
                        tonumber(params.skala_baja) or 1, vx or 0, vz or 0)
                    return true -- Ganti visual CEG. Damage tetap diproses Recoil.
                end
            end
        end
        if params.fx_jejak and GG.FxBenturanCadanganV2 then
            return GG.FxBenturanCadanganV2(x, y, z, proyektil, params.fx_jejak == "kecil", y - tanah <= 1.5)
        end
        return false
    end
    return
end

local ledakan = {}
local skenario = sp.GetModOptions().skenario
local pakaiBekasBawaan = skenario == "sungai" or skenario == "pinus" or skenario == "hijau"
local benturanTersembunyi = {}
local function visible(x, y, z)
    local _, semuaTerlihat = sp.GetSpectatingState()
    return semuaTerlihat or sp.IsPosInLos(x, y + 6, z, sp.GetMyAllyTeamID())
end

local suaraTempur = VFS.Include("LuaRules/Configs/suara_tempur.lua").main
local function suaraBenturan(_, x, y, z, volume)
    if visible(x, y, z) then
        suaraTempur("sounds/ledakan-permukaan.wav", volume, x, y, z)
    elseif pakaiBekasBawaan then
        benturanTersembunyi[#benturanTersembunyi + 1] = {x, z}
    end
end

function gadget:Update()
    if #benturanTersembunyi == 0 then return end
    -- Recoil menempelkan bekas secara otomatis. Saring benturan yang tidak disaksikan tim.
    for _, id in ipairs(sp.GetAllGroundDecals()) do
        if sp.GetGroundDecalType(id) == "explosion" then
            local x, z = sp.GetGroundDecalMiddlePos(id)
            for _, titik in ipairs(benturanTersembunyi) do
                if math.abs(x - titik[1]) < .5 and math.abs(z - titik[2]) < .5 then
                    sp.SetGroundDecalAlpha(id, 0)
                    sp.SetGroundDecalGlowParams(id, 0)
                    break
                end
            end
        end
    end
    benturanTersembunyi = {}
end
local baris, piksel = 4, 256
local profil = {
    tanah = {atlas = tanahAtlas, kolom = 8, setengah = 48, tinggi = 16, bias = 23,
             skala = 1.45, detik = 49 / 24, gravitasi = 40},
    baja = {atlas = bajaAtlas, kolom = 4, setengah = 40, tinggi = 4.4, bias = 6,
            skala = .86, detik = .95, gravitasi = 55},
}
profil.tanah.partikel = {
    {jumlah = 128, ukuran = {0.27, 0.69}, laju = {12, 53}, dorong = {34, 84}, hidup = {0.65, 1.35},
        warna = {0.20, 0.11, 0.055}},
    {jumlah = 40, ukuran = {0.57, 1.26}, laju = {16, 42}, dorong = {27, 60}, hidup = {0.8, 1.5},
        warna = {0.37, 0.24, 0.13}},
    {jumlah = 24, ukuran = {0.25, 0.50}, laju = {18, 48}, dorong = {33, 80}, hidup = {0.20, 0.60},
        warna = {1.0, 0.42, 0.09}},
}
profil.baja.partikel = {
    {jumlah = 34, ukuran = {.19, .38}, laju = {18, 64}, dorong = {8, 44}, hidup = {.12, .58},
        warna = {1, .58, .20}, panjang = 3.3},
    {jumlah = 11, ukuran = {.32, .62}, laju = {12, 40}, dorong = {4, 22}, hidup = {.20, .76},
        warna = {.22, .21, .19}, panjang = 1.4},
}
local sisi = {
    {1, 3, 2}, {1, 4, 3}, {1, 5, 4}, {1, 2, 5},
    {6, 2, 3}, {6, 3, 4}, {6, 4, 5}, {6, 5, 2},
}

local function mulai(_, namaProfil, x, y, z, proyektil, frame, ukuran, vx, vz)
    if not visible(x, y, z) then return end
    local p = profil[namaProfil]
    local seed = (math.abs(proyektil) + frame * 131) % 2147483646 + 1
    local function acak(a, b)
        seed = seed * 16807 % 2147483647
        return a + (b - a) * (seed / 2147483647)
    end

    local shards = {}
    local metal = namaProfil == "baja"
    local backDir = math.atan2(-vz, -vx)
    for _, grup in ipairs(p.partikel) do
        for _ = 1, grup.jumlah do
            local arah, laju = acak(0, 2 * math.pi), acak(unpack(grup.laju))
            if metal and vx*vx + vz*vz > .01 then arah = backDir + acak(-1.4, 1.4) end
            shards[#shards + 1] = {
                vx = math.cos(arah) * laju, vz = math.sin(arah) * laju,
                vy = acak(unpack(grup.dorong)), r = acak(unpack(grup.ukuran)),
                rot = acak(0, math.pi), putar = acak(-12, 12),
                hidup = acak(unpack(grup.hidup)), variasi = acak(0.65, 1.25),
                warna = grup.warna, panjang = grup.panjang or 1.4,
            }
        end
    end
    if #ledakan >= 24 then table.remove(ledakan, 1) end
    ledakan[#ledakan + 1] = {x = x, y = y + 1, z = z, frame = frame,
        shards = shards, profil = p, skala = ukuran * p.skala}
end

function gadget:Initialize()
    gadgetHandler:AddSyncAction(aksi, mulai)
    gadgetHandler:AddSyncAction(audio, suaraBenturan)
end

function gadget:Shutdown()
    gadgetHandler:RemoveSyncAction(aksi)
    gadgetHandler:RemoveSyncAction(audio)
end

local function gambarSerpih(terlihat)
    local vx, vy, vz = {}, {}, {}
    for _, fx in ipairs(terlihat) do
        local skala = fx.skala
        local t = fx.umur / Game.gameSpeed
        for _, shard in ipairs(fx.shards) do
            if t < shard.hidup then
                local x, z = fx.x + shard.vx * t * skala, fx.z + shard.vz * t * skala
                local y = fx.y + (shard.vy * t - fx.profil.gravitasi * t * t) * skala
                if y > sp.GetGroundHeight(x, z) then
                    local r = shard.r * math.min(1, (shard.hidup - t) * 5)
                    local sudut = shard.rot + t * shard.putar
                    local dx, dz = r * math.cos(sudut), r * math.sin(sudut)
                    vx[1], vy[1], vz[1] = x + dz * .4, y + r * shard.panjang, z + dx * .5
                    vx[2], vy[2], vz[2] = x + dx, y, z + dz
                    vx[3], vy[3], vz[3] = x - dz, y, z + dx
                    vx[4], vy[4], vz[4] = x - dx, y, z - dz
                    vx[5], vy[5], vz[5] = x + dz, y, z - dx
                    vx[6], vy[6], vz[6] = x - dx * .3, y - r * .8, z + dz * .4
                    local warna = shard.warna
                    for i, face in ipairs(sisi) do
                        local cahaya = shard.variasi * (1.05 - (i - 1) * .07)
                        gl.Color(warna[1] * cahaya, warna[2] * cahaya, warna[3] * cahaya, 1)
                        for _, v in ipairs(face) do gl.Vertex(vx[v], vy[v], vz[v]) end
                    end
                end
            end
        end
    end
end

function gadget:DrawWorld()
    if #ledakan == 0 then return end
    local frame = sp.GetGameFrame() + (sp.GetFrameTimeOffset() or 0)
    local cx, cy, cz = sp.GetCameraPosition()
    local terlihat = {}
    for i = #ledakan, 1, -1 do
        local fx = ledakan[i]
        fx.umur = math.max(0, frame - fx.frame)
        local durasi = fx.profil.detik * Game.gameSpeed
        if fx.umur >= durasi then
            table.remove(ledakan, i)
        elseif sp.IsSphereInView(fx.x, fx.y, fx.z, fx.profil.setengah * fx.skala * 1.6) then
            fx.progres = fx.umur / durasi
            fx.jarak = (fx.x - cx)^2 + (fx.y - cy)^2 + (fx.z - cz)^2
            terlihat[#terlihat + 1] = fx
        end
    end
    if #terlihat == 0 then return end
    table.sort(terlihat, function(a, b) return a.jarak > b.jarak end)

    gl.DepthTest(true)
    gl.DepthMask(false)
    gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
    gl.Color(1, 1, 1, 1)
    local insetY = 0.5 / (baris * piksel)
    local dx, dy, dz = sp.GetCameraDirection()
    local atlas
    for _, fx in ipairs(terlihat) do
        local p, skala = fx.profil, fx.skala
        if p.atlas ~= atlas then
            atlas = p.atlas
            gl.Texture(atlas)
        end
        local kolom = p.kolom
        local insetX = .5 / (kolom * piksel)
        local ukuran, tinggiPusat = p.setengah * skala, p.tinggi * skala
        local tile = math.floor(fx.progres * (kolom * baris - 1))
        local u, v = (tile % kolom) / kolom, math.floor(tile / kolom) / baris
        -- Geser sepanjang pandangan agar bidang debu tidak terpotong oleh tanah.
        local bias = p.bias * skala
        gl.PushMatrix()
        gl.Translate(fx.x - dx * bias, fx.y - dy * bias, fx.z - dz * bias)
        gl.Billboard()
        gl.TexRect(-ukuran, tinggiPusat - ukuran, ukuran, tinggiPusat + ukuran,
            u + insetX, v + 1 / baris - insetY, u + 1 / kolom - insetX, v + insetY)
        gl.PopMatrix()
    end
    gl.Texture(false)
    gl.Blending(false)
    gl.DepthMask(true)
    gl.BeginEnd(GL.TRIANGLES, gambarSerpih, terlihat)
    gl.DepthMask(false)
    gl.DepthTest(false)
    gl.Color(1, 1, 1, 1)
end
