class Category {
  final String id;
  final String name;
  final int productCount;

  Category({required this.id, required this.name, this.productCount = 0});

  factory Category.fromJson(Map<String, dynamic> json) {
    final count = json['_count'] as Map<String, dynamic>?;
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      productCount: count?['products'] as int? ?? 0,
    );
  }
}

class Warehouse {
  final String id;
  final String name;

  Warehouse({required this.id, required this.name});

  factory Warehouse.fromJson(Map<String, dynamic> json) {
    return Warehouse(id: json['id'] as String, name: json['name'] as String);
  }
}
