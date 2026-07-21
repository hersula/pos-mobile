import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/constants/app_colors.dart';

/// Halaman kamera untuk scan barcode. Return `Navigator.pop(context, code)`
/// begitu satu barcode berhasil terbaca — dipakai baik untuk mengisi field
/// barcode di form produk maupun mencari produk langsung di halaman kasir.
/// Helper singkat: buka halaman scan, return barcode yang terbaca (atau null
/// kalau dibatalkan). Contoh pakai: `final code = await scanBarcode(context);`
Future<String?> scanBarcode(BuildContext context, {String title = 'Scan Barcode'}) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => BarcodeScannerScreen(title: title)),
  );
}

class BarcodeScannerScreen extends StatefulWidget {
  final String title;

  const BarcodeScannerScreen({super.key, this.title = 'Scan Barcode'});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final value = barcodes.first.rawValue;
    if (value == null || value.isEmpty) return;

    _handled = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, child) {
                return Icon(state.torchState == TorchState.on ? Icons.flash_on_rounded : Icons.flash_off_rounded);
              },
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch_rounded),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          _ScannerOverlay(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                  child: const Text(
                    'Arahkan kamera ke barcode produk',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Batal', style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 260,
        height: 180,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.accent, width: 2.5),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
