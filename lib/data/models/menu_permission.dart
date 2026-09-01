class MenuAccessEntry {
  final String menuKey;
  final bool canAccess;
  final bool locked; // true = tidak bisa diubah (OWNER, atau menu "pengaturan")

  MenuAccessEntry({required this.menuKey, required this.canAccess, required this.locked});

  factory MenuAccessEntry.fromJson(Map<String, dynamic> json) {
    return MenuAccessEntry(
      menuKey: json['menuKey'] as String,
      canAccess: json['canAccess'] as bool,
      locked: json['locked'] as bool? ?? false,
    );
  }
}

class RoleMenuPermissions {
  final String role;
  final List<MenuAccessEntry> menus;

  RoleMenuPermissions({required this.role, required this.menus});

  factory RoleMenuPermissions.fromJson(Map<String, dynamic> json) {
    final menus = (json['menus'] as List<dynamic>)
        .map((e) => MenuAccessEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    return RoleMenuPermissions(role: json['role'] as String, menus: menus);
  }
}
