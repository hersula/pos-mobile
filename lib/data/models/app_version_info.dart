/// Model informasi versi app dari server.
/// Sesuai kontrak: GET /api/app/version?platform=android&version=<versi>&build=<build>
/// Respons: { data: { latestVersion, latestBuildNumber, minSupportedVersion, mandatory,
///   updateAvailable, downloadUrl, releaseNotes, releasedAt } }
class AppVersionInfo {
  final String? latestVersion;
  final int? latestBuildNumber;
  final String? minSupportedVersion;
  final bool mandatory;
  final bool updateAvailable;
  final String? downloadUrl;
  final String? releaseNotes;
  final String? releasedAt;

  AppVersionInfo({
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.minSupportedVersion,
    required this.mandatory,
    required this.updateAvailable,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.releasedAt,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      latestVersion: json['latestVersion'] as String?,
      latestBuildNumber: json['latestBuildNumber'] as int?,
      minSupportedVersion: json['minSupportedVersion'] as String?,
      mandatory: json['mandatory'] as bool? ?? false,
      updateAvailable: json['updateAvailable'] as bool? ?? false,
      downloadUrl: json['downloadUrl'] as String?,
      releaseNotes: json['releaseNotes'] as String?,
      releasedAt: json['releasedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'latestVersion': latestVersion,
        'latestBuildNumber': latestBuildNumber,
        'minSupportedVersion': minSupportedVersion,
        'mandatory': mandatory,
        'updateAvailable': updateAvailable,
        'downloadUrl': downloadUrl,
        'releaseNotes': releaseNotes,
        'releasedAt': releasedAt,
      };
}
