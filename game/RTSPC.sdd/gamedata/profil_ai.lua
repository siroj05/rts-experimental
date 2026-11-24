-- Tingkat AI skenario. 🟡 Angka usulan Claude 2026-11-24, disetel lewat tools/uji_ronde.py.
-- interval: detik antar-keputusan. insinyur: jumlah Engineer Bot yang dijaga. batasPasukan: unit tempur maksimum
-- per tim. gelombang: unit yang dikumpulkan dulu sebelum dilepas ke titik (setelah menit pembuka). bantuan: unit
-- tambahan per titik yang diperebutkan. pabrik: jumlah Pabrik Kendaraan maksimum.
return {
    easy = {
        nama = "Easy", ringkas = "Smaller groups, slower response",
        interval = 4, insinyur = 1, batasPasukan = 20, gelombang = 4, bantuan = 0, pabrik = 1, ekstraktor = 4,
    },
    normal = {
        nama = "Normal", ringkas = "Balanced reinforcements",
        interval = 2, insinyur = 2, batasPasukan = 36, gelombang = 6, bantuan = 0, pabrik = 1, ekstraktor = 6,
    },
    hard = {
        nama = "Hard", ringkas = "Larger groups, faster response",
        interval = 1, insinyur = 3, batasPasukan = 50, gelombang = 8, bantuan = 1, pabrik = 2, ekstraktor = 8,
    },
}
