class VersionInfo {
  final String version;
  final int build;
  final String apk;
  final List<String> notes;

  VersionInfo({
    required this.version,
    required this.build,
    required this.apk,
    required this.notes,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    return VersionInfo(
      version: json['version'],
      build: json['build'],
      apk: json['apk'],
      notes: List<String>.from(json['notes'] ?? []),
    );
  }
}