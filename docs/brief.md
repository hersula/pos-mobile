# Brief: Modul Stock Opname (pos-backend + pos-mobile)

## Tujuan
Petugas dapat menghitung stok fisik per gudang, membandingkannya dengan stok sistem, lalu menyetujui selisih sehingga stok dikoreksi otomatis dan tercatat.

## Pengguna
OWNER/MANAGER: buat, setujui, batalkan sesi. KASIR/staf gudang: hitung (isi qty fisik) bila diizinkan.

## MVP
- Buat sesi opname per gudang (semua produk atau filter kategori); snapshot stok sistem saat dibuat.
- Input hitung fisik per produk (manual + scan barcode), simpan draft.
- Ringkasan selisih (lebih/kurang), nilai selisih.
- Finalisasi: membuat StockMovement ADJUSTMENT per selisih (referenceType STOCK_OPNAME), menyesuaikan Stock; sesi tidak bisa diubah lagi.
- Riwayat & detail sesi; batalkan sesi draft.
## Nanti
Jurnal akuntansi selisih, ekspor PDF/Excel, opname multi-petugas.

## Stack
Backend: Next.js API + Prisma (`/home/sule/Projects/pos-backend`, perubahan skema additive). Mobile: Flutter + provider + dio (`/home/sule/Projects/pos-mobile`), tab Inventori.
## Asumsi
Mengikuti pola modul konsinyasi. Tampilan = spesifikasi UI/wireframe oleh designer.
