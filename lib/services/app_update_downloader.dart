import 'dart:io';

import 'package:dio/dio.dart';

import 'apk_installer.dart';

/// Progres unduhan APK (byte). `total` null bila server tidak mengirim Content-Length.
class DownloadProgress {
  final int received;
  final int? total;
  const DownloadProgress(this.received, this.total);

  double? get fraction => (total == null || total! <= 0)
      ? null
      : (received / total!).clamp(0.0, 1.0);
}

/// Mengunduh APK update ke folder cache aplikasi (tanpa izin storage), dengan progres dan bisa dibatalkan.
/// File lama di folder update dihapus dulu agar cache tidak menumpuk.
class AppUpdateDownloader {
  AppUpdateDownloader({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(minutes: 10),
            ));

  final Dio _dio;
  CancelToken? _cancel;

  Future<File> download(String url, String version,
      void Function(DownloadProgress) onProgress) async {
    final dir = Directory(await ApkInstaller.instance.updateDir());
    if (await dir.exists()) {
      for (final f in dir.listSync()) {
        if (f is File) await f.delete();
      }
    }
    final target = File('${dir.path}/qpos-$version.apk');
    _cancel = CancelToken();
    await _dio.download(
      url,
      target.path,
      cancelToken: _cancel,
      deleteOnError: true,
      onReceiveProgress: (r, t) =>
          onProgress(DownloadProgress(r, t > 0 ? t : null)),
    );
    if (!await target.exists() || await target.length() == 0) {
      throw const FileSystemException('File unduhan kosong');
    }
    return target;
  }

  void cancel() => _cancel?.cancel('Dibatalkan pengguna');
}
