# Handoff Designer: Stock Opname
Status: SELESAI

## Dikerjakan
- `design/stock-opname/spec.md` (alur, layar, state, komponen, responsif/a11y, copywriting, field data).
- Wireframe di `design/stock-opname/wireframe/`: 00-entri-inventori, 01-daftar-sesi, 02-buat-sesi, 03-hitung, 04-review-selisih, 05-detail-sesi (tiap file memuat semua state: default/loading/kosong/error/tanpa izin/dialog).

## Cara melihat
`xdg-open design/stock-opname/wireframe/01-daftar-sesi.html` (statis, tanpa build). Struktur HTML sudah dicek seimbang.

## Asumsi dan keputusan
- Tidak membuat tokens.json baru; memakai `AppColors` yang ada (CSS variables di wireframe memetakannya). `ember` tidak dipakai.
- Qty kosong = belum dihitung, 0 = dihitung nol; produk belum dihitung tidak diubah saat finalisasi.
- Nilai selisih = selisih qty x harga pokok; ikon entri `fact_check_outlined`.
- Satu sesi Draft per gudang (409 bila ada). Data contoh bersifat ilustrasi; angka di wireframe tidak sepenuhnya konsisten antar kartu.

## Belum selesai
- Wireframe tablet (>=600dp) hanya dijelaskan di spec, tidak digambar.

## Permintaan ke agent lain
- Backend: sediakan field di spec.md bagian 7 (khusus summary sesi, unitCost/diffValue per item, countedQty nullable, pembatal+alasan, filter status/search/paginasi daftar, endpoint simpan draft parsial, finalisasi atomik dengan error 409 untuk Draft ganda).
- Frontend: perhatikan aturan scan (fokus qty, tidak auto-tambah) dan dialog simpan saat keluar.
