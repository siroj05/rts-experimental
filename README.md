# RTS PC v3

Lingkungan pengembangan Windows x64 untuk RTS PC dengan Recoil Engine.

## Prioritas pengerjaan

**Poin 1 selesai** · Roster dari daftar aktif V2 tersedia di Recoil. Ada 8 unit, 10 bangunan, dan bangkai untuk semuanya.

**Poin 2 selesai** · Perbaikan tujuan akhir Light Tank dan rally Engineer Bot diuji ulang di Central Hill. Lihat [Regresi kontrol Central Hill](#regresi-kontrol-central-hill).

**Poin 6 selesai** · Central Hill dan River Valley dapat dipilih di menu skirmish.

**Ditunda atas arahan pengguna**

- Poin 3 · Uji keseimbangan skirmish Easy, Normal, dan Hard.
- Poin 4 · Pengaturan volume, tampilan, dan sensitivitas kamera.
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

### Build Windows x64

Jalankan `python tools/build_windows.py` dari Windows untuk membuat `dist/windows/RTS-PC-v3-win-x64.exe`. Skrip mengambil game, menu, dan peta dari commit `HEAD`, lalu membundel Recoil sesuai versi dan checksum di commit tersebut. Compiler .NET Framework Windows membangun peluncurnya.

Klik dua kali executable untuk mengekstrak game ke `%LOCALAPPDATA%\RTS PC v3\<commit>` dan membuka menu skirmish offline. Untuk ekstraksi portabel, jalankan `RTS-PC-v3-win-x64.exe --extract "C:\Games\RTS PC v3"` lalu buka `RTS PC.exe` dari folder hasil ekstraksi. Informasi build dan sumber Recoil tersedia di `BUILD.txt`.

Paket baru memakai mode jendela dan VSync standar dari `config/windows-defaults.cfg`. Keduanya disetel lewat `springsettings.cfg` karena Recoil 2026.09.03 mengabaikan `--window` ketika fullscreen masih aktif di konfigurasi.

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

Klik dua kali `Uji Bukit 1v1.cmd` untuk membuka menu skirmish offline di Recoil. Buka dropdown **Map** untuk memilih **Central Hill**, **River Valley**, **Pine Crossing**, atau **Verdant Ridge**. Pilih **Easy**, **Normal**, atau **Hard**, lalu klik **Start Match**. Menu menyimpan peta dan tingkat kesulitan saat pertandingan dimulai. Space membuka daftar peta. Di luar daftar, panah kiri/kanan memilih peta, panah atas/bawah memilih tingkat AI, dan Enter memulai pertandingan.

Saat pertandingan skirmish, tekan **Esc** untuk menjeda simulasi. Pilih **Resume**, **Restart Match**, atau **Back to Skirmish**. Memulai ulang memakai peta dan tingkat kesulitan AI pertandingan itu. Mode uji langsung tetap memakai kontrol Recoil.

Angka AI ada di `game/RTSPC.sdd/gamedata/profil_ai.lua`: Easy, Normal, dan Hard berbeda pada interval keputusan (4/2/1 detik), jumlah Engineer Bot (1/2/3), batas pasukan (20/36/50), ukuran gelombang (4/6/8), dan jumlah ekstraktor. Cara kerja AI dan hasil ujinya ada di `docs/tahapan.md`.

Hard juga dapat menugaskan satu unit tambahan untuk memperkuat titik. Mode **Control Points** dimulai dari markas. Klik kiri untuk memilih unit atau seret kotak untuk memilih beberapa. Klik kanan untuk bergerak. Tekan **A**, lalu klik tank lawan atau tanah dalam jangkauan untuk menyerang. Gulir untuk zoom dan pakai tombol panah untuk menggeser kamera.

**Mode pertandingan.** Menu skirmish punya dua tab: **Control Points** (kuasai titik A–D sampai skor target, atau hancurkan semua Command Core musuh) dan **Deathmatch** (tanpa titik dan skor; menang dengan menghancurkan semua Command Core musuh). Deathmatch memakai modoption `mode=hancur`. Panel atas menampilkan jumlah Command Core tersisa per kubu. Tingkat AI keempat, **Brutal**, membaca skor dan kekuatan, mengingat musuh yang menyerangnya, mundur untuk diperbaiki, dan belajar dari efektivitas unitnya.

Menu berada di `menu/RTSPCMenu.sdd/`. Jalankan `python tools/buat_peta_skirmish.py` untuk membuat ulang pratinjau kedua peta dari relief. Font lokal Barlow Medium dan Barlow Condensed Bold karya Jeremy Tribby memakai [SIL Open Font License](menu/RTSPCMenu.sdd/LuaMenu/fonts/OFL.txt). [Sumber Barlow](https://github.com/google/fonts/tree/main/ofl/barlow) · [Sumber Barlow Condensed](https://github.com/google/fonts/tree/main/ofl/barlowcondensed)

### Pengaturan dan tampilan

Tekan **Esc** saat bermain lalu pilih **Settings** untuk mengatur volume, jarak ikon unit, bayangan, kecepatan zoom, dan health bar. Pilihan disimpan ke `springsettings.cfg`. Health bar tampil di atas unit yang rusak, terpilih, atau sedang dibangun. Pada zoom jauh unit berganti menjadi ikon berwarna tim (`tools/buat_ikon.py`).

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
- Setiap titik aman memberi **1 poin per detik**. Tim pertama yang mencapai **2.400 poin** sambil unggul menang (memegang 2 titik sekitar 20 menit, 4 titik 10 menit). Jika keduanya mencapainya dengan skor sama, pertandingan berlanjut sampai ada yang unggul. Pada mode ekonomi, kehilangan Inti Komando juga mengakhiri pertandingan. Layar hasil menyediakan tombol **Play Again**.
- Posisi, radius, durasi perebutan, dan target skor ada di `game/RTSPC.sdd/gamedata/skenario/bukit.lua`.

### Medium Tank

Data unit ada di `game/RTSPC.sdd/gamedata/unit/medium_tank.lua` dan data meriam di `game/RTSPC.sdd/gamedata/senjata/meriam_medium.lua`. Angka awal dari v2 mencakup 1.200 HP, laju 5,5 m/detik, pandangan 45 m, biaya 300 besi dan 1.050 energi, serta meriam 110 damage, jangkauan 38 m dan reload 2,5 detik.

Roda dan track bergerak mengikuti jarak tempuh dan belokan setiap sisi. Track memakai lima pose geometri per sisi. Turret berputar, laras punya batas elevasi ±10°, dan proyektil berangkat dari moncong. Laras mundur 45 cm saat menembak.

Suara meriam memakai rekaman Medium Tank dari V2, sedangkan suara benturan memakai rekaman ledakan permukaan dari pustaka proyek. Kilatan moncong dan jejak asap berjalan lewat `game/RTSPC.sdd/LuaRules/Gadgets/efek_tempur_v2.lua`.

Uji grafis mengonfirmasi roda berhenti saat kendaraan berhenti, proyektil keluar dari posisi moncong, dan perintah tembak ke balik bukit tertahan. [Kilatan moncong](uji/medium-tank-tembak.png)

Koreksi meriam menyesuaikan gravitasi diskret dan titik potong lintasan dengan permukaan tanah. Pada titik uji Medium Tank 14, 25, dan 36 m, selisih mendatar paling besar sekitar 1 cm. Pada titik uji 10 m dan lereng curam, meriam menahan tembakan.

Benturan tanah memakai [flipbook asli proyek](game/RTSPC.sdd/bitmaps/fx/ledakan-tanah.png) dan 192 serpihan tanah serta bara 3D per benturan. Atlas 2048 × 1024 berisi 32 frame pada petak 256 × 256, sekitar dua detik per ledakan. Pandangannya dibake dari volume Blender pada sudut RTS 50°. Di Recoil, api, asap, dan debu menghadap kamera. Serpihan punya geometri sendiri dan jatuh ke permukaan.

Senjata lain bisa mengaktifkannya dengan `customparams.efek_benturan_tanah = "1"` di definisi senjata. Gadget memakai selisih tinggi maksimum 1,5 elmo dari permukaan untuk memilih efek tanah, sehingga benturan ke bagian unit yang sangat dekat dengan tanah bisa memakai visual tanah. Recoil menghitung damage. Klien menampilkan efek dan memutar suara tempur berdasarkan pandangan tim setempat. Untuk bake ulang, jalankan Blender dengan `--background --python tools/bake_ledakan_tanah.py`. Skrip membaca `../blender-assets/efek/ledakan-tanah/ledakan-tanah.blend` dan memakai Python dengan Pillow untuk mengemas atlas.

Benturan baja memakai [flipbook 16 frame](game/RTSPC.sdd/bitmaps/fx/benturan-baja.png) dari demo Medium Tank melawan Destroyer, ditambah percikan dan serpihan 3D. Aktifkan lewat `customparams.efek_benturan_baja = "1"`. Deteksi baja memakai kedekatan unit pada titik benturan di atas permukaan. Untuk bake ulang, tambahkan `-- baja` pada perintah Blender di atas.

Model uji memakai skala 8 elmo per meter untuk peta kecil ini, dan atlas warna tim/emisi untuk shader bawaan Recoil. Konverter `tools/impor_medium_tank.py` membaca GLB dan pivot dari v2. Jalankan dengan Python, NumPy, dan Pillow untuk meregenerasi aset. Konverter menggabungkan submesh material menjadi satu primitive GLB per bagian untuk menghindari indeks segitiga yang tertimpa di importer Recoil 2026.09.03.

Model markas dan bangunan ekonomi juga berasal dari aset v2. Konverter `tools/impor_markas.py` mengemas ulang tekstur, posisi soket, dan pose pintu pabrik. Ekstraktor dan pompa memakai pose model statis.

### Efek tempur dari V2

Meriam, roket, dan senjata ringan memilih model tracer 3D dan profil asap lewat `customparams.fx_jejak`. `python tools/impor_tracer_v2.py` membangun ulang tiga model tracer. Tracer meriam menyala sepanjang 1,4 m. Jejak meriam biasa mengikuti profil V2 dengan jarak 0,6 m antargumpalan, jeda 0,04 detik, dan umur 0,19 detik. Asap mengikuti posisi proyektil Recoil. Untuk artileri jejak tertinggal sekitar 2,45 detik per gumpalan sambil hanyut.

Kilatan moncong dan ledakan unit memakai mesh 3D dengan shader api prosedural. Asap dan debu satu bidang per partikel menghadap kamera, seperti implementasi V2. Ledakan unit mencakup inti api, bola api dengan buntut asap, percikan, serpihan dan asap bangkai sampai 24 detik. Reklamasi bangkai menghentikan keluaran asap. Efek benturan tanah dan baja yang sudah dibake tetap dipakai dan senjata ringan mendapat percikan serta debu prosedural saat kena tanah.

`sounds/unit-hancur-v2.ogg` berasal dari `Assets/Konten/Suara/Kandidat/244394.mp3` di V2, [Bang/Explosion Metallic](https://freesound.org/people/Werra/sounds/244394/) oleh Werra, CC0. Dipotong sampai 3 detik dengan pudar 80 ms mengikuti durasi di V2. Ini suara kandidat yang sudah dipakai sementara di V2.

Konstruksi dan reklamasi memakai visual Recoil. Shockwave belum aktif.

Bangunan berdiri di atas tapak tanah padat (decal `tools/buat_decal.py`). Peluru berat menggali kawah permanen di peta yang bisa dideformasi (Limestone Valley, Verdant Ridge). Kedalamannya 0,25–0,55 m per peluru, dan senjata kecil tidak membuat kawah. Gadget `kawah_bekas.lua` menempelkan bekas tanah teraduk yang tidak memudar.

### Suara mesin kendaraan

Light Tank, Medium Tank, dan Scout Halftrack masing-masing memakai rekaman mesin V2. Tank Destroyer dan Light Artillery memakai profil Medium Tank. Mixer audio lokal menghitung satu campuran per profil dari kendaraan yang terlihat, laju kendaraan, jarak ke titik pandang, dan zoom kamera. Mesin meredup antara 45 dan 100 m dari kamera ke titik pandang. Suara mesin memakai kanal pertempuran dengan prioritas lebih rendah dari suara senjata.

Setiap loop 4 detik dibagi menjadi 16 potongan WAV dengan peralihan 100 ms. Untuk membangunnya ulang dari rekaman V2, jalankan `python tools/impor_suara_mesin.py`. Game memuat hasilnya dari `game/RTSPC.sdd/sounds/mesin/`.

| Profil | Sumber | Pembuat | Lisensi |
| --- | --- | --- | --- |
| Light Tank | [AMX-13 Engine.wav](https://freesound.org/people/AdamHarvester/sounds/702456/) | AdamHarvester | CC0 |
| Medium Tank | [Driving Tank Engine.flac](https://freesound.org/people/qubodup/sounds/187676/) | qubodup | CC0 |
| Scout Halftrack | [djeep_idle.wav](https://freesound.org/people/Mihacappy/sounds/840649/) | Mihacappy | CC0 |

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

## Lembah Sungai 1v1

Pilih **River Valley** di menu skirmish atau buka `Uji Lembah Sungai 1v1.cmd` untuk langsung bermain melawan AI Normal. Peta berukuran 4.096 × 4.096 elmo atau 512 × 512 m. Tiap pihak mulai dengan Command Core, Engineer Bot, dan satu Medium Tank untuk mencoba jejak track dan menembak tanah. Ada empat titik perebutan dan 12 ladang besi. [Denah peta](maps/lembah-sungai-denah.png)

Ada dua penyeberangan dangkal yang bisa dilintasi unit darat. Typemap membatasi sungai yang dalam dan bukit curam. Sebaran cemara memakai empat model `fir_tree_*.s3o` dari `springcontent.sdz` dengan tabrakan bawaan Recoil. Rumput, detail tanah, material air, dan tekstur decal diambil dari `bitmaps.sdz` Recoil. Layout dan tinggi medannya dibuat prosedural untuk proyek ini.

Setelah menjalankan `setup.ps1`, jalankan `python tools/buat_lembah_sungai.py` untuk membuat ulang paket `.sdz`. Skrip membentuk heightmap, menyusun warna medan dari tekstur bawaan, lalu memberi PyMapConv peta jenis medan, mask rumput, minimap, dan posisi pohon. Recoil menggambar jejak track ketika kendaraan berjalan di darat dan menempelkan bekas ledakan saat peluru berat mengenai permukaan. Bekas tembakan yang terlihat memudar dalam sekitar dua menit. [Dokumentasi decal Recoil](https://recoilengine.org/docs/guides/rendering/using-decals/)

## Verdant Ridge 4v4

Pilih **Verdant Ridge** di Skirmish atau buka `Uji Punggung Hijau 4v4.cmd` untuk langsung bermain. Peta 1024 ? 768 m ini memiliki empat jalur perebutan, 40 ladang besi, dan 4.100 pinus. Setiap titik menghasilkan 1 poin per detik untuk kubu yang menguasainya. Target kemenangan 2.400. [Denah dan sumber peta](docs/peta-punggung-hijau.md)

## Verdant Ridge 4v4

Pilih **Verdant Ridge** di Skirmish atau buka `Uji Punggung Hijau 4v4.cmd`. Peta 1024 × 768 m dengan empat jalur utama, titik A–D di garis tengah, 40 ladang besi, pegunungan batu penghalang, dan dataran pasir kelabu di selatan. Rincian, sumber, dan cara build ulang ada di [docs/peta-punggung-hijau.md](docs/peta-punggung-hijau.md).

## Pine Crossing 4v4

Pilih **Pine Crossing** di Skirmish. Peta 512 × 384 m ini memakai tiga penyeberangan dangkal, empat titik perebutan, 36 deposit besi, dan pohon bawaan Recoil. Satu pemain dan tujuh AI terbagi menjadi dua kubu. Skor dibagi per kubu dengan aturan yang sama seperti peta lain (1 poin per detik per titik, target 2.400).

Sumber Blender ada di `../blender-assets/peta/pine-crossing-4v4/pine-crossing-4v4.blend`. Medan memakai grid 1 m dan albedo prosedural orisinal 4096 × 3072. Untuk membuat ulang versi prosedural, jalankan `python tools/buat_pine_crossing.py prepare`, jalankan Blender dengan `-b --python tools/blender_pine_crossing.py -- <folder staging> <folder sumber>`, lalu jalankan `python tools/buat_pine_crossing.py compile`. Folder staging adalah `.cache/lintasan-pinus-4v4` dan folder sumber adalah folder peta Blender di atas.

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

Setiap pembukaan berikut diuji saat target skor masih 1.000 poin, pada tiga seed dengan Biru dikendalikan skrip dan Merah memakai AI skenario. Semua waktu dihitung dari awal pertandingan. Pembukaan ekonomi paralel memesan Insinyur kedua dari markas dan mulai membangun Pabrik Kendaraan setelah ekstraktor pertama selesai.

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

Uji grafis ini berlangsung saat target skor masih 1.000 poin. Skrip mengatur kamera, seleksi, dan urutan klik untuk kartu HUD serta perintah medan. Tiga ronde memakai seed 1 dan rencana yang sama setelah pembukaan. Biru mengirim tiga unit ke A dan C, lalu mempertahankan perintah terakhir sampai pertandingan selesai.

| Pembukaan Biru | Unit tempur pertama | Titik pertama | Skor 2:00 | Skor akhir Biru–Merah |
| --- | ---: | ---: | ---: | ---: |
| Kendaraan dulu | 50 dtk | 67 dtk | 270–290 | 385–1.000 |
| Robot dulu | 46 dtk | 71 dtk | 250–290 | 320–1.000 |
| Ekonomi dulu | 94 dtk | 111 dtk | 50–290 | 130–1.000 |

Dalam uji kontrol terpisah, lima unit campuran tiba setelah **Move**, mengenai sasaran saat menjalankan **Attack Move**, menerima perintah fokus tembak, lalu kembali saat pemain klik kanan ke arah mundur. Light Tank keluar dari pabrik dan tiba di rally. Uji HUD memeriksa penanda rally, pesan **Low iron**, rentang 30–120 m, dan peringatan artileri saat sasaran berada di bawah 30 m. Log dan tangkapan layar tersedia lokal di `.cache/kontrol-v7-*-1280x800/`.

### Regresi kontrol Central Hill

Jalankan `python tools/uji_kontrol.py`. Pilih satu skenario lewat `--case koridor`, `--case koridor-stop`, `--case rally`, `--case rally-barat`, `--case lereng`, `--case artileri`, atau `--case radar`. Uji headless memakai salinan game, seed 1, dan AI skenario nonaktif. Log setiap skenario ada di `.cache/uji-kontrol/<case>/uji.log`. Perintah mengembalikan kode 1 bila ada baris `KONTROL, GAGAL`.

Uji `radar` memeriksa tiga kondisi sasaran di Central Hill. Radar berlistrik memberi perkiraan posisi, pandangan langsung memberi posisi bidik persis, dan artileri melepas kunci setelah kedua sensor kehilangan sasaran. Uji grafis terpisah dari sisi pemain Biru memperlihatkan titik radar, model Medium Tank, lalu kontak hilang. Dalam ketiga kondisi, tank Merah menembak. Kilatan, benturan, dan suara mesin Merah muncul saat terlihat langsung.

| Uji | Hasil |
| --- | --- |
| Dua koridor, delapan jenis unit per sisi, dua waypoint dan satu Gudang di tiap sisi | 16/16 unit masuk radius 4 m dari tujuan. Kasus `koridor-stop` memeriksa pembatalan pendekatan akhir dengan Stop. |
| Tiga produk Pabrik Kendaraan dan tiga produk Pabrik Robot | 6/6 keluar dari tapak dan mencapai rally di tiap orientasi. `rally` menguji pabrik menghadap timur dan `rally-barat` memakai posisi cermin. |
| Medium Tank menembak tanah datar, kaki bukit, dan lereng miring | Ketiga kasus mencatat 6/6 benturan. Selisih mendatar terbesar 0,022 elmo. Perintah ke lereng curam dan arah puncak menahan tembakan. |
| Artileri Ringan ke lereng pada 73,75 m dan sasaran dekat pada 20 m | Tiga benturan ke lereng tercatat dalam jendela uji. Artileri menahan tembakan pada 20 m. |
| Artileri Ringan dari Pabrik Kendaraan, dua perintah Move, dan Attack Ground | Artileri harus tiba, menghadap sasaran dalam toleransi 3°, dan meletakkan tembakan pertama dalam 0,5 m dari sasaran. |

Reproduksi perbaikan memakai koordinat `(x, z)` dalam elmo dan 8 elmo per meter.

1. **Tujuan akhir Light Tank di selatan.** Jalankan `--case koridor`. Grup memakai Hold Fire dan lewat `(790, 1631)` lalu `(1030, 1636)`. Light Tank dari `(575, 1693)` sebelumnya berhenti 4,67 m dari `(1395, 1628)` setelah Recoil menutup perintah Move terlalu dini. Sekarang, jika Move terakhir ditutup dengan status selesai di luar radius 4 m, jalur ke tujuan yang bisa dilalui diminta kembali satu kali setelah tank berhenti. Waypoint perantara tetap dijalankan oleh Recoil. Perintah baru membatalkan percobaan yang masih menunggu.
2. **Rally Engineer Bot dari Pabrik Robot.** Jalankan `--case rally`. Pabrik menghadap timur di `(560, 912)`, rally di `(705, 880)`, dan antrean Engineer Bot, Infantry Robot, Rocket Robot. Sebelumnya bukaan di yard map berada di sisi yang berlawanan dari soket produksi. Kolom bukaan dicerminkan agar sejajar dengan pintu dan soket. Posisi model serta ukuran tapak 16 × 16 m tetap sama.
3. **Artileri Ringan berhenti sebelum badan selesai membidik.** Recoil menganggap sasaran sudah masuk kerucut 3D, padahal meriam tetap masih meleset dari sasaran secara horizontal. Artileri yang sudah berhenti melanjutkan putaran badan memakai kecepatan putarnya sendiri saat ada target sah. Jalankan `--case artileri` untuk menguji sasaran serong di `(980, 1740)` setelah unit keluar dari pabrik.

## Verifikasi

- Pada uji produksi, delapan jenis unit Fraksi 1 keluar dari pabrik dan masing-masing memunculkan bangkai. Tujuh jenis bersenjata diuji menembak. Artileri menahan tembakan di bawah 30 m dan melontar di luar batas itu.
- Pada uji klik HUD, kedua pabrik dibangun dan masing-masing mengeluarkan unit. Dua ekstraktor dan satu pompa menghasilkan pemasukan kotor tim 6 besi/detik dan 25 energi/detik. Kedua tim merebut A–D, AI memakai tiga jenis pasukan, Merah menang 1.000–240, dan **Play Again** membuka pertandingan baru. Log lokal ada di `.cache/bukit-hud-journey/uji.log`.
- Uji A/B di RTX 4060 memakai 72 unit tambahan, resolusi 1280 × 800, bayangan aktif, dan simulasi 1× selama sampel. Median 11 sampel naik dari 76 FPS (69–80) ke 116 FPS (108–126). Kedua percobaan mencatat 48 unit lolos lewat dua koridor dan 355 tembakan. Log lokal ada di `.cache/tes-roster-lod-0/uji.log` dan `.cache/tes-roster-lod-1/uji.log`.
- Executable utama, headless, dan dedicated server melaporkan 2026.09.03.
- Executable grafis berhasil menginisialisasi OpenGL 4.6 di NVIDIA GeForce RTX 4060.
- Recoil headless memindai AI bawaan dan menghitung checksum arsip peta uji.
- PyMapConv berhasil menghasilkan `.smf` dan `.smt` dari bitmap warna 1024 ? 1024 dan heightmap 129 ? 129. Log tes tersedia di `.cache/tes-peta/`.
- Rilis PyMapConv 0.6.3 memiliki bug pada `--help` dan mengembalikan kode 1 setelah kompilasi yang sudah selesai. Untuk CLI, jalankan dari direktori yang berisi `nvdxt.exe` dan verifikasi keluaran SMF/SMT. [Kode sumber PyMapConv 0.6.3](https://github.com/Beherith/springrts_smf_compiler/blob/v0.6.3/src/pymapconv.py)
