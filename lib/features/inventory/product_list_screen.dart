import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/category.dart';
import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../../state/auth_provider.dart';
import '../procurement/purchase_order_list_screen.dart';
import 'product_form_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final _productRepo = ProductRepository();
  final _categoryRepo = CategoryRepository();
  final _searchCtrl = TextEditingController();

  List<Product> _products = [];
  List<Category> _categories = [];
  String? _selectedCategoryId;
  bool _lowStockOnly = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _categoryRepo.getCategories();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {
      // kategori gagal dimuat tidak fatal, filter kategori cuma tidak muncul
    }
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await _productRepo.getProducts(
        search: _searchCtrl.text.trim(),
        categoryId: _selectedCategoryId,
        lowStockOnly: _lowStockOnly,
      );
      if (mounted) setState(() => _products = products);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final canManage = user?.canManageInventory ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventori'),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.local_shipping_outlined),
              tooltip: 'Pengadaan Barang',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PurchaseOrderListScreen())),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadProducts,
          ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const ProductFormScreen()),
                );
                if (created == true) _loadProducts();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Produk'),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Cari nama produk, SKU, atau barcode...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                ),
                onSubmitted: (_) => _loadProducts(),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _FilterChip(
                    label: 'Semua',
                    selected: _selectedCategoryId == null && !_lowStockOnly,
                    onTap: () {
                      setState(() {
                        _selectedCategoryId = null;
                        _lowStockOnly = false;
                      });
                      _loadProducts();
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Stok Menipis',
                    selected: _lowStockOnly,
                    color: AppColors.pending,
                    onTap: () {
                      setState(() => _lowStockOnly = !_lowStockOnly);
                      _loadProducts();
                    },
                  ),
                  const SizedBox(width: 8),
                  ..._categories.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _FilterChip(
                        label: c.name,
                        selected: _selectedCategoryId == c.id,
                        onTap: () {
                          setState(() => _selectedCategoryId = _selectedCategoryId == c.id ? null : c.id);
                          _loadProducts();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildBody(canManage)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool canManage) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _loadProducts, child: const Text('Coba Lagi')),
            ],
          ),
        ),
      );
    }
    if (_products.isEmpty) {
      return const Center(child: Text('Tidak ada produk ditemukan', style: TextStyle(color: AppColors.muted)));
    }

    return RefreshIndicator(
      onRefresh: _loadProducts,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
        itemCount: _products.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final p = _products[i];
          return _ProductTile(
            product: p,
            onTap: canManage
                ? () async {
                    final updated = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(builder: (_) => ProductFormScreen(product: p)),
                    );
                    if (updated == true) _loadProducts();
                  }
                : null,
          );
        },
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;

  const _ProductTile({required this.product, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${product.categoryName ?? "Tanpa kategori"} · ${CurrencyFormatter.format(product.sellPrice)}',
          style: const TextStyle(fontSize: 12.5),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${product.totalStock} ${product.unit}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: product.isLowStock ? AppColors.danger : AppColors.ink,
              ),
            ),
            if (product.isLowStock)
              const Text('Stok menipis', style: TextStyle(color: AppColors.danger, fontSize: 10.5)),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({required this.label, required this.selected, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c : AppColors.line),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: selected ? c : AppColors.muted),
        ),
      ),
    );
  }
}
