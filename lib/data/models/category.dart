class Category {
  final String id;
  final String name;
  final int productCount;
  final bool isActive;

  Category({
    required this.id,
    required this.name,
    this.productCount = 0,
    this.isActive = true,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    final count = json['_count'] as Map<String, dynamic>?;
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      productCount:
          json['productCount'] as int? ?? count?['products'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'productCount': productCount,
        'isActive': isActive,
      };

  Category copyWith({bool? isActive}) => Category(
        id: id,
        name: name,
        productCount: productCount,
        isActive: isActive ?? this.isActive,
      );
}

class Warehouse {
  final String id;
  final String name;
  final String type; // STORE | CONSIGNMENT
  final String? customerId;

  Warehouse(
      {required this.id,
      required this.name,
      this.type = 'STORE',
      this.customerId});

  factory Warehouse.fromJson(Map<String, dynamic> json) {
    return Warehouse(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'STORE',
      customerId: json['customerId'] as String?,
    );
  }
}
