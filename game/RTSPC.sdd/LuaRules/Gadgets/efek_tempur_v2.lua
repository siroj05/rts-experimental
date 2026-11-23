function gadget:GetInfo()
    return {name = "V2 Combat FX", desc = "Muzzle, tracer trails, destruction and wreck smoke", enabled = true}
end

local sp = Spring
local muzzleEvent, deathEvent, wreckEvent, removeEvent = "v2_muzzle", "v2_death", "v2_wreck", "v2_wreck_remove"
local impactEvent = "v2_impact"
local function skala(def)
    if def.name == "tank_ringan" then return .72 end
    if def.name == "medium_tank" then return 1 end
    return math.max(.30, math.min(2.6, math.max(def.xsize, def.zsize) * Game.squareSize / 48))
end

if gadgetHandler:IsSyncedCode() then
    local bangkai = {}
    local deathWeapon = WeaponDefNames.noweapon and WeaponDefNames.noweapon.id
    function gadget:Initialize()
        if deathWeapon then Script.SetWatchExplosion(deathWeapon, true) end
        GG.FxMoncongV2 = function(id, kecil, x, y, z, dx, dy, dz)
            local def = UnitDefs[sp.GetUnitDefID(id)]
            local k = (kecil and .32) or (def.name == "tank_ringan" and .65) or 1
            SendToUnsynced(muzzleEvent, x, y, z, dx, dy, dz, k, id, sp.GetGameFrame())
        end
        GG.FxBenturanCadanganV2 = function(x, y, z, projectile, kecil, tanah)
            SendToUnsynced(impactEvent, x, y, z, projectile or -1, kecil, tanah, sp.GetGameFrame())
            return true
        end
    end
    function gadget:Shutdown()
        GG.FxMoncongV2 = nil
        GG.FxBenturanCadanganV2 = nil
    end
    function gadget:Explosion(weapon, x, y, z, owner)
        -- NOWEAPON hanya dipakai Recoil untuk kematian unit yang sudah jadi dan tidak direklamasi.
        if weapon ~= deathWeapon or not owner then return false end
        local def = UnitDefs[sp.GetUnitDefID(owner)]
        if not def then return false end
        SendToUnsynced(deathEvent, x, y, z, skala(def), owner, sp.GetGameFrame())
        return true
    end
    function gadget:FeatureCreated(id)
        local def = FeatureDefs[sp.GetFeatureDefID(id)]
        if not def or not def.name:match("_bangkai$") then return end
        local x, y, z = sp.GetFeaturePosition(id)
        bangkai[id] = true
        SendToUnsynced(wreckEvent, id, x, y, z, sp.GetGameFrame())
    end
    function gadget:FeatureDestroyed(id)
        if not bangkai[id] then return end
        bangkai[id] = nil
        SendToUnsynced(removeEvent, id)
    end
    return
end

local clouds, fires, sparks, trails, wrecks = {}, {}, {}, {}, {}
local cloudShader, fireShader, fireUniform, sphere
local tau = math.pi * 2
local elmo, fps = 8, Game.gameSpeed
local function waktu(frame) return frame / fps end
local function visible(x, y, z)
    local _, fullView = sp.GetSpectatingState()
    return fullView or sp.IsPosInLos(x, y, z)
end

local function rng(seed)
    seed = seed % 2147483646 + 1
    return function(a, b)
        seed = seed * 16807 % 2147483647
        return a + (b - a) * seed / 2147483647
    end
end

local function add(list, cap, p)
    if #list >= cap then return end
    list[#list + 1] = p
end

local function cloud(t, life, x, y, z, vx, vy, vz, s, alpha, tone, seed, grow, low, drift)
    add(clouds, 2200, {born=t, life=life, x=x, y=y, z=z, vx=vx, vy=vy, vz=vz,
        size=s, alpha=alpha, tone=tone, seed=seed, growth=grow, low=low, drift=drift})
end

local function fire(t, life, x, y, z, vx, vy, vz, s, kind, seed, drift)
    add(fires, 256, {born=t, life=life, x=x, y=y, z=z, vx=vx, vy=vy, vz=vz, size=s, kind=kind, seed=seed, drift=drift})
end

local function spark(t, life, x, y, z, vx, vy, vz, s, gravity, hot)
    add(sparks, 800, {born=t, life=life, x=x, y=y, z=z, vx=vx, vy=vy, vz=vz, size=s, g=gravity, hot=hot})
end

-- Counts and motion from V2 FxMeriam.AddShot. Ground dust uses the terrain under the muzzle.
local function muzzle(_, x, y, z, dx, dy, dz, k, id, frame)
    if not cloudShader or not visible(x, y, z) then return end
    local r, t, s = rng(id * 101 + frame * 7919), waktu(frame), k * elmo
    for j = 0, 6 do
        local d = j * .18 * s * 1.25
        fire(t, .10, x + dx*d, y + dy*d, z + dz*d, dx*3*s, dy*3*s, dz*3*s,
            (.4 + (j > 1 and .3 - j*.045 or 0)) * s * 1.25, 0, r(0, 50), true)
    end
    for _ = 1, 11 do
        local d, lateral = r(0, .65)*s, r(-.36, .36)*s
        local speed, side = r(.7, 1.8)*s, r(-.9, .9)*s
        cloud(t+r(0,.06), r(.9,1.7), x+dx*d+dz*lateral, y+dy*d, z+dz*d-dx*lateral,
            dx*speed+dz*side, r(.6,1.5)*s, dz*speed-dx*side, r(.45,.85)*s, .48, 0, r(0,50), 2.5)
    end
    if k > .4 and y - sp.GetGroundHeight(x, z) < 40 then
        for i = 1, 24 do
            local a = i / 24 * tau + r(-.1, .1)
            local cx, cz = math.cos(a), math.sin(a)
            local d, v, fwd = r(.2,.5)*s, r(1.9,3.2)*s, r(.25,.95)*s
            local px, pz = x + cx*d, z + cz*d
            cloud(t+r(.02,.08), r(.85,1.45), px, 0, pz, cx*v+dx*fwd, 0, cz*v+dz*fwd,
                r(.35,.65)*s, .42, 1, r(0,50), 2.5, true)
        end
    end
    for _ = 1, 9 do
        local speed, side = r(7,15)*s, r(-2,2)*s
        spark(t, r(.08,.18), x,y,z, dx*speed+dz*side, dy*speed+r(-.4,1.2)*s, dz*speed-dx*side,
            .035*s, 0, true)
    end
end

-- V2 FxHancur layers. We sample the fireballs' path to leave drifting white smoke.
local function death(_, x, y, z, k, id, frame)
    if not visible(x, y+4, z) then return end
    sp.PlaySoundFile("sounds/unit-hancur-v2.ogg", .5, x, y, z, "battle")
    if not cloudShader then return end
    local r, t, s = rng(id * 7919 + frame), waktu(frame), k * elmo
    local cy = y + 1.1*s
    fire(t, .42, x,cy,z, 0,0,0, 5*s, 0, r(0,50))
    for i = 1, 9 do
        local a = i / 9 * tau + r(-.25,.25)
        local cx, cz = math.cos(a), math.sin(a)
        local d = r(1.25,2.1)*s
        fire(t+r(0,.035), 1.35 + (i % 3)*.09, x+cx*.25*s,cy,z+cz*.25*s,
            cx*d, r(.6,1.5)*s, cz*d, r(2.5,3.55)*s, 1, r(0,50))
    end
    for i = 1, 22 do
        local a = i / 22 * tau + r(-.2,.2)
        local cx, cz = math.cos(a), math.sin(a)
        local d, endD, h = r(.6,1.2)*s, r(3.1,5.2)*s, r(.8,3.8)*s
        local delay, life, size = r(.13,.48), r(.9,1.55), r(.48,.95)*s
        local vx, vz = cx*(endD-d), cz*(endD-d)
        local px, pz = x+cx*d, z+cz*d
        fire(t+delay, life, px,cy,pz, vx,h,vz, size, 2, r(0,50))
        for age = .02, life, .08 do
            local u = 1 - (1 - age/life)^1.6
            cloud(t+delay+age, 3.7-age, px+vx*u, cy+h*u, pz+vz*u, 1.225*s,.315*s,.56*s,
                .43*s, .40, 2, r(0,50), 2.5, false, true)
        end
    end
    for i = 1, 18 do
        local a = i / 18 * tau + r(-.3,.3)
        local cx, cz = math.cos(a), math.sin(a)
        local d = r(.15,1.6)*s
        cloud(t+r(.02,.12), 3.9, x+cx*d,cy+r(0,.6)*s,z+cz*d, (cx*1.4+.5)*s, r(2.8,4.8)*s, cz*1.35*s,
            r(1.6,2.35)*s, .76, -1, r(0,50), 1.6)
        cloud(t+r(0,.06), 2.1, x+cx*.7*s,0,z+cz*.7*s, cx*4.6*s,0,cz*4.6*s,
            r(1.3,1.85)*s, .42, 1, r(0,50), 1.3, true)
    end
    for i = 1, 104 do
        local a, hot = r(0,tau), i <= 72
        spark(t, hot and r(.5,.95) or r(1.1,1.5), x,cy,z, math.cos(a)*r(3,6)*s, r(4,8)*s,
            math.sin(a)*r(3,6)*s, (hot and r(.035,.065) or r(.10,.22))*s, 9.81*s, hot)
    end
end

local function impact(_, x, y, z, projectile, kecil, tanah, frame)
    if not cloudShader or not visible(x, y+4, z) then return end
    local r, t, s = rng(math.abs(projectile)*7919 + frame), waktu(frame), kecil and 2.7 or 6
    y = y + 1.2
    fire(t,.16,x,y,z,0,s,0,2*s,0,r(0,50),true)
    for i = 1, kecil and 14 or 28 do
        local a, v = r(0,tau), r(3.5,9)*s
        spark(t,r(.15,.5),x,y,z,math.cos(a)*v,r(2.5,8.5)*s,math.sin(a)*v,r(.04,.09)*s,15*s,true)
    end
    for i = 1, kecil and 5 or 10 do
        local a, v = r(0,tau), r(.4,1.9)*s
        cloud(t,r(.45,.95),x,y,z,math.cos(a)*v,r(.4,1.45)*s,math.sin(a)*v,
            r(.65,1.2)*s,.44,tanah and 1 or 0,r(0,50),2)
    end
end

local function wreck(_, id, x, y, z, frame)
    if not cloudShader then return end
    wrecks[id] = {born = waktu(frame), next = waktu(frame) + 1.6, x=x, y=y, z=z, rng=rng(id*7919+frame)}
end

local function removeWreck(_, id) wrecks[id] = nil end

local profil = {
    meriam = {4.8, .23, 1.35, .42}, kecil = {5, .15, .8, .28},
    artileri = {4.8, 2.45, 5.6, .64}, roket = {4.4, .64, 1.8, .55},
}

local profilSenjata = {}
for id, def in pairs(WeaponDefs) do
    profilSenjata[id] = def.customParams.fx_jejak
end

local function jejak(frame)
    local t = waktu(frame)
    local _, fullView = sp.GetSpectatingState()
    for _, id in ipairs(sp.GetVisibleProjectiles(fullView and -1 or sp.GetMyAllyTeamID(), true, true, false) or {}) do
        local style = profilSenjata[sp.GetProjectileDefID(id)]
        local p = profil[style]
        if p then
            local x, y, z = sp.GetProjectilePosition(id)
            local old = trails[id]
            if x and old and old.frame == frame-1 then
                local dx, dy, dz = x-old.x, y-old.y, z-old.z
                local gap = math.sqrt(dx*dx + dy*dy + dz*dz)
                if gap > 0 and gap < 160 and #clouds < 1700 then
                    local step = p[1]
                    for d = step - old.carry, gap, step do
                        local u = d/gap
                        cloud(t - (1-u)/fps, p[2], old.x+dx*u, old.y+dy*u, old.z+dz*u,
                            style == "artileri" and 6 or 1, 2, 1.4, p[3], p[4],
                            style == "artileri" and 2 or 0, (id*.371+d*2.1)%48, 2.5, false, true)
                    end
                    old.carry = (old.carry + gap) % step
                end
            elseif x then
                old = {carry=0}
                trails[id] = old
            end
            if x then old.frame, old.x, old.y, old.z = frame, x, y, z end
        end
    end
    for id, old in pairs(trails) do if old.frame ~= frame then trails[id] = nil end end
end

function gadget:GameFrame(frame)
    if not cloudShader then return end
    jejak(frame)
    if frame % 5 ~= 0 then return end
    local t, active = waktu(frame), 0
    for id, w in pairs(wrecks) do
        local age = (t-w.born)/24
        if age >= 1 then
            wrecks[id] = nil
        elseif active < 32 and t >= w.next and sp.IsSphereInView(w.x, w.y+15, w.z, 44)
            and visible(w.x, w.y+4, w.z) then
            local r, strength = w.rng, 1-age^2
            w.next = t + .22 + age*.48 + r(0,.12)
            active = active+1
            cloud(t,r(3.2,4.8), w.x+r(-3,3),w.y+8,w.z+r(-3,3), 8,r(17.6,28.8),4,
                r(5.6,9.6), .55*strength, -.85, r(0,50), 2.5, false, true)
            if strength > .55 and r(0,1) < .6 then
                fire(t,r(.35,.55),w.x+r(-4,4),w.y+6,w.z+r(-4,4),0,9.6,0, r(2.8,6)*strength,2,r(0,50),true)
            end
        end
    end
end

local function buatBola()
    local function point(lat, lon)
        local a, b = (lat/10 - .5)*math.pi, lon/16*tau
        local x, y, z = math.cos(a)*math.cos(b), math.sin(a), math.cos(a)*math.sin(b)
        gl.Normal(x,y,z)
        gl.Vertex(x*.5,y*.5,z*.5)
    end
    for i = 0, 9 do
        for j = 0, 15 do
            point(i,j); point(i+1,j); point(i+1,j+1)
            point(i,j); point(i+1,j+1); point(i,j+1)
        end
    end
end

function gadget:Initialize()
    for _, pair in ipairs({{muzzleEvent,muzzle}, {deathEvent,death}, {impactEvent,impact}, {wreckEvent,wreck}, {removeEvent,removeWreck}}) do
        gadgetHandler:AddSyncAction(pair[1], pair[2])
    end
    if not gl.CreateShader then return end
    local shader = VFS.Include("LuaRules/Configs/fx_v2_shader.lua")
    cloudShader = gl.CreateShader(shader.cloud)
    fireShader = gl.CreateShader(shader.fire)
    if not cloudShader or not fireShader then
        Spring.Echo("V2 Combat FX shader unavailable", gl.GetShaderLog())
    end
    if fireShader then
        fireUniform = gl.GetUniformLocation(fireShader, "fx")
        sphere = gl.CreateList(function() gl.BeginEnd(GL.TRIANGLES, buatBola) end)
    end
end

function gadget:Shutdown()
    for _, event in ipairs({muzzleEvent, deathEvent, impactEvent, wreckEvent, removeEvent}) do gadgetHandler:RemoveSyncAction(event) end
    if sphere then gl.DeleteList(sphere) end
    if fireShader then gl.DeleteShader(fireShader) end
    if cloudShader then gl.DeleteShader(cloudShader) end
end

local function filter(list, now, draw)
    local nextIndex = 0
    local cx, cy, cz = sp.GetCameraPosition()
    for _, p in ipairs(list) do
        local age = now-p.born
        if age < p.life then
            nextIndex = nextIndex+1
            list[nextIndex] = p
            if age >= 0 then
                local u = age/p.life
                local v = age
                if not p.drift then
                    if p.tone then v = 1-(1-u)^2 end
                    if p.kind then v = 1-(1-u)^1.6 end
                end
                local x, z = p.x+p.vx*v, p.z+p.vz*v
                local y = p.y+p.vy*v - (p.g or 0)*v*v*.5
                if p.low then y = sp.GetGroundHeight(x,z)+p.size*(.1+v*.18) end
                if p.g and p.g > 0 then y = math.max(sp.GetGroundHeight(x,z)+p.size*.2, y) end
                if sp.IsSphereInView(x,y,z,p.size*3) then
                    p.drawX,p.drawY,p.drawZ,p.u = x,y,z,u
                    p.depth = (x-cx)^2+(y-cy)^2+(z-cz)^2
                    draw[#draw+1] = p
                end
            end
        end
    end
    for i = #list, nextIndex+1, -1 do list[i] = nil end
end

local function drawClouds(list, right, up)
    local function corner(p, w, h, u, v)
        gl.TexCoord(u,v)
        gl.Vertex(p.drawX + right[1]*w + up[1]*h, p.drawY + right[2]*w + up[2]*h, p.drawZ + right[3]*w + up[3]*h)
    end
    for _, p in ipairs(list) do
        local u = p.u
        local w = p.size * .5 * (1 + p.growth*u)
        local h = p.low and w*.4 or w
        gl.MultiTexCoord(1, p.seed, p.tone, p.alpha*math.min(1,u*11)*(1-u)^1.3)
        corner(p,-w,-h,0,0); corner(p,w,-h,1,0); corner(p,w,h,1,1); corner(p,-w,h,0,1)
    end
end

local function drawSparks(list, hot)
    for _, p in ipairs(list) do
        if p.hot == hot then
            local x,y,z = p.drawX,p.drawY,p.drawZ
            local s = p.size * math.min(1, (1-p.u)*5)
            local a = p.u*7
            local dx, dz = math.cos(a)*s, math.sin(a)*s
            if hot then gl.Color(1,.48,.10, (1-p.u)*.9) else gl.Color(.10,.085,.07,1) end
            gl.Vertex(x+dx,y,z+dz); gl.Vertex(x-dz,y,z+dx); gl.Vertex(x-dx,y,z-dz)
            gl.Vertex(x-dx,y,z-dz); gl.Vertex(x+dz,y,z-dx); gl.Vertex(x+dx,y+s*2,z+dz)
            gl.Vertex(x+dx,y+s*2,z+dz); gl.Vertex(x-dz,y,z+dx); gl.Vertex(x-dx,y,z-dz)
        end
    end
end

function gadget:DrawWorld()
    if not cloudShader or (#clouds == 0 and #fires == 0 and #sparks == 0) then return end
    local now = waktu(sp.GetGameFrame() + sp.GetFrameTimeOffset())
    local drawCloud, drawFire, drawBits = {}, {}, {}
    filter(clouds,now,drawCloud); filter(fires,now,drawFire); filter(sparks,now,drawBits)
    table.sort(drawCloud, function(a,b) return a.depth > b.depth end)
    table.sort(drawFire, function(a,b) return a.depth > b.depth end)
    gl.DepthTest(true)
    gl.Blending(false)
    gl.DepthMask(true)
    gl.BeginEnd(GL.TRIANGLES, drawSparks, drawBits, false)
    gl.DepthMask(false)
    gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
    local camera = sp.GetCameraVectors()
    gl.UseShader(cloudShader)
    gl.BeginEnd(GL.QUADS, drawClouds, drawCloud, camera.right, camera.up)
    if sphere and fireShader then
        gl.UseShader(fireShader)
        gl.Culling(GL.BACK)
        for _, p in ipairs(drawFire) do
            local u = p.u
            local alpha = math.min(1, u*12+.05) * (1-u)^.75
            local s = p.size * math.min(1,u*4+.13) * (1-.72*u^2)
            gl.Uniform(fireUniform, alpha, p.kind, p.seed)
            gl.PushMatrix()
            gl.Translate(p.drawX,p.drawY,p.drawZ)
            gl.Scale(s,s*(p.kind==1 and 1.15 or .94),s)
            gl.CallList(sphere)
            gl.PopMatrix()
        end
        gl.Culling(false)
    end
    gl.UseShader(0)
    gl.Blending(GL.SRC_ALPHA, GL.ONE)
    gl.BeginEnd(GL.TRIANGLES, drawSparks, drawBits, true)
    gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
    gl.DepthTest(false)
    gl.Color(1,1,1,1)
end
