# Plan: Fitur Penjualan Konsinyasi (pos-backend + pos-mobile)

Sumber rancangan: `C:\laragon\www\pos-backend\docs\analysis\consignment-fit.md` (tafsir A: barang kita dititipkan ke customer/outlet).

## Keputusan (diasumsikan, persetujuan pengguna: "langsung eksekusi bila tidak ada masalah")
- Tafsir A. Tafsir B (titipan supplier) = fase 2, tidak dikerjakan.
- Pencatatan barang terjual di outlet: hanya OWNER/MANAGER; KASIR hanya baca.
- Perubahan skema hanya additive.

## Tugas
| # | Agent | Tugas | Bergantung | Model |
|---|---|---|---|---|
| 1 | backend | Verifikasi [VERIFIKASI-BE] di kode; perbaiki bug conversionQty (retur/cancel) & jurnal piutang bila terbukti; tulis `docs/api-contract.md` konsinyasi; skema Prisma + endpoint; `GET /warehouses` default hanya STORE | - | sonnet |
| 2 | frontend | Layar/provider/service/model konsinyasi di mobile (tab Inventori), sesuai kontrak | 1 (kontrak) | sonnet |
| 3 | qc | Uji backend (tsc/build, skenario stok & jurnal) dan mobile (analyze) | 1,2 | sonnet |
| 4 | docs | Update dokumentasi | 3 | gemini-3.8-flash |

## Status
- [x] Analisis kelayakan
- [ ] 1 backend
- [ ] 2 mobile
- [ ] 3 QC
- [ ] 4 docs
