# Plan: Modul Stock Opname

| # | Agent | Tugas | Bergantung | Model | Alasan |
|---|---|---|---|---|---|
| 1 | designer | Spec UI + wireframe layar opname (list, buat, hitung, review selisih, detail) di `design/stock-opname/` | - | sonnet | |
| 2 | backend | `docs/api-contract.md` bagian opname, model Prisma (StockOpname, StockOpnameItem), endpoint, finalisasi atomik via transaksi | - | sonnet | logika stok sensitif |
| 3 | frontend | Model, repository, provider, layar Flutter, entri di tab Inventori | 1,2 | sonnet | |
| 4 | qc | Uji backend (tsc/build, skenario selisih+/-), mobile (flutter analyze/test) | 2,3 | sonnet | |
| 5 | docs | Manual pengguna, referensi API, README, CHANGELOG di kedua repo | 4 | gemini-2.5-flash-lite | tugas ringan, hemat kuota |

Ketergantungan: 1 dan 2 paralel. Review rencana oleh analyst dilewati (mode hemat, fitur sedang).

## Status
- [x] 1 designer  - [x] 2 backend (bug QC diperbaiki)  - [x] 3 frontend  - [~] 4 QC (statis saja; belum diuji dinamis)  - [x] 5 docs (model docs: gemini gagal -> claude sonnet)

---
Rencana konsinyasi sebelumnya (selesai/arsip) ada di git history.
