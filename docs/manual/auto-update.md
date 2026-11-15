# Auto-Update Aplikasi — Panduan

## Ringkas
Aplikasi Q-Pos secara otomatis memeriksa versi terbaru dari server saat dashboard dibuka (setelah login). Dialog update akan ditampilkan jika:
- Ada update tersedia (`updateAvailable` = true)
- User belum men-skip versi opsional tersebut di sesi sebelumnya
- Atau update adalah mandatory (wajib, tidak bisa di-skip)

## Kontrak API

**Endpoint:** `GET /api/app/version`

**Query parameter:**
- `platform`: `android` (hardcoded untuk mobile Flutter)
- `version`: versi app lokal (format: `1.0.0`, dibaca dari pubspec.yaml)
- `build`: build number lokal (format: string, mis. `1`)

**Contoh request:**
```
GET /api/app/version?platform=android&version=1.0.0&build=1
```

**Response (success 200):**
```json
{
  "data": {
    "latestVersion": "1.1.0",
    "latestBuildNumber": 2,
    "minSupportedVersion": "0.9.0",
    "mandatory": false,
    "updateAvailable": true,
    "downloadUrl": "https://example.com/releases/pos-mobile-1.1.0.apk",
    "releaseNotes": "- Perbaikan UI\n- Optimasi performa",
    "releasedAt": "2026-11-15T10:00:00Z"
  }
}
```

**Field penjelasan:**
- `latestVersion` (string|null): Versi terbaru (mis. "1.1.0")
- `latestBuildNumber` (int|null): Build number terbaru
- `minSupportedVersion` (string|null): Versi minimum yang masih didukung (untuk info; tidak digunakan saat ini)
- `mandatory` (bool, default false): Jika true, user tidak bisa skip update; dialog akan blokir tombol back
- `updateAvailable` (bool, default false): Flag utama; harus true agar dialog tampil
- `downloadUrl` (string|null): URL file APK untuk download
- `releaseNotes` (string|null): Catatan rilis (ditampilkan di dialog)
- `releasedAt` (string|null): Timestamp rilis (untuk info; saat ini tidak ditampilkan)

## Cara Kerja di Aplikasi

### 1. Pemeriksaan Otomatis
- Saat user membuka dashboard (setelah login), `AppUpdateChecker` secara otomatis memanggil endpoint versi.
- Pemeriksaan hanya dilakukan **sekali per sesi** (tracked di memory).

### 2. Dialog Update
Jika ada update:

**Update Mandatory:**
- Dialog muncul dengan judul "Versi Terbaru Tersedia"
- Menampilkan versi baru dan catatan rilis (scrollable)
- Tombol: "Perbarui Sekarang" saja
- User **tidak bisa menutup dialog** dengan back atau tap di luar (barrierDismissible=false, PopScope blokir)
- Saat klik "Perbarui": URL download dibuka di browser/Play Store

**Update Opsional:**
- Dialog sama, tapi user bisa memilih
- Tombol: "Nanti" + "Perbarui Sekarang"
- Saat klik "Nanti": dialog ditutup dan versi dicatat sebagai "di-skip" di SharedPreferences
- Versi yang di-skip tidak akan muncul lagi dalam sesi berikutnya

### 3. Skip Tracking
- Versi opsional yang di-skip disimpan ke `SharedPreferences` (key: `skipped_update_versions`)
- Format: daftar string (JSON list)
- Setiap kali app dibuka, daftar di-load ulang dan digunakan untuk filter
- Update mandatory selalu ditampilkan (tidak bisa di-skip)

### 4. Error Handling
- Jika jaringan gagal / timeout / respons error: **diam saja** (log debug saja, jangan tampilkan error ke user)
- UI tidak akan terblokir; user bisa pakai app normal
- Update checker tidak akan di-coba lagi dalam sesi yang sama

## Di Mana Kode Berada?

| File | Peran |
|---|---|
| `lib/data/models/app_version_info.dart` | Model data respons API |
| `lib/services/app_update_service.dart` | Service untuk memanggil endpoint |
| `lib/services/app_update_checker.dart` | Manajer logic (cek, tracking, show dialog) |
| `lib/features/app_update/update_dialog.dart` | UI dialog update |
| `lib/core/storage/local_storage.dart` | Menyimpan versi di-skip ke SharedPreferences |
| `lib/features/dashboard/dashboard_screen.dart` | Entry point (initState memanggil checker) |
| `lib/core/api/api_endpoints.dart` | Konstanta endpoint `/app/version` |

## Untuk Admin/Backend

1. **Menambahkan versi baru:**
   - Pastikan endpoint `/api/app/version` mengembalikan respons sesuai kontrak di atas
   - Set `updateAvailable` = true jika ada update
   - Set `mandatory` = true jika wajib (blokir user yang tidak update)
   - Isi `downloadUrl` dengan link APK yang valid
   - Isi `releaseNotes` dengan catatan rilis (support newline `\n`)

2. **Testing:**
   - Curl request (pastikan query parameter benar):
     ```bash
     curl "https://localhost:3000/api/app/version?platform=android&version=1.0.0&build=1"
     ```
   - Sebelum rilis: test dengan beberapa versi app (lama dan baru) untuk memastikan logic update bekerja

3. **Rollout gradual (optional):**
   - Tidak ada feature flag built-in untuk rollout gradual
   - Rekomendasi: kelola rilis di level infrastructure (backend bisa conditional response berdasarkan IP/user group)

## Paket Tergantung
- `package_info_plus`: Membaca versi dan build number app lokal
- `url_launcher`: Membuka URL download di browser/Play Store
- Existing: `dio`, `shared_preferences`, `provider`, `flutter` (sudah ada)

## Troubleshooting

**Q: Dialog update tidak muncul meskipun updateAvailable=true di API.**
- A: Cek apakah versi sudah pernah di-skip. Jika opsional, buka SharedPreferences editor atau clear app data.
- A: Pastikan checker berhasil di-init: cek log debug (grep "AppUpdateChecker").

**Q: URL download tidak bisa dibuka.**
- A: Pastikan URL valid dan accessible dari device (cek INTERNET permission di manifest).
- A: Jika Play Store link, pastikan format benar (misal: `https://play.google.com/store/apps/details?id=...`).

**Q: Update mandatory, tapi user bisa close/back.**
- A: Pastikan `mandatory: true` di respons API. Jika true tapi dialog masih bisa di-back, ada bug di UpdateDialog PopScope logic.

## Perubahan Masa Depan (TODOs)
- Rollout gradual (dengan feature flag atau canary user group)
- Notifikasi push sebelum mandatory update dipaksa (jika ada sistem push)
- Silently download & notify user (auto-install tidak didukung di Android tanpa app store atau special permissions)
- A/B test: opsional vs mandatory untuk metrik adoption
