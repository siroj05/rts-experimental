# RTS PC v3

Lingkungan pengembangan Windows x64 untuk RTS PC dengan Recoil Engine.

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

## Uji langsung

Klik dua kali `Uji Bukit 1v1.cmd` untuk menjalankan Recoil dengan Bukit Tengah dan Medium Tank dari v2. Klik kiri untuk memilih tank atau seret kotak untuk memilih beberapa. Klik kanan untuk bergerak. Tekan **A**, lalu klik tanah dalam jangkauan untuk menembak. Klik kanan di minimap sisi berlawanan dari markas untuk menguji jalur memutar. Gulir untuk zoom dan pakai tombol panah untuk menggeser kamera.

Paket uji memiliki tiga Medium Tank per sisi dengan NullAI di tim lawan. Roda dan track bergerak mengikuti jarak tempuh dan belokan setiap sisi. Track memakai lima pose geometri per sisi. Turret berputar, laras punya batas elevasi ±10°, dan proyektil berangkat dari moncong. Laras mundur 45 cm saat menembak.

Suara meriam memakai rekaman Medium Tank dari v2, sedangkan suara benturan memakai rekaman ledakan permukaan dari pustaka proyek. Kilatan moncong, jejak asap, dan benturan memakai partikel sprite Recoil yang dapat dipakai ulang dari `uji/BukitUji.sdd/gamedata/explosions.lua`.

Uji grafis mengonfirmasi roda berhenti saat kendaraan berhenti, proyektil keluar dari posisi moncong, dan perintah tembak ke balik bukit tertahan. [Kilatan moncong](uji/medium-tank-tembak.png) · [Benturan di tanah](uji/medium-tank-benturan.png)

Model uji memakai skala 8 elmo per meter untuk peta kecil ini, dan atlas warna tim/emisi untuk shader bawaan Recoil. Konverter `tools/impor_medium_tank.py` membaca GLB dan pivot dari v2. Jalankan dengan Python, NumPy, dan Pillow untuk meregenerasi aset. Konverter menggabungkan submesh material menjadi satu primitive GLB per bagian untuk menghindari indeks segitiga yang tertimpa di importer Recoil 2026.09.03.

## Bukit Tengah 1v1

Peta uji 2.048 ? 2.048 elmo dengan markas barat dan timur, bukit batu terblokir, dan dua koridor. Ada tiga titik besi dekat tiap markas dan dua di tiap koridor. Terrain, tekstur, dan penempatan mineral dibuat prosedural khusus untuk v3.

- Paket peta dan hasil kompilasi engine tersedia di `maps/bukit-tengah-1v1.sdz` dan `.deps/recoil/2026.09.03/maps/bukit-tengah-1v1.sdz`.
- Nama lengkap untuk start script ialah `Bukit Tengah 1v1 1.0`.
- [Denah](maps/bukit-tengah-denah.png) ? [Tampilan Recoil](maps/bukit-tengah-recoil.png)
- Uji gerak Recoil dengan kendaraan sementara melewati koridor utara dan selatan. Satu unit tambahan diperintah langsung ke markas lawan dan memilih jalur memutar sendiri. Posisi ketiganya diperiksa pada tiap frame simulasi dan semuanya tiba tanpa memasuki sel bukit. Log lokal tersedia di `.cache/tes-recoil-bukit/uji.log`.
- Peta sudah bisa dimuat bersama paket game uji. Untuk skirmish RTS PC, masih perlu definisi unit dan aturan pertandingan v3.

Bangun ulang dengan Python, NumPy, dan Pillow setelah dependensi Windows terpasang.

```powershell
python tools/buat_bukit_tengah.py
```

## Verifikasi

- Executable utama, headless, dan dedicated server melaporkan 2026.09.03.
- Executable grafis berhasil menginisialisasi OpenGL 4.6 di NVIDIA GeForce RTX 4060.
- Recoil headless memindai AI bawaan dan menghitung checksum arsip peta uji.
- PyMapConv berhasil menghasilkan `.smf` dan `.smt` dari bitmap warna 1024 ? 1024 dan heightmap 129 ? 129. Log tes tersedia di `.cache/tes-peta/`.
- Rilis PyMapConv 0.6.3 memiliki bug pada `--help` dan mengembalikan kode 1 setelah kompilasi yang sudah selesai. Untuk CLI, jalankan dari direktori yang berisi `nvdxt.exe` dan verifikasi keluaran SMF/SMT. [Kode sumber PyMapConv 0.6.3](https://github.com/Beherith/springrts_smf_compiler/blob/v0.6.3/src/pymapconv.py)
