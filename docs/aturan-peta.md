# Aturan membuat peta

✅ Keputusan user 2026-11-26: "jadikan aturan saat membuat peta ya, aturan dari 2 game itu beserta tekniknya". Aturan
desain dan teknik ini diambil dari panduan pemetaan Beyond All Reason (BAR) dan komunitas Supreme Commander
(Forged Alliance Forever, FAF). Berlaku untuk semua peta baru, baik buatan Claude maupun GPT. Yang ditiru hanya
prinsip dan teknik. Peta, tekstur, model, dan aset BAR/SupCom tidak disalin.

Contoh penerapan: Limestone Valley 4v4 (`tools/lembah_kapur_layout.py`, `maps/lembah-kapur-denah.png`).

## 1. Ukuran

- Paling besar 32 × 32 SMU (1 SMU = 512 elmo = 64 m), juga untuk salah satu sisi saja (BAR: lebih besar tidak seru dan engine mulai berat).
- 1v1 sekitar 8–16 SMU. 4v4 sekitar 16–24 SMU. Limestone Valley 24 × 24 = 1536 × 1536 m.
- Catat waktu tempuh Medium Tank (5,5 m/detik): markas ke garis depan pertama, markas ke markas lawan, dan lebar peta.

## 2. Posisi start dan simetri

- Posisi start tetap, ditulis lengkap untuk jumlah pemain maksimum (BAR).
- Peta kompetitif simetris: cermin atau putar 180°. Putar 180° dipakai kalau sungai atau medan tengah perlu berkelok alami. Setiap markas harus punya pasangan setara di kubu lawan.
- Setelah heightmap jadi, ukur selisih tinggi dan jarak antarpasangan. Hasil tes AI di peta lama menunjukkan posisi peta bisa menentukan pemenang.

## 3. Sumber daya

- Logam total sekitar **5–15 per detik per pemain**, disebar di seluruh peta, bukan menumpuk di start. Prinsip BAR: "less metal = more strategy", kekurangan lebih baik daripada kelebihan. Hitung: jumlah tambang × 2,5 ÷ jumlah pemain.
- Start: **2–5 tambang aman** dalam jangkauan bangun di sekitar markas (FAF). Kita memakai 3.
- **Ekspansi = kelompok 3 tambang atau lebih**, bukan titik tunggal tersebar (FAF).
- Tiap tambang masuk salah satu dari empat zona (FAF):
  - **aman**: dekat pabrik atau jalur bala bantuan;
  - **bisa dirampok**: terpencil dan jauh dari bantuan, jadi sasaran mode ganggu AI;
  - **rebutan**: waktu tempuh sama bagi kedua kubu. **Jumlahnya sedikit saja**, karena pemenang perebutannya untung berlipat;
  - **mati**: tidak bernilai, cuma ruang manuver.
- Energi (pompa minyak) dibangun bebas oleh pemain, tidak perlu titik di peta.
- ✅ 2026-11-26 (user: "sebaran mineral kurang banyak dan kurang acak", memilih "tambang banyak, hasil turun"):
  - Peta boleh punya banyak tambang dengan hasil per ekstraktor lebih kecil. Total tetap harus 5–15 per pemain.
  - Limestone Valley punya 74 tambang × 1,5 = 13,9 besi/detik per pemain. Ekstraktornya di-override di
    `gamedata/defs.lua` per skenario.
  - Ekspansi boleh berupa kelompok acak berisi 1–4 tambang, menggantikan aturan FAF "kelompok ≥ 3".

## 4. Medan

- **Jangan terlalu tertutup.** Tebing dan punggung yang memanjang membuat pertempuran darat sulit (FAF). Pecah punggung jadi segmen dengan bukaan yang lebar.
- **Bedakan lorong panjang dan celah pendek.** Pasukan yang keluar dari lorong rugi menghadapi musuh yang sudah berbaris di luar (FAF). Pakai efek ini dengan sengaja, misalnya titik pertahanan di mulut bukaan.
- **Titik pertahanan:** teras datar yang bisa dibangun di lokasi strategis untuk menara. Gunanya meredam raid, dan bisa dipakai sebagai titik kumpul (FAF).
- **Jalur raid:** lorong sempit (±40–80 m) di tepi peta, sekaligus titik buta radar.
- **Bukit dan tanjakan menghalangi peluru tembak langsung**, jadi pertimbangkan garis tembak menara dan Destroyer.
- **Air dangkal** cuma membuka jalur untuk unit amfibi atau hover. Selama belum ada unit seperti itu, air dipakai untuk penyeberangan dan rintangan saja.
- **Teras markas harus datar** (radius ±70 m). Kemiringan jalur utama harus bisa dilalui Medium Tank, dan **seluruh peta diuji kemampuan lalunya** (BAR). Kita mengujinya dengan uji gerak Recoil: semua markas harus bisa mencapai semua tambang dan bukaan.
- **Medan harus terbaca dari tekstur** (BAR):
  - jalur kendaraan terlihat datar dan berumput;
  - lereng yang masih bisa dilalui terlihat kerikil atau pasir;
  - area yang tidak bisa dilalui jelas berupa batu kasar atau tebing.
- **Tekstur jalur utama dan bukaan dibuat bersih.** Detail ramai diletakkan di tepi dan tebing (BAR).

## 5. Objek peta (pohon, batu, reruntuhan)

- Kelompok pohon **tidak boleh di jalur yang sering dilewati unit atau insinyur**, dan harus cukup jauh dari markas (FAF).
- Pohon tunggal tidak berharga untuk di-reclaim (FAF). Kalau objek punya nilai reclaim, nilainya diatur sama untuk kedua kubu.
- Objek peta tidak boleh memakai tinggi Y tetap, karena bisa melayang kalau tinggi air atau medan berubah (BAR).
- Semua model buatan sendiri, 600–6.000 segitiga per model, 3 varian per jenis.
- ✅ 2026-11-26 (user): "pohon dan batu pakai punya recoil". Pohon memakai cemara bawaan Recoil
  (`fir_tree_*.s3o` di `springcontent.sdz`, didaftarkan lewat `features/treetype.lua` di `gamedata/defs.lua`).
  Konten bawaan Recoil 2026.09.03 tidak menyertakan model batu. User lalu meminta "batunya acak". Batu kapur dibuat sendiri dengan
  `tools/buat_batu.py`: 3 varian, 1.280 segitiga per varian, dan bongkah besar menghalangi jalan. Penyebarannya
  ditulis di fungsi `batu()` pada `tools/buat_<stem>.py`:
  - acak, lebih rapat di kaki tebing dan jarang di padang;
  - menjauhi rute, bukaan, arungan, tambang, teras pertahanan, markas, dan hutan;
  - simetris putar 180°.
  Setelah objek ditambah, uji gerak diulang.

## 6. Cahaya dan suasana

- Matahari dari sisi **utara** peta, tidak terlalu tinggi atau rendah, supaya bayangan membantu mengenali unit. Peta sedikit digelapkan, jangan terang penuh (BAR).
- Arah visual proyek: natural dan dramatis (kontras, kabut atmosfer, cahaya hangat dan dingin).
- Kepadatan kabut dicek dari zoom jauh (BAR).
- 🟡 2026-11-26 (Limestone Valley): skybox cubemap buatan sendiri (`tools/buat_langit.py`), dengan gradasi langit,
  silau ke arah `sunDir`, awan, dan dua lapis pegunungan di cakrawala. `fogColor` disamakan dengan kabut cakrawala
  skybox. `water.hasWaterPlane = false` supaya area di luar tepi peta menampilkan kabut skybox, bukan bidang air.
- Ambient dan bayangan dibuat sejuk kebiruan, matahari hangat.

## 6a. Bekas pertempuran

- ✅ 2026-11-26 (user): "permukaan yang diatasnya ada bangunan dia ada tapaknya tanah, terus map bisa berlubang
  permanen jika terkena tembakan atau ledakan".
- **Tapak bangunan**: decal tanah padat (`useBuildingGroundDecal`). Ukurannya tapak bangunan ditambah satu petak
  di tiap sisi. Diatur di `gamedata/defs.lua`, teksturnya dari `tools/buat_decal.py`.
- **Kawah permanen**: deformasi heightmap Recoil (`craterMult`, `craterAreaOfEffect`). Peta wajib
  `notDeformable = false`. Senjata kecil tidak membuat kawah. Kedalaman per peluru dari hasil ukur: Light 0,25 m,
  Medium 0,4 m, Destroyer 0,55 m, Rocket 0,1–0,25 m. Lima peluru artileri di titik yang sama menggali ±1,9 m.
- **Bekas kawah**: decal Lua permanen dari gadget `kawah_bekas.lua`. Bekas ledakan bawaan (`explosionScar`) tidak
  dipakai, karena shader Recoil mengalikan warnanya dengan minimap, jadi tanah cokelat di atas rumput berubah
  menjadi hijau gelap. Bekas yang terjadi di luar pandangan baru ditempel saat lokasinya terlihat oleh tim.
- **Jebakan teknis**:
  - Kunci def ditulis `buildingGroundDecal*`, tetapi di `UnitDefs` Lua namanya jadi `buildingDecal*`.
  - Gadget handler berhenti di gadget pertama yang `Explosion`-nya mengembalikan `true`. Gadget kawah memakai
    layer -10 supaya selalu jalan duluan.

## 7. Teknik pembuatan (pipeline)

Semua lapisan dibuat oleh generator Python per peta (`tools/buat_<stem>.py`), lalu dikompilasi dengan PyMapConv. Blender hanya dipakai dalam mode **headless** (`blender.exe --background --python ...`) untuk aset yang dipakai ulang, supaya tidak mengganggu Blender yang sedang dipakai GPT.

| Lapisan | Ukuran (peta X × Z SMU) | Format | Catatan |
|---|---|---|---|
| Heightmap | 64·X + 1 × 64·Z + 1 | 16-bit | 8 elmo per piksel. Bentuk dasar dari denah, lalu **erosi hidrolik dan termal**. Keluarannya juga peta aliran air dan endapan untuk tekstur. |
| Tekstur warna (diffuse) | 512·X × 512·Z | BMP → SMT | 1 piksel per elmo. Diturunkan dari data medan: lereng curam = batu, alur air = kerikil, datar = rumput, cekungan digelapkan (AO/cavity), plus variasi warna. |
| Normal map | 512·X (maksimal 8K; "preferably always 8K") | DDS | Relief halus dari heightmap dan detail erosi. |
| Specular | 256·X × 256·Z (4K boleh) | RGBA DDS | Kilap per permukaan. |
| DNTS: peta campuran | 2048 px (pangkat dua) | RGBA PNG/TGA | 4 kanal untuk 4 tekstur detail, dari jenis medan dan kemiringan. |
| DNTS: 4 tekstur detail | 512–1024 px, seamless | **TGA**, bukan DDS (kanal hijau normal map bisa terbalik) | Contoh: rumput, tanah, kerikil, batu. Dibuat sekali lalu dipakai ulang (`tools/buat_dnts.py`). 🟡 2026-11-26: dibuat dengan numpy (sintesis spektral FFT, voronoi periodik) karena noise prosedural Blender tidak seamless. RGB = normal ruang tangen (R = +X, G = +Z, B = atas), A = detail terang-gelap berpusat 0,5 (`splatDetailNormalDiffuseAlpha = true`). Ukuran fitur minimal ±20 cm dan kontras alpha sedang (std ±0,05–0,1): fitur lebih kecil hilang oleh mipmap, kontras lebih tinggi terlihat belang. Jumlah bobot campuran ±0,7 supaya normal detail map-wide tetap terlihat. Skala ubin (`splats.texScales`) dan intensitas diatur di `mapinfo`. |
| Metal map | sesuai PyMapConv | BMP | Titik tambang dari modul layout. |
| Type map, grass map | 16·X × 16·Z | BMP | Jenis tanah dan kepadatan rumput. |
| Minimap | 1024 × 1024 | BMP | |
| Skybox | ±1–2K per sisi | cubemap DDS (BC3) | `tools/buat_langit.py` + `dds_bc3.simpan_bc3_kubus`. Urutan sisi OpenGL, utara = -z. |

Urutan kerja per peta, dan tiap tahap dicek sebelum lanjut:

1. **Denah**: modul layout (`tools/<stem>_layout.py`) berisi semua posisi dalam meter, ditambah gambar denah dan laporan angka (logam per pemain, waktu tempuh, jarak antarpasangan). Tunjukkan ke user dulu.
2. **Heightmap dan erosi.**
3. **Uji gerak di Recoil**: semua jalur bisa dilalui, teras datar, kedua kubu setara.
4. **Tekstur warna, normal map, specular.**
5. **DNTS.**
6. **Langit, cahaya, kabut, air.**
7. **Objek peta.**
8. **Integrasi**: skirmish, tes AI Deathmatch, fps, dokumen `docs/peta-<stem>.md`.

Verifikasi selalu memakai screenshot Recoil sungguhan, close-up dan dari sudut kamera RTS, serta angka terukur (fps, ukuran file, hasil tes AI).

## Sumber

- [BAR: map checklist](https://www.beyondallreason.info/guide/map-checklist)
- [BAR: mapping 1, file structure & prerequisites](https://www.beyondallreason.info/guide/mapping-1-file-structure-prerequisites)
- [BAR: mapmaking resources](https://www.beyondallreason.info/guide/mapmaking-resources)
- [MapsBalance (mirror wiki BAR)](https://github-wiki-see.page/m/beyond-all-reason/springrts_engine_wiki_mirror/wiki/MapsBalance)
- [Beherith: springrts_smf_compiler (PyMapConv)](https://github.com/Beherith/springrts_smf_compiler)
- [FAF: Patterns for map makers](https://docs.google.com/document/d/1HSoJUGNn27KQsLGo5Cqnstm0CU-RBab8-bk1-1vZwpY/export?format=pdf)
- [FAF: Mapping wiki](https://wiki.faforever.com/en/Development/Mapping)
