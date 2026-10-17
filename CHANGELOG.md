# Changelog

Format mengikuti [Keep a Changelog](https://keepachangelog.com/id-ID/1.1.0/). Versi belum dirilis, jadi seluruh perubahan ada di `[Unreleased]`.

## [Unreleased]

### Added
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
- Hasil catat terjual (settle-sale) membaca `sale.grandTotal` sesuai kontrak (BUG-005).
- Daftar konsinyasi memuat halaman berikutnya saat digulir, tidak hanya halaman pertama (BUG-007).

### Known issues
- Pelunasan piutang outlet belum ada di aplikasi. Hanya lewat API `POST /api/sales/{id}/payments`.
- Catat terjual belum punya input metode bayar, diskon, atau pajak. Pajak default 11%.
- Modul belum diuji di perangkat terhadap backend dan database nyata. Migrasi backend `20261017000000_add_consignment` harus diterapkan dulu.
