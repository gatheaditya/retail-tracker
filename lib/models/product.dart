class Product {
  final String? id;
  final String name;
  final String description;
  final double price;
  final String sku;
  final String category;

  Product({
    this.id,
    required this.name,
    this.description = '',
    required this.price,
    this.sku = '',
    this.category = 'General',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'sku': sku,
      'category': category,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String?,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      price: (map['price'] as num).toDouble(),
      sku: map['sku'] as String? ?? '',
      category: map['category'] as String? ?? 'General',
    );
  }

  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? sku,
    String? category,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      sku: sku ?? this.sku,
      category: category ?? this.category,
    );
  }
}
