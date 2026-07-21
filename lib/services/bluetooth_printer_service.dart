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
  Future<bool> printBytes(List<int> bytes) => PrintBluetoothThermal.writeBytes(bytes);

  /// Validasi format MAC address kasar (mis. "AA:BB:CC:DD:EE:FF"), dipakai
  /// untuk opsi "Hubungkan Manual" saat printer tidak muncul di daftar pairing.
  static bool isValidMacAddress(String value) {
    final regex = RegExp(r'^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$');
    return regex.hasMatch(value.trim());
  }
}
