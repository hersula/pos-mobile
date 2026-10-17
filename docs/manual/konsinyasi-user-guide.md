# Panduan Pengguna: Konsinyasi

Konsinyasi dipakai saat barang toko **dititipkan** ke customer atau outlet. Barang tetap milik toko sampai laku. Saat outlet melaporkan barang laku, penjualan tercatat dan muncul sebagai piutang ke outlet.

Panduan ini untuk aplikasi Q-Pos (Flutter). Dokumen teknis ada di `pos-backend/docs/manual/konsinyasi.md`.

> **Status:** alur di bawah sesuai kode mobile. Belum diuji manual di perangkat terhadap backend nyata. Lihat bagian "Batasan saat ini".

---

## 1. Siapa boleh apa

| Aksi | OWNER | MANAGER | KASIR | GUDANG | AKUNTAN |
|---|:---:|:---:|:---:|:---:|:---:|
| Melihat daftar dan detail konsinyasi | ya | ya | ya | ya | ya |
| Melihat sisa stok di outlet | ya | ya | ya | ya | ya |
| Buat, ubah draf, kirim | ya | ya | - | - | - |
| Catat terjual, retur, batalkan | ya | ya | - | - | - |

Untuk role yang tidak punya izin tulis, tombol tambah dan aksi di detail tidak muncul. Bila login sebagai KASIR, Anda hanya melihat data.

## 2. Membuka menu Konsinyasi

1. Buka tab **Inventori**.
2. Tekan ikon **jabat tangan** (`handshake`) di pojok AppBar.
3. Daftar konsinyasi terbuka.

Di daftar:
- **Chip status** di bagian atas menyaring daftar: Semua, Draf, Terkirim, Sebagian Selesai, Selesai, Dibatalkan.
- **Tarik ke bawah** untuk muat ulang.
- **Gulir ke bawah** untuk memuat data berikutnya.
- Ikon **toko** (`storefront`) di AppBar membuka **Sisa Stok di Outlet**.

## 3. Alur status

```
Draf ──kirim──▶ Terkirim ──catat terjual / retur──▶ Sebagian Selesai ──▶ Selesai
  │                 │
  └──batalkan──▶ Dibatalkan ◀──batalkan (belum ada terjual/retur)
```

| Status | Arti | Stok |
|---|---|---|
| Draf | Dokumen dibuat, belum dikirim | Belum pindah |
| Terkirim | Barang sudah di outlet | Pindah ke gudang konsinyasi outlet |
| Sebagian Selesai | Sebagian barang terjual atau diretur | Sisa masih di outlet |
| Selesai | Semua barang terjual atau diretur | Outlet kosong |
| Dibatalkan | Dokumen dibatalkan | Dikembalikan ke gudang toko |

## 4. Membuat konsinyasi baru

Langkah ini untuk OWNER dan MANAGER.

1. Di daftar, tekan tombol **Konsinyasi** (ikon +).
2. Isi **Customer / Outlet**. Jika belum ada, tekan ikon **+** di sebelahnya, isi nama (wajib) dan No. HP (opsional), lalu **Simpan**.
3. Pilih **Gudang Asal (toko)**. Hanya gudang toko yang muncul. Gudang outlet tidak bisa dipilih di sini.
4. Isi **Jatuh Tempo** (opsional). Tekan ikon hapus untuk mengosongkan.
5. Isi **Catatan** (opsional).
6. Tekan **Tambah Produk**.
   - Cari produk dengan nama atau SKU, atau tekan ikon barcode untuk scan.
   - Pilih satuan. Contoh: **Botol** (satuan dasar) atau **Dus** (1 Dus = 24 Botol).
   - Isi **Qty** dan **Harga Kesepakatan** per satuan yang dipilih. Harga default diambil dari harga jual produk.
   - Tekan **Simpan** pada item.
7. Ulangi langkah 6 untuk produk lain. Bagian **Nilai Titipan** menunjukkan total.
8. Tekan **Simpan**. Dokumen berstatus **Draf**. Stok belum pindah.

Untuk mengubah draf, buka detail lalu tekan **Ubah Draf**. Setelah dikirim, dokumen tidak bisa diubah.

## 5. Mengirim barang ke outlet

1. Buka detail konsinyasi berstatus **Draf**.
2. Tekan **Kirim Barang**, lalu **Kirim** pada dialog konfirmasi.
3. Status berubah menjadi **Terkirim**. Stok gudang toko berkurang, dan stok outlet bertambah.

Jika stok gudang toko tidak cukup, aplikasi menampilkan pesan stok tidak mencukupi. Tidak ada stok yang berubah.

## 6. Mencatat barang terjual

Lakukan saat outlet melapor barang laku. Tombol ini muncul untuk status **Terkirim** dan **Sebagian Selesai**.

1. Buka detail konsinyasi, lalu tekan **Catat Terjual**.
2. Untuk setiap item, isi **Qty** yang laku.
   - Pilih **satuan dasar** (default, mis. Botol) atau **satuan item** (mis. Dus).
   - Jumlah yang diisi tidak boleh melebihi **Sisa** item.
3. Isi **Harga** bila berbeda dari harga kesepakatan (opsional).
4. Isi **Catatan** (opsional), lalu **Simpan**.

Hasilnya:
- Sistem membuat penjualan (Sale) ke outlet dengan nomor invoice `INV-...`. Pajak 11% dipakai secara default. Diskon 0.
- Penjualan tercatat dengan status **piutang** (belum dibayar).
- Status menjadi **Sebagian Selesai** atau **Selesai**.

Contoh: 2 Dus (48 Botol) dikirim, 30 Botol laku. Status menjadi **Sebagian Selesai**. Sisa 18 Botol.

## 7. Retur barang sisa

Lakukan saat barang sisa dikembalikan dari outlet.

1. Buka detail konsinyasi, lalu tekan **Retur Barang**.
2. Isi **Qty** per item, dengan pilihan satuan yang sama seperti terjual.
3. Isi **Catatan** (opsional), lalu **Simpan**.

Stok outlet berkurang, dan stok gudang toko bertambah. Tidak ada penjualan atau jurnal yang dibuat. Bila semua barang sudah laku atau diretur, status menjadi **Selesai**.

Contoh: sisa 18 Botol diretur. Stok gudang toko +18, dan status menjadi **Selesai**.

## 8. Membatalkan konsinyasi

Tombol **Batalkan Konsinyasi** muncul hanya bila:
- status **Draf**, atau
- status **Terkirim** dan belum ada barang terjual maupun diretur.

1. Tekan **Batalkan Konsinyasi**.
2. Isi **Alasan** (minimal 3 karakter), lalu konfirmasi.

Seluruh stok kembali ke gudang toko.

Jika sudah ada barang terjual atau diretur, tombol tidak muncul dan aplikasi menampilkan pesan. Pilih salah satu:
- catat **Retur** untuk sisa barang, atau
- batalkan **penjualan** (Sale) terkait dari alur penjualan. Jika penjualan dibatalkan, catatan terjual di detail ditandai **Dibatalkan (penjualan dibatalkan)**.

## 9. Melihat sisa stok di outlet

1. Di daftar konsinyasi, tekan ikon **Sisa Stok di Outlet** di AppBar.
2. Daftar menampilkan setiap outlet dan jumlah barang yang masih ada, dalam satuan dasar.
3. Outlet tanpa sisa barang tidak ditampilkan.

## 10. Batasan saat ini

- **Pelunasan piutang outlet belum ada di aplikasi.** Setelah barang terjual, piutang tercatat di penjualan. Pelunasan saat ini hanya bisa lewat API (`POST /api/sales/{id}/payments`). Pelunasan dari aplikasi belum tersedia.
- **Catat terjual tidak punya input pembayaran, diskon, atau pajak.** Penjualan selalu piutang penuh, diskon 0, pajak 11%.
- **Detail konsinyasi tidak menautkan penjualan terkait.** Hanya nomor invoice yang ditampilkan.
- **Belum diuji di perangkat** dengan backend dan database nyata. Migrasi backend `20261017000000_add_consignment` harus diterapkan dulu. Lihat `pos-backend/docs/manual/konsinyasi.md`.
- **Kuota paket FREE:** catat terjual ikut dihitung dalam batas 10 transaksi per hari. Bila batas tercapai, aplikasi menampilkan pesan di snackbar.

## 11. Pesan kesalahan umum

| Pesan | Penyebab | Yang dilakukan |
|---|---|---|
| Stok tidak mencukupi | Stok gudang toko kurang saat kirim | Periksa stok produk, lalu coba lagi |
| Qty melebihi sisa | Qty terjual atau retur lebih besar dari Sisa item | Kurangi qty |
| Tidak bisa dibatalkan | Sudah ada barang terjual atau diretur | Gunakan retur atau batalkan penjualan terkait |
| Pesan status dari server (409) | Status dokumen sudah berubah di server | Aplikasi memuat ulang detail. Periksa status lalu coba lagi |
