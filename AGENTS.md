# Aturan agen AI (GPT/Codex dan lainnya)

Repo ini dikerjakan bergantian oleh beberapa agen AI (Claude dan GPT). Aturan lengkap proyek ada di `CLAUDE.md` dan berlaku juga untukmu. Sebelum mengubah apa pun, baca:
1. `CLAUDE.md`
2. `docs/serah-terima.md` (peta kode, perintah, jebakan, protokol bergantian, catatan sesi terakhir)
3. `docs/tahapan.md`

Ringkasnya: balas user dalam bahasa Indonesia santai (lu/gua), teks UI game bahasa Inggris, commit/push hanya kalau user minta, dan keputusan yang mengubah tampilan, gameplay, atau performa ditanyakan dulu.

## Tentukan dulu modemu
User akan bilang salah satu. Kalau tidak jelas, tanya.

### Mode A: melanjutkan pekerjaan proyek
- Ambil pekerjaan dari bagian **Catatan sesi terakhir** di `docs/serah-terima.md` dan status di `docs/tahapan.md`. Jangan mulai pekerjaan baru yang tidak ada di sana tanpa izin user.
- Ikuti protokol di `docs/serah-terima.md` bagian 6: cek `git status`/`git log`, kerjakan, uji, catat, lalu tulis catatan sesi sebelum berhenti.

### Mode B: membuat aset atau peta kandidat (belum masuk menu/game)
- Hanya buat file baru milik aset itu, dengan nama yang jelas (mis. `maps/<stem>.sdz`, `maps/mapinfo-<stem>.lua`, `tools/buat_<stem>.py`, `game/RTSPC.sdd/gamedata/skenario/<nama>.lua` + `-start.txt`, `docs/peta-<stem>.md`, sumber Blender di `../blender-assets/`).
- **Jangan** mengubah file bersama: `menu/`, `game/RTSPC.sdd/LuaUI/`, `game/RTSPC.sdd/LuaRules/`, `gamedata/fraksi1.lua`, `uji-bukit.ps1`, `tools/build_windows.py`, `README.md`, `docs/tahapan.md`, atau peta lain, kecuali user mengizinkan. Satu pengecualian untuk peta: satu baris pemilih skenario di `game/RTSPC.sdd/gamedata/skenario.lua`.
- Uji lewat start script atau `.cmd` sendiri. Pendaftaran ke menu skirmish dan paket Windows dikerjakan di Mode A setelah user setuju.
- Catat di `docs/<aset>.md`: apa asetnya, sumber/lisensi, ukuran, hasil uji, kekurangan yang masih terlihat.

## Git
- Jangan pakai `git add -A` atau `git add .`. Tambahkan file yang kamu ubah satu per satu, karena bisa ada file agen lain yang belum di-commit.
- Jangan `git reset --hard`, `git checkout -- <file>`, `git stash`, atau force push. Itu bisa menghapus pekerjaan agen lain yang belum di-commit.
