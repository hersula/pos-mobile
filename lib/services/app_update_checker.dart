import 'dart:async';
import 'package:flutter/material.dart';
import '../core/storage/local_storage.dart';
import '../data/models/app_version_info.dart';
import 'app_update_service.dart';
import '../features/app_update/update_dialog.dart';

/// Manajer untuk cek versi app dan tampilkan dialog update.
/// Cek hanya dilakukan sekali per sesi (tracking di memory).
/// Versi opsional yang di-skip user disimpan ke SharedPreferences.
class AppUpdateChecker {
  static final AppUpdateChecker _instance = AppUpdateChecker._internal();

  factory AppUpdateChecker() => _instance;

  AppUpdateChecker._internal();

  final AppUpdateService _service = AppUpdateService();
  bool _hasChecked = false;
  Set<String> _skippedVersions = {};

  /// Inisialisasi: load versi yang di-skip sebelumnya dari storage.
  Future<void> init() async {
    _skippedVersions = await LocalStorage.instance.getSkippedUpdateVersions();
  }

  /// Cek versi terbaru dan tampilkan dialog jika ada update.
  /// Aman untuk dipanggil berkali-kali; hanya jalankan sekali per sesi.
  /// Kegagalan jaringan/timeout → diam saja (log debug), JANGAN crash.
  Future<void> checkAndShowDialogIfNeeded(BuildContext context) async {
    if (_hasChecked) return;
    _hasChecked = true;

    try {
      final versionInfo = await _service.checkLatestVersion();

      // Jika tidak ada update atau sudah di-skip (dan opsional), jangan tampilkan dialog
      if (!versionInfo.updateAvailable) return;

      // Jika mandatory, selalu tampilkan
      // Jika opsional, cek apakah sudah di-skip
      if (!versionInfo.mandatory &&
          (versionInfo.latestVersion != null &&
              _skippedVersions.contains(versionInfo.latestVersion))) {
        return;
      }

      if (context.mounted) {
        _showUpdateDialog(context, versionInfo);
      }
    } catch (e) {
      // Log untuk debugging, tapi jangan crash UI
      debugPrint('AppUpdateChecker: Gagal cek versi: $e');
    }
  }

  void _showUpdateDialog(BuildContext context, AppVersionInfo versionInfo) {
    showDialog(
      context: context,
      barrierDismissible: !versionInfo.mandatory,
      builder: (ctx) => UpdateDialog(
        versionInfo: versionInfo,
        onSkipped: () async {
          if (!versionInfo.mandatory && versionInfo.latestVersion != null) {
            _skippedVersions.add(versionInfo.latestVersion!);
            await LocalStorage.instance
                .setSkippedUpdateVersions(_skippedVersions);
          }
        },
      ),
    );
  }
}
