# Serah terima: docs (fitur Konsinyasi, mobile)

- Status: SELESAI. README, CHANGELOG, dan panduan pengguna sudah diperbarui. Verifikasi build tidak dijalankan ulang di tugas dokumentasi ini.

## Yang dikerjakan
- `README.md`: bagian "Konsinyasi (Barang Titip ke Outlet)" setelah "Pengadaan Barang", dan `consignment/` di struktur folder.
- `docs/manual/konsinyasi-user-guide.md` (baru): panduan per peran, langkah demi langkah, alur status, pesan kesalahan umum, dan batasan saat ini.
- `CHANGELOG.md` (baru, Keep a Changelog, `[Unreleased]`).
- `docs/handoff/docs.md` (file ini).

## File utama
- `README.md` (diubah)
- `docs/manual/konsinyasi-user-guide.md` (baru)
- `CHANGELOG.md` (baru)
- `docs/handoff/docs.md` (baru)

## Cara memverifikasi
Dokumen mengacu pada kode di `lib/features/consignment/` dan `lib/state/consignment_provider.dart`. Label menu, tooltip, pesan dialog, dan kondisi tombol dicek langsung di kode. Perintah build tidak dijalankan ulang di tugas ini. Hasil yang tercatat di `docs/handoff/frontend.md`: `flutter analyze` 0 error, `flutter test` 2 lulus.

## Asumsi dan keputusan
- Panduan hanya memakai alur yang ada di kode. Tidak ada alur yang diasumsikan.
- Pajak 11% dan diskon 0 untuk catat terjual sesuai perilaku saat ini. Mobile belum punya input untuk keduanya.
- Panduan dibuat untuk pengguna akhir, dengan istilah dari UI (Draf, Terkirim, Sebagian Selesai, Selesai, Dibatalkan).

## Belum selesai / catatan
- Panduan belum diuji di perangkat terhadap backend nyata. Migrasi backend `20261017000000_add_consignment` harus diterapkan dulu.
- Pelunasan piutang outlet belum ada di aplikasi. `SalesRepository.addPayment` ada, tetapi tidak dipanggil dari layar mana pun. Ditulis sebagai batasan di panduan.
- Detail konsinyasi belum menautkan penjualan terkait. Hanya nomor invoice yang tampil.
- Perubahan perilaku: `getWarehouses()` tanpa parameter (checkout, form produk, form PO) kini hanya menerima gudang STORE. Sesuai rencana, tetapi perlu diuji di form produk dan PO.
- `README.md` masih menulis bahwa role GUDANG bisa membuka PO. Belum diverifikasi terhadap izin tulis PO di backend. Di luar lingkup tugas ini.

## Permintaan ke agent lain
- qc: uji alur konsinyasi di perangkat (kirim, catat terjual, retur, batalkan), dan pastikan form produk dan PO masih menampilkan gudang toko.
- frontend: pertimbangkan UI pelunasan piutang dan input pembayaran di catat terjual, jika diperlukan pengguna.
- backend: lihat `pos-backend/docs/handoff/docs.md` untuk BUG-004 dan `docs/qc/report.md` yang belum ada.
