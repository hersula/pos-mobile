# Serah terima: docs

## Stock Opname (2026-10-18)

- Status: SELESAI (dokumentasi). Isinya mengikuti kode dan kontrak; tidak ada perintah build/test yang dijalankan, dan kode tidak diubah.

## Yang dikerjakan
- `docs/manual/stock-opname-user-guide.md` (baru): peran/izin, buat sesi, hitung, scan, review selisih, finalisasi, batal, detail, pesan error (`DRAFT_EXISTS`, `STOCK_CONFLICT` / "Finalisasi, Tahan di 0"), batasan. Label UI dicek terhadap `stock_opname_review_screen.dart` dan `docs/handoff/frontend.md`.
- `README.md` dan `CHANGELOG.md` (pos-mobile): bagian modul, struktur folder `stock_opname/`, entri Added/Fixed/Known issues.
- pos-backend: `README.md` bagian 9 "Modul Stock Opname" (tabel endpoint, aturan, contoh curl, catatan migrasi; bagian lama 9-10 jadi 10-11), `CHANGELOG.md` (Added/Fixed/Known issues).
- Catatan migrasi: `prisma/migrations/20261018000000_add_stock_opname` additive, belum diterapkan; jalankan `npx prisma migrate deploy` saat rilis (setelah backup). TIDAK dijalankan.

## Ringkasan QC putaran 1 (berdasarkan temuan yang diberikan manager)
`docs/qc/report.md` tidak ada di pos-mobile saat dokumen ini ditulis (area qc), jadi ringkasan ini bersumber dari handoff frontend/backend dan tugas.
| Bug | Perbaikan | Status uji |
|---|---|---|
| BUG-001 | Backend: kunci baris gudang, 409 `DRAFT_EXISTS` + `details.opnameId`. Mobile: tombol "Buka Sesi Draft" hanya untuk code ini | Diperbaiki, belum diuji dinamis |
| BUG-002 | Mobile: input dibatasi maks 2.000.000.000 (`kMaxOpnameQty`) | Diperbaiki, belum diuji dinamis |
| BUG-003 | Backend: baris `stocks` dikunci saat finalisasi; kekurangan stok jadi 409 `STOCK_CONFLICT` | Diperbaiki, belum diuji dinamis |
| BUG-004, 005 | Backend: ringkasan memakai `appliedDiff` untuk item clamped; `unchangedItems` tidak menghitung clamped | Diperbaiki, belum diuji dinamis |
| BUG-006 | Mobile: error 400 menyebut produk bermasalah (format `details` 400 belum ada di kontrak) | Diperbaiki, belum diuji dinamis |

Penyebab belum teruji: Flutter SDK tidak ada (tidak ada `flutter analyze/test`, widget belum pernah dikompilasi), dan skrip `pos-backend/tests/stock-opname-e2e.mjs` belum dijalankan di DB `qc_opname_test`. Backend: `tsc` hanya 9 error lama (prices/units), `npm run build` gagal karena itu.

## Temuan dokumentasi
- Kontrak belum mendokumentasikan format `details` untuk 400 (dipakai BUG-006 di mobile berdasarkan asumsi).
- Pencarian daftar sesi hanya lokal; kontrak tak punya `search`. Kartu/detail tanpa nama kategori dan pembuat di mobile.
- Alasan batal wajib 3..500 di backend, spec bilang opsional: mobile mengirim "Dibatalkan oleh pengguna" bila kosong.
- Role GUDANG boleh menghitung walau tidak ada di brief.
- README backend tidak punya bagian Konsinyasi (hanya `docs/manual/konsinyasi.md`).
- Bagian lama di bawah (Konsinyasi) masih menyebut `README.md` mobile menulis GUDANG bisa membuka PO, belum diverifikasi.

## Permintaan ke agent lain
- qc: jalankan `flutter analyze`/`flutter test` dan e2e `stock-opname-e2e.mjs` di DB `qc_opname_test`, lalu tulis `docs/qc/report.md`; ubah status "belum diuji" di panduan dan CHANGELOG setelahnya.
- devops/pengguna: sediakan Flutter SDK; terapkan migrasi saat rilis.
- backend: pertimbangkan dokumentasi format `details` 400 di kontrak.

---
(Serah terima sebelumnya, Konsinyasi:)


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
