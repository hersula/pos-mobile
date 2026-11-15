# QC Review Statis — Modul Auto-Update (T3)

Tanggal: 15/11/2026. Review statis (tanpa menjalankan server/DB).
Repo: pos-backend (prisma/schema, migration, route handlers) dan pos-mobile (service, checker, dialog, model).

## Ringkasan
HASIL: GAGAL (ada bug Tinggi).

## Daftar Bug

| ID | Severity | File:Line | Ringkasan |
|---|---|---|---|
| BUG-AU-001 | Tinggi | pos-backend/src/app/api/app/versions/[id]/route.ts (DELETE, sekitar baris akhir fungsi) | Response 204 disertai body JSON — melanggar spesifikasi HTTP, bisa gagal di-parse client |
| BUG-AU-002 | Sedang | pos-mobile/lib/features/app_update/update_dialog.dart (`_openDownloadUrl`, `Navigator.pop(context)` setelah `launchUrl`) | Dialog mandatory tetap ditutup setelah tombol "Perbarui Sekarang" ditekan, meski user belum benar-benar menyelesaikan update |
| BUG-AU-003 | Rendah | pos-backend/src/app/api/app/version/route.ts (`compareSemver`) | Perbandingan semver naif, tidak menangani pre-release/suffix non-numerik (mis. "1.2.0-beta") — bisa NaN/salah urut |
| BUG-AU-004 | Rendah | pos-backend/src/app/api/app/versions/route.ts (`createVersionSchema.version` & `minSupportedVersion` regex `^\d+\.\d+\.\d+`) | Regex hanya mencocokkan prefix, menerima input seperti "1.0.0abcXYZ" sebagai valid |

## Detail

### BUG-AU-001 — DELETE /api/app/versions/[id] mengembalikan 204 dengan body
**File**: `pos-backend/src/app/api/app/versions/[id]/route.ts`
```
return NextResponse.json(
  { message: "Versi aplikasi berhasil dihapus" },
  { status: 204 }
);
```
**Dampak**: Status HTTP 204 (No Content) secara spesifikasi RFC 7231 tidak boleh memiliki body. Banyak HTTP client (termasuk `fetch`/axios/dio di Angular admin atau tooling lain) akan melempar error saat mencoba mem-parsing body JSON pada response 204, atau body akan diabaikan browser sehingga pesan sukses tidak pernah terbaca. Endpoint ini berisiko gagal secara fungsional di sisi admin web meskipun soft-delete di DB berhasil.
**Reproduksi**: `curl -i -X DELETE -H "Authorization: Bearer <token-owner>" http://localhost:3000/api/app/versions/<id>` — perhatikan response punya `Content-Length` > 0 pada status 204, yang invalid.
**Saran**: Gunakan status 200 dengan body message, atau status 204 tanpa body (`return new NextResponse(null, { status: 204 })`).

### BUG-AU-002 — Dialog mandatory bisa ditutup tanpa update selesai
**File**: `pos-mobile/lib/features/app_update/update_dialog.dart`, fungsi `_openDownloadUrl`:
```dart
if (await canLaunchUrl(url)) {
  await launchUrl(url, mode: LaunchMode.externalApplication);
  if (mounted) Navigator.pop(context);
}
```
**Dampak**: Untuk versi `mandatory=true`, dialog seharusnya "benar-benar tidak bisa ditutup" sampai update terpasang. Namun kode ini langsung `Navigator.pop(context)` setelah `launchUrl` berhasil dipanggil (hanya membuka browser/Play Store, bukan menunggu instalasi selesai). User bisa membuka link lalu segera menutup browser tanpa update, kembali ke app, dan dialog mandatory sudah tertutup — defeat tujuan mandatory block. `AppUpdateChecker._hasChecked` juga sudah `true` sehingga dialog tidak akan muncul lagi di sesi tersebut walau app masih versi lama.
**Reproduksi**: Set versi server dengan `mandatory: true` dan `minSupportedVersion` lebih tinggi dari versi client. Buka app, klik "Perbarui Sekarang", lalu segera tekan back dari browser tanpa install. Aplikasi lama tetap bisa dipakai penuh.
**Saran**: Jangan pop dialog setelah hanya membuka URL; biarkan dialog tetap tampil (karena `canPop: false`), atau re-check versi saat app resume sebelum mengizinkan interaksi lanjut.

### BUG-AU-003 — compareSemver tidak robust
**File**: `pos-backend/src/app/api/app/version/route.ts`, fungsi `compareSemver`.
**Dampak**: `v1.split(".").map(Number)` terhadap string seperti `"1.2.0-beta"` akan membuat elemen non-numerik menjadi `NaN`, lalu `NaN < NaN` dan `NaN > NaN` keduanya `false`, sehingga comparison salah (dianggap sama meski berbeda), yang dapat membuat `updateAvailable`/`mandatory` salah dihitung.
**Reproduksi**: Panggil endpoint dengan `version=1.2.0-beta` dan `latestVersion.version` di DB `1.3.0`. Secara logis harus update tersedia, namun hasil bisa tidak konsisten karena NaN comparisons.
**Saran**: Gunakan parser semver yang benar (strip suffix pre-release atau gunakan library `semver`).

### BUG-AU-004 — Validasi regex semver hanya cek prefix
**File**: `pos-backend/src/app/api/app/versions/route.ts` (dan endpoint PATCH `[id]/route.ts` memakai regex serupa).
**Dampak**: Regex `/^\d+\.\d+\.\d+/` tanpa anchor akhir (`$`) meloloskan input seperti `"1.0.0; DROP TABLE"` atau `"1.0.0garbage"` sebagai version/minSupportedVersion yang valid, berpotensi merusak data versi yang tersimpan dan logika compareSemver di atas.
**Reproduksi**: `POST /api/app/versions` dengan `version: "1.0.0xxxxx"` — request lolos validasi Zod (201 Created).
**Saran**: Tambahkan anchor akhir `$` atau gunakan regex semver standar penuh.

## Regresi 15/11

HASIL: LULUS (statis cepat, 4/4 bug ditutup, tidak ada bug baru).

| ID | Status | Bukti |
|---|---|---|
| BUG-AU-001 | CLOSED | `versions/[id]/route.ts` DELETE sekarang `NextResponse.json({message,data}, {status:200})`, bukan 204+body. |
| BUG-AU-002 | CLOSED | `update_dialog.dart` `_openDownloadUrl`: `Navigator.pop(context)` hanya dipanggil `if (!widget.versionInfo.mandatory)`; untuk mandatory dialog tetap tampil (`setState(_isOpening=false)`), `PopScope(canPop: !isMandatory)` tetap ada. |
| BUG-AU-003 | CLOSED | `compareSemver` tetap strip suffix pre-release via `v.split("-")[0]` sebelum `Number()`, menghindari NaN untuk kasus "1.2.0-beta". |
| BUG-AU-004 | CLOSED | Regex di `versions/route.ts` & `versions/[id]/route.ts` kini `/^\d+\.\d+\.\d+$/` (anchor akhir `$` ada), menolak "1.0.0xxxxx". |

Catatan: verifikasi hanya statis (baca kode), endpoint tidak dipanggil live karena di luar cakupan T6. Konsistensi `docs/api-contract.md` (pos-backend, baris ~353) untuk DELETE perlu dicek ulang oleh backend/docs karena file tersebut di luar area akses qc pos-mobile.

## Hal yang sudah sesuai (tidak ada bug)
- Field respons publik (`GET /api/app/version`) cocok 1:1 dengan parsing `AppVersionInfo.fromJson` di Flutter (nama & tipe field, nullable di-handle dengan default aman).
- Endpoint publik tidak membocorkan `id`, data platform lain, atau versi inactive — hanya field yang relevan untuk klien.
- Endpoint admin (`/api/app/versions`, `/api/app/versions/[id]`) konsisten menerapkan `requireRole(user, ["OWNER"])` di semua method (GET/POST/PATCH/DELETE).
- Kasus data kosong (`latestVersion === null`) pada endpoint publik mengembalikan 200 dengan semua field `null`/`false`, bukan 500 — sudah benar menangani tabel kosong.
- `AppUpdateChecker.checkAndShowDialogIfNeeded` membungkus `_service.checkLatestVersion()` dalam try/catch dan hanya `debugPrint`, tidak melempar — kegagalan jaringan tidak crash/blokir UI aplikasi secara umum (di luar isu BUG-AU-002).
- Migrasi SQL (`CREATE TABLE app_versions`, enum `AppPlatform`, unique+index `platform+buildNumber`) konsisten dengan `schema.prisma` (nama kolom via `@map`, tipe, default, unique index).
