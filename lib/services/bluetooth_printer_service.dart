import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

class PrinterDevice {
  final String name;
  final String address;

  PrinterDevice({required this.name, required this.address});
}

/// Wrapper tipis di atas `print_bluetooth_thermal`. Aplikasi hanya berurusan
/// dengan device yang sudah *paired* lewat pengaturan Bluetooth Android bawaan
/// (paling stabil untuk printer thermal 58mm/80mm) — bukan scan BLE manual.
///
/// Catatan penting: `getPairedDevices()` HANYA membaca daftar device yang
/// sudah di-pairing di level sistem Android (Settings > Bluetooth). Kalau
/// printer belum pernah dipasangkan di sana, printer itu TIDAK akan pernah
/// muncul di app ini — pairing di Settings Android dulu adalah langkah wajib,
/// bukan sesuatu yang bisa dilakukan lewat halaman ini.
class BluetoothPrinterService {
  /// Minta izin Bluetooth yang benar-benar dibutuhkan:
  ///  - Android 12+ (API 31+): BLUETOOTH_CONNECT (wajib, dangerous permission)
  ///  - Android < 12: BLUETOOTH/BLUETOOTH_ADMIN (normal permission, otomatis
  ///    granted oleh sistem — permission_handler akan langsung melaporkan
  ///    `.granted` tanpa munculkan dialog)
  ///
  /// Sengaja TIDAK mewajibkan izin Lokasi — itu hanya relevan untuk *scan*
  /// device BLE baru, bukan untuk membaca daftar device yang sudah di-pairing
  /// atau untuk connect ke device classic Bluetooth (SPP) seperti printer
  /// thermal. Mewajibkannya cuma bikin proses gagal tanpa alasan yang jelas.
  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return true;

    final connectStatus = await Permission.bluetoothConnect.request();
    return connectStatus.isGranted;
  }

  Future<List<PrinterDevice>> getPairedDevices() async {
    final List<BluetoothInfo> paired = await PrintBluetoothThermal.pairedBluetooths;
    return paired.map((d) => PrinterDevice(name: d.name, address: d.macAdress)).toList();
  }

  Future<bool> isConnected() => PrintBluetoothThermal.connectionStatus;

  Future<bool> connect(String address) => PrintBluetoothThermal.connect(macPrinterAddress: address);

  Future<bool> disconnect() => PrintBluetoothThermal.disconnect;

  /// Kirim bytes ESC/POS yang sudah jadi (lihat [ReceiptBuilder]) ke printer
  /// yang sedang terkoneksi. Return false kalau printer belum/tidak terhubung.
  ///
  /// PENTING — kenapa dikirim per potongan kecil dengan jeda, bukan sekaligus:
  /// Bluetooth (RFCOMM/SPP) bisa saja "berhasil" mengirim seluruh data dalam
  /// hitungan milidetik, tapi printer thermal itu perangkat MEKANIK — kepala
  /// cetak butuh waktu fisik nyata untuk menggerakkan kertas & membakar tiap
  /// baris (apalagi baris besar/tebal seperti nama toko, yang jauh lebih
  /// lambat dicetak daripada teks biasa). Kalau software terus mengirim data
  /// baru lebih cepat daripada kecepatan cetak fisiknya, buffer terima
  /// printer (yang di printer generik murah biasanya kecil) jadi penuh dan
  /// SISA DATA YANG BELUM SEMPAT DICETAK DIBUANG BEGITU SAJA — makanya struk
  /// keliatan "berhenti" persis di titik printer paling lambat (baris
  /// besar/tebal atau baris pertama setelah reset).
  ///
  /// [chunkSize] & [delayBetweenChunks] sengaja dibuat `static` (bukan
  /// `const` lokal) supaya gampang di-tuning tanpa bongkar kode kalau printer
  /// tertentu masih terpotong — printer generik beda merek/firmware punya
  /// kecepatan cetak & ukuran buffer terima yang beda-beda:
  ///   - Masih terpotong? Naikkan [delayBetweenChunks] (mis. jadi 150-200ms)
  ///     dan/atau kecilkan [chunkSize] (mis. jadi 32).
  ///   - Cetak sudah lengkap tapi kelamaan? Turunkan pelan-pelan sampai
  ///     ketemu titik teraman-tercepat untuk printer itu.
  static int chunkSize = 48;
  static Duration delayBetweenChunks = const Duration(milliseconds: 120);

  /// Preset kecepatan cetak. "normal" cukup untuk kebanyakan printer;
  /// "slow"/"very_slow" untuk printer generik yang masih kepotong di
  /// preset normal — kirim lebih sedikit byte per kirim, jeda lebih panjang.
  static const Map<String, ({int chunkSize, int delayMs})> speedPresets = {
    'normal': (chunkSize: 48, delayMs: 120),
    'slow': (chunkSize: 32, delayMs: 180),
    'very_slow': (chunkSize: 16, delayMs: 280),
  };

  static void applySpeedPreset(String preset) {
    final config = speedPresets[preset] ?? speedPresets['normal']!;
    chunkSize = config.chunkSize;
    delayBetweenChunks = Duration(milliseconds: config.delayMs);
  }

  Future<bool> printBytes(List<int> bytes) async {
    // Jeda "pemanasan" di awal — kasih waktu printer benar-benar siap
    // menerima (apalagi kalau baru saja connect() atau baru dikirim perintah
    // reset()) sebelum data pertama ditembakkan.
    await Future.delayed(const Duration(milliseconds: 250));

    var allSuccess = true;
    for (var i = 0; i < bytes.length; i += chunkSize) {
      final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
      final chunk = bytes.sublist(i, end);

      final success = await PrintBluetoothThermal.writeBytes(chunk);
      if (!success) allSuccess = false;

      if (end < bytes.length) {
        await Future.delayed(delayBetweenChunks);
      }
    }

    // Jeda penutup — beri waktu printer menghabiskan sisa buffer & menuntaskan
    // perintah feed/cut di akhir sebelum dianggap selesai.
    await Future.delayed(const Duration(milliseconds: 200));

    return allSuccess;
  }

  /// Validasi format MAC address kasar (mis. "AA:BB:CC:DD:EE:FF"), dipakai
  /// untuk opsi "Hubungkan Manual" saat printer tidak muncul di daftar pairing.
  static bool isValidMacAddress(String value) {
    final regex = RegExp(r'^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$');
    return regex.hasMatch(value.trim());
  }
}
