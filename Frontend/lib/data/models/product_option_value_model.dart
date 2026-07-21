// lib/data/models/product_option_value_model.dart
//
// قيمة داخل مجموعة مواصفات مخصصة (مثلاً "أحمر" جوا مجموعة "اللون")
// بسعر إضافي اختياري (ممكن يكون 0).

class ProductOptionValueModel {
  final String id;
  final String label;
  final double price;

  ProductOptionValueModel({
    required this.id,
    required this.label,
    required this.price,
  });

  factory ProductOptionValueModel.fromJson(Map<String, dynamic> json) {
    return ProductOptionValueModel(
      id: json['id']?.toString() ?? '',
      label: json['label'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'label': label, 'price': price};
  }
}
