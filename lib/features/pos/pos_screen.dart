import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_config.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/price_level.dart';
import '../../data/models/product.dart';
import '../../data/models/product_unit.dart';
import '../../data/repositories/product_repository.dart';
import '../../state/cart_provider.dart';
import '../common/barcode_scanner_screen.dart';
import 'cart_panel.dart';
import 'cart_screen.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _productRepo = ProductRepository();
  final _priceLevelRepo = PriceLevelRepository();
  final _searchCtrl = TextEditingController();
  List<Product> _products = [];
  List<PriceLevel> _priceLevels = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _loadPriceLevels();
  }

  Future<void> _loadPriceLevels() async {
    try {
      final levels = await _priceLevelRepo.getPriceLevels();
      if (mounted) setState(() => _priceLevels = levels);
    } catch (_) {
      // level harga gagal dimuat tidak fatal -- selector cuma tidak muncul, kasir tetap bisa jualan harga Umum
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await _productRepo.getProducts(search: _searchCtrl.text.trim());
      if (mounted) setState(() => _products = products);
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memuat produk');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scanAndAddProduct() async {
    final code = await scanBarcode(context, title: 'Scan Barcode Produk');
    if (code == null || !mounted) return;

    try {
      // Lookup khusus barcode: cocok dgn barcode satuan dasar ATAU barcode salah satu
      // satuan tambahan (mis. barcode kemasan "Dus") -> hasilnya selalu satu satuan yang
      // pasti, jadi langsung ditambahkan ke keranjang tanpa perlu tanya pilih satuan lagi.
      final result = await _productRepo.scanBarcode(code);
      if (!mounted) return;

      final matches = result.matchedUnitId == null
          ? <ProductUnit>[]
          : result.product.units.where((u) => u.id == result.matchedUnitId);
      _addToCart(result.product, unit: matches.isNotEmpty ? matches.first : null);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mencari produk berdasarkan barcode')),
        );
      }
    }
  }

  void _addToCart(Product product, {ProductUnit? unit}) {
    if (product.totalStock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stok ${product.name} habis'), backgroundColor: AppColors.danger),
      );
      return;
    }

    final cart = context.read<CartProvider>();
    // Level harga cuma berlaku utk satuan dasar (unit == null) -- satuan tambahan
    // (Dus dkk) selalu pakai harganya sendiri, tidak terpengaruh level yang aktif.
    final unitPriceOverride = unit == null ? product.priceForLevel(cart.activePriceLevel?.id) : null;
    cart.addProduct(product, unit: unit, unitPriceOverride: unitPriceOverride);
    final label = unit != null ? '${product.name} (${unit.name})' : product.name;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label ditambahkan'), duration: const Duration(milliseconds: 800)),
    );
  }

  // Sentinel utk baris "satuan dasar" di bottom sheet pilih satuan — perlu dibedakan dari
  // `null` yang dipakai showModalBottomSheet sendiri kalau sheet ditutup tanpa memilih apa pun
  // (tap di luar/tombol back), supaya batal tidak ikut nambah ke keranjang.
  static const Object _baseUnitChoice = Object();

  Future<void> _pickUnitAndAdd(Product product) async {
    final activeLevelId = context.read<CartProvider>().activePriceLevel?.id;
    final choice = await showModalBottomSheet<Object>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Pilih Satuan — ${product.name}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              ListTile(
                title: Text(product.unit),
                trailing: Text(CurrencyFormatter.format(product.priceForLevel(activeLevelId)), style: const TextStyle(fontWeight: FontWeight.w700)),
                onTap: () => Navigator.pop(ctx, _baseUnitChoice),
              ),
              ...product.units.map((u) => ListTile(
                    title: Text(u.name),
                    trailing: Text(CurrencyFormatter.format(u.sellPrice), style: const TextStyle(fontWeight: FontWeight.w700)),
                    onTap: () => Navigator.pop(ctx, u),
                  )),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (!mounted || choice == null) return; // sheet ditutup tanpa memilih -> batal
    _addToCart(product, unit: choice == _baseUnitChoice ? null : choice as ProductUnit);
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    // Layar lebar (tablet) tampilkan grid produk + panel keranjang/struk berdampingan,
    // alih-alih panel keranjang terpisah yang dibuka lewat tombol di bawah (perilaku HP).
    final isSplitView = MediaQuery.sizeOf(context).width >= Responsive.medium;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scan barcode',
            onPressed: _scanAndAddProduct,
          ),
        ],
      ),
      body: SafeArea(
        child: isSplitView ? _buildSplitView() : _buildProductColumn(),
      ),
      bottomNavigationBar: isSplitView || cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen())),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                            child: Text('${cart.totalQty}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 10),
                          const Text('Lihat Keranjang', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      Text(CurrencyFormatter.format(cart.grandTotal), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildProductColumn() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              hintText: 'Cari produk...',
              prefixIcon: Icon(Icons.search_rounded, size: 20),
              isDense: true,
            ),
            onChanged: (_) => _load(),
          ),
        ),
        if (_priceLevels.isNotEmpty) _buildPriceLevelSelector(),
        Expanded(child: _buildGrid()),
      ],
    );
  }

  Widget _buildPriceLevelSelector() {
    final cart = context.watch<CartProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SizedBox(
        height: 34,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _LevelChip(
              label: 'Umum',
              selected: cart.activePriceLevel == null,
              onTap: () => cart.setPriceLevel(null),
            ),
            ..._priceLevels.map((level) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _LevelChip(
                    label: level.name,
                    selected: cart.activePriceLevel?.id == level.id,
                    onTap: () => cart.setPriceLevel(level),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitView() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 3, child: _buildProductColumn()),
        Container(
          width: 400,
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: AppColors.line)),
          ),
          child: const CartPanel(),
        ),
      ],
    );
  }

  Widget _buildGrid() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: _load, child: const Text('Coba Lagi')),
          ],
        ),
      );
    }
    if (_products.isEmpty) {
      return const Center(child: Text('Tidak ada produk', style: TextStyle(color: AppColors.muted)));
    }

    final activeLevelId = context.watch<CartProvider>().activePriceLevel?.id;

    return RefreshIndicator(
      onRefresh: _load,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = Responsive.gridColumns(constraints.maxWidth);
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.82,
            ),
            itemCount: _products.length,
            itemBuilder: (context, i) {
              final product = _products[i];
              return _ProductCard(
                product: product,
                activeLevelId: activeLevelId,
                onTapAdd: () => _addToCart(product),
                onTapPickUnit: () => _pickUnitAndAdd(product),
              );
            },
          );
        },
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LevelChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withOpacity(0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.accent : AppColors.line),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: selected ? AppColors.accent : AppColors.muted),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final String? activeLevelId; // null = harga "Umum"
  final VoidCallback onTapAdd; // langsung add (satuan dasar saja)
  final VoidCallback onTapPickUnit; // ada >1 satuan -> tanya pilih dulu
  const _ProductCard({required this.product, this.activeLevelId, required this.onTapAdd, required this.onTapPickUnit});

  @override
  Widget build(BuildContext context) {
    final outOfStock = product.totalStock <= 0;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: outOfStock
          ? () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Stok produk ini habis')),
              )
          : (product.hasMultipleUnits ? onTapPickUnit : onTapAdd),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(8)),
                  child: _buildImage(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              CurrencyFormatter.format(product.priceForLevel(activeLevelId)),
              style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 13),
            ),
            Text(
              outOfStock ? 'Stok habis' : 'Stok: ${product.totalStock}',
              style: TextStyle(fontSize: 11, color: outOfStock ? AppColors.danger : AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    final url = AppConfig.resolveImageUrl(product.imageUrl);
    if (url == null) {
      return Icon(Icons.inventory_2_outlined, color: AppColors.muted.withOpacity(0.5), size: 30);
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          Icon(Icons.inventory_2_outlined, color: AppColors.muted.withOpacity(0.5), size: 30),
    );
  }
}
