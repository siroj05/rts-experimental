# Serah terima untuk agen berikutnya

Untuk model AI (Claude, GPT) atau orang yang melanjutkan proyek tanpa riwayat percakapan. Baca seluruhnya sebelum mengubah apa pun.

## 1. Urutan baca
1. `CLAUDE.md` (aturan proyek) atau `AGENTS.md` (aturan GPT/Codex, mode A dan B).
2. Dokumen ini.
3. `docs/tahapan.md`: rencana 0–10, status, keputusan user.
4. `README.md`: fitur, peta, cara bangun ulang aset, hasil uji lama.
5. Arsip `../rts-pc-v2` (Unity) dan `../rts-pc` (Rust/Three.js): sumber angka unit, aset asli, dan efek.

## 2. Peta kode
Game adalah paket Lua `game/RTSPC.sdd` (Recoil memuatnya sebagai game `RTSPC.sdd`). Skala **8 elmo = 1 m**.

- `gamedata/`
  - `defs.lua` menggabungkan `unit/markas.lua`, `unit/medium_tank.lua`, dan `fraksi1.lua` (statistik 8 unit + bangunan, dikonversi dari angka V2).
  - `senjata/`, `explosions.lua`, `lontar.lua` (balistik, jarak minimum artileri).
  - `profil_ai.lua`: tingkat AI Easy/Normal/Hard (interval keputusan, batas pasukan).
  - `skenario.lua` memilih skenario dari modoption `skenario` + nama peta. `skenario/<nama>.lua` berisi titik perebutan (`titik`), ladang besi (`ladang`), posisi awal (`awal`), rencana bangun AI (`lawan`), skor (`poinPerDetik`, `targetSkor`), dan `<nama>-start.txt`.
  - `rig_*`, `pintu_pabrik*.lua`, `mesin_kendaraan.lua`: data animasi dan suara.
- `LuaRules/Gadgets/` (synced kecuali efek):
  - `mulai_skenario.lua` memunculkan unit awal; `perebutan_titik.lua` skor titik; `lawan_skenario.lua` AI skenario (seluruh logika ada di dalam `buatPengendali()`).
  - `ladang_besi.lua` satu ekstraktor per ladang; `daya_fraksi1.lua` jaringan listrik radar/menara.
  - `lintasan_meriam.lua` koreksi gravitasi meriam dan busur artileri; `tujuan_tank_ringan.lua` perbaikan tujuan Move.
  - Efek: `efek_tempur_v2.lua` (moncong, jejak, ledakan, asap bangkai), `efek_benturan_tanah.lua` (flipbook benturan); `lod_unit.lua` model ringan berdasar jarak; `suara_mesin_kendaraan.lua`.
- `LuaUI/`: `main.lua` (kamera awal, skor, akhir pertandingan), `hud.lua` (panel seleksi, perintah, kartu bangun, sumber daya, minimap), `menu_jeda.lua` (Esc).
- `scripts/`: skrip animasi unit (turret, laras, roda, pintu pabrik).
- `menu/RTSPCMenu.sdd/LuaMenu/main.lua`: menu skirmish (pilih peta dan tingkat AI).
- `tools/`: impor model/LOD/suara dari V2, pembuat peta (PyMapConv, Blender), `build_windows.py`, uji headless (`uji_balance.py`, `uji_kontrol.py`), dan uji visual grafis (`uji_visual.py`).
- `maps/`: `.sdz` peta + `mapinfo-*.lua`. Peta: Central Hill 1v1, River Valley 1v1, Pine Crossing 4v4, Verdant Ridge 4v4.

## 3. Perintah
- Pasang engine: `powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1` (ke `.deps/`).
- Main lewat menu: `Uji Bukit 1v1.cmd`. Langsung: `uji-bukit.ps1 -Langsung | -Tempur | -Sungai`.
- **Uji visual** (grafis, screenshot + fps): `python tools/uji_visual.py <start-script> <nama> [--hook tools/uji_visual/<hook>.lua] [--spectator] [--opsi k=v]`. Hasil di `.cache/uji-visual/<nama>/shot-NN-*.png`. Hook bawaan `umum.lua` (10 menit, kamera ke pertempuran terpanas); `bentrok.lua` (pasukan campuran dipaksa bentrok di Central Hill, pakai `uji/bukit-1v1.txt --opsi lawanuji=0`).
- **Uji ronde AI vs AI** (headless, statistik tiap menit): `python tools/uji_ronde.py <start-script> --nama x --semua-ai --seed 1 2 3 [--menit 25] [--opsi uji_lacak=1]`. `uji_lacak=1` mencatat posisi dan perintah insinyur tiap 30 dtk.
- Uji balance lama (Biru skrip): `python tools/uji_balance.py --seed 1 2 3`. Uji kontrol: `python tools/uji_kontrol.py [--case ...]`.
- Paket Windows: `python tools/build_windows.py` (mengambil isi dari commit `HEAD`).
- Graph kode: `/graphify . --update` (lihat `graphify-out/GRAPH_REPORT.md`).

## 4. Jebakan yang sudah ditemui
- `/cheat` harus aktif satu frame sebelum `/give`; dikirim bersamaan, give ditolak ("cheats required").
- Di `LuaUI/main.lua` hanya ada satu fungsi global `Update`; hook yang mendefinisikan ulang `Update` menimpa yang sebelumnya. Bungkus fungsi lama, jangan timpa.
- Recoil 2026.09.03 mengabaikan `--window` kalau `Fullscreen=1` di `springsettings.cfg`; atur lewat cfg.
- Uji visual dengan `Spectator=1` di 4v4 membuat tim 0 tidak dikendalikan siapa pun (AI skenario melewati tim 0).
- PyMapConv 0.6.3: `--help` rusak dan selalu keluar dengan kode 1 setelah kompilasi; periksa hasil `.smf/.smt`.
- Graphify tidak membaca simbol di file data Lua (`return {...}`) maupun fungsi di dalam closure (`lawan_skenario.lua`), dan bisa salah menyambung fungsi lokal bernama sama di file berbeda (mis. `mulai()`).
- AI: tapak berpohon lolos `TestBuildOrder` (=2) tetapi insinyur harus reclaim pohonnya dulu dan bisa macet lama; selalu periksa `GetFeaturesInRectangle`.
- Perintah 90 di log = `CMD.RECLAIM`.
- Mask gambar engine unit: bit 1 = pass utama, bit 16 = bayangan. `lod_unit.lua` hanya mematikan bit 1.
- `UnitIconDist` dikali radius unit; nilai bawaan 200 berarti tank baru jadi ikon ±5.000 elmo.
- Hook `tools/uji_visual` tanpa SHOTS langsung keluar; untuk hook berbasis waktu, isi SHOTS dengan entri penahan `f = 1e9`.
- Kompilasi peta (PyMapConv) gagal "'nvdxt.exe' is not recognized" kalau environment punya `NoDefaultCurrentDirectoryInExePath=1` (diset di shell agen). Jalankan generator dengan variabel itu di-unset.
- Kunci rumput mapinfo yang benar: `grass = {bladeHeight, bladeWidth, bladeWaveScale, bladeColor}`. Kunci `grassBladeHeight` dkk. diabaikan diam-diam. Verdant Ridge sudah memakai kunci tahap 5 melalui `tools/poles_peta.py`.
- `tools/buat_pine_crossing.py compile` menulis ulang `gamedata/skenario/pinus.lua`; ubah konstanta di generator, bukan hanya file hasilnya.
- PowerShell `Get-Content`/`Set-Content` merusak UTF-8 tanpa BOM; pakai `[IO.File]` atau Python.

## 5. Status
Lihat `docs/tahapan.md`.

## 6. Protokol kerja bergantian
**Saat mulai:** baca bagian 7, lalu `git status` dan `git log --oneline -10`. File berubah yang belum di-commit bisa milik agen sebelumnya: jangan dibuang.
**Selama kerja:** satu langkah kecil sekali jalan: ubah, uji (headless dan/atau visual), catat di `docs/tahapan.md`.
**Sebelum berhenti (termasuk saat limit hampir habis):** tulis catatan di bagian 7 (paling atas): tanggal, agen, selesai, setengah jalan (file mana, langkah berikut persisnya), hasil uji, yang menunggu keputusan user. Commit hanya kalau user minta, dan hanya file milikmu.

## 7. Catatan sesi (terbaru di atas)
### 2026-11-25, Claude: AI Brutal garis depan (gaya C.R.A.I.G)
- Riset: C.R.A.I.G (AI Lua Spring:1944, GPL v2) dibaca sebagai referensi lalu ditulis ulang di `LuaRules/ai/garis_depan.lua`: grid 256 elmo, peta panas daya tembak, wilayah/garis depan, perebut terpisah (berpasangan, maks 2 per titik), regu menuju titik (komitmen +0,6), MOVE saat < 450 elmo dari titik, barisan ±60 di titik. Takut di titik mati (profil `takutTitik` untuk menghidupkan).
- Perbaikan semua tingkat: unit yang tertahan dekat pabrik dulu tidak pernah dilepas (sampai 29/48); sekarang dianggap keluar 20 detik setelah selesai (`lahir`).
- Hasil Verdant Ridge 4v4 Brutal vs Normal (gaya ekonomi, seed 1–3, dua sisi): 4 menang, 2 terpotong batas 30 menit dengan Brutal unggul/menguasai 4 titik. Sebelumnya 0/6.
- `tools/uji_ronde.py --batas-nyata` (4v4 dengan Brutal butuh 10–16 menit nyata per ronde).
- Log debug per regu di `AI KEADAAN`: `regu=<sel>x<n>(in,near,idle,@pusat)` dan `semua/lepas/dalam`.
- Langkah berikut: uji ulang peta kecil 24 ronde dan Brutal vs Hard, ukur fps 4v4, latih gaya (`tools/latih_ai.py`), lalu mode Saling Menghancurkan.

### 2026-11-24 (lanjutan 3), Claude: material markas + AI Brutal (setengah jalan, belum di-commit)
- Selesai: markas 70% (`tools/impor_markas.py` SKALA, footprint 9×9), pelapukan tex1 bangunan (`tools/poles_material.py lapuk()`, asli di `.cache/tex1-asli/`), clamp fase track di `scripts/unit_fraksi1.lua` dan `scripts/medium_tank.lua` (error `sp_SetPieceVisibility` nil).
- ✅ User: mode rebut titik tetap jadi mode utama (mode "saling serang" ditunda). User minta AI "brutal, hasrat ingin menang bukan cuma puas point, mampu berfikir balas dendam" dan "bisa belajar".
- Hard (profil `hatiHati` + 2 pabrik, 8 ekstraktor) vs Normal: 6/12 (awal 3/12). Ditahan di situ.
- Setengah jalan: otak Brutal `LuaRules/ai/otak_brutal.lua` (ingatan LOS, dendam, mode dari skor, sasaran titik/ekonomi/markas/pasukan, kumpul lalu serbu, deteksi macet, mundur + insinyur perawat, belajar efektivitas unit, gaya main per peta). Disambung di `lawan_skenario.lua` (cabang `if otak then` di urusPasukan). Profil `brutal` di `profil_ai.lua`, baris ke-4 di menu (`menu/RTSPCMenu.sdd/LuaMenu/main.lua`). Statistik antarronde `gamedata/belajar_ai.lua`, dilatih `tools/latih_ai.py` (belum pernah dijalankan).
- Log otak: `AI GAYA tim= gaya=` dan tiap menit `AI KEADAAN tim= t= mode= sasaran= fase= kita= musuh= pusat= tuju= n= tunggu= jaga= mundur=`.
- Uji Brutal vs Normal: versi awal 5/12. Bug yang sudah dibetulkan: pasukan macet di depan sungai, unit "mundur" tidak pernah lepas (18 unit), memilih titik kandang musuh daripada titik dekat rumah, memburu kelompok musuh tak terjangkau. Sesudahnya: Central Hill 3/3, River Valley 1/3 (sisi Brutal tim 0 saja).
- Kendali pasukan penuh oleh otak (`pasukanOtak`) tetap kalah (1/6–4/6), jadi dimatikan. Brutal sekarang = logika titik Hard (`hatiHati`, ambang dari `otak.Ambang()` per mode) + `otak.Rawat` (mundur/perawat) + `kilat` (4 pengintai di 3 menit pertama) + `bersihkan` (Hard juga: insinyur reclaim bangkai di ladang sendiri) + belajar produksi + gaya.
- Analisis 127 ronde (skrip di scratchpad, ulangi dengan regex atas `RONDE, SKOR/TIM`): titik dipegang di menit 4 menebak pemenang 79%, pemasukan besi menit 8 80%, jumlah pasukan 52%. Gaya `serbu` 0/4.
- Hasil terakhir Brutal vs Normal (gaya ekonomi dipaksa, seed 4–9, 24 ronde): **9/24**. River Valley sisi tim 0: 0/6. Pemasukan rata-rata sama (13,7 vs 13,9). Brutal lebih lemah dari Hard (6/12).
- Langkah berikut: ablation 24 ronde per fitur (tanpa `kilat`, tanpa `mundur`, insinyur 2) untuk menemukan fitur yang merugikan; baru setelah itu langkah ekonomi (rebut/jaga ladang, serbu ekstraktor musuh dengan kelompok kecil). User menolak bonus sumber daya ("tanpa bonus"). Target: Brutal ≥10/12 vs Normal, ≥8/12 vs Hard.
### 2026-11-24, Codex ? Verdant Ridge masuk Skirmish
- Permintaan user mengaktifkan peta kandidat. Peluncur repo, peluncur langsung dan staging Windows memuat peta, pratinjau, skenario serta pinus dari game utama. Skor mengikuti tahap 1. Rumput dan cahaya mengikuti tahap 5.
- Build Windows lokal dari working tree `7f256062c80b`. Uji dropdown ? Start Match dari paket memeriksa 8 HQ, 4 titik, 40 ladang dan 4.100 pinus. Uji navigasi 64/64 lulus. [Laporan dan dua screenshot integrasi](peta-punggung-hijau.md).
- Pekerjaan integrasi selesai. Balance ronde penuh Verdant Ridge belum diukur. Perubahan siap ditinjau bersama pekerjaan Claude sebelum commit.

### 2026-11-24 (lanjutan 2), Claude
- Selesai (belum di-commit): tahap 5 albedo + rumput, 6 sebagian (pantulan), 7 tracer, 8 health bar + ikon, 9 Settings, 10 diukur. Rincian di `docs/tahapan.md`.
- Selesai juga: bayangan LOD (`DrawShadowUnitsLua`) + LOD 560 elmo. Menunggu: model game ringan dari GPT, normal map/skala markas, notifikasi.
- Alat baru: `tools/grading_medan.py`, `tools/poles_material.py`, `tools/buat_ikon.py`, `tools/uji_visual.py --cfg/--tanpa` (A/B), hook `pengaturan.lua`, `ikon.lua`, `ui.lua`, `performa.lua.tpl`.
- Regresi: uji_kontrol 7/7, uji_balance seed 1 7/7.
### 2026-11-24 (lanjutan), Claude
- Selesai: tahap 1–4 (tempo, AI, ekonomi diukur, `tools/uji_ronde.py`), tahap 5 sebagian (cahaya/kabut via `tools/poles_peta.py`). Rincian dan angka di `docs/tahapan.md`.
- Berikutnya: tahap 5 albedo, lalu 6 (material model), 7 (efek), 8 (UI), 9 (pengaturan), 10 (performa).
- Belum di-commit. Peta GPT `punggung-hijau-4v4` sedang dikerjakan (ada `maps/mapinfo-punggung-hijau-4v4.lua`); jangan disentuh.
### 2026-11-24, Claude
- Mengambil alih v3 penuh (user: "gua mau lu ambil alih penuh v3 ini"). Rencana 0–10 di `docs/tahapan.md`, disetujui user ("kerjakan 1 sampai 10").
- Perubahan yang belum di-commit sebelum sesi ini (22 file + Pine Crossing 4v4, dari user/GPT) dipakai sebagai titik awal, belum di-commit.
- Dibuat: `CLAUDE.md`, `AGENTS.md`, dokumen ini, `docs/tahapan.md`, `tools/uji_visual.py` + `tools/uji_visual/*.lua`, `graphify-out/`.
- GPT diberi tugas mode B: peta 4v4 baru "Verdant Ridge 4v4" (stem `punggung-hijau-4v4`, skenario `hijau`). Pendaftaran ke menu dikerjakan Claude setelah GPT selesai.
