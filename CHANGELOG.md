# Changelog

Format mengikuti [Keep a Changelog](https://keepachangelog.com/id-ID/1.1.0/).

## [Unreleased]

### Fixed
- Stock Opname: layar Hitung, Review Selisih, Detail, dan Buat Sesi tampil kosong putih dengan tombol menempel di atas layar. `BottomActionBar` memakai `Align` tanpa `heightFactor`, sehingga di `bottomNavigationBar` ia membesar setinggi layar dan menutupi isi (`stock_opname_widgets.dart`).
- Stock Opname: produk tanpa SKU menampilkan "· pcs" (titik di depan satuan).
- Stock Opname: isi kartu hitung dipusatkan vertikal (sebelumnya ruang kosong menumpuk di bawah); status sesi di daftar tampil sebagai badge; label "Cocok" kini hijau (`success`), bukan oranye warna aksi.
- Teks semua tombol (Elevated/Filled/Outlined/Text) kini memakai Mulish. Sebelumnya jatuh ke Roboto karena `textStyle` di tema tombol menggantikan gaya teks bawaan tanpa `fontFamily`.

## [1.0.4] - 2026-11-20 (build 5)

### Changed
- Tema aplikasi diganti dari "Hypermart Clean" ke **"Warm Roastery"**: latar krem hangat (`#FAF7F2`) dengan kartu putih, Burnt Orange sebagai brand (`#EA580C`, khusus elemen non-teks: FAB, garis fokus, indikator) dan aksi utama (`#C2410C`, kontras 5.18:1 dengan teks putih), Coffee Brown `#78350F` khusus tombol Bayar/Selesaikan Pembayaran dengan teks putih, teks netral cokelat-abu. Font tidak berubah (Mulish/Archivo).
- Token warna kini juga tersedia sebagai `ThemeExtension` `PosColors` (`lib/core/constants/pos_colors.dart`) dengan varian terang & gelap, dipanggil lewat `context.pos.x`. `AppColors.x` tetap ada (varian terang, nama token sama), jadi semua layar ikut berubah tanpa disentuh. Tema gelap (`AppTheme.dark`) sudah siap tapi belum diaktifkan (`themeMode: ThemeMode.light`) sampai layar dimigrasi; panduan di `docs/manual/tema.md`.
- Grid katalog kasir: foto produk memenuhi bagian atas kartu (tanpa bingkai), kartu lebih tinggi (`childAspectRatio` 0.82 → 0.72), produk stok habis fotonya diredupkan.
- Status `pending` kini kuning tua (`#A16207`) agar tidak tertukar dengan oranye aksi utama; `success` hijau `#15803D`; `danger` `#B91C1C`.
- `AppTheme`: `colorScheme` lengkap, AppBar putih bergaris bawah tipis, tema `NavigationBar`, `TabBar`, tombol (Elevated/Filled/Outlined/Text), input dengan garis fokus oranye, FAB, Chip, Dialog, BottomSheet, dan SnackBar mengambang.
- Versi aplikasi `1.0.4+5` (pubspec.yaml).

### Catatan rilis
- Didaftarkan sebagai update di panel admin (`/admin/app-versions`) versi `1.0.4`, build `5`. Ditandatangani dengan kunci yang sama dengan 1.0.3 (debug keystore), jadi bisa langsung menimpa versi terpasang.

## [1.0.3] - 2026-11-20 (build 4)

### Fixed
- Perbaikan update otomatis (catatan rilis di server: "Perbaikan Update Otomatis").

## [1.0.2] - 2026-11-20 (build 3)

### Added
- Update aplikasi di dalam aplikasi (Android): APK diunduh di dialog update dengan progres (persen dan MB, bisa dibatalkan) ke cache aplikasi, lalu dipasang lewat `PackageInstaller` tanpa membuka browser (`lib/services/app_update_downloader.dart`, `lib/services/apk_installer.dart`, `ApkInstaller.kt`). Setelah terpasang, aplikasi dibuka kembali otomatis (`UpdateRelaunchReceiver`, `MY_PACKAGE_REPLACED`), dengan notifikasi "Pembaruan Q-Pos selesai" sebagai cadangan.
- Izin `REQUEST_INSTALL_PACKAGES` dan `POST_NOTIFICATIONS`. Bila izin "Instal aplikasi tak dikenal" belum ada, dialog membuka pengaturannya dan pemasangan berlanjut otomatis saat pengguna kembali.
- Bila unduh/pasang gagal, dialog menawarkan "Coba Lagi"/"Pasang Ulang" dan "Unduh via Browser" (alur lama).

### Changed
- Tema aplikasi diganti ke **"Hypermart Clean"**: latar abu sangat muda (`#F5F6F8`) dengan kartu putih, merah `#D7182A` sebagai warna aksi utama/brand (sebelumnya emerald), kuning `#FFC20E` khusus tombol Bayar/Selesaikan Pembayaran (sebelumnya jingga), teks netral abu gelap. Hanya token di `lib/core/constants/app_colors.dart` yang diganti (nama token sama), jadi semua layar ikut berubah.
- Tombol pembayaran (`cart_panel.dart`, `checkout_screen.dart`) memakai teks gelap (`AppColors.onEmber`) karena teks putih tidak terbaca di atas kuning.
- Warna status `success` kini hijau sendiri (`#15803D`), tidak lagi sama dengan warna aksi utama; `danger` lebih gelap (`#B42318`) agar aksi hapus/batal tetap beda dari tombol utama.
- `AppTheme`: `colorScheme` lengkap (primary, secondary, error, onSurface), AppBar putih bergaris bawah tipis, tema `NavigationBar` (indikator merah muda, ikon/label terpilih merah), FAB merah, Chip, dan SnackBar mengambang.
- Versi aplikasi `1.0.2+3` (pubspec.yaml).

### Catatan rilis
- Batasan Android: update PERTAMA lewat fitur ini tetap meminta izin "Instal aplikasi tak dikenal" dan konfirmasi "Pasang" (aturan sistem). Di Android 12+ update berikutnya bisa tanpa konfirmasi. Buka ulang otomatis bisa diblokir sistem di Android 10+ (pembatasan buka dari latar belakang); saat itu pengguna mengetuk notifikasi. APK update wajib ditandatangani dengan kunci yang sama dengan aplikasi terpasang.
- Perubahan berikut (sebelumnya tercatat di `[Unreleased]`) ikut terbawa di build ini.

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
