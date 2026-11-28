-- Bayangan awan bergerak di medan, aktif bawaan (✅ user 2026-11-27: "kasih siluet awan bergerak secara default
-- di game").
--
-- 🟡 Cara kerja: satu pass layar penuh di awal DrawWorld, setelah medan, pohon, dan unit tergambar. Depth layar
-- disalin ke tekstur, posisi dunia tiap piksel dihitung balik dari depth itu, lalu noise awan (fbm) di bidang x-z
-- digeser angin. Hasilnya mengalikan warna layar (blend ZERO, SRC_COLOR), jadi medan, pohon, dan unit di bawah awan ikut lebih gelap. Penanda
-- HUD di DrawWorld digambar sesudahnya dan tidak ikut gelap.
-- G-buffer peta ($map_gbuffer_zvaltex) tidak dipakai: butuh AllowDeferredMapRendering = 1, yang menggambar medan
-- dua kali, dan opsi itu mati di config bawaan.
-- Awan ±50-200 m, tutupan ±40%, gerak 6 m/detik, gelap maksimal 40%.
local M = {}

local SKALA = 3600        -- elmo per satu periode noise dasar
local ANGIN = {1, .35}    -- arah angin (x, z), dinormalkan di bawah
local LAJU = 48           -- elmo per detik permainan
local KUAT = .4           -- penggelapan maksimal

local shader, loc, depth, lebarTex, tinggiTex

local vs = [[
varying vec2 uv;
void main() {
    uv = gl_Vertex.xy * 0.5 + 0.5;
    gl_Position = vec4(gl_Vertex.xy, 0.0, 1.0);
}
]]

local fs = [[
uniform sampler2D depthTex;
uniform mat4 viewProjInv;
uniform vec2 geser;
uniform float skala;
uniform float kuat;
uniform float clip01;
varying vec2 uv;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
    float s = 0.0, a = 0.5;
    for (int k = 0; k < 5; k++) { s += a * noise(p); p = p * 2.03 + vec2(17.1, 9.2); a *= 0.5; }
    return s;
}

void main() {
    float d = texture2D(depthTex, uv).x;
    if (d >= 1.0) discard;
    vec4 ndc = vec4(uv * 2.0 - 1.0, mix(d * 2.0 - 1.0, d, clip01), 1.0);
    vec4 w = viewProjInv * ndc;
    vec2 xz = w.xz / w.w;
    vec2 p = (xz + geser) / skala;
    // Bentuk awan: fbm + distorsi pelan supaya tepinya bergumpal, lalu ambang lembut
    float c = fbm(p * 2.5 + vec2(fbm(p * 2.0 + 3.7), fbm(p * 2.0 - 1.3)) * 0.8);
    float awan = smoothstep(0.48, 0.68, c);
    float g = 1.0 - kuat * awan;
    gl_FragColor = vec4(g, g, g, 1.0);
}
]]

function M.Initialize()
    if not gl.CreateShader then return end
    shader = gl.CreateShader({vertex = vs, fragment = fs, uniformInt = {depthTex = 0}})
    if not shader then
        Spring.Echo("Cloud shadows: shader unavailable", gl.GetShaderLog())
        return
    end
    loc = {}
    for _, nama in ipairs({"viewProjInv", "geser", "skala", "kuat", "clip01"}) do
        loc[nama] = gl.GetUniformLocation(shader, nama)
    end
end

function M.DrawWorld()
    if not shader then return end
    local t = Spring.GetGameFrame() / 30 + (Spring.GetFrameTimeOffset and Spring.GetFrameTimeOffset() or 0) / 30
    local n = math.sqrt(ANGIN[1]^2 + ANGIN[2]^2)
    gl.UseShader(shader)
    gl.UniformMatrix(loc.viewProjInv, "viewprojectioninverse")
    gl.Uniform(loc.geser, -ANGIN[1] / n * LAJU * t, -ANGIN[2] / n * LAJU * t)
    gl.Uniform(loc.skala, SKALA)
    gl.Uniform(loc.kuat, KUAT)
    gl.Uniform(loc.clip01, (Platform and Platform.glSupportClipSpaceControl) and 1 or 0)
    local vsx, vsy, vpx, vpy = Spring.GetViewGeometry()
    if not depth or lebarTex ~= vsx or tinggiTex ~= vsy then
        if depth then gl.DeleteTexture(depth) end
        depth = gl.CreateTexture(vsx, vsy, {format = 0x81A6, min_filter = GL.NEAREST, mag_filter = GL.NEAREST,
            wrap_s = GL.CLAMP_TO_EDGE, wrap_t = GL.CLAMP_TO_EDGE}) -- GL_DEPTH_COMPONENT24
        lebarTex, tinggiTex = vsx, vsy
        if not depth then
            gl.UseShader(0)
            gl.DeleteShader(shader)
            shader = nil
            Spring.Echo("Cloud shadows: depth texture unavailable")
            return
        end
    end
    gl.CopyToTexture(depth, 0, 0, vpx, vpy, vsx, vsy)
    gl.Texture(0, depth)
    gl.DepthTest(false)
    gl.DepthMask(false)
    gl.Blending(GL.ZERO, GL.SRC_COLOR)
    gl.BeginEnd(GL.QUADS, function()
        gl.Vertex(-1, -1, 0); gl.Vertex(1, -1, 0); gl.Vertex(1, 1, 0); gl.Vertex(-1, 1, 0)
    end)
    gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
    gl.Texture(0, false)
    gl.DepthTest(true)
    gl.UseShader(0)
end

function M.Shutdown()
    if shader then gl.DeleteShader(shader) end
    if depth then gl.DeleteTexture(depth) end
    shader, depth = nil, nil
end

return M
