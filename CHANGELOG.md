# Changelog

Format mengikuti [Keep a Changelog](https://keepachangelog.com/id-ID/1.1.0/). Versi belum dirilis, jadi seluruh perubahan ada di `[Unreleased]`.

## [Unreleased]

### Added
- Modul Stock Opname di tab Inventori (ikon `fact_check_outlined`): daftar sesi dengan filter status, buat sesi per gudang (opsional per kategori), layar hitung (manual, stepper, scan barcode, progres, simpan draft), review selisih, finalisasi, batalkan sesi, dan detail. Dialog `STOCK_CONFLICT` menawarkan "Finalisasi, Tahan di 0" (`clampToZero`).
- Izin: `UserProfile.canManageStockOpname` (OWNER/MANAGER: buat, finalisasi, batal) dan `canCountStockOpname` (OWNER/MANAGER/GUDANG/KASIR: hitung).
- Model, repository, provider (`lib/data/models/stock_opname.dart`, `lib/data/repositories/stock_opname_repository.dart`, `lib/state/stock_opname_provider.dart`), `ApiClient.patch`, dan `test/stock_opname_test.dart`.
- Dokumentasi: `docs/manual/stock-opname-user-guide.md`, bagian Stock Opname di `README.md`, kontrak `docs/api-contract-stock-opname.md`.
- Modul Konsinyasi di tab Inventori (ikon `handshake`): daftar dengan filter status dan muat lebih banyak, buat dan ubah draf, kirim, catat terjual, retur, batalkan, dan sisa stok per outlet.
- Aksi tulis konsinyasi hanya untuk OWNER dan MANAGER (`UserProfile.canWriteConsignment`). Role lain hanya melihat.
- Model, repository, dan provider konsinyasi (`lib/data/models/consignment.dart`, `lib/data/repositories/consignment_repository.dart`, `lib/state/consignment_provider.dart`).
- Dokumentasi: `docs/manual/konsinyasi-user-guide.md`, bagian Konsinyasi di `README.md`.

### Changed
- Model `Warehouse` memuat `type` dan `customerId`. `WarehouseRepository.getWarehouses({type})` menerima parameter tipe.
- Form konsinyasi meminta `?type=STORE` secara eksplisit.
- Pemanggilan `GET /warehouses` tanpa parameter (checkout, form produk, form PO) kini hanya menerima gudang toko, karena backend default `STORE`. Gudang outlet tidak lagi muncul di pilihan ini.
- `test/widget_test.dart` diganti dengan smoke test `PosApp` dan test parsing `ConsignmentOrder`.

### Fixed
- Stock Opname (QC putaran 1): BUG-001 tombol "Buka Sesi Draft" hanya untuk `DRAFT_EXISTS` dan membuka `details.opnameId`; BUG-002 input hitungan dibatasi maksimal 2.000.000.000; BUG-006 error 400 saat simpan menyebut produk bermasalah. BUG-003 sampai 005 diperbaiki di backend. Seluruhnya belum diuji dinamis.
- Hasil catat terjual (settle-sale) membaca `sale.grandTotal` sesuai kontrak (BUG-005).
- Daftar konsinyasi memuat halaman berikutnya saat digulir, tidak hanya halaman pertama (BUG-007).

### Known issues
- Pelunasan piutang outlet belum ada di aplikasi. Hanya lewat API `POST /api/sales/{id}/payments`.
- Catat terjual belum punya input metode bayar, diskon, atau pajak. Pajak default 11%.
- Modul belum diuji di perangkat terhadap backend dan database nyata. Migrasi backend `20261017000000_add_consignment` harus diterapkan dulu.
- Stock Opname belum dikompilasi atau diuji: Flutter SDK tidak ada di mesin pengembangan, jadi `flutter analyze` dan `flutter test` belum dijalankan. Hanya `dart format` dan `dart analyze` pada folder fitur.
- Migrasi backend `20261018000000_add_stock_opname` harus diterapkan dulu. Skrip e2e backend `tests/stock-opname-e2e.mjs` belum dijalankan.
- Pencarian daftar sesi hanya lokal. Kartu/detail belum menampilkan nama kategori dan pembuat. Layout tablet 2 kolom dan menu overflow layar sempit belum ada.
