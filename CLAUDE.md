# RTS PC v3 (Recoil Engine)

Proyek RTS aktif sejak 2026-11-24, dibangun di Recoil Engine 2026.09.03 (engine Beyond All Reason). `../rts-pc-v2` (Unity) dan `../rts-pc` adalah arsip: sumber aset, data, dan angka, tidak dikembangkan lagi. Keputusan user: "pakai recoil karna biar gaperlu bangun dari 0 semuanya jadi kita tinggal tune up aja".

Balas user dalam bahasa Indonesia santai (lu/gua). Teks UI game berbahasa Inggris.

## Mulai dari sini
1. `docs/serah-terima.md`: peta kode, perintah, jebakan, protokol kerja bergantian, catatan sesi terakhir. **Wajib.**
2. `docs/tahapan.md`: rencana kerja 0–10, status, dan keputusan user.
3. `README.md`: dokumentasi fitur dan cara pakai.

Repo dikerjakan bergantian dengan GPT (aturannya di `AGENTS.md`). Ikuti protokol di `docs/serah-terima.md` bagian 6 dan tulis catatan sesi di bagian 7 sebelum berhenti.

## Aturan kerja
- Commit dan push hanya kalau user minta. Commit hanya file milik sendiri (`git add <file>`), jangan `git add -A` / `git add .`. Jangan `reset --hard`, `stash`, `checkout -- <file>`.
- Aset atau peta kandidat buatan GPT (mode B di `AGENTS.md`) jangan diubah tanpa izin user.
- **Aturan peta 2026-11-26 (keputusan user).** Setiap peta baru mengikuti [docs/aturan-peta.md](docs/aturan-peta.md): aturan desain dan teknik dari BAR dan FAF/Supreme Commander (ukuran, simetri, logam per pemain, zona tambang, medan, objek, cahaya, pipeline lapisan tekstur).
- Bedakan keputusan user (✅, tanggal + kutipan) dan usulan sendiri (🟡).
- Keputusan yang mengubah tampilan, gameplay, atau tradeoff performa: diskusikan dulu, kecuali sudah ada di rencana yang disetujui.
- Verifikasi visual pakai screenshot Recoil sungguhan (`python tools/uji_visual.py ...`), bukan asumsi. Lihat gambarnya sebelum melapor.
- Laporkan angka terukur (fps, jumlah unit, lama pertandingan, win-rate). Jangan klaim "ringan" atau "seimbang" sebelum diuji.
- Semua aset buatan sendiri, konten bawaan Recoil, atau CC0, dan sumbernya dicatat. Kode BAR (GPL) boleh dibaca sebagai referensi, ditulis ulang sendiri. Jangan menyalin peta, tekstur, model, ikon, atau suara BAR/SupCom.
- Graph kode ada di `graphify-out/` (skill `/graphify`). Cocok untuk struktur HUD, efek, dan tools; kurang untuk alur data Lua (`VFS.Include` dan fungsi di dalam closure tidak terbaca).
