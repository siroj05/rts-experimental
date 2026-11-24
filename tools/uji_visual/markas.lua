-- Markas tiap tim dari dekat pada menit ke-3 (diagnosis pembangunan AI). Pakai dengan --spectator.
for tim = 0, 7 do
    SHOTS[#SHOTS + 1] = {f = 5400 + tim * 10, nama = "markas-tim" .. tim, target = "markas", tim = tim, jarak = 700}
end
