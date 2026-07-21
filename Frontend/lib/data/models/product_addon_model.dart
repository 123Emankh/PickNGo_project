// lib/data/models/product_addon_model.dart
//
// إضافة اختيارية بسعر لمنتج (مثلاً: Extra Cheddar Cheese +$1.50).

class ProductAddonModel {
  final String id;
  final String name;
  final double price;

  ProductAddonModel({
    required this.id,
    required this.name,
    required this.price,
  });

  factory ProductAddonModel.fromJson(Map<String, dynamic> json) {
    return ProductAddonModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'price': price};
  }
}
