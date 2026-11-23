# RTS PC v3

Lingkungan pengembangan Windows x64 untuk RTS PC dengan Recoil Engine.

## Prioritas pengerjaan

**Poin 1 selesai** · Roster dari daftar aktif V2 tersedia di Recoil. Ada 8 unit, 10 bangunan, dan bangkai untuk semuanya.

**Poin 2 selesai diuji** · Dua temuan kontrol masih terbuka. Lihat [Regresi kontrol Central Hill](#regresi-kontrol-central-hill).

**Ditunda atas arahan pengguna**

- Poin 3 · Uji keseimbangan skirmish Easy, Normal, dan Hard.
- Poin 4 · Pengaturan volume, tampilan, dan sensitivitas kamera.
- Poin 5 · Paket build Windows dan uji instalasi dari folder bersih.
- Poin 6 · Peta kedua dan pemilih peta di menu.
- Uji performa pertempuran 50, 100, dan 200 unit pada zoom dekat dan jauh.

## Instalasi

Jalankan dari folder ini dengan PowerShell. Installer memakai curl dan tar bawaan Windows, memverifikasi SHA-256, dan memasang paket lokal di `.deps/`.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1
```

| Paket | Versi | Lokasi |
| --- | --- | --- |
| [Recoil Engine](https://github.com/beyond-all-reason/RecoilEngine/releases/tag/2026.09.03) | 2026.09.03 | `.deps/recoil/2026.09.03/` |
| [PyMapConv](https://github.com/Beherith/springrts_smf_compiler/releases/tag/v0.6.3) | 0.6.3 | `.deps/pymapconv/0.6.3/` |

`dependencies.windows.json` menyimpan versi, URL, dan hash arsip. Hash Recoil berasal dari metadata rilis GitHub. Hash PyMapConv dicatat dari unduhan resmi saat setup.

## Recoil

```powershell
Push-Location .\.deps\recoil\2026.09.03
.\spring.exe --version
.\spring-headless.exe --list-skirmish-ais
Pop-Location
```

Instalasi memakai `isolated.txt` agar Recoil mencari konten dan menyimpan data pengembangan di folder lokalnya. Tempatkan paket game di `games/` dan peta di `maps/` di bawah folder engine. [Panduan Recoil](https://recoilengine.org/docs/guides/getting-started/first-steps-with-the-engine/)

Paket game utama ada di [game/RTSPC.sdd](game/RTSPC.sdd). Launcher menyalin paket ini dan arsip peta ke instalasi lokal Recoil. Folder `uji/` menyimpan start script dan gambar uji. Start script Bukit mengaktifkan opsi `skenario=bukit` untuk memuat [konfigurasi Bukit](game/RTSPC.sdd/gamedata/skenario/bukit.lua), termasuk titik perebutan, ladang besi, posisi relatif unit awal, dan tapak yang dipakai lawan.

## Uji langsung

Klik dua kali `Uji Bukit 1v1.cmd` untuk membuka menu skirmish offline di Recoil. Pilih **Easy**, **Normal**, atau **Hard**, lalu klik **Start Match**. Pilihan terakhir disimpan saat memulai pertandingan. Panah atas/bawah dan Enter juga bisa dipakai.

Saat pertandingan skirmish, tekan **Esc** untuk menjeda simulasi. Pilih **Resume**, **Restart Match**, atau **Back to Skirmish**. Memulai ulang mempertahankan tingkat kesulitan AI. Mode uji langsung tetap memakai kontrol Recoil.

| AI | Interval keputusan | Ambang produksi pasukan |
| --- | ---: | ---: |
| Easy | 4 detik | 6 |
| Normal | 2 detik | 9 |
| Hard | 1 detik | 12 |

Hard juga dapat menugaskan satu unit tambahan untuk memperkuat titik. Mode **Control Points** dimulai dari markas. Klik kiri untuk memilih unit atau seret kotak untuk memilih beberapa. Klik kanan untuk bergerak. Tekan **A**, lalu klik tank lawan atau tanah dalam jangkauan untuk menyerang. Gulir untuk zoom dan pakai tombol panah untuk menggeser kamera.

Menu berada di `menu/RTSPCMenu.sdd/`. Jalankan `python tools/buat_peta_skirmish.py` untuk membuat ulang peta briefing dari relief Bukit. Font lokal Barlow Medium dan Barlow Condensed Bold karya Jeremy Tribby memakai [SIL Open Font License](menu/RTSPCMenu.sdd/LuaMenu/fonts/OFL.txt). [Sumber Barlow](https://github.com/google/fonts/tree/main/ofl/barlow) · [Sumber Barlow Condensed](https://github.com/google/fonts/tree/main/ofl/barlowcondensed)

### Pembangunan dan produksi

1. Pilih **Engineer Bot**, klik **Vehicle Factory** dan pilih lahan datar yang cukup luas. Putar arah bangunan dengan **[** atau **]** dan sisakan jalan di depan pintu.
2. Buka **Production** di pabrik. **Vehicle Factory** memproduksi Light Tank, Medium Tank, Tank Destroyer, Scout Halftrack, dan Light Artillery. **Robot Factory** memproduksi Engineer Bot, Infantry Robot, dan Rocket Robot. Klik kanan medan saat pabrik dipilih untuk menentukan titik kumpul.
3. Tempatkan **Iron Extractor** pada penanda kuning. Ekstraktor menempel ke pusat ladang, satu per ladang. Ekstraktor aktif memberi 2,5 besi/detik dengan biaya 3 energi/detik.
4. Tempatkan **Oil Pump** di lahan datar untuk menambah 10 energi/detik. Markas sendiri memberi 1 besi dan 15 energi/detik serta bisa melatih Insinyur pengganti.

Setiap tim mulai dengan satu Inti Komando, satu Insinyur, 800 besi dan 2.600 energi. Lawan AI membangun pabrik kendaraan, pompa, hingga dua ekstraktor, dan pabrik robot saat stok cukup. Pabrik AI memilih jenis pasukan yang terjangkau dari daftar produksinya. Jika insinyurnya hancur dan markas masih ada, lawan dapat membuat pengganti.

Untuk melewati menu, jalankan `powershell -NoProfile -ExecutionPolicy Bypass -File .\uji-bukit.ps1 -Langsung`. Ganti `-Langsung` dengan `-Tempur` untuk langsung menguji tiga Medium Tank per tim.

HUD menampilkan peran, HP, dan jangkauan senjata unit terpilih di kiri, perintah dan kartu bangun di tengah, serta sumber daya dan minimap A–D di kanan. Jangkauan Light Artillery ditulis 30–120 m. Perintah serang di dalam jarak minimum memunculkan pesan di atas panel perintah.

Saat pabrik dipilih, klik kiri kartu unit untuk menambah pesanan dan klik kanan untuk mengurangi. Progres dan peringatan sumber daya mengikuti produksi yang sedang berjalan. Klik kanan medan atau pilih **Orders → Rally Point** untuk mengatur tujuan unit yang keluar dari pabrik. Penanda teal menunjukkan rally pabrik yang sedang dipilih.

### Perebutan titik

- Biru mulai di barat dan Merah di timur. Pada mode `-Tempur`, masing-masing mulai dengan tiga Medium Tank.
- Lawan membagi pasukannya untuk mengambil titik kosong, memperkuat titik yang diperebutkan, dan mengambil kembali titik yang hilang. Ia memakai status titik yang tampil di HUD dan posisi pasukan lawan yang terlihat oleh timnya.
- A dan B berada di jalur utara, C dan D di jalur selatan. Bawa unit tempur ke lingkaran selama 4 detik untuk mengambil titik. Titik tetap dimiliki setelah unit pergi dan bisa direbut kembali.
- Saat kedua tim berada di lingkaran yang sama, perebutan dan skor titik itu berhenti. Saat penantang sendirian di dalam lingkaran, pemilik lama juga berhenti mendapat skor sampai titik aman atau berpindah.
- Setiap titik aman memberi **5 poin per detik**. Tim pertama yang mencapai **1.000 poin** menang. Jika keduanya mencapainya pada detik yang sama, hasilnya seri. Pada mode ekonomi, kehilangan Inti Komando juga mengakhiri pertandingan. Layar hasil menyediakan tombol **Play Again**.
- Posisi, radius, durasi perebutan, dan target skor ada di `game/RTSPC.sdd/gamedata/skenario/bukit.lua`.

### Medium Tank

Data unit ada di `game/RTSPC.sdd/gamedata/unit/medium_tank.lua` dan data meriam di `game/RTSPC.sdd/gamedata/senjata/meriam_medium.lua`. Angka awal dari v2 mencakup 1.200 HP, laju 5,5 m/detik, pandangan 45 m, biaya 300 besi dan 1.050 energi, serta meriam 110 damage, jangkauan 38 m dan reload 2,5 detik.

Roda dan track bergerak mengikuti jarak tempuh dan belokan setiap sisi. Track memakai lima pose geometri per sisi. Turret berputar, laras punya batas elevasi ±10°, dan proyektil berangkat dari moncong. Laras mundur 45 cm saat menembak.

Suara meriam memakai rekaman Medium Tank dari v2, sedangkan suara benturan memakai rekaman ledakan permukaan dari pustaka proyek. Kilatan moncong dan jejak asap memakai CEG di `game/RTSPC.sdd/gamedata/explosions.lua`.

Uji grafis mengonfirmasi roda berhenti saat kendaraan berhenti, proyektil keluar dari posisi moncong, dan perintah tembak ke balik bukit tertahan. [Kilatan moncong](uji/medium-tank-tembak.png)

Koreksi meriam menyesuaikan gravitasi diskret dan titik potong lintasan dengan permukaan tanah. Pada titik uji Medium Tank 14, 25, dan 36 m, selisih mendatar paling besar sekitar 1 cm. Pada titik uji 10 m dan lereng curam, meriam menahan tembakan.

Benturan tanah memakai [flipbook asli proyek](game/RTSPC.sdd/bitmaps/fx/ledakan-tanah.png) dan 192 serpihan tanah serta bara 3D per benturan. Atlas 2048 × 1024 berisi 32 frame pada petak 256 × 256, sekitar dua detik per ledakan. Pandangannya dibake dari volume Blender pada sudut RTS 50°. Di Recoil, api, asap, dan debu menghadap kamera. Serpihan punya geometri sendiri dan jatuh ke permukaan.

Senjata lain bisa mengaktifkannya dengan `customparams.efek_benturan_tanah = "1"` di definisi senjata. Gadget memakai selisih tinggi maksimum 1,5 elmo dari permukaan untuk memilih efek tanah, sehingga benturan ke bagian unit yang sangat dekat dengan tanah bisa memakai visual tanah. Recoil tetap menghitung damage dan memutar audio. Untuk bake ulang, jalankan Blender dengan `--background --python tools/bake_ledakan_tanah.py`. Skrip membaca `../blender-assets/efek/ledakan-tanah/ledakan-tanah.blend` dan memakai Python dengan Pillow untuk mengemas atlas.

Benturan baja memakai [flipbook 16 frame](game/RTSPC.sdd/bitmaps/fx/benturan-baja.png) dari demo Medium Tank melawan Destroyer, ditambah percikan dan serpihan 3D. Aktifkan lewat `customparams.efek_benturan_baja = "1"`. Deteksi baja memakai kedekatan unit pada titik benturan di atas permukaan. Untuk bake ulang, tambahkan `-- baja` pada perintah Blender di atas.

Model uji memakai skala 8 elmo per meter untuk peta kecil ini, dan atlas warna tim/emisi untuk shader bawaan Recoil. Konverter `tools/impor_medium_tank.py` membaca GLB dan pivot dari v2. Jalankan dengan Python, NumPy, dan Pillow untuk meregenerasi aset. Konverter menggabungkan submesh material menjadi satu primitive GLB per bagian untuk menghindari indeks segitiga yang tertimpa di importer Recoil 2026.09.03.

Model markas dan bangunan ekonomi juga berasal dari aset v2. Konverter `tools/impor_markas.py` mengemas ulang tekstur, posisi soket, dan pose pintu pabrik. Ekstraktor dan pompa memakai pose model statis.

### Impor Fraksi 1

`tools/impor_unit_fraksi1.py` membangun aset dari model Fraksi 1 asli, bangkai dan audio dari v2, serta memasukkan model Pabrik Robot. Node.js memakai dependensi konverter v2 untuk dekode meshopt. Jalankan `python tools/buat_potret_hud.py` sesudahnya untuk memperbarui potret. Statistik roster ada di `game/RTSPC.sdd/gamedata/fraksi1.lua`.

Daftar aktif V2 berisi **8 unit dan 10 bangunan**. `tools/impor_bangunan_fraksi1.py` mengimpor model Gardu, Gudang, Radar, Tiang Relay, dan Menara Pertahanan, serta bangkai seluruh bangunan. Semua bangunan selain Inti Komando tersedia lewat **Build** pada Engineer Bot. Inti Komando ada di awal ronde dan memproduksi Engineer Bot. Daftar produksi kedua pabrik mengikuti V2.

Tiang Relay memperluas jaringan dari Command Core. Substation memberi listrik lokal dengan biaya 5 energi/detik. Radar dan Defense Tower memerlukan sambungan dan energi, sedangkan Depot menambah simpanan 3.000 besi dan 500 energi. Ini port fungsi roster. Pabrik dan ekstraktor memakai aturan energi V3 yang sudah ada, dan AI memakai rencana pembangunan Bukit yang sama. Model pompa dan ekstraktor memakai pose statis.

Di Central Hill, uji roster memverifikasi kelima bangunan dapat dibangun, penambahan kapasitas Depot, putaran dan jangkauan deteksi Radar, tembakan Menara, putus sambung jaringan, dan bangkai 10 bangunan. Uji klik HUD memeriksa sembilan kartu Build, dan regresi produksi memverifikasi kedelapan unit keluar dari pabrik.

Model hidup memakai warna tim, roda/track berfase, dan bagian bidik terpisah sesuai model. Robot Roket memakai pose langkah dari Blender, sedangkan Robot Infanteri memakai langkah prosedural. Recoil memakai atlas warna tim/refleksi/emisi bawaannya, dengan tekstur hasil impor yang dipadatkan agar semua model dapat dimuat bersamaan.

### LOD unit

Delapan unit Fraksi 1 memakai model ringan saat jarak kamera ke unit mencapai 150 m. Saat kamera mendekat hingga di bawah 135 m, model penuh tampil kembali. Unit dalam konstruksi tetap memakai tampilan Recoil. Ikon pada zoom jauh, bayangan yang dicetak unit, dan refleksi air tetap ditangani Recoil.

LOD memakai atlas yang sama dan mengikuti transformasi serta visibilitas bagian dari unit yang sedang berjalan. Lima kendaraan berangkat dari LOD yang sudah disetujui. Roda Medium Tank disederhanakan dari roda V3 karena roda kiri dan kanan bergerak independen. Ketiga robot disederhanakan per bagian dari model aktif.

| Unit | Segitiga LOD pada satu pose | Segitiga tersimpan dengan seluruh fase |
| --- | ---: | ---: |
| Engineer Bot | 3.742 | 9.950 |
| Infantry Robot | 2.038 | 2.038 |
| Rocket Robot | 3.696 | 3.696 |
| Scout Halftrack | 5.998 | 10.606 |
| Light Tank | 7.110 | 11.718 |
| Medium Tank | 7.902 | 12.510 |
| Tank Destroyer | 7.094 | 11.702 |
| Light Artillery | 6.800 | 10.544 |

Jalankan `python tools/impor_lod.py` setelah impor model penuh untuk membangun ulang `game/RTSPC.sdd/objects3d/lod/`. Konverter memeriksa nama bagian, pivot sumber, urutan material, dan batas keseluruhan dengan toleransi 1 cm. Setel `RTSPCUnitLOD = 0` di konfigurasi Recoil sebelum memulai game untuk membandingkan dengan model penuh.

## Bukit Tengah 1v1

Peta uji 2.048 ? 2.048 elmo dengan markas barat dan timur, bukit batu terblokir, dan dua koridor. Ada tiga titik besi dekat tiap markas dan dua di tiap koridor. Terrain, tekstur, dan penempatan mineral dibuat prosedural khusus untuk v3.

- Paket peta dan hasil kompilasi engine tersedia di `maps/bukit-tengah-1v1.sdz` dan `.deps/recoil/2026.09.03/maps/bukit-tengah-1v1.sdz`.
- Nama peta dalam game dan start script ialah `Central Hill 1v1 1.0`.
- [Denah](maps/bukit-tengah-denah.png) ? [Tampilan Recoil](maps/bukit-tengah-recoil.png)
- Uji gerak Recoil dengan kendaraan sementara melewati koridor utara dan selatan. Satu unit tambahan diperintah langsung ke markas lawan dan memilih jalur memutar sendiri. Posisi ketiganya diperiksa pada tiap frame simulasi dan semuanya tiba tanpa memasuki sel bukit. Log lokal tersedia di `.cache/tes-recoil-bukit/uji.log`.
- Peta ini dipakai untuk mematangkan aturan pertandingan, navigasi, dan statistik sebelum membuat map berikutnya.

Bangun ulang dengan Python, NumPy, dan Pillow setelah dependensi Windows terpasang.

```powershell
python tools/buat_bukit_tengah.py
```

### Balance pembukaan dan AI

Setiap pembukaan diuji pada tiga seed dengan Biru dikendalikan skrip dan Merah memakai AI skenario. Semua waktu dihitung dari awal pertandingan. Pembukaan ekonomi paralel memesan Insinyur kedua dari markas dan mulai membangun Pabrik Kendaraan setelah ekstraktor pertama selesai.

| Pembukaan Biru | Unit tempur pertama | Titik pertama | Poin Biru pada 2:00 | Skor Biru–Merah per seed |
| --- | ---: | ---: | ---: | --- |
| Kendaraan dulu | 48 dtk | 60 dtk | 630 | 985–1.000, 985–1.000, 1.000–630 |
| Robot dulu | 42 dtk | 62 dtk | 530 | 730–1.000, 945–1.000, 770–1.000 |
| Ekonomi dulu | 101 dtk | 113 dtk | 40 | 100–1.000, 205–1.000, 275–1.000 |
| Ekonomi paralel | 78 dtk | 90 dtk | 155 | 365–1.000, 405–1.000, 300–1.000 |

Scout Halftrack merebut titik pertama lebih cepat meski selesai diproduksi setelah Infantry Robot. Pada pembukaan robot, pabrik kedua tertunda 94–103 detik ketika produksi menyerap besi. Ekonomi dulu memiliki 427 besi dan 1.812 energi pada menit kedua. Upaya paralel mempercepat perebutan titik 23 detik, tetapi Merah tetap menang pada ketiga seed.

Tank Destroyer sekarang memberi 170 damage nominal ke lapis baja berat (dari 102), dan Rocket Robot 56,25 (dari 45). Dalam uji sasaran diam, damage aktual terhadap Medium Tank naik dari 368 ke 613 untuk Tank Destroyer dan dari 203 ke 253 untuk Rocket Robot. Light Artillery teruji tidak menembak pada 20 m dan mengenai sasaran di 70 m saat sasaran terlihat oleh Scout.

AI mengutamakan pemulihan Insinyur dan pabrik. Insinyur melanjutkan konstruksi yang terhenti dan pemasukan disisihkan sampai pabrik pengganti jadi. Dalam uji stok minim, Insinyur kembali dalam 9 detik dan Pabrik Kendaraan dalam 168 detik. Pabrik Robot yang dihancurkan terpisah kembali dalam 48 detik. Uji taktik memverifikasi pasukan tambahan dikirim memperkuat titik B dan artileri membantu dari luar lingkaran perebutan.

Jalankan `python tools/uji_balance.py --seed 1 2 3` di folder proyek. Hasil dan log Recoil ada di `.cache/balance-bukit/`. Angka pembukaan mewakili strategi skrip di Bukit, sehingga balansi untuk pemain manusia masih perlu dinilai lewat playtest.

### Uji kontrol dan pembukaan 1×

Uji grafis memakai klik mouse untuk kartu HUD dan perintah medan. Skrip mengatur kamera, seleksi, dan urutan klik. Tiga ronde memakai seed 1 dan rencana yang sama setelah pembukaan. Biru mengirim tiga unit ke A dan C, lalu mempertahankan perintah terakhir sampai pertandingan selesai.

| Pembukaan Biru | Unit tempur pertama | Titik pertama | Skor 2:00 | Skor akhir Biru–Merah |
| --- | ---: | ---: | ---: | ---: |
| Kendaraan dulu | 50 dtk | 67 dtk | 270–290 | 385–1.000 |
| Robot dulu | 46 dtk | 71 dtk | 250–290 | 320–1.000 |
| Ekonomi dulu | 94 dtk | 111 dtk | 50–290 | 130–1.000 |

Dalam uji kontrol terpisah, lima unit campuran tiba setelah **Move**, mengenai sasaran saat menjalankan **Attack Move**, menerima perintah fokus tembak, lalu kembali saat pemain klik kanan ke arah mundur. Light Tank keluar dari pabrik dan tiba di rally. Uji HUD memeriksa penanda rally, pesan **Low iron**, rentang 30–120 m, dan peringatan artileri saat sasaran berada di bawah 30 m. Log dan tangkapan layar tersedia lokal di `.cache/kontrol-v7-*-1280x800/`.

### Regresi kontrol Central Hill

Jalankan `python tools/uji_kontrol.py`. Pilih satu skenario lewat `--case koridor`, `--case rally`, atau `--case lereng`. Uji headless memakai salinan game, seed 1, dan AI skenario nonaktif. Log setiap skenario ada di `.cache/uji-kontrol/<case>/uji.log`. Perintah mengembalikan kode 1 bila ada baris `KONTROL, GAGAL`.

| Uji | Hasil |
| --- | --- |
| Dua koridor, delapan jenis unit per sisi, dua waypoint dan satu Gudang di tiap sisi | 16 unit melewati garis tengah. Utara 8/8 dan selatan 7/8 masuk radius 4 m dari tujuan. |
| Tiga produk Pabrik Kendaraan dan tiga produk Pabrik Robot | Keenam unit keluar dari tapak. Lima masuk radius 4,5 m dari rally. |
| Medium Tank menembak tanah datar, kaki bukit, dan lereng miring | Ketiga kasus mencatat 6/6 benturan. Selisih mendatar terbesar 0,022 elmo. Perintah ke lereng curam dan arah puncak menahan tembakan. |
| Artileri Ringan ke lereng pada 73,75 m dan sasaran dekat pada 20 m | Tiga benturan ke lereng tercatat dalam jendela uji. Artileri menahan tembakan pada 20 m. |

Temuan yang bisa diulang, dengan koordinat `(x, z)` dalam elmo dan 8 elmo per meter.

1. **Light Tank berhenti sebelum tujuan di selatan.** Jalankan `--case koridor`. Grup memakai Hold Fire dan lewat `(790, 1631)` lalu `(1030, 1636)`. Light Tank dari `(575, 1693)` kehilangan perintah Move pada sampel frame 666, masih 6,59 m dari `(1395, 1628)`. Posisi akhirnya `(1359.46, 1616.61)` atau sekitar 4,67 m dari tujuan.
2. **Engineer Bot melewatkan rally Pabrik Robot.** Jalankan `--case rally`. Pabrik menghadap timur di `(560, 912)`, rally di `(705, 880)`, dan antrean Engineer Bot, Infantry Robot, Rocket Robot. Insinyur menerima perintah menuju rally pada frame 384. Pada frame 402 ia menjalankan perintah Move internal menjauh dari pintu, kemudian antreannya kosong pada frame 594. Ia berakhir di `(574.18, 985.66)`. Dua robot berikutnya sampai. Dalam uji pembanding dengan satu pesanan Engineer Bot, perintah rally juga habis dan unit berhenti di dekat titik keluarnya.

## Verifikasi

- Pada uji produksi, delapan jenis unit Fraksi 1 keluar dari pabrik dan masing-masing memunculkan bangkai. Tujuh jenis bersenjata diuji menembak. Artileri menahan tembakan di bawah 30 m dan melontar di luar batas itu.
- Pada uji klik HUD, kedua pabrik dibangun dan masing-masing mengeluarkan unit. Dua ekstraktor dan satu pompa menghasilkan pemasukan kotor tim 6 besi/detik dan 25 energi/detik. Kedua tim merebut A–D, AI memakai tiga jenis pasukan, Merah menang 1.000–240, dan **Play Again** membuka pertandingan baru. Log lokal ada di `.cache/bukit-hud-journey/uji.log`.
- Uji A/B di RTX 4060 memakai 72 unit tambahan, resolusi 1280 × 800, bayangan aktif, dan simulasi 1× selama sampel. Median 11 sampel naik dari 76 FPS (69–80) ke 116 FPS (108–126). Kedua percobaan mencatat 48 unit lolos lewat dua koridor dan 355 tembakan. Log lokal ada di `.cache/tes-roster-lod-0/uji.log` dan `.cache/tes-roster-lod-1/uji.log`.
- Executable utama, headless, dan dedicated server melaporkan 2026.09.03.
- Executable grafis berhasil menginisialisasi OpenGL 4.6 di NVIDIA GeForce RTX 4060.
- Recoil headless memindai AI bawaan dan menghitung checksum arsip peta uji.
- PyMapConv berhasil menghasilkan `.smf` dan `.smt` dari bitmap warna 1024 ? 1024 dan heightmap 129 ? 129. Log tes tersedia di `.cache/tes-peta/`.
- Rilis PyMapConv 0.6.3 memiliki bug pada `--help` dan mengembalikan kode 1 setelah kompilasi yang sudah selesai. Untuk CLI, jalankan dari direktori yang berisi `nvdxt.exe` dan verifikasi keluaran SMF/SMT. [Kode sumber PyMapConv 0.6.3](https://github.com/Beherith/springrts_smf_compiler/blob/v0.6.3/src/pymapconv.py)
