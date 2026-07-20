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
class BluetoothPrinterService {
  /// Minta izin Bluetooth (wajib di Android 12+ / API 31+) sebelum membaca
  /// daftar device yang sudah di-pairing.
  Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();

    return statuses.values.every((s) => s.isGranted || s.isLimited);
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
}
