function gadget:GetInfo()
    return {
        name = "Vehicle and Robot LOD",
        desc = "Distance-based meshes using the live unit poses",
        layer = -10,
        enabled = true,
    }
end

if gadgetHandler:IsSyncedCode() then return false end

local sp = Spring
local directory = "objects3d/lod/"
local stride = 9
-- 🟡 2026-11-24: LOD masuk 70 m dari kamera (sebelumnya 150 m), lihat docs/tahapan.md tahap 10.
local enterDistSq, leaveDistSq = 560 ^ 2, 500 ^ 2
local capacity = 128
local instanceFormat = {{id = 6, name = "instance", size = 4, type = GL.UNSIGNED_INT}}
local batches, active = {}, {}
local shader, shadows, shaderBayangan

local function loadBatch(name, meta)
    local stem = name:gsub("_", "-")
    local partMap = assert(sp.GetModelPieceMap("objects3d/" .. stem .. ".glb"))
    local remap = {}
    for index, part in ipairs(meta.parts) do
        remap[index - 1] = assert(partMap[part], part) - 1
    end
    local raw = assert(VFS.LoadFile(directory .. stem .. ".bin"))
    assert(#raw == (stride * meta.vertices + meta.indices) * 4, stem)
    local data = VFS.UnpackF32(raw, 1, stride * meta.vertices)
    for offset = stride, #data, stride do
        data[offset] = assert(remap[data[offset]], stem)
    end
    local vertices = assert(gl.GetVBO(GL.ARRAY_BUFFER, false))
    vertices:Define(meta.vertices, {
        {id = 0, name = "position", size = 3}, {id = 1, name = "normal", size = 3},
        {id = 4, name = "texcoord", size = 2}, {id = 5, name = "pieceIndex", size = 1},
    })
    vertices:Upload(data)
    local indices = assert(gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false))
    indices:Define(meta.indices, GL.UNSIGNED_INT)
    indices:Upload(VFS.UnpackU32(raw, #data * 4 + 1, meta.indices))
    local instances = assert(gl.GetVBO(GL.ARRAY_BUFFER, true))
    instances:Define(capacity, instanceFormat)
    local vao = assert(gl.GetVAO())
    vao:AttachVertexBuffer(vertices)
    vao:AttachIndexBuffer(indices)
    vao:AttachInstanceBuffer(instances)
    local texture = "%" .. UnitDefNames[name].id
    return {
        vao = vao, vertices = vertices, indices = indices, instances = instances,
        indexCount = meta.indices, visible = {},
        tex1 = texture .. ":0", tex2 = texture .. ":1",
    }
end

function gadget:Initialize()
    if sp.GetConfigInt("RTSPCUnitLOD", 1) == 0 or not gl.GetEngineUniformBufferDef
            or not gl.GetVAO or not sp.GetUnitEngineDrawMask then
        gadgetHandler:RemoveGadget(self)
        return
    end
    local matrices, params = gl.GetEngineUniformBufferDef(0), gl.GetEngineUniformBufferDef(1)
    if not matrices or not params then
        gadgetHandler:RemoveGadget(self)
        return
    end
    local definitions = "#version 430 core\n" .. matrices .. "\n" .. params .. "\n"
    shader = gl.CreateShader({
        vertex = definitions .. VFS.LoadFile("shaders/lod_unit.vert.glsl"),
        fragment = definitions .. VFS.LoadFile("shaders/lod_unit.frag.glsl"),
        uniformInt = {tex1 = 0, tex2 = 1, shadowTex = 2, shadowColorTex = 3, reflectTex = 4},
    })
    if not shader then
        sp.Echo("[Unit LOD] " .. gl.GetShaderLog())
        gadgetHandler:RemoveGadget(self)
        return
    end
    shadows = gl.GetUniformLocation(shader, "withShadows")
    -- Model LOD juga dicetak ke shadow map (DrawShadowUnitsLua), jadi engine tidak perlu menggambar bayangan model
    -- penuh untuk unit LOD (bit 16). Tanpa shader ini, bayangan tetap dari engine (model penuh).
    shaderBayangan = gl.CreateShader({
        vertex = definitions .. VFS.LoadFile("shaders/lod_unit_bayangan.vert.glsl"),
        fragment = definitions .. VFS.LoadFile("shaders/lod_unit_bayangan.frag.glsl"),
    })
    if not shaderBayangan then sp.Echo("[Unit LOD] bayangan: " .. gl.GetShaderLog()) end
    local catalog = VFS.Include(directory .. "index.lua")
    for name, meta in pairs(catalog) do
        local ok, batch = pcall(loadBatch, name, meta)
        if ok then
            batches[UnitDefNames[name].id] = batch
        else
            sp.Echo("[Unit LOD] " .. name .. " " .. tostring(batch))
        end
    end
end

-- Only the render settings need the unit owner's control context. LOS is
-- always checked against the local player before a unit enters a batch.
local function setRenderState(unit, team, mask, updateMatrix)
    CallAsTeam({ctrl = team}, function()
        sp.SetUnitEngineDrawMask(unit, mask)
        sp.SetUnitAlwaysUpdateMatrix(unit, updateMatrix)
    end)
end

local function release(unit, saved)
    setRenderState(unit, saved.team, saved.mask, saved.updateMatrix)
    active[unit] = nil
end

function gadget:Shutdown()
    for unit, saved in pairs(active) do release(unit, saved) end
    if shader then gl.DeleteShader(shader) end
    if shaderBayangan then gl.DeleteShader(shaderBayangan) end
    for _, batch in pairs(batches) do
        batch.vao:Delete()
        batch.vertices:Delete()
        batch.indices:Delete()
        batch.instances:Delete()
    end
end

function gadget:UnitDestroyed(unit)
    active[unit] = nil
end

function gadget:UnitGiven(unit, _, newTeam)
    local saved = active[unit]
    if saved then
        saved.team = newTeam
        release(unit, saved)
    end
end

function gadget:Update()
    local cx, cy, cz = sp.GetCameraPosition()
    local ally = sp.GetMyAllyTeamID()
    local _, fullView = sp.GetSpectatingState()
    local keep = {}
    for _, batch in pairs(batches) do batch.visible = {} end
    for _, unit in ipairs(sp.GetVisibleUnits(-1, nil, false) or {}) do
        local batch = batches[sp.GetUnitDefID(unit)]
        local saved = active[unit]
        local los = batch and (fullView or sp.GetUnitLosState(unit, ally))
        if batch and (los == true or (los and los.los)) and not sp.GetUnitIsBeingBuilt(unit) then
            local x, y, z = sp.GetUnitViewPosition(unit)
            local distance = x and ((x - cx)^2 + (y - cy)^2 + (z - cz)^2)
            if distance and distance >= (saved and leaveDistSq or enterDistSq) then
                local mask = sp.GetUnitEngineDrawMask(unit)
                if not saved and mask and mask % 2 == 1 then
                    -- The main opaque pass switches. Recoil still handles shadows and icons.
                    local updateMatrix = sp.GetUnitAlwaysUpdateMatrix(unit)
                    local team = sp.GetUnitTeam(unit)
                    -- Bit 1 = pass utama; bit 16 = bayangan (digambar gadget ini kalau shader bayangan siap).
                    local baru = mask - 1
                    if shaderBayangan and math.floor(mask / 16) % 2 == 1 then baru = baru - 16 end
                    setRenderState(unit, team, baru, true)
                    if sp.GetUnitEngineDrawMask(unit) == baru then
                        saved = {mask = mask, updateMatrix = updateMatrix, team = team}
                        active[unit] = saved
                    end
                end
                if saved then
                    keep[unit] = true
                    batch.visible[#batch.visible + 1] = unit
                end
            end
        end
    end
    for unit, saved in pairs(active) do
        if not keep[unit] then release(unit, saved) end
    end
end

local function gambarBatch()
    for _, batch in pairs(batches) do
        local ids = batch.visible
        if #ids > 0 then
            for first = 1, #ids, capacity do
                local chunk = ids
                if #ids > capacity then
                    chunk = {}
                    for index = first, math.min(first + capacity - 1, #ids) do chunk[#chunk + 1] = ids[index] end
                end
                batch.instances:InstanceDataFromUnitIDs(chunk, 6, 0)
                batch.vao:DrawElements(GL.TRIANGLES, batch.indexCount, 0, #chunk)
            end
        end
    end
end

function gadget:DrawShadowUnitsLua()
    if not shaderBayangan or not next(active) then return end
    gl.UseShader(shaderBayangan)
    gambarBatch()
    gl.UseShader(0)
end

function gadget:DrawWorldPreUnit()
    if not shader or not next(active) then return end
    gl.DepthTest(GL.LEQUAL)
    gl.DepthMask(true)
    gl.Culling(GL.BACK)
    gl.Blending(false)
    gl.UseShader(shader)
    local hasShadows = sp.GetConfigInt("Shadows", 1) > 0
        and gl.Texture(2, "$shadow") and gl.Texture(3, "$shadow_color")
    gl.UniformInt(shadows, hasShadows and 1 or 0)
    gl.Texture(4, "$reflection")
    for _, batch in pairs(batches) do
        local ids = batch.visible
        if #ids > 0 then
            gl.Texture(0, batch.tex1)
            gl.Texture(1, batch.tex2)
            for first = 1, #ids, capacity do
                local chunk = ids
                if #ids > capacity then
                    chunk = {}
                    for index = first, math.min(first + capacity - 1, #ids) do
                        chunk[#chunk + 1] = ids[index]
                    end
                end
                batch.instances:InstanceDataFromUnitIDs(chunk, 6, 0)
                batch.vao:DrawElements(GL.TRIANGLES, batch.indexCount, 0, #chunk)
            end
        end
    end
    for i = 0, 4 do gl.Texture(i, false) end
    gl.UseShader(0)
    gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
    gl.Culling(false)
    gl.DepthMask(false)
    gl.DepthTest(false)
end
