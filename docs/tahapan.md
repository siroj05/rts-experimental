# Tahapan RTS PC v3

✅ (2026-11-24) User memindah proyek ke Recoil: "gua putuskan pakai recoil karna biar gaperlu bangun dari 0 semuanya jadi kita tinggal tune up aja".
✅ (2026-11-24) User menyerahkan v3 ke Claude: "gua mau lu ambil alih penuh v3 ini, soalnya gak optimal banget dari gameplay visual, efek dan lainnya", lalu menyetujui rencana: "kerjakan 1 sampai 10".

## Temuan awal (2026-11-24)
Diambil dari uji visual (Pine Crossing 4v4 10 menit sebagai penonton, Central Hill 1v1, bentrokan pasukan campuran) dan pembacaan kode.
- **Tempo:** target skor 100.000 poin. 4v4: setelah 10 menit skor 70.000 vs 70.020, titik tidak pernah berpindah. 1v1 (5 poin/detik per titik, memegang 2 titik) butuh sekitar 2,8 jam.
- **AI:** hampir tidak membangun pasukan. 4v4: 38 entity (termasuk bangunan) untuk 8 tim setelah 10 menit dan tidak ada bentrokan. Batas pasukan AI 6/9/12; pemasukan markas 1 besi/detik, gudang 2.000 cepat penuh.
- **Peta:** Pine Crossing 512 × 384 m untuk 8 pemain, markas berjarak sekitar 85 m. Markas sekitar 4× panjang tank.
- **Visual:** medan hijau terlalu jenuh dan blur dari dekat, cahaya datar. Model terlihat plastik (atlas tanpa normal map), markas abu-abu polos. Tracer meriam berupa balok putih kaku. Api ledakan, asap bangkai, kilatan moncong, dan bayangan unit sudah cukup baik.
- **UI:** belum ada health bar di atas unit, ikon zoom jauh, indikator tim; belum ada menu pengaturan.
- **Performa:** pertempuran kecil 120–600 fps; skala besar belum diuji.

## Rencana (🟡 urutan dan target usulan Claude, disetujui user sebagai daftar)
| # | Pekerjaan | Target | Status |
|---|---|---|---|
| 0 | Fondasi: CLAUDE.md, AGENTS.md, serah terima, uji visual otomatis, graph kode | Tiap perubahan bisa diverifikasi dengan screenshot dan angka | ✅ 2026-11-24 |
| 1 | Tempo pertandingan: target skor dan poin per detik | Satu pertandingan ±20 menit 🟡 | ✅ 2026-11-24 |
| 2 | Ekonomi: pemasukan, harga, kapasitas gudang | Pasukan pertama menit 1–2, gelombang serangan ±2 menit sekali | ✅ diukur, angka tetap |
| 3 | AI: batas pasukan, serangan bergelombang, perebutan titik aktif, counter | Pertempuran nyata di semua peta | ✅ 2026-11-24 |
| 4 | Uji balance otomatis 1v1 dan 4v4 headless, banyak seed | Angka win-rate, lama pertandingan, jumlah unit | ✅ 2026-11-24 |
| 5 | Visual medan: warna natural, detail tanah, cahaya, kabut, grading | Natural dan dramatis | 🔄 cahaya/kabut selesai, albedo belum |
| 6 | Material model: normal map, roughness, kotoran; skala markas | Unit tidak terlihat plastik | belum |
| 7 | Efek: tracer bercahaya, benturan, ledakan, bekas hangus | Pertempuran dramatis | belum |
| 8 | UI: health bar, ikon zoom jauh, indikator seleksi/tim, panel, notifikasi | Terbaca jelas saat tempur | belum |
| 9 | Menu pengaturan (volume, grafis, kamera) | Poin 4 README lama | belum |
| 10 | Uji performa 50/100/200+ unit, zoom dekat dan jauh | Angka fps tercatat | belum |

Paralel (GPT, mode B): peta 4v4 baru "Verdant Ridge 4v4" (1024 × 768 m, A–D, hijau tua padat, pegunungan penghalang, pasir abu-abu gelap, pohon dan rumput bawaan Recoil). Setelah selesai, Claude mendaftarkannya ke menu dan paket Windows.

## Hasil tahap 1–4 (2026-11-24)
**Tempo (1).** Skor diseragamkan di semua peta: 1 poin/detik per titik, target 2.400 (2 titik 20 menit, 3 titik ±13 menit, 4 titik 10 menit). Sebelumnya 100.000 poin (1v1 ±2,8 jam). Bila kedua tim mencapai target dengan skor sama, pertandingan berlanjut sampai ada yang unggul. Bar skor HUD dibatasi 100%.

**AI (3)** `LuaRules/Gadgets/lawan_skenario.lua`, angka di `gamedata/profil_ai.lua` 🟡:
- tapak skenario tulisan tangan dicoba dulu; kalau terhalang, tapak dicari otomatis (cincin 48 elmo di depan markas, wilayah sendiri, menjauhi ladang, **tanpa pohon**); ekstraktor ke ladang kosong terdekat di separuh peta sendiri yang tidak dijaga musuh;
- rencana bawaan berlanjut sesudah rencana skenario (ekstraktor sampai 4/6/8, pompa sampai 4, pabrik kendaraan kedua di Hard); pompa didahulukan saat energi menipis;
- insinyur 1/2/3 (Easy/Normal/Hard) membagi tugas, membantu bangunan yang belum jadi, dan dihentikan kalau macet (reclaim pohon >20 dtk, perintah sama >75 dtk);
- produksi berbobot dengan counter (unit musuh berat yang terlihat menaikkan Tank Destroyer dan Rocket Robot; ringan menaikkan Light Tank dan Infantry Robot), robot maksimal 45% kuota;
- batas pasukan 20/36/50; menit pembuka unit dilepas berpasangan, sesudahnya bergelombang 4/6/8; titik sendiri yang diserang langsung dibantu; bangunan yang diserang dibela unit terdekat;
- serbuan terpusat: satu titik musuh terbaik menampung semua unit yang tidak menjaga titik sendiri;
- semua tim yang dikendalikan AI mendapat pengendali, termasuk tim 0 (untuk uji AI vs AI).

**Penyebab AI lama hampir tidak membangun:** koordinat tapak tetap terhalang pohon/lereng sehingga pabrik dan pompa dilewati selamanya; insinyur yang mendapat tapak berpohon macet reclaim pohon.

**Ekonomi (2).** Tidak diubah: setelah AI membangun dengan benar, unit tempur pertama keluar ±60–90 dtk, kontak pertama ±90–120 dtk, dan pasukan 10–15 unit di menit ke-4. Energi adalah pembatas yang disengaja (Medium Tank 1.050 energi), AI menanganinya dengan pompa.

**Uji (4)** `tools/uji_ronde.py` (headless, AI vs AI, `--semua-ai`), Normal:
| Peta | Seed | Pemenang | Lama | Catatan |
|---|---|---|---|---|
| Central Hill 1v1 | 1/2/3 | Barat/Timur/Barat | 21:53 / 21:49 / 18:50 | titik berpindah tangan |
| River Valley 1v1 | 1/2/3 | Timur/Timur/Barat | 21:23 / 19:32 / 19:36 | sebelumnya Timur 3/3 (energi Barat habis) |
| Pine Crossing 4v4 | 1/2 | Barat/Timur | 21:18 / 21:27 | 8 tim 8–17 unit di menit 4; macet 2-2 (peta sempit, diganti peta GPT) |
Sebelum perubahan (Pine Crossing): 1 unit tempur per tim, tidak ada pertempuran, 83.760/100.000 poin di menit 12.
Regresi: `uji_kontrol.py` 7/7 lulus, `uji_balance.py --seed 1` 7/7 lulus.

## Tahap 5 sejauh ini (2026-11-24)
`tools/poles_peta.py` menulis ulang `lighting` dan `atmosphere` di `maps/mapinfo-*.lua` dan mengemas ulang `mapinfo.lua` di `.sdz` (Central Hill, River Valley, Pine Crossing; peta GPT tidak disentuh). Cadangan peta lama di `.cache/cadangan-peta/`.
- 🟡 matahari ±35° (arah sama untuk ketiga peta), ambient medan 0,36–0,42 kebiruan (sebelumnya 0,57–0,60, penyebab cahaya datar), cahaya matahari hangat, shadow density 0,86, specular halus, kabut mulai 30% (sebelumnya 55–63%).
- Hasil (screenshot `.cache/uji-visual/cahaya-*`): dari jauh hijau lebih kalem, bukit bervolume, ada kedalaman udara; dari dekat bayangan unit panjang dan searah.
- Belum: albedo/rumput peta masih terlalu jenuh dan terang dari dekat (ada di tekstur peta). Perlu grading di generator peta (`tools/buat_*.py`) lalu kompilasi ulang dengan PyMapConv.
