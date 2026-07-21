import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/version_info.dart';

class UpdateService {
  Future<VersionInfo> getVersion() async {
    final response = await http.get(
      Uri.parse('https://pos-backend.sicerdiq.my.id/api/version'),
    );

    if (response.statusCode != 200) {
      throw Exception('Gagal mengambil informasi versi');
    }

    final json = jsonDecode(response.body);

    return VersionInfo.fromJson(json);
  }
}