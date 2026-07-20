/// Dilempar setiap kali request API gagal (status non-2xx). [message] diambil
/// dari field `message` response backend supaya pesan error yang tampil ke
/// kasir/owner selalu dalam Bahasa Indonesia yang konsisten dengan backend.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? data;

  ApiException(this.message, {this.statusCode, this.data});

  @override
  String toString() => message;
}
