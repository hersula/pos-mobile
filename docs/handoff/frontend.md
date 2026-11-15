# Handoff frontend (pos-mobile) — T9: aktif/nonaktif kategori
## Status: SELESAI (belum diuji di perangkat/emulator)

### File diubah
- lib/data/models/category.dart: +isActive (default true bila null), toJson, copyWith
- lib/data/models/user_profile.dart: +canManageCategoryStatus (OWNER/MANAGER)
- lib/data/repositories/product_repository.dart (CategoryRepository): getCategories({includeInactive}),
  +setCategoryActive(id, isActive) via PATCH /categories/{id}
- lib/features/inventory/category_management_screen.dart: load includeInactive=true, Switch per baris
  (hanya tampil utk canManageCategoryStatus), optimistic update + rollback, snackbar, chip "Nonaktif"
- lib/features/inventory/product_form_screen.dart: dropdown kategori tetap pakai getCategories() default
  (hanya aktif); saat EDIT produk dengan kategori yang sudah nonaktif, kategori itu di-fetch terpisah
  (includeInactive=true) dan disisipkan ke list agar tidak hilang, ditandai "(Nonaktif)"

### Tidak diubah
product_list_screen.dart & stock_opname_form_screen.dart sudah memakai getCategories() default
(tanpa includeInactive) → kategori nonaktif otomatis tersembunyi di filter kasir/produk, tanpa perlu ubah.

### Cara uji
1. `dart format .` dan `flutter analyze` sudah bersih dari error (hanya info lint pre-existing).
2. Belum ada emulator/device untuk uji visual — sarankan QC uji toggle switch, rollback saat API gagal,
   dan kasus produk dengan kategori nonaktif tetap tampil di form edit.

### Asumsi
Backend kontrak T9 (GET includeInactive, PATCH isActive) belum diverifikasi hidup — dikerjakan paralel
sesuai arahan tugas.
