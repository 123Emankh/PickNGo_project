// lib/data/models/product_option_group_model.dart
//
// مجموعة مواصفات مخصصة يعرّفها صاحب المحل حسب نوع المنتج (مثلاً "نوع الخبز"
// أو "اللون") - اختيار واحد أو أكتر، وممكن تكون إجبارية.

import 'product_option_value_model.dart';

class ProductOptionGroupModel {
  final String id;
  final String name;
  final String selectionMode; // 'single' أو 'multiple'
  final bool isRequired;
  final List<ProductOptionValueModel> values;

  ProductOptionGroupModel({
    required this.id,
    required this.name,
    required this.selectionMode,
    required this.isRequired,
    this.values = const [],
  });

  bool get isSingleSelect => selectionMode != 'multiple';

  factory ProductOptionGroupModel.fromJson(Map<String, dynamic> json) {
    return ProductOptionGroupModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      selectionMode: json['selection_mode'] ?? 'single',
      isRequired: json['is_required'] ?? false,
      values: json['values'] != null
          ? (json['values'] as List)
              .map((v) => ProductOptionValueModel.fromJson(v))
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'selection_mode': selectionMode,
      'is_required': isRequired,
      'values': values.map((v) => v.toJson()).toList(),
    };
  }
}
