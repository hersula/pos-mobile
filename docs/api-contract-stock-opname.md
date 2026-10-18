# API Contract: Stock Opname (pos-backend)

Versi dokumen: 1.0 (2026-10-18). Konvensi umum (base URL `{host}/api`, Bearer JWT, format error `{message, code?, errors?/details?}`, pagination `page/pageSize`, `tenantId` dari JWT) sama dengan bagian 0 dokumen konsinyasi di atas/di `docs/api-contract.md`. Angka Decimal (uang) dikirim sebagai angka JSON.

## 1. Konsep & aturan
- Sesi opname = satu gudang (`Warehouse.type = STORE`; gudang CONSIGNMENT ditolak 400 `code: "CONSIGNMENT_WAREHOUSE"`), opsional difilter satu kategori.
- Saat dibuat, sistem membuat **snapshot**: satu item per produk **aktif** milik tenant (di kategori filter bila ada), `systemQty` = stok gudang saat itu (0 bila belum ada baris stok), `unitCost` = `Product.costPrice` saat itu. Semua qty dalam **satuan dasar** produk.
- **Satu DRAFT per gudang**: membuat sesi saat gudang sudah punya DRAFT => 409 `DRAFT_EXISTS` dengan `details: { opnameId, opnameNo }`. Dicek di dalam transaksi setelah baris gudang dikunci (`FOR UPDATE`), aman terhadap request paralel. Batalkan/finalisasi DRAFT lama dulu.
- Status: `DRAFT -> COMPLETED` atau `DRAFT -> CANCELLED`. Hanya `DRAFT` yang bisa diubah; status lain => 409 `INVALID_STATUS`.
- Item: `countedQty` null = belum dihitung. `diff = countedQty - systemQty` (positif = lebih, negatif = kurang), `diffValue = diff x unitCost`. Item yang belum dihitung **tidak** disentuh saat finalisasi.
- **Stok berubah sejak snapshot (penjualan/pembelian saat penghitungan)**: finalisasi menerapkan **selisih relatif** (`diff`) ke stok saat ini, bukan menimpa stok dengan `countedQty`. Jadi transaksi yang terjadi setelah snapshot tidak hilang. Stok akhir = `stok saat finalisasi + diff`. Tiap item menyimpan `stockBeforeFinalize` (stok riil sebelum finalisasi) dan `appliedDiff`; detail menandai `stockChanged = true` bila stok saat ini != `systemQty`. Saran: lakukan penghitungan saat tidak ada transaksi di gudang itu.
- Jika `stok saat ini + diff < 0` untuk sebuah item: finalisasi **ditolak seluruhnya** 409 `code: "STOCK_CONFLICT"` dengan `details.items[]` (tanpa perubahan apa pun). Klien boleh mengulang dengan `clampToZero: true`: item tersebut dikoreksi sampai stok tepat 0 (`appliedDiff` lebih kecil dari `diff`).
- Finalisasi atomik dalam satu transaksi DB: per item `diff != 0` dibuat `StockMovement` `type = ADJUSTMENT`, `referenceType = "STOCK_OPNAME"`, `referenceId = <opname id>`, `qty = |appliedDiff|`, serta `Stock` diperbarui. Sesi diberi `COMPLETED`, `completedAt`, `completedById`. Pemanggilan ulang => 409 (tidak ada penyesuaian ganda). Tidak ada jurnal akuntansi (MVP).
- Finalisasi minimal butuh 1 item yang sudah dihitung, jika tidak 400 `code: "NO_COUNTED_ITEMS"`.

## 2. Hak akses
| Aksi | Role |
|---|---|
| GET list/detail | semua role tenant |
| POST create, finalize, cancel | OWNER, MANAGER |
| PATCH hitungan item | OWNER, MANAGER, GUDANG, KASIR |
Role lain / tidak berwenang => 403. Sesi milik tenant lain => 404.

## 3. Objek
### StockOpname (header + summary)
```json
{
  "id": "uuid", "opnameNo": "OPN-20261018-0001", "status": "DRAFT|COMPLETED|CANCELLED",
  "warehouseId": "uuid", "warehouse": { "id": "uuid", "name": "Gudang Utama" },
  "categoryId": "uuid|null", "categoryName": "string|null", "note": "string|null", "cancelReason": "string|null",
  "createdById": "uuid", "createdByName": "string|null", "completedById": "uuid|null", "completedAt": "ISO|null",
  "createdAt": "ISO", "updatedAt": "ISO",
  "summary": { "totalItems": 120, "countedItems": 45, "surplusQty": 6, "shortageQty": 9,
               "surplusValue": 60000, "shortageValue": 90000, "netValue": -30000 }
}
```
`shortage*` dikirim sebagai angka positif; pada sesi `COMPLETED`, item yang di-clamp dihitung memakai `appliedDiff` (bukan `diff`); `netValue = surplusValue - shortageValue`.
### StockOpnameItem
```json
{ "id": "uuid", "productId": "uuid",
  "product": { "id": "uuid", "name": "Kopi", "sku": "KP01|null", "barcode": "899...|null", "unit": "pcs" },
  "categoryName": "Minuman|null", "systemQty": 10, "countedQty": 8, "diff": -2, "unitCost": 10000, "diffValue": -20000,
  "currentQty": 10, "stockChanged": false,
  "stockBeforeFinalize": null, "appliedDiff": null,
  "countedAt": "ISO|null", "countedById": "uuid|null" }
```
`currentQty`/`stockChanged` hanya diisi untuk sesi `DRAFT` (saat COMPLETED/CANCELLED: `currentQty: null`, `stockChanged: false`).

## 4. Endpoint
### GET `/api/stock-opnames`
Query: `status` (DRAFT|COMPLETED|CANCELLED, lainnya 400), `warehouseId`, `page`, `pageSize`. Urut `createdAt` desc. Respons 200: `{ "data": [StockOpname], "pagination": {...} }` (tanpa items).
### POST `/api/stock-opnames` (OWNER, MANAGER)
Body: `{ "warehouseId": "uuid" (wajib), "categoryId": "uuid" (opsional), "note": "string<=500" (opsional) }`.
201: `{ "message": "Sesi opname dibuat", "data": StockOpname + items[] }`.
Error: 409 `DRAFT_EXISTS` (`details.opnameId`); 400 validasi / `CONSIGNMENT_WAREHOUSE` / `NO_PRODUCTS` (tidak ada produk untuk disnapshot); 404 gudang/kategori tidak ditemukan.
### GET `/api/stock-opnames/{id}`
200: `{ "data": StockOpname + "items": [StockOpnameItem] }` (urut nama produk). 404.
### PATCH `/api/stock-opnames/{id}/items` (OWNER, MANAGER, GUDANG, KASIR)
Batch update hitungan, hanya `DRAFT`. Body: `{ "items": [ { "itemId": "uuid", "countedQty": 8 } ] }`; 1-500 elemen; `countedQty` integer 0..2.000.000.000 atau `null` (menghapus hitungan); `itemId` tidak boleh duplikat. Semua atau tidak sama sekali (transaksi). 200: `{ "message": "Hitungan disimpan", "data": StockOpname (header+summary), "items": [StockOpnameItem yang diubah] }`.
Error: 400 validasi; 404 bila ada `itemId` yang bukan milik sesi/tenant ini; 409 `INVALID_STATUS`.
### POST `/api/stock-opnames/{id}/finalize` (OWNER, MANAGER)
Body (opsional): `{ "clampToZero": false }`. 200: `{ "message": "Stok opname difinalisasi", "data": StockOpname + items[], "result": { "adjustedItems": 7, "unchangedItems": 38, "uncountedItems": 75, "clampedItems": 0 } }`. `unchangedItems` = item terhitung dengan selisih 0 (item yang di-clamp, termasuk yang stoknya sudah 0, masuk `clampedItems`, bukan `unchangedItems`); `adjustedItems` = item yang stoknya benar-benar berubah (`appliedDiff != 0`).
Error: 400 `NO_COUNTED_ITEMS`; 409 `INVALID_STATUS`; 409 `STOCK_CONFLICT` (juga bila stok terkuras oleh transaksi lain saat penulisan; tidak pernah 400 `INSUFFICIENT_STOCK`; baris stok dikunci selama finalisasi; UI dapat menawarkan `clampToZero`) (`details.items: [{ itemId, productId, productName, currentQty, diff }]`).
### POST `/api/stock-opnames/{id}/cancel` (OWNER, MANAGER)
Body: `{ "reason": "string 3..500" }` wajib. Hanya `DRAFT`; tidak mengubah stok. 200: `{ "message": "Sesi opname dibatalkan", "data": StockOpname + items[] }`. 409 `INVALID_STATUS`.

## 5. Skema database (additive)
| Tabel | Kolom |
|---|---|
| `stock_opnames` | id, tenant_id (FK), opname_no (unik per tenant, format `OPN-YYYYMMDD-NNNN`), warehouse_id (FK), category_id NULL, status ENUM(DRAFT,COMPLETED,CANCELLED), note TEXT, cancel_reason TEXT, created_by_id, completed_by_id NULL, completed_at NULL, created_at, updated_at; index (tenant_id,status), (tenant_id,warehouse_id) |
| `stock_opname_items` | id, stock_opname_id (FK cascade), product_id (FK), system_qty INT, counted_qty INT NULL, diff INT, unit_cost DECIMAL(14,2), diff_value DECIMAL(16,2), stock_before_finalize INT NULL, applied_diff INT NULL, counted_at NULL, counted_by_id NULL; unik (stock_opname_id, product_id); index product_id |
| `stock_movements` | tidak berubah; memakai `type = ADJUSTMENT`, `reference_type = 'STOCK_OPNAME'` |

Migrasi: `prisma/migrations/20261018000000_add_stock_opname/migration.sql` (hanya CREATE TABLE / FK).
