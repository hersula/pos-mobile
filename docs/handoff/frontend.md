# Serah terima: frontend

## Stock Opname (Flutter)

- Status: SEBAGIAN. Kode lengkap, tetapi `flutter pub get/analyze/test` TIDAK dapat dijalankan: Flutter SDK tidak terpasang di mesin ini (hanya Dart 3.9.2). Verifikasi yang dilakukan: `dart format` pada semua file baru (sintaks valid), serta `dart analyze` + eksekusi parsing `StockOpname.fromJson` di sandbox Dart murni (0 issue, hasil sesuai). Widget belum pernah dikompilasi/dijalankan; jalankan `flutter analyze` dan `flutter test` sebelum merge.
- Model `lib/data/models/stock_opname.dart`; repo `lib/data/repositories/stock_opname_repository.dart` (list, detail, create, saveCounts via PATCH, finalize dengan `clampToZero`, cancel; `StockConflictException` untuk 409 STOCK_CONFLICT); provider `lib/state/stock_opname_provider.dart` (didaftarkan di `main.dart`); endpoint di `api_endpoints.dart`; `ApiClient.patch` ditambah; `UserProfile.canManageStockOpname` (OWNER/MANAGER) dan `canCountStockOpname` (OWNER/MANAGER/GUDANG/KASIR).
- Layar `lib/features/stock_opname/`: daftar (chip status, cari lokal, infinite scroll, skeleton/kosong/error, banner tanpa izin, FAB hanya OWNER/MANAGER), buat sesi (gudang STORE, kategori, catatan; 409 -> banner + "Buka Sesi Draft"), hitung (cari, scan via `scanBarcode`, progres, stepper, tag selisih, simpan draft, dialog simpan saat keluar), review selisih (+ bottom sheet finalisasi, dialog konflik STOCK_CONFLICT dengan opsi tahan di 0), detail (read-only, batalkan sesi). Titik masuk: ikon `fact_check_outlined` di AppBar `ProductListScreen`, setelah Konsinyasi.
- Tes: `test/stock_opname_test.dart` (parsing model + `parseConflictItems`).
- Keputusan/ketidaksesuaian kontrak vs spec:
  - Kontrak tidak punya parameter `search`: pencarian daftar sesi hanya lokal pada data termuat.
  - Kontrak tidak mengirim nama kategori maupun nama pembuat/pembatal: kartu menampilkan "Semua kategori"/"Satu kategori"; detail tanpa "dibuat oleh". Tanggal selesai memakai `completedAt` (pembatalan tidak punya `cancelledAt`, jadi tampil bila ada).
  - qty integer (kontrak), jadi keyboard numerik bulat, bukan desimal.
  - Alasan batal wajib 3..500 di backend, spec bilang opsional: bila kosong dikirim "Dibatalkan oleh pengguna".
  - 409 saat buat sesi diasumsikan "Draft sudah ada" (kontrak tidak menyebut code-nya); tombol "Buka Sesi Draft" mencari Draft gudang itu lewat daftar.
  - Baris Layar Hitung memakai tinggi tetap 148dp (untuk scroll ke produk hasil scan); bisa terpotong pada skala font sangat besar. Layar 2 kolom tablet dan menu overflow <360dp belum dibuat.
  - Tidak ada beep saat scan (hanya getar haptic).
- Permintaan ke agent lain: devops/pengguna sediakan Flutter SDK agar analyze/test dapat dijalankan; backend: pertimbangkan `categoryName`, `createdBy`, `cancelledAt` di objek sesi dan `code` khusus untuk 409 Draft ganda.

---
(Serah terima sebelumnya, Konsinyasi:)


- Status: SELESAI (kode). Belum diuji manual terhadap backend/DB nyata.
- Verifikasi: Flutter ada di `C:\src\flutter` (3.47.7, Dart 3.13.5; tidak di PATH). `flutter analyze`: 0 error; seluruh temuan adalah info/warning lama proyek plus 5 info gaya (`withOpacity`, `value` di dropdown, lint context) di file konsinyasi yang sama dengan pola kode lama. `flutter test`: 2 test lulus. `flutter pub get` mengeluh "Building with plugins requires symlink support" (Developer Mode Windows mati), tetapi `.dart_tool` sudah ada sehingga analyze/test tetap jalan.

## Yang dikerjakan
- Model `lib/data/models/consignment.dart` (order, item, settlement, summary, outlet stock; angka lewat `parseNum/parseInt`).
- Endpoint di `core/api/api_endpoints.dart`; repo `data/repositories/consignment_repository.dart` (list+filter, detail, create, update DRAFT, send, settle-sale, return, cancel, outlet-stock) memakai `ApiClient` yang ada.
- `state/consignment_provider.dart` (daftar + filter status + outlet stock), didaftarkan di `main.dart`.
- Layar `lib/features/consignment/`: daftar (chip filter status, pull-to-refresh, state loading/kosong/error), form buat/ubah draf (customer + tambah customer cepat, gudang asal, jatuh tempo, catatan, item + satuan + qty + harga), detail (kirim, catat terjual, retur, batalkan, ubah draf, riwayat settlement termasuk yang void), sheet qty untuk terjual/retur dengan pilihan satuan dasar/satuan item (`useBaseUnit`, default satuan dasar) dan validasi sisa di klien, sisa stok outlet.
- Pintu masuk: ikon `handshake` di AppBar tab Inventori (tanpa menu bawah baru). Terlihat untuk semua role; aksi tulis (FAB, kirim, terjual, retur, batal, ubah) hanya bila `UserProfile.canWriteConsignment` (OWNER/MANAGER). KASIR hanya baca.
- `Warehouse` kini punya `type` dan `customerId`; `WarehouseRepository.getWarehouses({type})`. Checkout dan form PO tetap memanggil tanpa `type` sehingga memakai default backend STORE (tidak diubah). Form konsinyasi eksplisit `?type=STORE`; `?type=ALL` tidak dibutuhkan.
- `test/widget_test.dart` diganti: smoke test `PosApp` + test parsing `ConsignmentOrder`.

## Cara menjalankan/menguji
```
set PATH=C:\src\flutter\bin;%PATH%
cd C:\laragon\www\pos-mobile
flutter pub get   (butuh Developer Mode Windows untuk plugin)
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

## Pelunasan piutang konsinyasi (tambahan)
- `lib/features/consignment/consignment_receivables.dart`: section "Piutang Penjualan" di detail konsinyasi. Memuat `GET /sales/{id}` untuk tiap settlement SALE non-void, menampilkan total/dibayar/sisa piutang dan status. Tombol "Catat Pembayaran" hanya untuk `canWriteConsignment` (OWNER/MANAGER) dan Sale `PARTIAL`.
- Dialog: nominal (default sisa), metode bayar enum kontrak (CASH/DEBIT/CREDIT/QRIS/TRANSFER/EWALLET), no. referensi opsional untuk non-tunai. Validasi klien nominal > 0 dan <= sisa (`validatePaymentAmount`). 409 `CONCURRENT_UPDATE` menampilkan pesan coba lagi di dalam dialog (tombol jadi "Coba Lagi"). Memakai `SalesRepository.addPayment` yang sudah ada.
- Setelah sukses, daftar Sale dan detail konsinyasi dimuat ulang. Test: `test/consignment_receivables_test.dart`. `flutter test`: 5 lulus; `flutter analyze`: 0 error (hanya info deprecated gaya lama).
- Catatan: backend sebenarnya mengizinkan nominal > sisa (kelebihan jadi kembalian) dan KASIR boleh memanggil endpoint ini; UI sengaja lebih ketat sesuai permintaan. Belum diuji ke backend nyata.

## Asumsi dan keputusan
- Daftar memakai infinite scroll (`pageSize=20`, `page` berikutnya dimuat saat sisa scroll < 200px, berhenti di `totalPages`) - fix BUG-007.
- `ConsignmentSettleResult.saleTotal` kini membaca `sale.grandTotal` sesuai kontrak - fix BUG-005.
- Settle-sale dikirim tanpa `payments` (piutang penuh), diskon 0, pajak default backend (11%); pelunasan lewat alur Sale yang sudah ada. Belum ada input metode bayar/diskon/pajak di layar settle.
- Hanya OWNER/MANAGER menulis (sesuai kontrak; GUDANG tidak boleh menulis, berbeda dari draf analisis).
- Aturan "bisa dibatalkan" dihitung di klien dari item (sold/returned = 0); server tetap sumber kebenaran (409 memicu muat ulang).
- FREE_LIMIT_REACHED (403) pada settle ditampilkan sebagai snackbar, bukan dialog khusus.
- Harga default item baru = `sellPrice` satuan terpilih/produk (bukan level harga).

## Belum selesai / catatan
- Belum dijalankan di perangkat/emulator; alur kirim/terjual/retur belum diuji dengan backend nyata (migrasi backend belum diterapkan).
- Detail tidak menampilkan Sale terkait sebagai tautan (hanya nomor invoice).
- Temuan lama (bukan dari tugas ini): `main.dart` import `pending_status_screen` tak terpakai; `product.dart` import `category.dart` tak terpakai; `update_service.dart` memakai paket `http` tanpa dependensi langsung.

## Permintaan ke agent lain
- qc: skenario kirim 2 Dus -> terjual 30 Botol (`useBaseUnit`) -> retur 18 -> SETTLED; cancel dari SENT; KASIR tidak melihat aksi tulis; checkout hanya menampilkan gudang STORE; batalkan Sale hasil settle lalu cek detail (settlement void).
- devops/pengguna: aktifkan Developer Mode Windows agar `flutter pub get` sukses.

## Perbaikan QC (BUG-001, BUG-002, BUG-006) - lib/features/stock_opname/
- BUG-001: `stock_opname_form_screen.dart` hanya menawarkan "Buka Sesi Draft" bila 409 dengan `code == DRAFT_EXISTS`; membuka `details.opnameId` langsung (fallback: cari di daftar Draft). 409 lain memakai pesan generik. Bergantung backend mengirim code ini.
- BUG-002: `stock_opname_count_screen.dart` membatasi input dan stepper maks 2.000.000.000 (`kMaxOpnameQty`, formatter `_MaxQtyFormatter`).
- BUG-006: 400 saat simpan menampilkan nama produk bermasalah bila respons memuat `details.items[].itemId` (atau `path` `items.N...`); jika tidak, pesan jelas tentang nilai tidak valid. Format `details` 400 belum ada di kontrak (asumsi, perlu konfirmasi backend).
- Verifikasi: `dart format` dan `dart analyze lib/features/stock_opname` (hanya 6 info lint, tanpa error). Flutter SDK tidak ada, belum ada uji widget/build.
