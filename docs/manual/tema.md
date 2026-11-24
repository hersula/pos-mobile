# Tema Tampilan Q-Pos — Panduan

Tema aktif: **"Warm Roastery"** (v1.0.2). Latar krem hangat dengan kartu putih. Burnt Orange dipakai sebagai brand dan aksi utama, Coffee Brown khusus tombol pembayaran. Font tidak berubah: Mulish untuk isi, Archivo untuk judul, IBM Plex Mono untuk angka/struk.

## Di mana tema diatur

| File | Isi |
|---|---|
| `lib/core/constants/app_colors.dart` | **Sumber nilai warna terang**, berupa konstanta `AppColors.x`. Ganti warna terang di sini. |
| `lib/core/constants/pos_colors.dart` | `ThemeExtension` `PosColors`: `PosColors.light` (merujuk ke `AppColors`) dan `PosColors.dark`. Ganti warna gelap di sini. Diakses lewat `context.pos.x`. |
| `lib/core/constants/app_theme.dart` | `AppTheme.light` / `AppTheme.dark`: `ThemeData` Material 3 yang dibangun dari `PosColors` (colorScheme, tombol, input, AppBar, NavigationBar, dll). |
| `lib/main.dart` | `theme`, `darkTheme`, `themeMode` di `MaterialApp`. |

## Token warna

| Token | Terang | Gelap | Dipakai untuk |
|---|---|---|---|
| `paper` | `#FAF7F2` | `#1C1917` | Latar Scaffold, isian input |
| `surface` | `#FFFFFF` | `#292524` | Kartu, AppBar, dialog, sheet |
| `line` | `#E8E1D8` | `#44403C` | Garis tepi, divider |
| `text` / `ink` | `#292524` | `#F5F5F4` | Teks utama |
| `muted` | `#6B635D` | `#A8A29E` | Teks sekunder, ikon nonaktif |
| `accent` | `#C2410C` | `#FB923C` | Aksi utama, teks aksen (harga, tab aktif) |
| `onAccent` | putih | `#1C1917` | Teks/ikon di atas `accent` |
| `accentSoft` | `#FFEDD5` | `#431407` | Latar terpilih (chip, indikator nav) |
| `brand` | `#EA580C` | `#FB923C` | **Non-teks saja**: FAB, garis fokus, indikator tab, progress |
| `ember` | `#78350F` | `#E7B98A` | **Khusus** tombol Bayar / Selesaikan Pembayaran |
| `onEmber` | putih | `#1C1917` | Teks di atas `ember` |
| `pending` | `#A16207` | `#FACC15` | Status menunggu (kuning tua, beda dari oranye aksi) |
| `success` | `#15803D` | `#4ADE80` | Status berhasil |
| `danger` | `#B91C1C` | `#F87171` | Hapus, batal, stok habis, error |
| `info` | `#1D4ED8` | `#60A5FA` | Informasi |
| `productImageBg` | `#F3EEE7` | `#312C29` | Latar kotak foto produk di grid |

Semua pasangan teks/latar di atas lolos **WCAG AA (≥ 4,5:1)**. Satu-satunya pengecualian adalah `brand` `#EA580C`, yang hanya mencapai 3,56:1 terhadap putih. Karena itu `brand` **tidak boleh dipakai untuk teks**. Untuk teks berwarna oranye, pakai `accent`.

## Strategi: reskin aplikasi yang sudah berjalan

Pendekatan ini **berbeda dari membangun proyek baru**. Di proyek baru, setiap widget langsung ditulis memakai `Theme.of(context)` / `context.pos`. Di aplikasi kasir yang sudah berjalan, struktur layout, alur keranjang, pembayaran, cetak struk, dan sinkronisasi **tidak disentuh**. Yang berubah hanya nilai token dan tema komponen.

1. **Token tetap, nilai diganti.** Hasil audit: 449 referensi `AppColors.x` dan **0** warna hex di luar `core/constants`. Mengganti nilai di `app_colors.dart` sudah mengubah seluruh layar dalam mode terang tanpa membuka file layar mana pun.
2. **Komponen bawaan lewat `ThemeData`.** Tombol, input, AppBar, NavigationBar, Chip, Dialog, SnackBar, dan TabBar diatur di `AppTheme`. Widget yang memakai komponen bawaan tanpa `style:` sendiri otomatis ikut.
3. **Perubahan visual terarah hanya di tempat yang perlu.** Pada v1.0.2 hanya `_ProductCard` di `pos_screen.dart` yang diubah, supaya foto produk tampil besar. Callback (`onTapAdd`, `onTapPickUnit`) dan logika stok tetap sama.
4. **Mode gelap bertahap.** Lihat bagian berikutnya.
5. **Rollback mudah.** Semua perubahan tema ada di 3 file `core/constants`, `main.dart`, dan `_ProductCard`. Kembalikan file-file itu dengan `git checkout <commit> -- <file>` untuk memulihkan tema lama.

## Mode gelap: migrasi per layar

`AppColors.x` adalah konstanta, sehingga **selalu terang**. Kalau `themeMode` langsung dibuat gelap, komponen bawaan akan ikut gelap tetapi kartu `AppColors.surface` tetap putih, dan tampilannya jadi belang. Karena itu `main.dart` sengaja memakai `themeMode: ThemeMode.light`.

Cara memigrasi satu layar:

```dart
import '../../core/constants/pos_colors.dart';

@override
Widget build(BuildContext context) {
  final pos = context.pos;              // 1. ambil token tema aktif
  return Container(
    color: pos.surface,                 // 2. AppColors.surface -> pos.surface
    child: Text('Total',
        style: TextStyle(color: pos.muted)), // 3. hapus `const` di depan TextStyle
  );
}
```

Aturan penggantian:

| Sebelum | Sesudah |
|---|---|
| `AppColors.x` | `pos.x` (nama token sama) |
| `const TextStyle(color: AppColors.x)` | `TextStyle(color: pos.x)` (`const` harus dihapus) |
| `Colors.white` di atas `accent` | `pos.onAccent` |
| `Colors.white` di atas `ember` | `pos.onEmber` |
| `Colors.white` sebagai latar kartu | `pos.surface` |
| `Colors.black54` / `black38` (overlay) | Boleh tetap (overlay foto/scanner) |

Urutan yang disarankan, dari yang paling sering dilihat kasir:

1. `features/pos/` (`pos_screen`, `cart_panel`, `cart_screen`, `checkout_screen`, `receipt_screen`). `_ProductCard` sudah memakai `context.pos`.
2. `features/dashboard/`, `features/auth/`
3. `features/inventory/`, `features/stock_opname/`
4. `features/procurement/`, `features/consignment/`, `features/reports/`, `features/settings/`

Layar yang memakai `Colors.white`/`Colors.black` (perlu ditinjau manual saat dimigrasi): `auth/login_screen`, `auth/register_screen`, `common/barcode_scanner_screen`, `consignment/consignment_detail_screen`, `consignment/consignment_form_screen`, `consignment/consignment_receivables`, `inventory/product_form_screen`, `inventory/product_image_picker`, `pos/checkout_screen`, `pos/pos_screen`, `pos/receipt_screen`, `procurement/purchase_order_detail_screen`, `procurement/purchase_order_form_screen`, `settings/printer_settings_screen`, `settings/subscription_card`, `settings/user_form_screen`.

Setelah semua layar selesai (perintah audit di bawah mengembalikan 0 baris di `lib/features`), ganti `themeMode` di `main.dart` menjadi `ThemeMode.system`.

**Pratinjau struk** (`receipt_screen`) sebaiknya tetap putih di mode gelap, karena menggambarkan kertas cetak. Gunakan `AppColors.surface` / `AppColors.ink` secara sengaja di bagian itu.

## Audit warna hardcoded

Jalankan dari root proyek (Git Bash):

```bash
# Warna hex di luar core/constants (harus 0)
grep -rnE "Color\(0x" lib --include=*.dart | grep -v core/constants

# Colors.* bawaan Material (bukan AppColors)
grep -rnP "(?<![A-Za-z])Colors\.\w+" lib --include=*.dart | grep -v core/constants

# Sisa AppColors per file (progres migrasi mode gelap)
for f in lib/features/*/*.dart; do n=$(grep -o "AppColors\." "$f" | wc -l); [ "$n" -gt 0 ] && echo "$n $f"; done | sort -rn
```

## Uji setelah ganti tema

Fokus pada layar kasir, karena kesalahan di sini langsung berdampak ke transaksi:

- [ ] Grid katalog: foto tampil penuh, nama 2 baris tidak terpotong aneh, harga dan stok terbaca. Cek di HP kecil (2 kolom) dan tablet.
- [ ] Produk tanpa foto dan produk dengan URL foto rusak menampilkan ikon placeholder.
- [ ] Produk stok habis: foto redup, teks "Stok habis" merah, tap memunculkan SnackBar.
- [ ] Tombol Bayar (`cart_panel`) dan Selesaikan Pembayaran (`checkout_screen`) berwarna cokelat dengan teks putih, dan spinner saat memproses terlihat.
- [ ] Input fokus bergaris oranye, label terbaca.
- [ ] Chip level harga terpilih berbeda jelas dari yang tidak.
- [ ] Status pending (kuning tua) tidak tertukar dengan tombol utama (oranye).
- [ ] Alur transaksi lengkap (tambah ke keranjang → bayar → cetak struk) tetap berjalan sama seperti sebelumnya.
- [ ] Layar dibaca di bawah cahaya terang / layar dengan kecerahan rendah.
