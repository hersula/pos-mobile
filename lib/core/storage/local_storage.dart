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
}
