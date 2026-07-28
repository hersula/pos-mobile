# POS Mobile (Flutter)

Aplikasi kasir mobile yang mengonsumsi backend `pos-backend` (Next.js). Mencakup modul Kasir/POS (diskon, PPN, split payment, cetak struk Bluetooth), Inventori, dan Laporan (tutup kasir + laba rugi), dengan alur login yang menghormati status persetujuan tenant (PENDING/APPROVED/REJECTED/SUSPENDED).

Project ini berisi **kode Dart lengkap (`lib/`)**. Folder platform native (`android/`, `ios/`) belum di-generate di sini — ikuti langkah Setup di bawah untuk membuatnya (langkah standar, sekali jalan).

---

## 1. Prasyarat

- Flutter SDK 3.3+ terpasang (`flutter --version`)
- Backend `pos-backend` sudah jalan (lihat README backend) — minimal Fase 1–4 (auth, inventori, penjualan) untuk aplikasi ini berfungsi penuh
- HP Android dengan printer thermal Bluetooth (opsional, untuk fitur cetak struk) — sudah di-*pairing* lewat pengaturan Bluetooth HP sebelum dipakai di app

---

## 2. Setup Awal

```bash
# 1. Masuk ke folder project
cd pos_mobile

# 2. Generate folder platform native (android/, ios/) — sekali saja
flutter create .

# 3. Install dependencies
flutter pub get
```

### a. Tambahkan izin di `android/app/src/main/AndroidManifest.xml`

Tempel di dalam tag `<manifest>`, sebelum tag `<application>`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

Kalau backend dites di HTTP lokal (bukan HTTPS) saat development, tambahkan juga di tag `<application>`:
```xml
android:usesCleartextTraffic="true"
```

> **Catatan `mobile_scanner`**: pastikan `minSdkVersion` di `android/app/build.gradle` minimal **21**, dan `compileSdkVersion`/`targetSdkVersion` mengikuti default `flutter create` terbaru (biasanya sudah otomatis terpenuhi).

### b. Tambahkan izin di `ios/Runner/Info.plist` (kalau target iOS)

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Aplikasi butuh akses Bluetooth untuk mencetak struk ke printer thermal.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>Aplikasi butuh akses Bluetooth untuk mencetak struk ke printer thermal.</string>
<key>NSCameraUsageDescription</key>
<string>Aplikasi butuh akses kamera untuk scan barcode produk.</string>
```

### c. Set alamat backend

Default `lib/core/constants/app_config.dart` mengarah ke `http://10.0.2.2:3000` (alamat `localhost` versi emulator Android). Sesuaikan sesuai kebutuhan:

```bash
# Emulator Android (default, tidak perlu diubah)
flutter run

# Device fisik / backend yang sudah di-deploy
flutter run --dart-define=API_BASE_URL=https://api.tokokamu.com

# iOS Simulator (localhost langsung bisa dipakai)
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

---

## 3. Menjalankan Aplikasi

```bash
flutter run
```

Alur pertama kali pakai:
1. **Daftar Toko Baru** dari halaman login → pilih paket **Gratis** atau **Berlangganan** → submit
2. Login ke Admin Panel web backend (`/admin/dashboard`) → **Setujui** tenant yang baru daftar
3. Kembali ke app Flutter → login pakai email/password yang didaftarkan tadi
4. Mulai pakai: tambah produk di tab **Inventori**, lalu jual di tab **Kasir**

---

## 4. Struktur Folder

```
lib/
├── main.dart                     # entry point, setup Provider
├── core/
│   ├── api/                      # Dio client, endpoint constants, exception
│   ├── constants/                # warna, tema, konfigurasi base URL
│   ├── storage/                  # penyimpanan token & pengaturan printer lokal
│   └── utils/                    # format Rupiah, tanggal, parsing angka
├── data/
│   ├── models/                   # Product, Sale, CartItem, dll
│   └── repositories/             # 1 class per resource, bicara ke ApiClient
├── state/
│   ├── auth_provider.dart        # status login (ChangeNotifier)
│   └── cart_provider.dart        # keranjang POS (ChangeNotifier)
├── features/
│   ├── auth/                     # login, register, status pending/ditolak
│   ├── common/                   # komponen dipakai lintas modul (scan barcode)
│   ├── dashboard/                # bottom navigation antar modul
│   ├── inventory/                # daftar & form produk
│   ├── pos/                      # kasir, keranjang, checkout, struk
│   ├── procurement/               # pengadaan barang (PO) & supplier
│   ├── reports/                  # tutup kasir & laba rugi
│   └── settings/                 # profil, printer, logout
└── services/
    ├── bluetooth_printer_service.dart   # wrapper print_bluetooth_thermal
    └── receipt_builder.dart             # generator struk format ESC/POS
```

---

## 5. Cara Kerja Fitur Kunci

### Diskon & PPN
Dihitung real-time di `CartProvider` (untuk preview di layar) memakai rumus yang sama persis dengan backend (`subtotal → diskon → PPN → total`), lalu backend **menghitung ulang dari nol saat transaksi disimpan** — jadi Flutter tidak pernah mengirim angka total, hanya item + persentase/nominal diskon & pajak. Ini mencegah manipulasi harga dari sisi client.

### Split Payment
Di `CheckoutScreen`, tombol **Split Bayar** menambah baris metode pembayaran baru. Semua baris (CASH/QRIS/dll) dikirim sebagai array `payments` ke `POST /api/sales`. Kalau total pembayaran kurang dari tagihan, transaksi tetap bisa disimpan sebagai **piutang** (status `PARTIAL`) dan dilunasi nanti lewat detail transaksi.

### Cetak Struk Bluetooth
1. `PrinterSettingsScreen` membaca daftar device Bluetooth yang **sudah di-pairing** di HP (bukan scan BLE baru — lebih stabil untuk printer thermal 58mm/80mm)
2. Alamat MAC printer yang dipilih disimpan lokal (`LocalStorage`)
3. Saat transaksi selesai, `ReceiptScreen` memanggil `ReceiptBuilder.build()` untuk membentuk bytes ESC/POS dari data transaksi (termasuk rincian tiap metode pembayaran & sisa tagihan kalau `PARTIAL`), lalu mengirimkannya lewat `BluetoothPrinterService.printBytes()`

#### Troubleshooting: printer tidak muncul di daftar

Penyebab paling umum (contoh kasus: printer generik seperti **PRJ-R58B**) beserta urutan solusinya, sesuai yang sudah dibuatkan di `PrinterSettingsScreen`:

1. **Printer belum di-pairing di level Android** — `getPairedDevices()` HANYA membaca device yang sudah di-pairing lewat Pengaturan Bluetooth sistem, plugin ini **tidak** melakukan scan BLE ke device baru. Tombol **"Pairing di Pengaturan HP"** di halaman ini langsung membuka `Settings > Bluetooth` Android (via `android_intent_plus`) supaya user bisa pairing tanpa keluar-masuk app. PIN pairing printer thermal generik biasanya `0000` atau `1234`.
2. **Izin Bluetooth ditolak** — sebelumnya app meminta izin Lokasi yang sebenarnya tidak diperlukan untuk sekadar baca daftar pairing/connect classic Bluetooth (izin Lokasi cuma relevan untuk *scan* BLE), sehingga permintaan izin bisa gagal tanpa alasan yang jelas ke user. Sekarang hanya meminta `BLUETOOTH_CONNECT` (satu-satunya yang benar-benar wajib di Android 12+). Kalau masih tertolak permanen, ada tombol **"Buka Pengaturan Aplikasi"** di banner error untuk mengaktifkannya manual.
3. **Plugin gagal membaca daftar meski printer sudah paired** (kadang terjadi di beberapa merek/OEM Android) — pakai tombol **"Hubungkan Manual via MAC Address"**: masukkan MAC address printer (cek di stiker printer atau di detail device pairing pada Pengaturan Bluetooth HP), app akan connect langsung tanpa bergantung pada hasil `pairedBluetooths`.
4. Setelah pairing baru, tekan ikon refresh (⟳) di AppBar halaman Printer Bluetooth — daftar tidak auto-refresh sendiri.

#### Bug yang sudah diperbaiki: struk penjualan cuma keluar tulisan "Toko"

**Root cause sebenarnya bukan kecepatan cetak** (walau itu juga sempat diperbaiki di preset kecepatan di bawah), tapi **data yang dikirim ke printer memang tidak lengkap**: endpoint `POST /api/sales` (dipanggil saat checkout) ternyata tidak menyertakan relasi `tenant` di response-nya, jadi begitu transaksi baru selesai dibuat dan langsung dicetak, `sale.businessName` masih `null` → `ReceiptBuilder` fallback ke teks literal **"Toko"** (lihat `sale.businessName ?? 'Toko'`) — persis apa yang dilihat user. Sudah diperbaiki di dua lapis:

1. **Backend** — `POST /api/sales` sekarang ikut meng-include `tenant`, `cashier`, `customer`, `warehouse`, jadi respons langsung setelah checkout sudah lengkap.
2. **Mobile (lapis pengaman tambahan)** — sebelum benar-benar mengirim ke printer, `ReceiptScreen` sekarang selalu **ambil ulang detail transaksi terbaru** lewat `GET /api/sales/:id` (`SalesRepository.getSaleDetail`), bukan langsung pakai objek `Sale` yang diterima dari layar sebelumnya. Kalau fetch ini gagal (mis. lagi offline), tetap lanjut cetak pakai data yang ada sebagai fallback — supaya cetak tidak pernah gagal total gara-gara masalah jaringan sesaat.

#### Bug yang sudah diperbaiki: Test Print bilang "belum terhubung" padahal printer sudah terhubung

Koneksi Bluetooth klasik (SPP) **tidak bertahan lintas sesi aplikasi** — walau printer sudah pernah dipilih & terhubung sebelumnya (tersimpan di `LocalStorage`), begitu app ditutup lalu dibuka lagi, socket-nya sudah putus dan perlu `connect()` ulang secara eksplisit. Sebelumnya `_testPrint()` di `PrinterSettingsScreen` langsung nyerah begitu `isConnected()` balas `false`, tanpa coba sambungkan ulang dulu pakai alamat yang tersimpan. Sekarang diperbaiki: kalau belum terkoneksi, otomatis coba `connect()` pakai `_savedAddress` dulu sebelum benar-benar dianggap gagal. Perbaikan yang sama juga sudah ada di alur cetak struk penjualan & nota pembelian.

#### Ukuran/lebar hasil cetak tidak sesuai fisik kertas (mis. sudah pilih 58mm tapi hasilnya kelihatan salah)

Beberapa printer generik murah **tidak konsisten dengan label lebar kertas resminya** — kepala cetak fisiknya bisa saja beda dot-width dari yang diklaim di kardus/nama produk, jadi walau kode sudah eksplisit set `PaperSize.mm58`, hasil cetak masih bisa kelihatan tidak pas di kertas 58mm fisik pada model tertentu. Karena ini murni karakteristik hardware yang beda-beda per merek dan tidak bisa dideteksi otomatis dari software, sekarang ada pemilih **Lebar Kertas: 58mm / 80mm** di halaman **Pengaturan → Printer Bluetooth** — tinggal coba kedua opsi lewat **Test Print** (sekarang juga menampilkan baris "Kertas: 58mm/80mm" supaya gampang dibandingkan) dan pakai yang hasilnya paling pas secara fisik. Pilihan otomatis tersimpan dan dipakai untuk struk penjualan maupun nota pembelian.

#### Troubleshooting: struk masih terpotong di tengah jalan (bukan cuma "Toko" doang, tapi beneran kepotong sebagian)

Ini beda kasus dari bug "Toko" di atas — kalau datanya sudah lengkap (nama toko asli muncul, bukan fallback) tapi tetap berhenti di tengah struk yang panjang, ini soal **kecepatan cetak fisik**. Printer thermal itu perangkat mekanik — kepala cetak butuh waktu nyata untuk menggerakkan kertas & "membakar" tiap baris, apalagi baris besar/tebal seperti nama toko (jauh lebih lambat dicetak daripada teks biasa). Kalau software terus mengirim data baru lebih cepat daripada kecepatan cetak fisik printer, buffer terima printer (yang di printer generik murah biasanya kecil) jadi penuh dan **sisa data yang belum sempat dicetak dibuang begitu saja**.

**Solusi cepat tanpa perlu update aplikasi** — buka **Pengaturan → Printer Bluetooth**, di bagian bawah ada pemilih **Kecepatan Cetak**: Normal / Lambat / Sangat Lambat. Kalau struk masih terpotong di "Normal", coba "Lambat", lalu "Sangat Lambat" kalau masih belum cukup. Pilihan ini otomatis tersimpan (`LocalStorage`) dan langsung dipakai untuk semua cetakan berikutnya (struk penjualan maupun nota pengadaan barang, karena keduanya lewat method `printBytes()` yang sama). Setelah ganti preset, coba **Test Print** dulu (mencetak 15 baris uji coba) — kalau baris terakhir "SELESAI" ikut tercetak utuh, berarti preset itu sudah cukup untuk printer kamu.

**Detail teknis** (`BluetoothPrinterService`):
- Data dikirim bertahap per potongan kecil (default 48 byte di preset Normal, turun ke 16 byte di preset Sangat Lambat), dengan jeda di antaranya (120ms Normal, sampai 280ms Sangat Lambat) — bukan dikirim sekaligus dalam satu panggilan.
- Ada jeda "pemanasan" 250ms di awal (kasih waktu printer siap menerima setelah `connect()`/`reset()`) dan jeda "penutup" 200ms di akhir sebelum proses cetak dianggap selesai.
- `generator.reset()` (perintah ESC/POS inisialisasi ulang) ditambahkan di awal setiap cetak (`ReceiptBuilder` & `PurchaseOrderReceiptBuilder`) untuk membersihkan sisa state cetak sebelumnya.
- Preset kecepatan didefinisikan di `BluetoothPrinterService.speedPresets` — kalau preset "Sangat Lambat" masih belum cukup untuk printer tertentu yang benar-benar bermasalah, nilainya bisa ditambah manual di kode (chunk makin kecil, delay makin panjang).

### Scan Barcode
Tombol ikon scan (📷) tersedia di beberapa tempat:
- **Form Produk** (`ProductFormScreen`) — hasil scan langsung mengisi field Barcode, memudahkan input barang baru tanpa ketik manual.
- **Halaman Kasir** (`PosScreen`, ikon di AppBar) — hasil scan langsung dicari lewat `GET /api/products?search=<kode>` (backend sudah mendukung pencarian barcode di endpoint ini sejak Fase 2), dan kalau ketemu langsung ditambahkan ke keranjang tanpa perlu cari manual dari grid produk.
- **Form Pengadaan Barang** (`PurchaseOrderFormScreen`) — di dalam pemilih produk, tombol scan mempercepat pencarian barang yang mau dibeli.

Komponen `BarcodeScannerScreen` (`lib/features/common/barcode_scanner_screen.dart`) dipakai bersama oleh semuanya lewat helper `scanBarcode(context)`, jadi kalau butuh titik scan baru di layar lain, tinggal panggil fungsi yang sama.


### Pengadaan Barang (Purchase Order)
Diakses lewat ikon truk (🚚) di AppBar tab **Inventori** (khusus role OWNER/MANAGER/GUDANG, sesuai role yang diizinkan backend):
- **Buat PO baru** — pilih gudang tujuan & supplier (opsional), tambah produk (bisa lewat scan barcode juga), isi qty & harga beli per item. PO tersimpan berstatus `DRAFT` — **stok belum bertambah**.
- **Terima Barang** — dari halaman detail PO, tombol ini memanggil `POST /api/purchase-orders/:id/receive`: stok otomatis bertambah di gudang tujuan, dan harga modal (`costPrice`) tiap produk ter-update mengikuti harga beli terbaru. Aksi ini final (PO jadi `RECEIVED`, tidak bisa di-receive dua kali — sudah divalidasi juga di backend).
- **Kelola Supplier** — ikon di AppBar halaman Pengadaan Barang, list & tambah supplier baru lewat dialog singkat.
- **Cetak Nota** — tombol di halaman detail PO (AppBar & tombol utama), mencetak nota pengadaan barang ke printer thermal Bluetooth (`PurchaseOrderReceiptBuilder`, format ESC/POS sama dengan struk penjualan). Nota mencantumkan No. PO, tanggal, supplier, gudang tujuan, rincian item, metode bayar, dan status hutang + sisa tagihan kalau pembeliannya tempo (`CREDIT`) — plus kolom tanda tangan "Diserahkan oleh / Diterima oleh" untuk bukti serah terima fisik. Bisa dicetak kapan saja, termasuk saat PO masih `DRAFT` (nota otomatis menandai "barang belum diterima").

### Laporan (Tutup Kasir, Laba Rugi, Pembelian)
- **Auto-refresh saat pindah tab** — `DashboardScreen` memakai `IndexedStack` supaya state tiap tab (termasuk filter tanggal di Laporan) tidak hilang saat pindah-pindah menu. Konsekuensinya, `ReportsScreen` normalnya *tidak* otomatis reload data saat dibuka ulang. Untuk mengatasi ini, `DashboardScreen` menyimpan `GlobalKey<ReportsScreenState>` dan memanggil method publik `refreshActiveTab()` setiap kali bottom nav pindah ke tab **Laporan** — jadi kasir selalu lihat angka terbaru tanpa perlu tarik-refresh manual. Tab "Tutup Kasir" selalu di-refresh (murah, tab default); tab Laba Rugi/Pembelian cuma ikut di-refresh kalau sebelumnya sudah pernah dibuka (hemat request).
- **Jumlah item terjual & produk terlaris** — tab "Tutup Kasir" sekarang menampilkan total qty barang yang terjual (`totalItemsSold`) dan daftar 5 produk terlaris berdasarkan qty (`topProducts`), diambil dari endpoint `GET /api/reports/sales-summary` yang sudah diperluas di backend.

### Paket & Langganan (FREE 10 transaksi/hari, SUBSCRIBE trial 30 hari)

- **Kartu status langganan** (`SubscriptionCard`, tampil di halaman Pengaturan) — beda tampilan tergantung `user.tenant.planType`:
  - **FREE**: progress bar "X dari 10 transaksi hari ini", berubah merah kalau sisa ≤3. Tombol **"Upgrade ke Berlangganan"** (khusus role OWNER) langsung memanggil `POST /api/tenant/subscription/upgrade` dan aktifkan trial 30 hari seketika.
  - **SUBSCRIBE**: badge status (Trial/Aktif/Menunggu Konfirmasi/Sudah Berakhir) + hitung mundur hari tersisa. Tombol **"Ajukan Pembayaran"** buka dialog catatan singkat (mis. "sudah transfer via BCA"), mengirim ke `POST /api/tenant/subscription/request-payment` — admin lalu konfirmasi lewat Admin Panel.
- **Batas transaksi FREE tercapai saat checkout** — `POST /api/sales` balas `403` dengan `code: "FREE_LIMIT_REACHED"`. `CheckoutScreen` mendeteksi kode ini secara spesifik (bukan cuma tampilkan pesan error generik) dan munculkan dialog dengan CTA "Lihat Opsi Upgrade" yang mengarahkan ke tab Pengaturan.
- **"Sistem off" saat trial/langganan SUBSCRIBE habis** — kalau backend balas `tenantStatus: "SUBSCRIPTION_EXPIRED"` (baik saat `login` maupun saat auto-refresh token gagal di tengah sesi), `LoginScreen` otomatis mengarahkan ke `PendingStatusScreen` dengan pesan yang jelas. Data toko **tidak pernah hilang** — begitu admin konfirmasi pembayaran, tinggal login lagi seperti biasa dan semua data (produk, transaksi, laporan) langsung utuh seperti sebelumnya.

### Sesi Login & Refresh Token
`ApiClient` otomatis menyisipkan `Authorization: Bearer <token>` di setiap request. Kalau server balas 401 (access token kedaluwarsa), client otomatis mencoba `POST /api/auth/refresh` sekali, lalu mengulang request asli. Kalau refresh juga gagal, sesi dianggap habis dan pengguna diarahkan ke halaman login (lihat `AuthProvider._handleSessionExpired`).

### ⚠️ Pola Wajib: `TextEditingController` Tidak Boleh Dibuat di Dalam Method `build`

Bug yang pernah terjadi (field qty di form Pengadaan Barang cuma bisa diisi 1 digit, field diskon/PPN di Keranjang serupa) disebabkan `TextEditingController(text: ...)` dibuat ulang setiap kali widget di-*rebuild* — begitu `setState`/`onChanged` jalan, controller lama "dibuang" dan diganti yang baru dengan cursor/teks ke-reset, jadi user cuma sempat mengetik 1 karakter sebelum field terasa "macet".

**Aturan:** controller untuk field yang nilainya berubah lewat `setState`/Provider harus dibuat **sekali saja** dan disimpan sebagai field/instance variable (bukan variabel lokal di dalam `build()` atau method yang dipanggil dari `build()`), lalu di-`dispose()` saat widget/item-nya tidak dipakai lagi. Pola yang benar:
- Form dengan field tetap (jumlah item statis) → buat controller di `initState()`, simpan sebagai `late final` field di State, dispose di `dispose()`. Contoh: `ProductFormScreen`.
- List item dinamis (bisa nambah/hapus baris, mis. item PO) → simpan controller sebagai field di dalam model item itu sendiri (bukan di widget-nya), dibuat sekali saat item ditambahkan, di-dispose saat item dihapus atau saat State di-dispose. Contoh: `_POItemDraft` di `purchase_order_form_screen.dart`.
- Dialog sementara (`showDialog`) → boleh dibuat sekali di scope function sebelum `showDialog` dipanggil, selama TIDAK dibuat ulang di dalam `builder:`/`StatefulBuilder`'s `builder:` callback (yang itu yang di-rebuild berulang).

Sebelum menambah field input baru yang controlled, cek dulu apakah controller-nya berpotensi ikut ke-rebuild bareng parent widget-nya.

---

## 6. Belum Termasuk / Pengembangan Lanjutan

- Mode offline (draft transaksi tersimpan lokal saat tidak ada internet, baru sync belakangan)
- Halaman detail & pembatalan transaksi dari riwayat penjualan (endpoint backend `POST /api/sales/:id/cancel` sudah siap, tinggal dibuatkan UI-nya)
- Push notification saat tenant di-approve admin (saat ini notifikasi dikirim lewat WhatsApp dari backend, lihat README backend)
