class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? email;

  Customer({required this.id, required this.name, this.phone, this.email});

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      name: json['name'] as String? ?? '-',
      phone: json['phone'] as String?,
      email: json['email'] as String?,
    );
  }
}
