# Spesifikasi UI: Modul Stock Opname

Mengikuti gaya Q-Pos yang ada: `AppTheme` (Material 3, font Mulish isi / Archivo judul), `AppColors`, pola layar konsinyasi (chip filter, kartu, FAB extended, `Coba Lagi`). Tidak ada token baru: semua warna dari `AppColors`. Wireframe: `design/stock-opname/wireframe/*.html` (buka langsung di browser; CSS variables memetakan `AppColors`).

## 1. Persona dan alur
- **Manager/Owner (Budi)**: membuat sesi, menyetujui (finalisasi), membatalkan.
- **Staf gudang/Kasir (Dewi)**: menghitung fisik pada sesi Draft (bila diizinkan), tidak membuat/finalisasi.

Alur utama: Inventori -> ikon Stock Opname -> Daftar Sesi -> FAB `+ Sesi Opname` -> Buat Sesi -> (otomatis) Layar Hitung -> isi qty/scan -> `Simpan Draft` -> `Review Selisih` -> `Finalisasi & Sesuaikan Stok` -> konfirmasi -> Detail Sesi (SELESAI).
Alur sekunder: kartu Draft -> Hitung; kartu SELESAI/BATAL -> Detail; Detail Draft -> `Batalkan Sesi`.

## 2. Titik masuk (00-entri-inventori)
AppBar `ProductListScreen`: tambah `IconButton` `Icons.fact_check_outlined`, tooltip/Semantics "Stock Opname", ditempatkan setelah Konsinyasi dan sebelum Muat ulang. Terlihat untuk semua role (seperti Konsinyasi); aksi tulis dibatasi di dalam layar. Navigasi `MaterialPageRoute` ke `StockOpnameListScreen`. Layar sempit (<360dp): pindahkan ikon Kategori/Level Harga/Pengadaan ke menu overflow.

## 3. Layar
Semua layar: AppBar putih (judul Archivo 19/800), body `AppColors.paper`, padding horizontal 16, jarak antar kartu 8, `SafeArea`, bar aksi bawah putih dengan border atas `line`.

### 3.1 Daftar Sesi (01)
- Tujuan: riwayat sesi + akses cepat ke Draft.
- Komponen: search field (hint "Cari nomor sesi atau gudang..."), chip status `Semua | Draft | Selesai | Batal` (tinggi hit 44, scroll horizontal), kartu sesi, FAB extended `+ Sesi Opname` (hanya OWNER/MANAGER), pull-to-refresh, infinite scroll (muat lagi saat sisa <200px, spinner kecil di akhir).
- Kartu (min tinggi 72): kiri = nomor sesi (w700), subjudul `Gudang · Kategori/Semua kategori · tanggal` (12, muted); kanan = nilai (13/w700) + label status (10.5/w700). Nilai kanan: DRAFT = "N selisih" (atau "Belum dihitung"), SELESAI = nilai selisih bersih Rp (tanda +/-), BATAL = "-".
- Warna status: DRAFT `pending`, SELESAI `success`, BATAL `muted`. Chip aktif: warna status, latar 12% opasitas, border warna status (chip Semua = `accent`).
- State: loading (4 skeleton), kosong, kosong-karena-filter, error + `Coba Lagi`, tanpa izin tulis (FAB hilang + banner info), sukses (daftar).

### 3.2 Buat Sesi (02)
- Field: Gudang * (dropdown; terisi otomatis bila hanya 1), Kategori (opsional, default "Semua kategori"), Catatan (opsional, maks 200).
- Banner info: snapshot stok saat dibuat.
- Bar bawah: `Batal` (outlined) + `Buat & Mulai Hitung` (primary; nonaktif sampai gudang dipilih; label "Membuat..." saat submit dan form dikunci).
- Sukses: `pushReplacement` ke Layar Hitung sesi baru.
- Error: field wajib (inline merah 12), 409 sesi Draft sudah ada untuk gudang itu (banner `danger` + tombol `Buka Sesi Draft`), kategori tanpa produk, jaringan.

### 3.3 Hitung (03)
- AppBar: judul nomor sesi, aksi `Scan barcode` (`qr_code_scanner`) dan menu overflow (Review Selisih, Batalkan Sesi bila berhak).
- Header: search (nama/SKU/barcode, filter lokal), teks progres "28 / 64 sudah dihitung" + progress bar 6px (`accent` di atas `line`), chip `Semua | Belum dihitung | Selisih`.
- Baris produk (kartu radius 12, padding 12x16): nama (w700), "SKU · satuan" (12 muted), kanan "Stok sistem" + angka (snapshot, read-only). Di bawah: stepper `-` [input qty] `+` (tombol 48x48, input lebar 96, angka tengah w700 16, `keyboardType` desimal bila satuan boleh pecahan) dan tag selisih real-time di kanan.
- Tag selisih: `Belum` (pending-soft), `Cocok` (accent-soft), `+N lebih` (info-soft/info), `-N kurang` (danger-soft/danger).
- Aturan: qty kosong = belum dihitung (BUKAN 0); mengisi 0 = dihitung nol. `-` tidak turun di bawah 0. Tap `+`/`-` pada kolom kosong mulai dari 0 lalu +1.
- Scan: kamera penuh dengan bingkai 260x160; hasil -> tutup kamera, scroll ke baris produk, fokus input qty (bukan auto-tambah). Beep/getar singkat. Barcode asing -> banner `danger` "Barcode ... tidak ada di sesi ini".
- Simpan: bar bawah `Simpan Draft` (outlined) dan `Review Selisih` (primary; menyimpan draft dulu lalu pindah). Snackbar "Draft tersimpan". Tombol Kembali dengan perubahan belum disimpan -> dialog "Simpan hitungan?" (`Buang` / `Simpan Draft`).
- State: loading, error muat (hitungan lokal aman), error simpan (banner, input tetap), pencarian kosong, sukses.
- Hanya status DRAFT; sesi lain diarahkan ke Detail.

### 3.4 Review Selisih (04)
- Ringkasan 3 kotak: Lebih (+Rp, `info`), Kurang (-Rp, `danger`), Selisih bersih (warna sesuai tanda; 0 = `muted`).
- Chip `Semua selisih | Lebih | Kurang`. Baris: nama, selisih qty besar kanan (+2 / -3), "Sistem X · Fisik Y · Nilai Rp". Produk cocok disembunyikan (catatan "61 produk cocok tidak ditampilkan").
- Nilai selisih = selisih qty x harga pokok produk (field backend; lihat permintaan).
- Banner `pending` bila ada produk belum dihitung (tidak diubah saat finalisasi).
- Tombol bawah `Finalisasi & Sesuaikan Stok` (OWNER/MANAGER) -> bottom sheet konfirmasi: jumlah produk, selisih bersih, peringatan tak dapat diubah; `Kembali` + `Ya, Finalisasi` (warna `danger` karena irreversibel). Proses: tombol "Memproses...", back diblokir. Sukses: snackbar + `pushReplacement` ke Detail. Gagal: banner `danger`, sesi tetap Draft.
- State: ada selisih, belum dihitung, tidak ada selisih ("Semua stok cocok"), memproses, sukses, error, tanpa izin (pesan menggantikan tombol).
- Catatan warna: `ember` TIDAK dipakai (khusus pembayaran).

### 3.5 Detail Sesi (05)
- Read-only. Kartu header: gudang + status; baris meta (kategori, dibuat oleh/waktu, difinalisasi oleh/waktu, catatan). Ringkasan 3 kotak (Dihitung, Selisih, Nilai selisih). Daftar baris seperti Review (semua produk selisih; produk cocok dapat dilihat lewat chip `Semua`).
- SELESAI: tanpa tombol. BATAL: tampilkan pembatal + alasan, angka berwarna `muted`. DRAFT: bar `Batalkan Sesi` (outlined teks `danger`, hanya OWNER/MANAGER) + `Lanjut Hitung`. Batalkan -> dialog dengan alasan opsional.
- State: loading, error/404 + `Coba Lagi`, sukses.

## 4. Komponen
| Komponen | Spesifikasi |
|---|---|
| Chip status | tinggi hit >=44, radius 20, padding 14, teks 12.5/w600; `Semantics(button, selected)` |
| Kartu sesi / baris | `Card` tema (radius 12, border `line`, tanpa elevasi) |
| Tag selisih | radius 6, padding 2x6, teks 11/w700, pasangan warna soft + solid |
| Kotak ringkasan | radius 12, border `line`, label 11 muted, nilai 15/w800 |
| Stepper qty | tombol 48x48 radius 10 border `line` 1.4; input 48 tinggi |
| Banner | radius 10, padding 10x12, teks 12.5; info/pending/danger (soft + solid) |
| Bottom sheet/dialog | radius atas 16, judul Archivo 17; aksi sejajar, primer di kanan |
| Skeleton | tinggi 72 radius 12, shimmer 1.2s (nonaktif bila reduce-motion) |

## 5. Responsif dan aksesibilitas
- Mobile-first, lebar acuan 375dp. <360dp: ikon overflow, stepper tetap 48. >=600dp (tablet): daftar dan konten maksimal 640dp di tengah; Layar Hitung boleh 2 kolom kartu.
- Target sentuh >=48 (minimum 44). Kontras teks >= AA (muted `#68776B` di atas putih ~4.6:1; jangan dipakai di atas `paper` untuk teks <12).
- Selisih tidak hanya warna: selalu ada tanda +/- dan kata "lebih/kurang". Status selalu berupa teks.
- Setiap input punya label/hint dan `Semantics`; urutan fokus: pencarian -> scan -> chip -> baris (qty tiap baris) -> bar bawah. Keyboard numeric `done` memindahkan fokus ke qty baris berikut. Fokus terlihat: border `accent` 1.6.

## 6. Copywriting
Judul: "Stock Opname", "Buat Sesi Opname", "Review Selisih". Tombol: "Buat & Mulai Hitung", "Simpan Draft", "Review Selisih", "Finalisasi & Sesuaikan Stok", "Ya, Finalisasi", "Batalkan Sesi", "Ya, Batalkan", "Lanjut Hitung", "Coba Lagi".
Kosong: "Belum ada sesi opname" / "Buat sesi untuk mencocokkan stok sistem dengan hitungan fisik di gudang." Error: "Gagal memuat sesi opname" / "Periksa koneksi internet Anda, lalu coba lagi." Konfirmasi: "Stok sistem akan dikoreksi dan dicatat sebagai penyesuaian. Sesi tidak dapat diubah lagi." Sukses: "Opname selesai. Stok disesuaikan untuk N produk."

## 7. Field data yang dibutuhkan (untuk kontrak API)
Sesi: id, sessionNo, status (DRAFT|COMPLETED|CANCELLED; UI: Draft/Selesai/Batal), warehouseId/Name, categoryId/Name?, note, createdAt/By, finalizedAt/By, cancelledAt/By/reason, summary {totalItems, countedItems, diffItems, valuePositive, valueNegative, valueNet}. Item: id, productId, name, sku, barcode, unit, systemQty (snapshot), countedQty (nullable), diffQty, unitCost, diffValue.
