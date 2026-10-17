# Peta Codebase — Q-Pos Mobile (`pos_mobile`)

Tanggal: 2026-10-17. Mode: read-only (tidak ada pub get/build/run). Backend pasangan: `C:\laragon\www\pos-backend` (hanya dibaca untuk pencocokan route).

## 1. Stack & versi (FAKTA dari pubspec.yaml)
- Flutter app "Q-Pos" v1.0.0+1, Dart SDK `>=3.3.0 <4.0.0`. Versi Flutter terpasang: tidak diketahui (lihat bagian Lingkungan).
- State management: `provider ^6.1.2` (ChangeNotifier). Routing: **tanpa router**; `MaterialApp(home: _RootGate)` + `Navigator.push` imperatif.
- HTTP: `dio ^5.4.3` (interceptor Bearer + auto-refresh). Satu pemanggilan memakai paket `http` (lihat utang teknis).
- Penyimpanan lokal: `shared_preferences ^2.2.3` (token, profil, setting printer). Tidak ada DB lokal/SQLite dan tidak ada antrian offline.
- Perangkat: `print_bluetooth_thermal ^1.1.4` + `esc_pos_utils_plus ^2.0.4` (printer thermal), `permission_handler ^11.3.1`, `mobile_scanner ^5.2.3` (barcode kamera), `image_picker ^1.1.2`, `android_intent_plus ^5.1.0`, `uuid ^4.4.0`, `intl ^0.19.0` (locale id_ID), `cupertino_icons`.
- Dev: `flutter_lints ^4.0.0`, `flutter_launcher_icons ^0.14.1`. Font bundel: Archivo, Mulish, IBMPlexMono.
- Platform: folder android/, ios/, web/, linux/, macos/ ada (tidak ada windows/). Fitur Bluetooth/Android Intent/izin hanya bermakna di **Android** (platform aktif utama; manifest berisi INTERNET, BLUETOOTH*, FINE_LOCATION, CAMERA, READ_MEDIA_IMAGES). `applicationId = com.example.pos_mobile` (placeholder), `minSdk = flutter.minSdkVersion`.
- Ukuran: ~9.700 baris Dart di `lib/`, 1 file test.

## 2. Struktur `lib/` dan titik masuk
| Path | Peran |
|---|---|
| `main.dart` | Titik masuk. Init locale `id_ID`, terapkan preset kecepatan & mode cetak printer dari LocalStorage, `MultiProvider(AuthProvider..restoreSession(), CartProvider)`. `_RootGate`: unknown -> spinner, unauthenticated -> LoginScreen, authenticated -> DashboardScreen. |
| `core/api/` | `api_client.dart` (Dio singleton, interceptor, wrapper get/post/put/delete/postMultipart), `api_endpoints.dart` (konstanta path), `api_exception.dart`. |
| `core/constants/` | `app_config.dart` (base URL), `app_theme.dart`, `app_colors.dart`, `role_labels.dart`. |
| `core/storage/local_storage.dart` | Wrapper SharedPreferences (sesi + printer). |
| `core/utils/` | currency (Rupiah), date, num_parser, responsive. |
| `data/models/` | app_user, cart_item, category, customer, menu_permission, price_level, product, product_unit, purchase_order, sale, subscription_status, supplier, user_profile. |
| `data/repositories/` | Satu repo per domain (bagian 4). Repo Category/PriceLevel/Warehouse didefinisikan di dalam `product_repository.dart`. |
| `features/` | Layar per modul (bagian 3). |
| `services/` | `bluetooth_printer_service`, `receipt_builder`, `purchase_order_receipt_builder`, `update_service`. |
| `state/` | `auth_provider.dart`, `cart_provider.dart` (hanya 2 provider; layar lain memakai `setState` + repo langsung). |
| `models/version_info.dart` | Model info versi (di luar `data/models`, tidak konsisten). |

**Konfigurasi base URL:** `AppConfig.baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000')`, prefix `/api`. Untuk device fisik/produksi wajib `--dart-define=API_BASE_URL=https://...`. Manifest utama tidak memuat `usesCleartextTraffic`/network security config, sehingga **HTTP cleartext diblok di Android 9+ pada build rilis** (manifest debug/profile belum diperiksa). `update_service.dart` meng-hardcode host `https://pos-backend.sicerdiq.my.id`.

## 3. Modul/fitur
| Modul | Layar | State/Service | Model | Repository |
|---|---|---|---|---|
| Auth & registrasi tenant | `auth/login_screen`, `register_screen`, `registration_submitted_screen`, `pending_status_screen` | `AuthProvider` | user_profile, app_user | `AuthRepository` |
| Dashboard | `dashboard/dashboard_screen` | `AuthProvider` | menu_permission | - |
| Kasir (POS) | `pos/pos_screen`, `cart_panel`, `cart_screen`, `checkout_screen`, `receipt_screen`; `common/barcode_scanner_screen` | `CartProvider`, `ReceiptBuilder`, `BluetoothPrinterService` | cart_item, sale, customer, price_level | `SalesRepository`, `ProductRepository`, `CustomerRepository`, `PriceLevelRepository`, `WarehouseRepository` |
| Inventori/produk | `inventory/product_list_screen`, `product_form_screen`, `product_image_picker`, `category_management_screen`, `price_level_management_screen` | - | product, product_unit, category, price_level | `ProductRepository`, `CategoryRepository`, `PriceLevelRepository`, `WarehouseRepository` |
| Pengadaan | `procurement/purchase_order_list/form/detail_screen`, `supplier_list_screen` | `PurchaseOrderReceiptBuilder` | purchase_order, supplier | `PurchaseOrderRepository`, `SupplierRepository` |
| Laporan | `reports/reports_screen` | - | model di dalam `report_repository.dart` | `ReportRepository` |
| Pengaturan | `settings/settings_screen`, `printer_settings_screen`, `user_management_screen`, `user_form_screen`, `menu_permission_screen`, `subscription_card` | `BluetoothPrinterService`, `LocalStorage` | user_profile, menu_permission, subscription_status | `UserRepository`, `MenuPermissionRepository`, `SubscriptionRepository` |
| Update app | (tidak ada layar) | `UpdateService` | `models/version_info` | tidak terpakai |

## 4. Pemanggilan API & pencocokan dengan pos-backend
Backend punya 62 file route di `src/app/api/`. Path dan metode HTTP diverifikasi dari `export function GET/POST/PUT/DELETE` di tiap `route.ts`.

| Modul | Endpoint yang dipakai mobile | Status |
|---|---|---|
| Auth | POST `/auth/login`, POST `/auth/register-tenant`, POST `/auth/refresh` (interceptor) | COCOK |
| Produk | GET/POST `/products`, GET/PUT/DELETE `/products/{id}`, GET `/products/scan?code=` | COCOK |
| Upload gambar | POST `/upload` (multipart) | COCOK. Catatan: gambar disajikan via `/api/uploads/[...path]`, sedangkan `resolveImageUrl` membentuk `{baseUrl}/uploads/...` (tanpa `/api`); perlu dicek apakah ada rewrite di `next.config.js` atau backend mengembalikan URL penuh |
| Kategori | GET/POST `/categories`, PUT/DELETE `/categories/{id}` | COCOK |
| Level harga | GET/POST `/price-levels`, PUT/DELETE `/price-levels/{id}` | COCOK |
| Gudang | GET `/warehouses` | COCOK |
| Supplier | GET/POST `/suppliers` | COCOK |
| Pelanggan | GET/POST `/customers` | COCOK |
| PO | GET/POST `/purchase-orders`, GET `/{id}`, POST `/{id}/receive`, POST `/{id}/payments` | COCOK |
| Penjualan | GET/POST `/sales`, GET `/sales/{id}`, POST `/{id}/cancel`, POST `/{id}/payments` | COCOK |
| Laporan | GET `/reports/sales-summary`, `/profit-loss`, `/purchases-summary` | COCOK |
| User | GET/POST `/users`, PUT/DELETE `/users/{id}` | COCOK |
| Otoritas menu | GET/PUT `/menu-permissions` | COCOK |
| Langganan | GET `/tenant/subscription`, POST `/upgrade`, POST `/request-payment` | COCOK |
| Versi | GET `/api/version` (via paket `http`, host hardcode) | route COCOK, tetapi kodenya tidak dipanggil |

**Backend ada, mobile belum pakai:** `/stocks`, `/stock-movements` (konstanta ada di `ApiEndpoints`, tanpa repo/layar); `/expenses` dan `/expenses/{id}`; `/accounting/chart-of-accounts` (+`/{id}`), `/accounting/journal`, `/accounting/ledger` (konstanta ada, tanpa repo/layar, padahal deskripsi app menyebut "akunting"); POST/PUT/DELETE `/warehouses`; PUT/DELETE `/suppliers/{id}` dan `/customers/{id}`; GET `/purchase-orders/{id}/payments`; seluruh `/admin/*` (memang untuk panel admin web).
**Mobile pakai tapi backend tidak ada:** tidak ditemukan.
**Batasan:** pencocokan hanya pada path+metode. Nama field payload/response belum dibandingkan per endpoint; perlu uji kontrak.

## 5. Autentikasi, error, offline, perangkat
- **Auth:** login -> `{accessToken, refreshToken, user}` disimpan di SharedPreferences (**plaintext, bukan secure storage**). Default backend: access 15 menit, refresh 30 hari. Interceptor: 401 -> POST `/auth/refresh` sekali -> ulang request; gagal -> `onSessionExpired` -> clearSession -> ke login. Refresh hanya mengembalikan accessToken baru. Login 403 membawa `tenantStatus` (PENDING/REJECTED/SUSPENDED) -> `pending_status_screen`. Role backend: OWNER, MANAGER, KASIR, GUDANG, AKUNTAN; menu diatur via `/menu-permissions`.
- **Error:** `ApiException(message, statusCode, data)`; pesan dari field `message` backend, fallback "Tidak bisa terhubung ke server..." (juga muncul untuk 5xx tanpa body). Timeout 15 detik.
- **Offline/sinkronisasi:** **tidak ada.** Semua transaksi wajib online; tidak ada cache produk, antrian, atau retry. Risiko tinggi bagi kasir saat koneksi buruk.
- **Printer:** `BluetoothPrinterService` (ESC/POS), preset kecepatan (normal/slow/very_slow), ukuran kertas (mm58/mm80), mode kirim (single/chunked), semua tersimpan lokal; struk penjualan dan struk PO. Izin runtime via permission_handler. Riwayat git terbaru berisi perbaikan Bluetooth berulang (area rawan).
- **Scanner:** `mobile_scanner` lewat `barcode_scanner_screen`, pencarian lewat `/products/scan`.
- **Pembayaran:** hanya pencatatan ke backend (`/sales/{id}/payments`, `/purchase-orders/{id}/payments`) dan langganan manual (`request-payment`). Tidak ada integrasi payment gateway/QRIS.

## 6. Test, utang teknis, risiko, TODO
**Test:** hanya `test/widget_test.dart`, template counter bawaan yang memakai `MyApp`, padahal kelas di `main.dart` bernama `PosApp`. **Test ini tidak akan compile** (FAKTA dari pembacaan kode). Tidak ada unit test untuk repo/provider/model/receipt builder.

**Utang teknis & temuan:**
1. `services/update_service.dart` meng-import `package:http/http.dart` padahal `http` bukan dependensi langsung di pubspec (hanya transitif di pubspec.lock). `UpdateService`/`VersionInfo` tidak dipanggil di mana pun, host hardcode.
2. `widget_test.dart` rusak.
3. Token di SharedPreferences plaintext; disarankan `flutter_secure_storage`.
4. Default base URL `http://`, tanpa konfigurasi cleartext.
5. `applicationId` masih `com.example.pos_mobile`; signing rilis belum diaudit.
6. Interceptor 401 juga terpicu pada login salah password (401 "Email atau password salah") dan memanggil `onSessionExpired`; kegagalan refresh karena jaringan ikut dianggap sesi habis, sehingga pengguna ter-logout saat sinyal buruk.
7. Layar besar mencampur UI dan logika (product_form 577, reports 535, printer_settings 530, PO detail 485 baris); hanya 2 provider; tanpa routing terpusat.
8. Penempatan tidak konsisten: `models/version_info.dart` di luar `data/models`; 3 repo dalam satu file.
9. Akunting, stok, dan biaya tersedia di backend dan sebagai konstanta endpoint, tetapi belum ada UI.
10. Tidak ada TODO/FIXME di `lib/` (grep kosong).

**Risiko:** transaksi gagal total saat offline; kompatibilitas printer BT beragam; kontrak payload belum diuji; URL produksi dan cleartext belum jelas.

## Lingkungan (skill dt-laragon-env-audit, bagian Flutter; hanya cek keberadaan)
- `which flutter` dan `which java`: **tidak ditemukan** di PATH Git Bash. `%LOCALAPPDATA%\Android\Sdk`: **tidak ada**. Build/test/run belum bisa dijanjikan di mesin ini sebelum Flutter SDK (Dart >=3.3), JDK, dan Android SDK tersedia (bisa saja terpasang di lokasi non-PATH; disk tidak dipindai penuh).
- `pubspec.lock` ada; `android/` dan `ios/` lengkap; aset font/ikon dirujuk di pubspec (keberadaan tiap file aset tidak diaudit). Tidak ada model TFLite.
- Perintah yang dipakai nanti: `flutter pub get`, `flutter analyze`, `flutter test`, `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000`, `flutter build apk --dart-define=API_BASE_URL=https://...`.
