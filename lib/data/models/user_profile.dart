class Tenant {
  final String id;
  final String businessName;
  final String planType;

  Tenant({required this.id, required this.businessName, required this.planType});

  factory Tenant.fromJson(Map<String, dynamic> json) {
    return Tenant(
      id: json['id'] as String,
      businessName: json['businessName'] as String,
      planType: json['planType'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'businessName': businessName, 'planType': planType};
}

class UserProfile {
  final String id;
  final String name;
  final String email;
  final String role; // OWNER, MANAGER, KASIR, GUDANG, AKUNTAN
  final Tenant tenant;

  UserProfile({required this.id, required this.name, required this.email, required this.role, required this.tenant});

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      name: json['name'] as String? ?? '-',
      email: json['email'] as String? ?? '-',
      role: json['role'] as String,
      tenant: Tenant.fromJson(json['tenant'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email, 'role': role, 'tenant': tenant.toJson()};

  bool get canManageInventory => ['OWNER', 'MANAGER', 'GUDANG'].contains(role);
  bool get canSell => ['OWNER', 'MANAGER', 'KASIR'].contains(role);
  bool get canCancelSale => ['OWNER', 'MANAGER'].contains(role);
  bool get canViewAccounting => ['OWNER', 'MANAGER', 'AKUNTAN'].contains(role);
}
