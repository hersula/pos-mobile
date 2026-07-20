import 'package:flutter/material.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/storage/local_storage.dart';
import '../../services/bluetooth_printer_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final _printerService = BluetoothPrinterService();
  List<PrinterDevice> _devices = [];
  String? _savedAddress;
  bool _loading = true;
  bool _connecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    try {
      _savedAddress = await LocalStorage.instance.getPrinterAddress();

      final granted = await _printerService.requestPermissions();
      if (!granted) {
        setState(() => _error = 'Izin Bluetooth/Lokasi ditolak. Aktifkan lewat pengaturan HP untuk melihat daftar printer.');
        return;
      }

      final devices = await _printerService.getPairedDevices();
      setState(() => _devices = devices);
    } catch (e) {
      setState(() => _error = 'Gagal membaca daftar printer Bluetooth: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connect(PrinterDevice device) async {
    setState(() => _connecting = true);
    try {
      final ok = await _printerService.connect(device.address);
      if (ok) {
        await LocalStorage.instance.savePrinter(address: device.address, name: device.name);
        setState(() => _savedAddress = device.address);
        _showSnack('Berhasil terhubung ke ${device.name}');
      } else {
        _showSnack('Gagal terhubung ke ${device.name}', isError: true);
      }
    } catch (e) {
      _showSnack('Gagal terhubung: $e', isError: true);
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _testPrint() async {
    setState(() => _connecting = true);
    try {
      final isConnected = await _printerService.isConnected();
      if (!isConnected) {
        _showSnack('Belum terhubung ke printer manapun', isError: true);
        return;
      }

      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      final bytes = <int>[];
      bytes.addAll(generator.text('TEST PRINT', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2)));
      bytes.addAll(generator.text('Printer berhasil terhubung', styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(generator.hr());
      bytes.addAll(generator.text('Aplikasi POS siap mencetak struk.'));
      bytes.addAll(generator.feed(2));
      bytes.addAll(generator.cut());

      final success = await _printerService.printBytes(bytes);
      _showSnack(success ? 'Test print terkirim' : 'Gagal mengirim test print', isError: !success);
    } catch (e) {
      _showSnack('Terjadi kesalahan: $e', isError: true);
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? AppColors.danger : AppColors.accent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer Bluetooth'),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _init)],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(10)),
                      child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Pastikan printer thermal sudah di-pairing lewat pengaturan Bluetooth HP terlebih dahulu, baru pilih dari daftar di bawah.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                    ),
                  ),
                  Expanded(
                    child: _devices.isEmpty
                        ? const Center(child: Text('Belum ada printer yang di-pairing', style: TextStyle(color: AppColors.muted)))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _devices.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final d = _devices[i];
                              final isSaved = d.address == _savedAddress;
                              return Card(
                                margin: EdgeInsets.zero,
                                child: ListTile(
                                  leading: Icon(Icons.print_rounded, color: isSaved ? AppColors.accent : AppColors.muted),
                                  title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text(d.address, style: const TextStyle(fontSize: 11.5)),
                                  trailing: isSaved
                                      ? const Icon(Icons.check_circle_rounded, color: AppColors.accent)
                                      : TextButton(
                                          onPressed: _connecting ? null : () => _connect(d),
                                          child: const Text('Hubungkan'),
                                        ),
                                ),
                              );
                            },
                          ),
                  ),
                  if (_savedAddress != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: OutlinedButton.icon(
                        onPressed: _connecting ? null : _testPrint,
                        icon: const Icon(Icons.receipt_long_rounded, size: 18),
                        label: const Text('Test Print'),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
