# Panduan Pengguna: Stock Opname

Stock Opname dipakai untuk **mencocokkan stok sistem dengan hitungan fisik** di gudang. Setelah selisih disetujui, stok dikoreksi otomatis dan tercatat sebagai penyesuaian (`ADJUSTMENT`).

Panduan ini untuk aplikasi Q-Pos (Flutter). Referensi API: `pos-backend/docs/api-contract.md` (bagian Stock Opname) dan `docs/api-contract-stock-opname.md`.

> **Status:** alur di bawah sesuai kode mobile dan kontrak API. Kode mobile **belum pernah dikompilasi atau dijalankan** (Flutter SDK tidak ada saat pengembangan) dan backend belum diuji terhadap database nyata. Lihat "Batasan saat ini".

---

## 1. Siapa boleh apa

| Aksi | OWNER | MANAGER | GUDANG | KASIR | AKUNTAN |
|---|:---:|:---:|:---:|:---:|:---:|
| Melihat daftar dan detail sesi | ya | ya | ya | ya | ya |
| Buat sesi | ya | ya | - | - | - |
| Isi dan simpan hitungan (sesi Draft) | ya | ya | ya | ya | - |
| Finalisasi | ya | ya | - | - | - |
| Batalkan sesi | ya | ya | - | - | - |

Role tanpa izin tidak melihat tombol terkait: tombol **+ Sesi Opname** diganti banner info, dan di Review Selisih tombol finalisasi diganti pesan "Hanya Owner/Manager yang dapat melakukan finalisasi."

## 2. Membuka menu Stock Opname

1. Buka tab **Inventori**.
2. Tekan ikon **fact check** (`fact_check_outlined`, tooltip "Stock Opname") di AppBar, setelah ikon Konsinyasi.
3. Daftar sesi terbuka.

Di daftar:
- **Chip status** menyaring: Semua, Draft, Selesai, Batal.
- **Kolom cari** mencari nomor sesi atau gudang, hanya pada data yang sudah termuat.
- **Tarik ke bawah** untuk muat ulang; **gulir ke bawah** untuk memuat data berikutnya.
- Kartu **Draft** membuka Layar Hitung. Kartu **Selesai** dan **Batal** membuka Detail.

## 3. Alur status

```
Draft ──finalisasi──▶ Selesai
  │
  └────batalkan────▶ Batal
```

| Status | Arti | Stok |
|---|---|---|
| Draft | Sesi dibuat, hitungan boleh diubah | Belum berubah |
| Selesai | Selisih sudah diterapkan, sesi terkunci | Dikoreksi |
| Batal | Sesi dibatalkan | Tidak berubah |

Hanya sesi **Draft** yang dapat diubah. Hanya satu Draft yang boleh ada per gudang.

## 4. Membuat sesi (OWNER, MANAGER)

1. Di daftar, tekan **+ Sesi Opname**.
2. Pilih **Gudang** (wajib). Hanya gudang toko yang muncul. Bila hanya ada satu gudang, terisi otomatis.
3. Pilih **Kategori** (opsional). Kosong = **Semua kategori**.
4. Isi **Catatan** (opsional, maksimal 200 karakter).
5. Tekan **Buat & Mulai Hitung**.

Saat sesi dibuat, sistem mengambil **snapshot**: satu baris per produk aktif (di kategori terpilih bila ada), dengan **stok sistem** saat itu dan harga pokok saat itu. Layar Hitung terbuka otomatis.

## 5. Menghitung

Buka dari kartu Draft, atau otomatis setelah membuat sesi. Role yang boleh menghitung: OWNER, MANAGER, GUDANG, KASIR.

1. Tiap baris menampilkan nama, SKU, satuan, dan **Stok sistem** (snapshot, tidak bisa diubah).
2. Isi jumlah fisik dengan kolom angka, atau tombol **+** dan **-**. Hanya bilangan bulat.
3. Perhatikan tag di kanan baris:
   - **Belum**: kolom kosong.
   - **Cocok**: fisik sama dengan sistem.
   - **+N lebih** atau **-N kurang**: ada selisih.
4. Gunakan chip **Semua**, **Belum dihitung**, **Selisih** dan kolom cari (nama, SKU, barcode) untuk menyaring. Bar progres menunjukkan "N / total sudah dihitung".
5. Tekan **Simpan Draft**. Muncul "Draft tersimpan".

Aturan penting:
- **Kolom kosong = belum dihitung**, bukan 0. Isi **0** bila memang tidak ada barang di rak.
- Produk yang belum dihitung **tidak diubah** saat finalisasi.
- Nilai tidak bisa kurang dari 0 dan maksimal 2.000.000.000.
- Bila menekan Kembali dengan perubahan belum tersimpan, muncul dialog "Simpan hitungan?" (**Buang** atau **Simpan Draft**).
- Bila simpan gagal, input di layar tetap aman. Perbaiki lalu coba lagi. Bila ada nilai tidak valid, pesan menyebut nama produknya jika server memberi tahu.

### Scan barcode
1. Tekan ikon **Scan barcode** di AppBar.
2. Arahkan kamera ke barcode. Hasilnya menutup kamera, menggulir ke baris produk, dan memindahkan fokus ke kolom jumlah. Scan **tidak** menambah jumlah otomatis; ketik jumlahnya.
3. Barcode yang tidak ada di sesi menampilkan "Barcode ... tidak ada di sesi ini".

## 6. Review selisih

1. Di Layar Hitung, tekan **Review Selisih** (menyimpan draft dulu).
2. Tiga kotak ringkasan: **Lebih**, **Kurang**, **Selisih bersih** (dalam Rupiah, berdasarkan harga pokok).
3. Chip **Semua selisih**, **Lebih**, **Kurang**. Produk yang cocok tidak ditampilkan.
4. Banner kuning muncul bila masih ada produk belum dihitung. Banner info muncul bila stok sebagian produk berubah sejak snapshot (ada penjualan atau pembelian saat menghitung).

Disarankan menghitung saat tidak ada transaksi di gudang itu.

## 7. Finalisasi (OWNER, MANAGER)

1. Di Review Selisih, tekan **Finalisasi & Sesuaikan Stok**.
2. Lembar konfirmasi menampilkan selisih bersih dan peringatan "Stok sistem akan dikoreksi dan dicatat sebagai penyesuaian. Sesi tidak dapat diubah lagi."
3. Tekan **Ya, Finalisasi**. Tombol berubah menjadi "Memproses..." dan tombol kembali diblokir.
4. Sukses: "Opname selesai. Stok disesuaikan untuk N produk." Layar pindah ke Detail dengan status Selesai.

Cara kerja koreksi: sistem menerapkan **selisih** (fisik dikurangi stok sistem saat snapshot) ke stok **saat finalisasi**, bukan menimpa stok. Penjualan yang terjadi setelah snapshot tidak hilang. Contoh: snapshot 10, fisik 8 (selisih -2), lalu terjual 1 sehingga stok jadi 9. Setelah finalisasi stok = 9 - 2 = 7.

Finalisasi gagal bila belum ada satu pun produk yang dihitung ("Belum ada produk yang dihitung. Isi minimal satu hitungan."). Sesi tetap Draft.

## 8. Membatalkan sesi (OWNER, MANAGER)

1. Buka sesi Draft: dari menu overflow Layar Hitung, atau tombol **Batalkan Sesi** di Detail.
2. Isi alasan di dialog, lalu **Ya, Batalkan**. Backend mewajibkan alasan 3 sampai 500 karakter; bila dikosongkan, aplikasi mengirim "Dibatalkan oleh pengguna".
3. Stok tidak berubah. Sesi menjadi Batal dan tidak bisa dibuka lagi. Gudang boleh membuat sesi baru.

## 9. Melihat detail

Detail bersifat baca saja: gudang, status, kategori, catatan, ringkasan (Dihitung, Selisih, Nilai selisih), dan daftar produk. Chip **Semua** menampilkan juga produk yang cocok. Sesi Batal menampilkan alasan pembatalan.

## 10. Pesan kesalahan umum

| Pesan / kondisi | Penyebab | Yang dilakukan |
|---|---|---|
| Banner merah saat membuat sesi, tombol **Buka Sesi Draft** (`DRAFT_EXISTS`, HTTP 409) | Gudang itu sudah punya sesi Draft | Tekan **Buka Sesi Draft** untuk melanjutkan, atau finalisasi/batalkan Draft lama dulu |
| Dialog **Stok berubah sejak snapshot** dengan tombol **Finalisasi, Tahan di 0** (`STOCK_CONFLICT`, HTTP 409) | Setelah selisih diterapkan, stok sebuah produk akan negatif (mis. sudah banyak terjual sejak snapshot). Tidak ada perubahan yang disimpan | Baca daftar produk. Pilih **Batal** untuk memeriksa ulang hitungan, atau **Finalisasi, Tahan di 0** agar produk itu dikoreksi sampai stok tepat 0 |
| "Belum ada produk yang dihitung" (`NO_COUNTED_ITEMS`) | Semua baris masih kosong | Isi minimal satu hitungan |
| "Sesi sudah tidak berstatus Draft." (`INVALID_STATUS`) | Sesi sudah selesai atau dibatalkan (mis. oleh pengguna lain) | Muat ulang daftar |
| Gagal memuat / "Periksa koneksi internet Anda" | Jaringan atau server | Tekan **Coba Lagi**. Hitungan lokal tidak hilang |
| Gudang tidak bisa dipilih | Hanya gudang toko; gudang konsinyasi ditolak | Pilih gudang toko |
| 403 | Role tidak berizin | Minta OWNER atau MANAGER |

Pada **Tahan di 0**, penyesuaian untuk produk itu lebih kecil dari selisih hitungan, sehingga stok akhir 0, bukan negatif. Hasilnya tercatat di jumlah "clamped" pada respons finalisasi.

## 11. Batasan saat ini

- Kode mobile belum dikompilasi dan diuji di perangkat. Hasil QC putaran 1 ada di `docs/handoff/docs.md`.
- Pencarian daftar sesi hanya pada data yang sudah dimuat.
- Kartu dan detail belum menampilkan nama kategori (kartu menulis "Semua kategori"/"Satu kategori") dan nama pembuat/pembatal.
- Jumlah hanya bilangan bulat dalam satuan dasar produk.
- Tidak ada bunyi beep saat scan (hanya getar). Tata letak 2 kolom tablet belum ada.
- Tidak ada jurnal akuntansi untuk selisih, dan tidak ada ekspor PDF/Excel.
- Migrasi backend `20261018000000_add_stock_opname` harus diterapkan lebih dulu.
