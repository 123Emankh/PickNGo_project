// lib/data/models/product_variant_model.dart
//
// حجم/خيار منتج (مثلاً Small/Medium/Large) بسعر خاص فيه.

class ProductVariantModel {
  final String id;
  final String label;
  final double price;

  ProductVariantModel({
    required this.id,
    required this.label,
    required this.price,
  });

  factory ProductVariantModel.fromJson(Map<String, dynamic> json) {
    return ProductVariantModel(
      id: json['id']?.toString() ?? '',
      label: json['label'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'label': label, 'price': price};
  }
}
