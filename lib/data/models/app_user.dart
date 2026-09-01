class AppUser {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String role; // OWNER, MANAGER, KASIR, GUDANG, AKUNTAN
  final bool isActive;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    required this.isActive,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      name: json['name'] as String? ?? '-',
      email: json['email'] as String? ?? '-',
      phone: json['phone'] as String?,
      role: json['role'] as String,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
