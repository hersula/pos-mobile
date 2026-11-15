import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/app_version_info.dart';

/// Dialog untuk menampilkan update app.
/// Jika mandatory=true: tidak bisa ditutup (PopScope blokir back, barrierDismissible=false),
///   hanya ada tombol "Perbarui Sekarang".
/// Jika opsional: ada "Nanti" + "Perbarui Sekarang".
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

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isOpening = false;
  String? _errorMessage;

  Future<void> _openDownloadUrl() async {
    if (widget.versionInfo.downloadUrl == null ||
        widget.versionInfo.downloadUrl!.isEmpty) {
      setState(() => _errorMessage = 'URL download tidak tersedia');
      return;
    }

    setState(() {
      _isOpening = true;
      _errorMessage = null;
    });

    try {
      final url = Uri.parse(widget.versionInfo.downloadUrl!);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);

        if (!mounted) return;

        // Untuk update opsional, tutup dialog setelah membuka URL
        // Untuk mandatory, dialog tetap tampil
        if (!widget.versionInfo.mandatory) {
          Navigator.pop(context);
        } else {
          setState(() => _isOpening = false);
        }
      } else {
        if (mounted) {
          setState(() => _errorMessage = 'Tidak bisa membuka URL download');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Error: $e');
      }
    }

    if (mounted && widget.versionInfo.mandatory) {
      setState(() => _isOpening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMandatory = widget.versionInfo.mandatory;
    final latestVersion = widget.versionInfo.latestVersion ?? 'unknown';
    final releaseNotes =
        widget.versionInfo.releaseNotes ?? 'Pembaruan penting untuk aplikasi';

    return PopScope(
      canPop: !isMandatory, // Blokir back jika mandatory
      child: AlertDialog(
        title: const Text('Versi Terbaru Tersedia'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Versi baru: $latestVersion'),
              const SizedBox(height: 12),
              const Text(
                'Catatan rilis:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(releaseNotes),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!isMandatory)
            TextButton(
              onPressed: _isOpening
                  ? null
                  : () {
                      Navigator.pop(context);
                      widget.onSkipped();
                    },
              child: const Text('Nanti'),
            ),
          ElevatedButton(
            onPressed: _isOpening ? null : _openDownloadUrl,
            child: _isOpening
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Perbarui Sekarang'),
          ),
        ],
      ),
    );
  }
}
