import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Status hasil pemasangan dari native (ApkInstaller.kt).
enum InstallStatus { pendingUserAction, success, aborted, failure }

class InstallEvent {
  final InstallStatus status;
  final String? message;
  const InstallEvent(this.status, this.message);
}

/// Pembungkus channel `qpos/app_update` (Android). Pemasangan memakai PackageInstaller, jadi pengguna tidak dibawa
/// ke browser. Pada sukses, proses aplikasi dihentikan sistem lalu dibuka kembali oleh UpdateRelaunchReceiver.
class ApkInstaller {
  ApkInstaller._() {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'installResult') return;
      final args = Map<String, dynamic>.from(call.arguments as Map);
      final status = switch (args['status']) {
        'pending_user_action' => InstallStatus.pendingUserAction,
        'success' => InstallStatus.success,
        'aborted' => InstallStatus.aborted,
        _ => InstallStatus.failure,
      };
      _events.add(InstallEvent(status, args['message'] as String?));
    });
  }

  static final ApkInstaller instance = ApkInstaller._();

  static const _channel = MethodChannel('qpos/app_update');
  final _events = StreamController<InstallEvent>.broadcast();

  /// Hasil pemasangan (konfirmasi diminta, dibatalkan, gagal).
  Stream<InstallEvent> get events => _events.stream;

  /// Update di dalam aplikasi hanya untuk Android; platform lain memakai link unduhan.
  bool get supported => Platform.isAndroid;

  Future<String> updateDir() async =>
      (await _channel.invokeMethod<String>('updateDir'))!;

  /// Izin "Instal aplikasi tak dikenal" untuk aplikasi ini (Android 8+).
  Future<bool> canInstall() async =>
      (await _channel.invokeMethod<bool>('canInstall')) ?? false;

  Future<void> openInstallPermission() =>
      _channel.invokeMethod('openInstallPermission');

  Future<void> install(String path) =>
      _channel.invokeMethod('install', {'path': path});
}
