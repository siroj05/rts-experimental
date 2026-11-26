-- Fog of war di medan, meniru tampilan BAR (✅ user 2026-11-26: "benerin fog of war nya, ikutin fog of war nya
-- game BAR"). BAR memakai tampilan LOS bawaan engine (Spring.SetLosViewColors) tanpa shader khusus. Kode ini
-- ditulis ulang sendiri; luaui/Widgets/gfx_los_colors.lua BAR hanya dibaca sebagai referensi.
--
-- Shader medan Recoil (SMFFragProg.glsl): warna medan += tekstur info - 0,5. Titik netralnya 0,5.
-- Tekstur info (infoLOS.lua) = selalu + pandangan x LOS + radar2 x radar (hanya di luar LOS).
-- Kalau angka BAR dipakai mentah (pandangan 0,60), area dalam LOS jadi 0,86 dan medan terlihat pucat
-- (sudah diuji). Karena itu 🟡 nilainya disesuaikan supaya tampilannya sama dengan BAR:
--   di luar pandangan  0,26 (sama dengan BAR: 0,40 x opasitas 0,66) -> gelap;
--   dalam pandangan    0,26 + 0,26 x 0,9 = 0,50 -> warna medan normal (diukur A/B: selisih ±5 dari 255);
--   cakupan radar      0,26 + 0,12 = 0,38 -> di antara gelap dan normal.
-- Area yang di-jam diberi semburat merah tipis. Bangunan musuh yang pernah terlihat tetap tampil sebagai
-- bayangan (ghost) bawaan engine.
local M = {}
local OPASITAS = .66
local asli

local function warna()
    local gelap = .40 * OPASITAS
    -- LOS darat hanya dihitung 90% (losMix = los x 0,9 + airLos x 0,1), jadi nilainya dibagi 0,9
    local terang = (.5 - gelap) / .9
    return {gelap, gelap, gelap}, {terang, terang, terang}, {0, 0, 0}, {.03, -.03, -.03},
        {.12, .12, .12}
end

function M.Initialize()
    asli = {Spring.GetLosViewColors()}
    Spring.SetLosViewColors(warna())
    -- Nyalakan tampilan LOS sekali di awal. Tombol L bawaan engine tetap bisa mematikannya.
    if Spring.GetMapDrawMode() ~= "los" then Spring.SendCommands("togglelos") end
end

function M.Shutdown()
    if asli and #asli > 0 then Spring.SetLosViewColors(unpack(asli)) end
end

return M
