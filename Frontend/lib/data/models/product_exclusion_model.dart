// lib/data/models/product_exclusion_model.dart
//
// طلب خاص محدد سلفًا لمنتج (مثلاً: No Onions) - يحدده صاحب المتجر عند
// إضافة المنتج، والزبون يختار منها عند الطلب.

class ProductExclusionModel {
  final String id;
  final String label;

  ProductExclusionModel({
    required this.id,
    required this.label,
  });

  factory ProductExclusionModel.fromJson(Map<String, dynamic> json) {
    return ProductExclusionModel(
      id: json['id']?.toString() ?? '',
      label: json['label'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'label': label};
  }
}
