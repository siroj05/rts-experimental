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
| 5 | Visual medan: warna natural, detail tanah, cahaya, kabut, grading | Natural dan dramatis | ✅ 2026-11-24 |
| 6 | Material model: normal map, roughness, kotoran; skala markas | Unit tidak terlihat plastik | 🔄 pantulan dinaikkan; normal map/kotoran/skala markas belum |
| 7 | Efek: tracer bercahaya, benturan, ledakan, bekas hangus | Pertempuran dramatis | ✅ tracer; sisanya sudah ada dari sebelumnya |
| 8 | UI: health bar, ikon zoom jauh, indikator seleksi/tim, panel, notifikasi | Terbaca jelas saat tempur | ✅ health bar + ikon; notifikasi belum |
| 9 | Menu pengaturan (volume, grafis, kamera) | Poin 4 README lama | ✅ 2026-11-24 |
| 10 | Uji performa 50/100/200+ unit, zoom dekat dan jauh | Angka fps tercatat | ✅ diukur; perbaikan menunggu keputusan user |

? 2026-11-24, Verdant Ridge 4v4 terintegrasi di dropdown Skirmish, peluncur langsung, dan paket Windows. User meminta ?integrasiin map ke game, sesuai aturan yang udah dibuat claude?. Target skor 2.400. Uji paket grafis dan 64 rute lulus. [Bukti dan ukuran peta](peta-punggung-hijau.md)

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
- Albedo: `tools/grading_medan.py` (hijau jenuh -35% saturasi, geser ke zaitun, -12% terang, kontras tengah +10%) dipasang di ketiga generator; Central Hill, River Valley, Pine Crossing dikompilasi ulang.
- Rumput 3D: mapinfo memakai kunci `grassBlade*` yang tidak dikenali Recoil, jadi warna bawaan hijau terang {0.59, 0.81, 0.57} yang tampil. Sekarang `grass = {bladeHeight, bladeWidth, bladeWaveScale, bladeColor = {0.34, 0.42, 0.25}}`.
- `buat_pine_crossing.py compile` menulis ulang `pinus.lua` dengan skor lama; konstanta generator ikut diperbarui.

## Tahap 6–10 (2026-11-24)
**6. Material.** Importer mengisi kanal pantulan `tex2.G` = metallic × 0,28 sehingga pantulan hampir nol. `tools/poles_material.py` menaikkannya (G × 2,2 + 0,03, rata-rata 0,04–0,16 → 0,11–0,35) untuk unit dan bangunan hidup; sumber asli di `.cache/tex2-asli/`. Belum: normal map (shader bawaan Recoil untuk model glTF di proyek ini tidak memakainya), kotoran/aus, skala markas.

**7. Tracer.** Model tracer 3D (balok kaku) untuk meriam, senjata kecil, dan artileri diganti garis cahaya aditif menghadap kamera di `efek_tempur_v2.lua` (wajik runcing, inti terang, ekor memudar; panjang meriam 3,6 m, kecil 2 m, artileri 1,6 m, tumbuh dari moncong). Roket tetap model. Ledakan, asap, kilatan, benturan sudah ada sebelumnya.

**8. UI.**
- Health bar di atas unit (`LuaUI/batang_hp.lua`): tampil untuk unit rusak, terpilih, atau sedang dibangun (bar biru = progres); hijau/kuning/merah; disembunyikan saat unit menjadi ikon.
- Ikon strategis (`tools/buat_ikon.py` → `gamedata/icontypes.lua`, `icons/*.png`, `gamedata/ikon_unit.lua`): 12 bentuk orisinal (tank, tank ringan, destroyer, pengintai, artileri, robot, roket, insinyur, markas, pabrik, menara, bangunan), diwarnai warna tim. `UnitIconDist = 120` (Very Far, ✅ user 2026-11-26; sebelumnya 50) di `config/windows-defaults.cfg` (bawaan Recoil 200 tidak pernah menampilkan ikon di peta kecil; jarak dikali radius unit).
- Belum: notifikasi (diserang, unit selesai), penanda tim selain warna.

**9. Pengaturan.** Menu jeda (Esc) punya **Settings**: Master Volume, Battle Volume, Unit Icons (Near/Normal/Far/Very Far/Off), Shadows, Zoom Speed (tanda `ScrollWheelSpeed` dipertahankan supaya arah zoom tidak terbalik), Health Bars. Disimpan ke `springsettings.cfg`. Diuji lewat `tools/uji_visual/pengaturan.lua` (nilai berubah dan tersimpan).

**10. Performa** (`tools/uji_visual/performa.lua.tpl`, Central Hill, campuran 7 jenis per tim bertempur, 1600 × 900, VSync mati, RTX 4060; fps sesaat dari 4 sampel):
| Unit per tim | Total | Zoom dekat (400) | Zoom jauh (1800) |
|---|---|---|---|
| 50 | ±100 | 64–71 | 81–114 |
| 100 | ±200 | 33–39 | 57–67 |
| 200 | ±400 | 13–21 | 25–28 |
| 400 | ±800 | 8–13 | 8–14 |

A/B pada 200 per tim: tanpa gadget efek, LOD, suara mesin, benturan, lintasan: tidak berubah berarti. Kamera ke area kosong saat pertempuran yang sama: 280–400 fps (simulasi dan Lua ringan). Bayangan mati: jauh 25 → 60, dekat 15 → 27. Penyebab utama: **model penuh berat (Medium Tank ±76.000 segitiga) digambar di pass utama dan pass bayangan**; gadget LOD hanya mengganti pass utama, bayangan tetap model penuh.
✅ (2026-11-24, user: "langsung aja kerjain") Perbaikan dipasang di `lod_unit.lua`: model LOD juga dicetak ke shadow map lewat callin `DrawShadowUnitsLua` (`shaders/lod_unit_bayangan.*.glsl`), bit bayangan engine (16) dimatikan untuk unit LOD, dan LOD masuk di 560 elmo (70 m, sebelumnya 150 m). Unit jauh tetap berbayangan (diperiksa di capture 750 elmo).
| Unit per tim | Dekat sebelum → sesudah | Jauh sebelum → sesudah |
|---|---|---|
| 50 | 64–71 → 67–85 | 81–114 → 78–108 |
| 100 | 33–39 → 35–50 | 57–67 → 68–115 |
| 200 | 13–21 → 16–28 | 25–28 → 60–64 |
| 400 | 8–13 → 8–18 | 8–14 → 19–45 |
Sisa: zoom dekat dengan ratusan unit tetap berat karena model penuh (±76.000 segitiga Medium Tank). Model game lebih ringan diberikan ke GPT (mode B, `docs/model-ringan.md`); Claude memasukkannya dan mengukur ulang.

## Verdant Ridge 4v4 masuk game (2026-11-24)
Dibuat GPT (mode B, `docs/peta-punggung-hijau.md`); pendaftaran menu, skrip uji, dan daftar paket juga sudah disiapkan GPT. Claude memverifikasi:
- AI vs AI headless (`uji_ronde.py`, 8 tim Normal): kontak pertama 2:09–2:11; di menit 8 tiap tim punya 22–30 unit tempur; titik berpindah tangan. Seed 2 Barat menang 21:40; seed 1 belum selesai di menit 25 (1.708 vs 1.435).
- Visual: tampilan seluruh peta (ikon markas/unit di zoom jauh) dan pertempuran menit 8 di titik C, 161 fps dengan 297 unit (960 × 540).
- Catatan: pohon tidak tampil di zoom paling jauh (jarak gambar fitur bawaan engine).

## Material markas dan tingkat AI (2026-11-24/25)
✅ (user: "kerjain yang nomor 3 dan no 4 dulu")
- **Markas 70%:** `tools/impor_markas.py` (`SKALA`), footprint 12 → 9. Model 12.871 segitiga, bangkai 2.968.
- **Pelapukan bangunan:** `tools/poles_material.py` `lapuk()` pada tex1 10 bangunan (noda, bintik, debu, desaturasi 10%); asli di `.cache/tex1-asli/`.
- **Perbaikan skrip track:** fase track di-clamp (error `sp_SetPieceVisibility` nil di River Valley).
- **Hard vs Normal** (12 ronde, Central Hill + River Valley, dua sisi): awal 3/12 → serbu hanya bila unggul ×1,3 (`hatiHati`) 5/12 → + 2 pabrik, 8 ekstraktor 6/12.
- ✅ (user) Mode rebut titik tetap mode utama; mode "saling serang" ditunda. Tanpa bonus sumber daya.
- 🟡 **Brutal (belum selesai):** `LuaRules/ai/otak_brutal.lua` + profil `brutal` + baris menu. Hasil terakhir vs Normal 9/24, lebih lemah dari Hard. Analisis 127 ronde: titik menit 4 (79%) dan pemasukan menit 8 (80%) menentukan pemenang, jumlah pasukan tidak (52%). Rincian dan langkah berikut di `docs/serah-terima.md` bagian 7.
- 🟡 **Brutal garis depan (2026-11-25):** `LuaRules/ai/garis_depan.lua` (konsep C.R.A.I.G Spring:1944). Verdant Ridge 4v4 vs Normal: 4 menang + 2 terpotong waktu dengan Brutal unggul (sebelumnya 0/6). Perbaikan semua tingkat: unit tertahan dekat pabrik.
- ✅ (2026-11-25, user: "gua pengen ada dua mode nanti, rebut point sama saling menghancurkan") Dua mode: **Rebut Titik** (sekarang) dan **Saling Menghancurkan** (menyusul setelah AI Brutal mode titik selesai: gadget menang/kalah, pilihan mode di menu, AI sasaran markas/bangunan dari `otak_brutal.lua`).
- ✅ (2026-11-25, user: "close case buat mode rebut poin ... pindah ke mode deathmatch") Mode titik ditutup apa adanya: Brutal vs Hard 19/24, vs Normal 13/24 (River Valley sisi barat 1/6 belum terpecahkan), 4v4 vs Normal 4 menang + 2 unggul.
- 🟡 **Deathmatch (2026-11-25):** `mode=hancur` (`gamedata/skenario.lua` mengosongkan titik), HUD jumlah Command Core, tab mode di menu, AI semua tingkat lewat `garis_depan.lua` (sasaran bangunan/markas, ATTACK langsung, perampok ekstraktor, menara masuk peta panas, titik tunggu hanya di sel yang bisa dilalui). Brutal vs Normal 7 menang, 3 kalah, 2 seri (12 ronde).
