import 'dart:io';
import 'package:flutter/material.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;

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
  String _speedPreset = 'normal';
  String _paperSize = 'mm58';
  bool _loading = true;
  bool _connecting = false;
  bool _permissionDenied = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
      _permissionDenied = false;
    });
    try {
      _savedAddress = await LocalStorage.instance.getPrinterAddress();
      _speedPreset = await LocalStorage.instance.getPrintSpeedPreset() ?? 'normal';
      _paperSize = await LocalStorage.instance.getPrinterPaperSize() ?? 'mm58';
      BluetoothPrinterService.applySpeedPreset(_speedPreset);

      final granted = await _printerService.requestPermissions();
      if (!granted) {
        setState(() {
          _permissionDenied = true;
          _error = 'Izin Bluetooth ditolak. Aplikasi butuh izin ini untuk membaca daftar printer yang sudah di-pairing.';
        });
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

  /// Buka halaman Pengaturan > Bluetooth bawaan Android supaya user bisa
  /// pairing printer dulu, tanpa harus keluar-masuk app secara manual.
  Future<void> _setSpeedPreset(String preset) async {
    setState(() => _speedPreset = preset);
    BluetoothPrinterService.applySpeedPreset(preset);
    await LocalStorage.instance.savePrintSpeedPreset(preset);
  }

  Future<void> _setPaperSize(String size) async {
    setState(() => _paperSize = size);
    await LocalStorage.instance.savePrinterPaperSize(size);
  }

  Future<void> _openSystemBluetoothSettings() async {
    if (!Platform.isAndroid) {
      _showSnack('Buka Pengaturan > Bluetooth di HP kamu secara manual untuk pairing printer.');
      return;
    }
    try {
      final intent = AndroidIntent(action: 'android.settings.BLUETOOTH_SETTINGS');
      await intent.launch();
    } catch (_) {
      _showSnack('Tidak bisa membuka pengaturan Bluetooth otomatis. Buka manual lewat Pengaturan HP.', isError: true);
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
        _showSnack('Gagal terhubung ke ${device.name}. Pastikan printer menyala & dalam jangkauan.', isError: true);
      }
    } catch (e) {
      _showSnack('Gagal terhubung: $e', isError: true);
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _showManualConnectDialog() async {
    final macCtrl = TextEditingController();
    final nameCtrl = TextEditingController(text: 'Printer Manual');
    String? dialogError;
    bool submitting = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Hubungkan Manual via MAC Address'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kalau printer tidak muncul di daftar padahal sudah di-pairing, coba hubungkan langsung pakai MAC address-nya. Cek di kertas manual printer atau di Pengaturan > Bluetooth HP (ketuk ikon info di sebelah nama printer).',
                style: TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              if (dialogError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(dialogError!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
                ),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama Printer (bebas)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: macCtrl,
                decoration: const InputDecoration(labelText: 'MAC Address', hintText: 'AA:BB:CC:DD:EE:FF'),
                textCapitalization: TextCapitalization.characters,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: submitting ? null : () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final mac = macCtrl.text.trim().toUpperCase();
                      if (!BluetoothPrinterService.isValidMacAddress(mac)) {
                        setDialogState(() => dialogError = 'Format MAC address tidak valid. Contoh: AA:BB:CC:DD:EE:FF');
                        return;
                      }

                      setDialogState(() {
                        submitting = true;
                        dialogError = null;
                      });

                      try {
                        final ok = await _printerService.connect(mac);
                        if (!ok) {
                          setDialogState(() {
                            dialogError = 'Gagal terhubung. Pastikan printer menyala, dalam jangkauan, dan sudah di-pairing.';
                            submitting = false;
                          });
                          return;
                        }

                        final name = nameCtrl.text.trim().isEmpty ? 'PRJ-R58B' : nameCtrl.text.trim();
                        await LocalStorage.instance.savePrinter(address: mac, name: name);
                        if (ctx.mounted) Navigator.pop(ctx);
                        setState(() => _savedAddress = mac);
                        _showSnack('Berhasil terhubung ke $name');
                      } catch (e) {
                        setDialogState(() {
                          dialogError = 'Gagal terhubung: $e';
                          submitting = false;
                        });
                      }
                    },
              child: submitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Hubungkan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testPrint() async {
    setState(() => _connecting = true);
    try {
      var isConnected = await _printerService.isConnected();
      if (!isConnected) {
        // Koneksi Bluetooth SPP tidak bertahan lintas sesi app — device yang
        // sudah dipilih/paired sebelumnya (ada di _savedAddress) belum tentu
        // socket-nya masih aktif kalau app baru saja dibuka lagi. Sebelum
        // bilang "belum terhubung", coba sambungkan ulang otomatis dulu.
        if (_savedAddress != null) {
          isConnected = await _printerService.connect(_savedAddress!);
        }
        if (!isConnected) {
          _showSnack('Belum terhubung ke printer manapun. Pilih printer dari daftar di atas dulu.', isError: true);
          return;
        }
      }

      final paperSize = _paperSize == 'mm80' ? PaperSize.mm80 : PaperSize.mm58;
      final profile = await CapabilityProfile.load();
      final generator = Generator(paperSize, profile);
      final bytes = <int>[];
      bytes.addAll(generator.reset());
      bytes.addAll(generator.text('TEST PRINT', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2)));
      bytes.addAll(generator.text('Printer berhasil terhubung', styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(generator.text(
        paperSize == PaperSize.mm80 ? 'Kertas: 80mm' : 'Kertas: 58mm',
        styles: const PosStyles(align: PosAlign.center),
      ));
      bytes.addAll(generator.hr());
      // Cetak beberapa baris sekaligus (bukan cuma 1-2 baris) supaya kalau ada
      // masalah struk terpotong di tengah (buffer printer kewalahan), langsung
      // ketahuan dari sini — baris terakhir "SELESAI" harus ikut tercetak utuh.
      for (var i = 1; i <= 15; i++) {
        bytes.addAll(generator.row([
          PosColumn(text: 'Baris pengujian ke-$i', width: 8),
          PosColumn(text: 'OK', width: 4, styles: const PosStyles(align: PosAlign.right)),
        ]));
      }
      bytes.addAll(generator.hr());
      bytes.addAll(generator.text('SELESAI', styles: const PosStyles(align: PosAlign.center, bold: true)));
      bytes.addAll(generator.text(
        'Kalau baris ini ikut tercetak DAN lebar teks di atas pas dengan lebar kertas kamu, printer siap dipakai.',
        styles: const PosStyles(align: PosAlign.center),
      ));
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
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                          if (_permissionDenied) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: openAppSettings,
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                              child: const Text('Buka Pengaturan Aplikasi untuk Izinkan Bluetooth'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Printer harus sudah di-pairing lewat Pengaturan Bluetooth HP dulu, baru bisa muncul & dipilih di sini.',
                            style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _openSystemBluetoothSettings,
                            icon: const Icon(Icons.settings_bluetooth_rounded, size: 17),
                            label: const Text('Pairing di Pengaturan HP'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _devices.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Lebar Kertas', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        const SizedBox(height: 4),
                        const Text(
                          'Kalau hasil cetak kelihatan tidak pas dengan lebar kertas fisik (kepenuhan/kesempitan), coba ganti opsi ini — beberapa printer generik tidak konsisten dengan label resminya.',
                          style: TextStyle(color: AppColors.muted, fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'mm58', label: Text('58mm')),
                            ButtonSegment(value: 'mm80', label: Text('80mm')),
                          ],
                          selected: {_paperSize},
                          onSelectionChanged: (s) => _setPaperSize(s.first),
                        ),
                        const SizedBox(height: 20),
                        const Text('Kecepatan Cetak', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        const SizedBox(height: 4),
                        const Text(
                          'Kalau struk masih terpotong/berhenti di tengah jalan, coba turunkan kecepatan ini bertahap.',
                          style: TextStyle(color: AppColors.muted, fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'normal', label: Text('Normal')),
                            ButtonSegment(value: 'slow', label: Text('Lambat')),
                            ButtonSegment(value: 'very_slow', label: Text('Sangat Lambat')),
                          ],
                          selected: {_speedPreset},
                          onSelectionChanged: (s) => _setSpeedPreset(s.first),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _showManualConnectDialog,
                          icon: const Icon(Icons.keyboard_rounded, size: 18),
                          label: const Text('Hubungkan Manual via MAC Address'),
                        ),
                        if (_savedAddress != null) ...[
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _connecting ? null : _testPrint,
                            icon: const Icon(Icons.receipt_long_rounded, size: 18),
                            label: const Text('Test Print'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.print_disabled_rounded, size: 40, color: AppColors.muted),
        const SizedBox(height: 12),
        const Text(
          'Belum ada printer yang di-pairing',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
        ),
        const SizedBox(height: 8),
        const Text(
          'Kalau printer PRJ-R58B (atau merek lain) sudah dinyalakan tapi tetap tidak muncul di sini, coba urutan ini:\n\n'
          '1. Pastikan Bluetooth di HP menyala\n'
          '2. Buka "Pairing di Pengaturan HP" di atas, cari & pasangkan printer dari sana (sering minta PIN "0000" atau "1234")\n'
          '3. Kembali ke halaman ini dan ketuk ikon refresh di kanan atas\n'
          '4. Kalau masih belum muncul, coba "Hubungkan Manual via MAC Address" di bawah — cek MAC address di stiker printer atau di daftar Bluetooth HP',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.5),
        ),
      ],
    );
  }
}
