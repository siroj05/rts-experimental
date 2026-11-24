# Verdant Ridge 4v4

Kandidat peta perebutan empat titik untuk Recoil 2026.09.03. Buka [Uji Punggung Hijau 4v4.cmd](../Uji%20Punggung%20Hijau%204v4.cmd) untuk bermain sebagai pemain pertama di barat bersama tiga sekutu AI melawan empat AI timur. Peluncur menjalankan paket dari folder kerja privat `.cache/main-punggung-hijau/`. [Denah markas, titik dan besi](../maps/punggung-hijau-denah.png)

## Ukuran dan tempo

| Ukuran | Nilai |
|---|---|
| Medan | 8192 × 6144 elmo, 1024 × 768 m, 16 × 12 SMU |
| Grid Blender dan heightmap Recoil | 1025 × 769 simpul, jarak 1 m, tinggi 16 bit |
| Albedo | 8192 × 6144 piksel, 8 piksel per meter |
| Elevasi | −3,10 hingga +42,22 m terhadap muka air |
| Area markas | 8 bidang datar 112 × 112 m, elevasi 7 m |
| Vegetasi dan medan | 4.100 pinus, 11,35% permukaan dominan pasir, 18,07% sel typemap terblokir |
| Arsip | 23.742.670 byte atau 22,64 MiB |
| Target kemenangan | 100.000 poin per kubu, 60 poin/detik per titik, radius 88 elmo atau 11 m |

Empat jalur utama menghubungkan barat–timur. Pada penampang utara–selatan, pita ±25 m dari garis tengah masing-masing jalur bebas sel blokir di antara barisan markas. Jarak minimum pusat pohon ke garis tengah 27,97 m. Celah batu selebar nominal 16 m membuka jalur memotong antarkoridor di kedua sisi. Anak sungai membagi dua kawasan tengah, dengan ambang dangkal yang naik melewati permukaan air. Medan, blokir dan penempatan pohon dicerminkan terhadap X = 4096 elmo. Selisih tinggi maksimum kedua sisi pada heightmap final 0 m.

Jarak lurus HQ terdekat ke titik berkisar 390,0–390,1 m untuk kedua tim. Pada laju maksimum Medium Tank 5,5 m/detik, lintasan lurus sepanjang lebar peta memerlukan sekitar 3 menit 6 detik. Dalam uji gerak, tank paling cepat mencapai titik dalam 68,5 detik dari petak berangkat di sisi dalam markas.

## Penempatan

Koordinat berikut dalam **meter dari sudut barat laut**, X ke timur, Z ke selatan. Kalikan delapan untuk koordinat Recoil. Nilai elmo lengkap dan tapak ekonomi AI ada di [skenario](../game/RTSPC.sdd/gamedata/skenario/hijau.lua).

| Titik | X | Z | Medan |
|---|---:|---:|---|
| A | 512 | 100 | Pelana di punggung utara, pusat pada elevasi 20 m |
| B | 512 | 275 | Padang terbuka antara punggung utara dan sungai |
| C | 512 | 478 | Celah dengan dinding batu di utara dan selatan |
| D | 512 | 670 | Dataran pasir kelabu di selatan |

- **Markas.** Barat X = 122 m, timur X = 902 m. Masing-masing punya empat markas pada Z = 94, 282, 478 dan 672 m.
- **24 ladang aman.** Untuk setiap markas barat tambahkan offset (−36, −28), (−32, +31) dan (+43, +12) m. Di timur balik tanda offset X.
- **16 ladang tengah.** Delapan posisi barat adalah (318, 82), (455, 124), (353, 247), (476, 303), (328, 456), (461, 493), (346, 635), (445, 686). Delapan posisi timur memakai (1024 − X, Z). Jarak terpendek antar-ladang 59,14 m.

## Sumber dan build ulang

Geometri medan, susunan batuan, tekstur makro, pewarnaan, mask rumput, ladang dan tata hutan dibuat secara prosedural untuk peta ini. Empat variasi pinus berasal dari `springcontent.sdz`, melalui `features/treetype.lua` dan model `fir_tree_*.s3o`. Kredit metadata Recoil menyebut Beherith dan 0 A.D. Wildfire Games menyebut CC BY-SA 3.0 untuk karya seni 0 A.D. Paket peta hanya menyimpan tipe, posisi dan rotasi pohon. [Lisensi seni 0 A.D.](https://play0ad.com/new-release-0-a-d-release-28-boiorix/) · [Definisi pohon bawaan Recoil](https://recoilengine.org/docs/guides/migrating-from-spring/)

Tekstur mikro albedo mengambil luminans `grass3.jpg` dan `detailtex2.bmp` dari `base/spring/bitmaps.sdz`. `README.txt` di arsip itu mencatat atribusi tentatif kepada SJ/Yeha dan tidak mencantumkan lisensi individual untuk kedua berkas. Rumput 3D dan air digambar Recoil. Blender memakai bentuk pinus sederhana sebagai penanda jenis, skala dan posisi.

Sumber ada di [folder Blender](../../blender-assets/peta/punggung-hijau-4v4/). Dari root repo dengan dependensi Recoil/PyMapConv proyek, Python 3 + NumPy/Pillow, dan Blender 5.2.3, jalankan di PowerShell:

```powershell
python tools/buat_punggung_hijau.py prepare
$blender = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
& $blender -b --python-exit-code 1 --python tools/punggung_hijau_blender.py
& $blender -b '../blender-assets/peta/punggung-hijau-4v4/punggung-hijau-4v4.blend' --python-exit-code 1 --python tools/punggung_hijau_blender.py -- --export-height
python tools/buat_punggung_hijau.py compile
```

`prepare` membangun sumber raster di `.cache/punggung-hijau-4v4/`. Blender menyimpan sumber berisi albedo tertanam serta render RTS. Ekspor balik dari mesh tersimpan menghasilkan heightmap identik byte per byte. Untuk revisi topografi besar, perbarui juga mask blokir, vegetasi dan albedo di [modul tata letak](../tools/punggung_hijau_layout.py). PyMapConv 0.6.3 mengemas SMF/SMT dan [mapinfo](../maps/mapinfo-punggung-hijau-4v4.lua) menjadi [arsip kandidat](../maps/punggung-hijau-4v4.sdz).

## Uji di Recoil

- **Peluncuran langsung.** Peluncur membuka Verdant Ridge 4v4 1.0 dengan delapan tim. Log grafis mencapai frame permainan tanpa error Lua. Log lokal ada di `.cache/main-punggung-hijau/infolog.txt`.
- **Gerak.** Dari tiap area markas, delapan unit uji berangkat dari petak bebas di depan HQ. Satu Medium Tank dan satu Infantry Robot menerima satu perintah Move ke masing-masing titik A–D. AI lawan dan tembakan dinonaktifkan di salinan uji agar lintasan tiap unit dapat diukur. Pusat unit dicocokkan dengan kecepatan kelas medan setiap frame sampai masuk radius 11 m. **64/64 tiba, 0 melewati sel blokir**, dengan 4.100 fitur pinus fisik aktif. Waktu simulasi tank 68,5–165,9 detik, robot 68,2–200,0 detik. Hasil terakhir di `.cache/uji-punggung-rute-fir/uji.log`, frame 6002.
- **Grafis.** RTX 4060, 1600 × 900, VSync mati, 38 entitas unit/bangunan pada saat pengambilan. Kamera seluruh peta dengan HUD tersembunyi membaca **375 FPS**, kamera dekat markas dengan HUD **278 FPS**. Ini dua pembacaan saat screenshot di awal pertandingan. Dengan HUD juga tampil pada kamera jauh, pengambilan terpisah mencatat 281 FPS jauh dan 257 FPS dekat. Beban pertempuran akhir belum diukur.
- **Bukti.** [Seluruh peta](punggung-hijau/shot-00-seluruh-peta.jpg) · [Markas barat](punggung-hijau/shot-01-markas-barat.jpg) · [A](punggung-hijau/shot-02-A-punggung-bukit.jpg) · [B](punggung-hijau/shot-03-B-padang.jpg) · [C](punggung-hijau/shot-04-C-celah.jpg) · [D](punggung-hijau/shot-05-D-pasir.jpg). PNG asli dan log pengambilan ada di `.cache/uji-visual/verdant-final/`.

## Serah terima untuk Claude

Kunci skenario `hijau`, nama start script `Verdant Ridge 4v4 1.0`, arsip `punggung-hijau-4v4.sdz`. Satu baris pemilih skenario menghubungkan ketiganya. Untuk menu gunakan [start script](../game/RTSPC.sdd/gamedata/skenario/hijau-start.txt).

Saat ini game utama memuat definisi pohon bawaan khusus skenario sungai dan pinus. Peluncur kandidat mendaftarkan pohon hanya pada salinan privat. Saat mengintegrasikan kandidat ke menu/paket Windows, muat `features/treetype.lua` dari `VFS.BASE` ke tabel featuredefs bagi skenario `hijau`. Pengujian grafis dan gerak di atas menggunakan definisi pohon ini. Logika skor, kemampuan mengarungi air dan jejak kendaraan bisa ditentukan terpisah dari pendaftaran model pohon.

Dari zoom paling jauh, pencerminan tebing dan hutan terbaca jelas. Pasir D dan padang B sama-sama berada pada elevasi 7 m, sehingga warna permukaan dan posisi tebing menjadi pembeda utama. Uji rute menggunakan satu skenario deterministik. Lama pertandingan penuh dan keseimbangan kemenangan antartim masih perlu playtest.

