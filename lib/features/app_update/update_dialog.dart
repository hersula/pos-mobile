import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/app_version_info.dart';
import '../../services/apk_installer.dart';
import '../../services/app_update_downloader.dart';

enum _Tahap { siap, unduh, izin, pasang, gagal }

/// Dialog update aplikasi. Android: APK diunduh DI DALAM aplikasi (progres persen + MB), lalu dipasang lewat
/// PackageInstaller tanpa membuka browser; setelah terpasang aplikasi dibuka kembali (UpdateRelaunchReceiver,
/// dengan notifikasi cadangan). Platform lain: membuka link unduhan seperti sebelumnya.
/// Mandatory: tidak bisa ditutup (PopScope + barrierDismissible=false). Opsional: ada "Nanti".
class UpdateDialog extends StatefulWidget {
  final AppVersionInfo versionInfo;
  final VoidCallback onSkipped; // Dipanggil saat user klik "Nanti" atau dismiss

  const UpdateDialog({
    required this.versionInfo,
    required this.onSkipped,
    super.key,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog>
    with WidgetsBindingObserver {
  final _downloader = AppUpdateDownloader();
  final _installer = ApkInstaller.instance;
  StreamSubscription<InstallEvent>? _sub;

  _Tahap _tahap = _Tahap.siap;
  DownloadProgress? _progress;
  File? _apk;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sub = _installer.events.listen(_onInstallEvent);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _downloader.cancel();
    super.dispose();
  }

  /// Kembali dari layar izin "Instal aplikasi tak dikenal": lanjut pasang otomatis bila izin sudah diberikan.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _tahap == _Tahap.izin &&
        _apk != null) {
      _pasang(_apk!);
    }
  }

  String? get _url {
    final u = widget.versionInfo.downloadUrl;
    return (u == null || u.isEmpty) ? null : u;
  }

  Future<void> _mulai() async {
    final url = _url;
    if (url == null) return _gagal('URL download tidak tersedia');
    if (!_installer.supported) return _bukaBrowser(url);

    setState(() {
      _tahap = _Tahap.unduh;
      _progress = null;
      _error = null;
    });
    try {
      final apk = await _downloader
          .download(url, widget.versionInfo.latestVersion ?? 'baru', (p) {
        if (mounted) setState(() => _progress = p);
      });
      _apk = apk;
      if (!mounted) return;
      await _pasang(apk);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        if (mounted) setState(() => _tahap = _Tahap.siap);
        return;
      }
      _gagal('Unduhan gagal. Periksa koneksi internet lalu coba lagi.');
    } catch (e) {
      _gagal('Unduhan gagal: $e');
    }
  }

  Future<void> _pasang(File apk) async {
    if (!await _installer.canInstall()) {
      if (!mounted) return;
      setState(() => _tahap = _Tahap.izin);
      return;
    }
    // Android 13+: izin notifikasi untuk notifikasi "Pembaruan selesai" (cadangan bila sistem memblokir buka ulang).
    await Permission.notification.request();
    if (!mounted) return;
    setState(() {
      _tahap = _Tahap.pasang;
      _error = null;
    });
    try {
      await _installer.install(apk.path);
    } catch (e) {
      _gagal('Pemasangan gagal dimulai: $e');
    }
  }

  void _onInstallEvent(InstallEvent e) {
    if (!mounted) return;
    switch (e.status) {
      case InstallStatus.pendingUserAction:
      case InstallStatus.success:
        setState(() => _tahap = _Tahap.pasang);
      case InstallStatus.aborted:
        _gagal(
            'Pemasangan dibatalkan. Ketuk "Pasang Ulang" untuk mencoba lagi.');
      case InstallStatus.failure:
        _gagal('Pemasangan gagal${e.message != null ? ': ${e.message}' : ''}. '
            'Pastikan APK ditandatangani dengan kunci yang sama dengan aplikasi terpasang.');
    }
  }

  void _gagal(String msg) {
    if (!mounted) return;
    setState(() {
      _tahap = _Tahap.gagal;
      _error = msg;
    });
  }

  Future<void> _bukaBrowser(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (mounted && !widget.versionInfo.mandatory) Navigator.pop(context);
    } else {
      _gagal('Tidak bisa membuka URL download');
    }
  }

  String _mb(int b) => (b / (1024 * 1024)).toStringAsFixed(1);

  Widget _isiProgres() {
    final p = _progress;
    final f = p?.fraction;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: f,
            minHeight: 8,
            backgroundColor: AppColors.accentSoft,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
                f == null
                    ? 'Mengunduh...'
                    : 'Mengunduh ${(f * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            if (p != null)
              Text(
                  p.total != null
                      ? '${_mb(p.received)} / ${_mb(p.total!)} MB'
                      : '${_mb(p.received)} MB',
                  style:
                      const TextStyle(color: AppColors.muted, fontSize: 12.5)),
          ],
        ),
      ],
    );
  }

  Widget _info(IconData icon, String text, Color color) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      );

  List<Widget> _tombol() {
    final mandatory = widget.versionInfo.mandatory;
    final nanti = TextButton(
      onPressed: () {
        Navigator.pop(context);
        widget.onSkipped();
      },
      child: const Text('Nanti'),
    );
    switch (_tahap) {
      case _Tahap.siap:
        return [
          if (!mandatory) nanti,
          ElevatedButton(
              onPressed: _mulai, child: const Text('Perbarui Sekarang'))
        ];
      case _Tahap.unduh:
        return [
          TextButton(
              onPressed: _downloader.cancel, child: const Text('Batalkan'))
        ];
      case _Tahap.izin:
        return [
          if (!mandatory) nanti,
          ElevatedButton(
              onPressed: _installer.openInstallPermission,
              child: const Text('Buka Pengaturan')),
        ];
      case _Tahap.pasang:
        return [
          TextButton(
            onPressed: _apk == null ? null : () => _pasang(_apk!),
            child: const Text('Pasang Ulang'),
          ),
        ];
      case _Tahap.gagal:
        return [
          if (!mandatory) nanti,
          if (_url != null)
            TextButton(
                onPressed: () => _bukaBrowser(_url!),
                child: const Text('Unduh via Browser')),
          ElevatedButton(
            onPressed: _apk != null ? () => _pasang(_apk!) : _mulai,
            child: Text(_apk != null ? 'Pasang Ulang' : 'Coba Lagi'),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMandatory = widget.versionInfo.mandatory;
    final latestVersion = widget.versionInfo.latestVersion ?? 'unknown';
    final releaseNotes =
        widget.versionInfo.releaseNotes ?? 'Pembaruan penting untuk aplikasi';
    final sibuk = _tahap == _Tahap.unduh || _tahap == _Tahap.pasang;

    return PopScope(
      canPop: !isMandatory &&
          !sibuk, // Blokir back jika mandatory atau sedang mengunduh/memasang
      child: AlertDialog(
        title: const Text('Versi Terbaru Tersedia'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Versi baru: $latestVersion'),
              const SizedBox(height: 12),
              const Text('Catatan rilis:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(releaseNotes),
              if (_tahap == _Tahap.unduh) _isiProgres(),
              if (_tahap == _Tahap.izin)
                _info(
                    Icons.lock_open_outlined,
                    'Izinkan Q-Pos memasang pembaruan: aktifkan "Izinkan dari sumber ini", lalu kembali ke aplikasi. '
                    'Pemasangan berlanjut otomatis.',
                    AppColors.pending),
              if (_tahap == _Tahap.pasang)
                _info(
                    Icons.system_update_outlined,
                    'Memasang pembaruan... Bila muncul konfirmasi, ketuk "Pasang"/"Perbarui". '
                    'Aplikasi akan tertutup sebentar lalu terbuka kembali otomatis.',
                    AppColors.info),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.dangerSoft,
                    border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(_error!,
                      style: const TextStyle(
                          color: AppColors.danger, fontSize: 12)),
                ),
              ],
            ],
          ),
        ),
        actions: _tombol(),
      ),
    );
  }
}
