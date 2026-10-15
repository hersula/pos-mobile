import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/cart_item.dart';
import '../../data/models/customer.dart';
import '../../data/repositories/customer_repository.dart';
import '../../state/cart_provider.dart';
import 'checkout_screen.dart';

/// Isi keranjang: daftar item, pelanggan, diskon/PPN, catatan, ringkasan, dan
/// tombol lanjut bayar. Dipakai sebagai halaman penuh lewat [CartScreen] (HP)
/// maupun ditempel langsung sebagai panel sisi kanan di layar Kasir (tablet).
class CartPanel extends StatefulWidget {
  /// Tampilkan header "Keranjang" + tombol "Kosongkan" bawaan panel ini.
  /// Dimatikan saat dipakai dari [CartScreen] karena sudah ada di AppBar halaman itu.
  final bool showHeader;

  const CartPanel({super.key, this.showHeader = true});

  @override
  State<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends State<CartPanel> {
  final _customerRepo = CustomerRepository();
  late final TextEditingController _discountCtrl;
  late final TextEditingController _taxCtrl;

  @override
  void initState() {
    super.initState();
    final cart = context.read<CartProvider>();
    _discountCtrl = TextEditingController(text: cart.discountValue == 0 ? '' : cart.discountValue.toString());
    _taxCtrl = TextEditingController(text: cart.taxPercent.toString());
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    _taxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Column(
      children: [
        if (widget.showHeader)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Text('Keranjang', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      if (cart.activePriceLevel != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            cart.activePriceLevel!.name,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accent),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                TextButton(
                  onPressed: cart.isEmpty ? null : () => cart.clear(),
                  child: const Text('Kosongkan', style: TextStyle(color: AppColors.danger)),
                ),
              ],
            ),
          ),
        Expanded(
          child: cart.isEmpty
              ? const Center(child: Text('Keranjang masih kosong', style: TextStyle(color: AppColors.muted)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    ...cart.items.map((item) => _CartItemTile(item: item)),
                    const SizedBox(height: 20),
                    _buildCustomerPicker(cart),
                    const SizedBox(height: 16),
                    _buildDiscountAndTax(cart),
                    const SizedBox(height: 16),
                    _buildNote(cart),
                    const SizedBox(height: 20),
                    _buildSummary(cart),
                  ],
                ),
        ),
        if (!cart.isEmpty)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CheckoutScreen())),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.ember),
                child: Text('Lanjut ke Pembayaran · ${CurrencyFormatter.format(cart.grandTotal)}'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCustomerPicker(CartProvider cart) {
    return _SectionCard(
      title: 'Pelanggan (opsional)',
      child: Row(
        children: [
          Expanded(
            child: Text(
              cart.selectedCustomer?.name ?? 'Tanpa pelanggan',
              style: TextStyle(color: cart.selectedCustomer != null ? AppColors.text : AppColors.muted, fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(onPressed: () => _pickCustomer(cart), child: const Text('Pilih')),
          if (cart.selectedCustomer != null)
            IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => cart.setCustomer(null)),
        ],
      ),
    );
  }

  Future<void> _pickCustomer(CartProvider cart) async {
    final searchCtrl = TextEditingController();
    List<Customer> results = [];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> search(String q) async {
              final res = await _customerRepo.getCustomers(search: q);
              setModalState(() => results = res);
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
              child: SizedBox(
                height: 420,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Pilih Pelanggan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchCtrl,
                      decoration: const InputDecoration(hintText: 'Cari nama/nomor telepon'),
                      onChanged: search,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: results.isEmpty
                          ? const Center(child: Text('Ketik untuk mencari pelanggan', style: TextStyle(color: AppColors.muted)))
                          : ListView.builder(
                              itemCount: results.length,
                              itemBuilder: (_, i) => ListTile(
                                title: Text(results[i].name),
                                subtitle: Text(results[i].phone ?? '-'),
                                onTap: () {
                                  cart.setCustomer(results[i]);
                                  Navigator.pop(ctx);
                                },
                              ),
                            ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final created = await _showCreateCustomerDialog();
                        if (created != null) {
                          cart.setCustomer(created);
                          if (mounted) Navigator.pop(ctx);
                        }
                      },
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                      label: const Text('Tambah Pelanggan Baru'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<Customer?> _showCreateCustomerDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    return showDialog<Customer>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pelanggan Baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama')),
            const SizedBox(height: 10),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Telepon')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              try {
                final customer = await _customerRepo.createCustomer(name: nameCtrl.text.trim(), phone: phoneCtrl.text.trim());
                if (mounted) Navigator.pop(ctx, customer);
              } catch (_) {
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountAndTax(CartProvider cart) {
    return _SectionCard(
      title: 'Diskon & PPN',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _discountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Diskon'),
                  onChanged: (v) => cart.setDiscount(cart.discountType, num.tryParse(v) ?? 0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'NOMINAL', label: Text('Rp')),
                    ButtonSegment(value: 'PERCENT', label: Text('%')),
                  ],
                  selected: {cart.discountType},
                  onSelectionChanged: (s) => cart.setDiscount(s.first, cart.discountValue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Pakai PPN'),
            value: cart.useTax,
            onChanged: (v) => cart.setUseTax(v ?? false),
          ),
          TextField(
            controller: _taxCtrl,
            enabled: cart.useTax,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'PPN (%)'),
            onChanged: (v) => cart.setTaxPercent(num.tryParse(v) ?? 0),
          ),
        ],
      ),
    );
  }

  Widget _buildNote(CartProvider cart) {
    return _SectionCard(
      title: 'Catatan (opsional)',
      child: TextField(
        decoration: const InputDecoration(hintText: 'Contoh: bungkus terpisah'),
        onChanged: cart.setNote,
      ),
    );
  }

  Widget _buildSummary(CartProvider cart) {
    return _SectionCard(
      title: 'Ringkasan',
      child: Column(
        children: [
          _summaryRow('Subtotal', cart.subtotal),
          if (cart.discountAmount > 0) _summaryRow('Diskon', -cart.discountAmount),
          if (cart.taxAmount > 0) _summaryRow('PPN (${cart.taxPercent}%)', cart.taxAmount),
          const Divider(height: 20),
          _summaryRow('Total', cart.grandTotal, bold: true),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, num amount, {bool bold = false}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: bold ? 16 : 13.5);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: style.copyWith(color: bold ? AppColors.ink : AppColors.muted))),
          Text(CurrencyFormatter.format(amount), style: style),
        ],
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  const _CartItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.unit != null ? '${item.product.name} (${item.unitLabel})' : item.product.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${CurrencyFormatter.format(item.unitPrice)} / ${item.unitLabel}',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    _stepperButton(Icons.remove_rounded, () => cart.decrementQty(item.product.id, unitId: item.unit?.id)),
                    Container(
                      width: 32,
                      alignment: Alignment.center,
                      child: Text('${item.qty}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    _stepperButton(Icons.add_rounded, () => cart.incrementQty(item.product.id, unitId: item.unit?.id)),
                  ],
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 78,
                  child: Text(
                    CurrencyFormatter.format(item.subtotal),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.sell_outlined, size: 14, color: AppColors.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: item.discountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 12.5),
                    decoration: const InputDecoration(
                      isDense: true,
                      isCollapsed: true,
                      hintText: 'Diskon item (Rp)',
                      hintStyle: TextStyle(color: AppColors.muted, fontSize: 12.5),
                      border: InputBorder.none,
                    ),
                    onChanged: (v) => cart.updateItemDiscount(item.product.id, num.tryParse(v) ?? 0, unitId: item.unit?.id),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepperButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(20)),
        child: Icon(icon, size: 16),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
