import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

class PrinterDevice {
  final String name;
  final String address;

  PrinterDevice({required this.name, required this.address});
}

/// Hasil detail satu proses cetak — dipakai supaya user (atau developer yang
/// bantu troubleshoot) bisa lihat PERSIS apa yang terjadi, bukan cuma
/// sukses/gagal generik. Ini penting karena masalah print terpotong itu
/// hardware-dependent banget, jadi diagnosa yang jelas jauh lebih berguna
/// daripada nebak-nebak lagi.
class PrintResult {
  final bool success;
  final String mode;
  final int totalBytes;
  final int chunksSent;
  final int chunksFailed;

  PrintResult({
    required this.success,
    required this.mode,
    required this.totalBytes,
    required this.chunksSent,
    required this.chunksFailed,
  });

  String get summary =>
      'Mode: $mode · $totalBytes byte · ${success ? "berhasil" : "GAGAL"}'
      '${chunksFailed > 0 ? " ($chunksFailed dari ${chunksSent + chunksFailed} kirim gagal)" : ""}';
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
  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return true;

    // Secara dokumentasi resmi Android, baca daftar bonded device & connect ke
    // classic Bluetooth (SPP) cuma butuh BLUETOOTH_CONNECT (Android 12+).
    // Tapi beberapa OEM/skin Android serta beberapa versi plugin ternyata
    // masih mengecek BLUETOOTH_SCAN juga sebelum mau kasih akses daftar
    // device — jadi diminta sekalian sebagai jaring pengaman, tidak
    // menggantungkan hasil akhir cuma pada satu izin ini.
    final statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();

    return statuses[Permission.bluetoothConnect]?.isGranted ?? false;
  }

  Future<List<PrinterDevice>> getPairedDevices() async {
    final List<BluetoothInfo> paired = await PrintBluetoothThermal.pairedBluetooths;
    return paired.map((d) => PrinterDevice(name: d.name, address: d.macAdress)).toList();
  }

  Future<bool> isConnected() => PrintBluetoothThermal.connectionStatus;

  Future<bool> connect(String address) => PrintBluetoothThermal.connect(macPrinterAddress: address);

  Future<bool> disconnect() => PrintBluetoothThermal.disconnect;

  // ================= MODE CETAK (bisa dipilih di Pengaturan Printer) =================
  //
  // Percobaan sebelumnya (kirim bertahap + jeda, berbagai preset kecepatan) TERNYATA
  // TIDAK cukup untuk beberapa printer generik — struk/nota tetap berhenti persis
  // setelah header, bahkan di preset paling lambat. Ini artinya dugaan "buffer printer
  // kewalahan karena kecepatan fisik" kemungkinan BUKAN akar masalah sebenarnya untuk
  // printer tersebut. Daripada terus menebak, sekarang disediakan beberapa MODE yang
  // bisa dicoba satu-satu lewat Test Print di Pengaturan, supaya ketemu kombinasi yang
  // benar-benar cocok untuk printer spesifik yang dipakai:
  //
  //   "single"  -> kirim SEMUA byte dalam SATU panggilan writeBytes (paling sederhana,
  //                cara paling "standar" dipakai kebanyakan contoh/dokumentasi plugin
  //                print_bluetooth_thermal). DEFAULT.
  //   "chunked" -> kirim bertahap per potongan kecil + jeda (pendekatan sebelumnya).
  //
  // Kalau salah satu mode bikin printer tertentu cetak lengkap sementara mode lain
  // tidak, itu petunjuk kuat akar masalahnya ADA di sisi mana (transmisi vs lainnya).
  static String printMode = 'single'; // 'single' | 'chunked'

  static int chunkSize = 48;
  static Duration delayBetweenChunks = const Duration(milliseconds: 120);

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

  static void applyPrintMode(String mode) {
    printMode = (mode == 'chunked') ? 'chunked' : 'single';
  }

  /// Kirim bytes ESC/POS ke printer yang sedang terkoneksi, sesuai [printMode]
  /// yang aktif. Return [PrintResult] berisi rincian (bukan cuma true/false)
  /// supaya kalau masih gagal, ada info konkret buat di-diagnosa lebih lanjut
  /// daripada cuma "gagal" tanpa konteks.
  Future<PrintResult> printBytes(List<int> bytes) async {
    if (printMode == 'chunked') {
      return _printChunked(bytes);
    }
    return _printSingle(bytes);
  }

  Future<PrintResult> _printSingle(List<int> bytes) async {
    final success = await PrintBluetoothThermal.writeBytes(bytes);
    return PrintResult(
      success: success,
      mode: 'single (sekaligus)',
      totalBytes: bytes.length,
      chunksSent: success ? 1 : 0,
      chunksFailed: success ? 0 : 1,
    );
  }

  Future<PrintResult> _printChunked(List<int> bytes) async {
    await Future.delayed(const Duration(milliseconds: 250));

    var sent = 0;
    var failed = 0;
    for (var i = 0; i < bytes.length; i += chunkSize) {
      final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
      final chunk = bytes.sublist(i, end);

      final success = await PrintBluetoothThermal.writeBytes(chunk);
      if (success) {
        sent++;
      } else {
        failed++;
      }

      if (end < bytes.length) {
        await Future.delayed(delayBetweenChunks);
      }
    }

    await Future.delayed(const Duration(milliseconds: 200));

    return PrintResult(
      success: failed == 0,
      mode: 'chunked (bertahap, ${chunkSize}b/${delayBetweenChunks.inMilliseconds}ms)',
      totalBytes: bytes.length,
      chunksSent: sent,
      chunksFailed: failed,
    );
  }

  /// Validasi format MAC address kasar (mis. "AA:BB:CC:DD:EE:FF"), dipakai
  /// untuk opsi "Hubungkan Manual" saat printer tidak muncul di daftar pairing.
  static bool isValidMacAddress(String value) {
    final regex = RegExp(r'^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$');
    return regex.hasMatch(value.trim());
  }
}
