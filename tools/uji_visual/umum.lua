-- Hook bawaan: markas dan seluruh peta di awal, lalu pertempuran terpanas tiap 2 menit selama 10 menit.
SHOTS[#SHOTS + 1] = {f = 150, nama = "markas", target = "markas", jarak = 420}
SHOTS[#SHOTS + 1] = {f = 160, nama = "peta", target = "tengah", jarak = 3600}
for menit = 2, 10, 2 do
    SHOTS[#SHOTS + 1] = {f = menit * 1800, nama = menit .. "m-tempur", target = "panas", jarak = 520}
    SHOTS[#SHOTS + 1] = {f = menit * 1800 + 10, nama = menit .. "m-dekat", target = "panas", jarak = 220}
end
