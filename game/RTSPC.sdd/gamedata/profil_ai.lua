-- Tingkat AI skenario. 🟡 Angka usulan Claude 2026-11-24, disetel lewat tools/uji_ronde.py.
-- interval: detik antar-keputusan. insinyur: jumlah Engineer Bot yang dijaga. batasPasukan: unit tempur maksimum
-- per tim. gelombang: unit yang dikumpulkan dulu sebelum dilepas ke titik (setelah menit pembuka). bantuan: unit
-- tambahan per titik yang diperebutkan. pabrik: jumlah Pabrik Kendaraan maksimum.
return {
    easy = {
        nama = "Easy", ringkas = "Smaller groups, slower response",
        interval = 4, insinyur = 1, batasPasukan = 20, gelombang = 4, bantuan = 0, pabrik = 1, ekstraktor = 4, menara = 0, menaraLadang = 0, radar = 1,
        -- Deathmatch (LuaRules/ai/militer.lua): lebih penakut, grup serang lebih besar, tanpa raid.
        ambangSerang = .9, minSerang = 1500, raidMin = 99999,
        belajar = .35, -- belajar efektivitas unit dalam ronde (LuaRules/ai/belajar_unit.lua), lambat
    },
    normal = {
        nama = "Normal", ringkas = "Balanced reinforcements",
        interval = 2, insinyur = 2, batasPasukan = 36, gelombang = 6, bantuan = 0, pabrik = 1, ekstraktor = 6, menara = 1, menaraLadang = 1, radar = 2,
        belajar = .6,
    },
    hard = {
        nama = "Hard", ringkas = "Larger groups, faster response",
        interval = 1, insinyur = 2, batasPasukan = 50, gelombang = 6, bantuan = 1, pabrik = 2, ekstraktor = 8, menara = 2, menaraLadang = 2, radar = 3,
        hatiHati = true, bersihkan = true,
        belajar = .85,
    },
    -- Otak brutal (LuaRules/ai/otak_brutal.lua): ingatan, dendam, mode dari skor, berburu ekonomi/markas musuh,
    -- serbuan berkumpul, mundur untuk diperbaiki, belajar efektivitas unit dan gaya main per peta.
    brutal = {
        nama = "Brutal", ringkas = "Plays to win, holds grudges, adapts",
        interval = 1, insinyur = 3, batasPasukan = 60, gelombang = 6, bantuan = 1, pabrik = 2, ekstraktor = 8, menara = 3, menaraLadang = 3, radar = 3,
        otak = "brutal", belajar = 1, mundur = true, hatiHati = true, bersihkan = true,
        garisDepan = true, perebut = 4, gelombangAwal = 3,
        -- Deathmatch (militer.lua): serang hanya grup yang tidak lebih kuat; kabur kalau panas musuh > 1,3x regu.
        ambangSerang = .8, kaburSerang = 1.3,
    },
}
