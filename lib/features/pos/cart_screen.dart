import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../state/cart_provider.dart';
import 'cart_panel.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keranjang'),
        actions: [
          TextButton(
            onPressed: () {
              cart.clear();
              Navigator.of(context).pop();
            },
            child: const Text('Kosongkan', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
      body: const SafeArea(child: CartPanel(showHeader: false)),
    );
  }
}
