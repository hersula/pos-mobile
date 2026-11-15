# QC Statis — Fitur Aktif/Nonaktif Kategori Produk (T10)

**HASIL: LULUS** (review statis, tanpa DB/server) — tidak ditemukan bug Kritis/Tinggi.

## Cakupan pemeriksaan
1. Migrasi SQL (`20261115080000_add_category_is_active/migration.sql`): sintaks MariaDB valid
   (`ALTER TABLE ... ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT true` + index), konsisten dengan
   `schema.prisma` (`isActive Boolean @default(true) @map("is_active")`). Default `true` aman untuk
   baris lama. Tidak ada `CREATE TYPE`/gaya Postgres. — OK.
2. Kontrak: `includeInactive` query param, field `isActive` di respons GET/POST/PUT/PATCH sesuai
   `docs/api-contract.md` baris 367-397. `Category.fromJson` (lib/data/models/category.dart:14-23)
   null-safe: `json['isActive'] as bool? ?? true` → respons lama tanpa field tetap aman. — OK.
3. Otorisasi: PATCH `[id]/route.ts` memakai `requireRole(user, ["OWNER", "MANAGER"])` sesuai kontrak;
   `assertOwnedByTenant` memfilter `findFirst({ id, tenantId })` sebelum update → mencegah ubah
   kategori tenant lain (404 jika beda tenant). — OK.
4. Sembunyi kategori nonaktif di pemilihan: `getCategories()` default `includeInactive=false`.
   Saat edit produk, `product_form_screen.dart:244-259` mendeteksi bila `_categoryId` produk tidak
   ada di daftar aktif, lalu fetch ulang dengan `includeInactive: true` dan menyisipkan kategori
   tersebut ke list agar nilai tidak hilang/reset. — OK.
5. Toggle di `category_management_screen.dart:48-77`: optimistic update (`setState` sebelum request),
   rollback ke nilai lama pada `ApiException`, guard `if (mounted)`/`if (!mounted) return` sebelum
   setState lanjutan, dan Switch diganti `CircularProgressIndicator` saat `_togglingIds` berisi id
   tersebut (mencegah double-tap/double-request). — OK.

## Catatan minor (bukan bug, tidak memblokir LULUS)
- Tidak ada debounce eksplisit di level network (hanya UI disable); untuk kasus ekstrem race
  (user mematikan airplane mode sambil toggle) tidak diuji karena review ini statis tanpa server aktif.
- Review ini tidak mencakup uji fungsional nyata (server/DB belum dijalankan sesuai lingkup T10).
