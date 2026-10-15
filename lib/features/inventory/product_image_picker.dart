import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_config.dart';

/// Widget pemilih gambar produk.
///
/// Menampilkan preview dari salah satu sumber (prioritas atas ke bawah):
///  1. [pickedFile]  - file lokal yang baru dipilih user, belum diupload
///  2. [imageUrl]    - path/URL gambar yang sudah tersimpan di server
///  3. placeholder   - ikon kamera
///
/// Widget ini TIDAK mengupload apa pun. Ia hanya memilih file dan
/// melaporkannya lewat [onPicked] / [onRemoved]; upload dilakukan oleh
/// form saat tombol simpan ditekan (lihat ProductFormScreen._submit).
class ProductImagePicker extends StatelessWidget {
  final File? pickedFile;
  final String? imageUrl;
  final ValueChanged<File> onPicked;
  final VoidCallback onRemoved;
  final bool enabled;

  /// 0.0 - 1.0 saat upload berjalan; null = tidak sedang upload.
  final double? uploadProgress;

  const ProductImagePicker({
    super.key,
    this.pickedFile,
    this.imageUrl,
    required this.onPicked,
    required this.onRemoved,
    this.enabled = true,
    this.uploadProgress,
  });

  bool get _hasImage => pickedFile != null || (imageUrl != null && imageUrl!.isNotEmpty);

  Future<void> _pick(BuildContext context, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        // Kompres di sisi device supaya upload ringan & hemat kuota
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (picked == null) return;
      onPicked(File(picked.path));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil gambar: $e')),
        );
      }
    }
  }

  Future<void> _showSourceSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Gambar Produk', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Ambil dari Kamera'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _pick(context, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Pilih dari Galeri'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _pick(context, ImageSource.gallery);
              },
            ),
            if (_hasImage)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                title: const Text('Hapus Gambar', style: TextStyle(color: AppColors.danger)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  onRemoved();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (pickedFile != null) {
      return Image.file(pickedFile!, fit: BoxFit.cover);
    }

    final resolved = AppConfig.resolveImageUrl(imageUrl);
    if (resolved != null) {
      return Image.network(
        resolved,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_outlined, color: AppColors.muted, size: 32),
        ),
      );
    }

    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo_outlined, color: AppColors.muted, size: 30),
          SizedBox(height: 6),
          Text('Tambah Gambar', style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uploading = uploadProgress != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: (!enabled || uploading) ? null : () => _showSourceSheet(context),
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: AppColors.paper,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildPreview(),
                if (uploading)
                  Container(
                    color: Colors.black38,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: uploadProgress,
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Gambar Produk', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 4),
              const Text(
                'Opsional. Maks. 1024px, otomatis dikompres sebelum dikirim.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: (!enabled || uploading) ? null : () => _showSourceSheet(context),
                    icon: const Icon(Icons.image_outlined, size: 16),
                    label: Text(_hasImage ? 'Ganti' : 'Pilih'),
                  ),
                  if (_hasImage)
                    TextButton.icon(
                      onPressed: (!enabled || uploading) ? null : onRemoved,
                      icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.danger),
                      label: const Text('Hapus', style: TextStyle(color: AppColors.danger)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
