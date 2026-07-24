import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Menyimpan sesi login (token + profil user) dan pengaturan printer Bluetooth
/// secara lokal di device, supaya kasir tidak perlu login ulang tiap buka app.
class LocalStorage {
  LocalStorage._();
  static final LocalStorage instance = LocalStorage._();

  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';
  static const _kUserProfile = 'user_profile';
  static const _kPrinterAddress = 'printer_address';
  static const _kPrinterName = 'printer_name';
  static const _kPrintSpeedPreset = 'print_speed_preset';
  static const _kPrinterPaperSize = 'printer_paper_size';

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required Map<String, dynamic> userProfile,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccessToken, accessToken);
    await prefs.setString(_kRefreshToken, refreshToken);
    await prefs.setString(_kUserProfile, jsonEncode(userProfile));
  }

  Future<void> updateAccessToken(String accessToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccessToken, accessToken);
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kAccessToken);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRefreshToken);
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUserProfile);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccessToken);
    await prefs.remove(_kRefreshToken);
    await prefs.remove(_kUserProfile);
  }

  // ---------- Printer ----------
  Future<void> savePrinter({required String address, required String name}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrinterAddress, address);
    await prefs.setString(_kPrinterName, name);
  }

  Future<String?> getPrinterAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPrinterAddress);
  }

  Future<String?> getPrinterName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPrinterName);
  }

  /// Preset kecepatan cetak (lihat [BluetoothPrinterService.applySpeedPreset]):
  /// "normal" | "slow" | "very_slow". Disimpan supaya pilihan user tetap
  /// dipakai lagi tiap buka app, tidak perlu diatur ulang tiap kali cetak.
  Future<void> savePrintSpeedPreset(String preset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrintSpeedPreset, preset);
  }

  Future<String?> getPrintSpeedPreset() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPrintSpeedPreset);
  }

  /// Lebar kertas printer: "mm58" (default) | "mm80". Beberapa printer generik
  /// tidak konsisten dengan label lebar kertas resminya (kepala cetak fisik
  /// beda dot-width dari yang diklaim), jadi dibuat bisa dipilih manual lewat
  /// Pengaturan Printer daripada di-hardcode.
  Future<void> savePrinterPaperSize(String size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrinterPaperSize, size);
  }

  Future<String?> getPrinterPaperSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPrinterPaperSize);
  }
}
