import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../../state/cart_provider.dart';
import 'cart_screen.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _productRepo = ProductRepository();
  final _searchCtrl = TextEditingController();
  List<Product> _products = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
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

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Kasir')),
      body: SafeArea(
        child: Column(
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
            Expanded(child: _buildGrid()),
          ],
        ),
      ),
      bottomNavigationBar: cart.isEmpty
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

    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.82,
        ),
        itemCount: _products.length,
        itemBuilder: (context, i) => _ProductCard(product: _products[i]),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final outOfStock = product.totalStock <= 0;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: outOfStock
          ? () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Stok produk ini habis')),
              )
          : () {
              context.read<CartProvider>().addProduct(product);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${product.name} ditambahkan'), duration: const Duration(milliseconds: 700)),
              );
            },
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
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.inventory_2_outlined, color: AppColors.muted.withOpacity(0.5), size: 30),
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
            Text(CurrencyFormatter.format(product.sellPrice), style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 13)),
            Text(
              outOfStock ? 'Stok habis' : 'Stok: ${product.totalStock}',
              style: TextStyle(fontSize: 11, color: outOfStock ? AppColors.danger : AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
