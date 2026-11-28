-- Suara tempur berjarak (bug user 2026-11-28: "suara efek terdengar dekat meski suara aslinya bukan deket gua").
--
-- Penyebab: volume tembakan/benturan 3–9 diteruskan ke OpenAL, yang memotong gain akhir ke 1 sesudah pelemahan jarak,
-- dan pendengar Recoil berada di posisi kamera (ratusan elmo di atas tanah), sehingga suara jauh tetap penuh.
-- 🟡 Perbaikan: seperti suara mesin (suara_mesin_kendaraan.lua), volume dihitung sendiri dari jarak ke titik fokus
-- kamera (tengah layar) plus redaman zoom. SoundItems di gamedata/sounds.lua memakai rolloff 0 untuk suara ini supaya
-- OpenAL tidak melemahkan dua kali; posisi 3D tetap dipakai untuk panning kiri-kanan.
local M = {}
local sp = Spring
local elmo = 8
-- Uji 2026-11-28 (2 vs 2 Medium Tank): fokus di pertempuran gain 1,0; fokus 110 m menjauh gain 0,35 dengan 40/220 m,
-- terlalu keras untuk suara di luar layar, jadi dipersempit ke 30/150 m (110 m -> ±0,11).
local DEKAT, JAUH = 30 * elmo, 150 * elmo         -- penuh sampai 30 m dari fokus, hilang di 150 m
local ZOOM_DEKAT, ZOOM_JAUH = 60 * elmo, 400 * elmo -- kamera <= 60 m dari fokus: penuh; 400 m: 35%
local SKALA_VOLUME = 8                             -- volume lama (customparams volume_*) 8 = gain penuh

local cacheFrame, fx, fz, fzoom

local function fokus()
    local frame = sp.GetDrawFrame and sp.GetDrawFrame() or sp.GetGameFrame()
    if frame == cacheFrame then return fx, fz, fzoom end
    cacheFrame = frame
    local w, h = sp.GetViewGeometry()
    local _, p = sp.TraceScreenRay(math.floor(w / 2), math.floor(h / 2), true)
    local cx, cy, cz = sp.GetCameraPosition()
    if p then
        fx, fz = p[1], p[3]
        local d = math.sqrt((cx - p[1])^2 + (cy - p[2])^2 + (cz - p[3])^2)
        fzoom = 1 - .65 * math.max(0, math.min(1, (d - ZOOM_DEKAT) / (ZOOM_JAUH - ZOOM_DEKAT)))
    else
        fx, fz, fzoom = cx, cz, .35
    end
    return fx, fz, fzoom
end

-- Volume memakai skala lama (customparams volume_tembak/volume_bentur): 8 = penuh.
function M.main(file, volume, x, y, z)
    local px, pz, zoom = fokus()
    local d = math.sqrt((x - px)^2 + (z - pz)^2)
    if d >= JAUH then return end
    local u = d <= DEKAT and 1 or 1 - (d - DEKAT) / (JAUH - DEKAT)
    local gain = math.min(1, (volume or 1) / SKALA_VOLUME) * u * u * zoom
    if gain < .01 then return end
    sp.PlaySoundFile(file, gain, x, y, z, "battle")
end

return M
