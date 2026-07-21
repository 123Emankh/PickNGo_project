// lib/data/models/cart_item_model.dart

import 'product_model.dart';
import 'product_variant_model.dart';
import 'product_addon_model.dart';

/// اختيار الزبون لقيمة معيّنة بمجموعة مواصفات مخصصة (مش قيمة الكتالوج
/// نفسها - هاي تمثّل "شو اختار الزبون بالضبط" مع اسم المجموعة عشان العرض بالسلة).
class SelectedProductOption {
  final String groupId;
  final String groupName;
  final String valueId;
  final String label;
  final double price;

  SelectedProductOption({
    required this.groupId,
    required this.groupName,
    required this.valueId,
    required this.label,
    required this.price,
  });

  factory SelectedProductOption.fromJson(Map<String, dynamic> json) {
    return SelectedProductOption(
      groupId: json['groupId'].toString(),
      groupName: json['groupName'] ?? '',
      valueId: json['valueId'].toString(),
      label: json['label'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'groupId': groupId,
      'groupName': groupName,
      'valueId': valueId,
      'label': label,
      'price': price,
    };
  }
}

class CartItem {
  final ProductModel product;
  final String storeName;
  final int quantity;
  final ProductVariantModel? selectedVariant;
  final List<ProductAddonModel> selectedAddons;
  final List<String> selectedExclusionLabels;
  final List<SelectedProductOption> selectedOptions;

  CartItem({
    required this.product,
    required this.storeName,
    this.quantity = 1,
    this.selectedVariant,
    this.selectedAddons = const [],
    this.selectedExclusionLabels = const [],
    this.selectedOptions = const [],
  });

  double get addonsPrice => selectedAddons.fold(0.0, (sum, a) => sum + a.price);

  double get optionsPrice => selectedOptions.fold(0.0, (sum, o) => sum + o.price);

  double get unitPrice => (selectedVariant?.price ?? product.price) + addonsPrice + optionsPrice;

  double get subtotal => unitPrice * quantity;

  /// معرّف سطر السلة: نفس المنتج بحجم/إضافات/طلبات خاصة/مواصفات مختلفة = سطر مختلف بالسلة
  String get lineKey {
    final addonsKey = (selectedAddons.map((a) => a.id).toList()..sort()).join(',');
    final exclusionsKey = (List<String>.from(selectedExclusionLabels)..sort()).join(',');
    final optionsKey = (selectedOptions.map((o) => o.valueId).toList()..sort()).join(',');
    return '${product.id}::${selectedVariant?.id ?? ''}::$addonsKey::$exclusionsKey::$optionsKey';
  }

  CartItem copyWith({int? quantity}) {
    return CartItem(
      product: product,
      storeName: storeName,
      quantity: quantity ?? this.quantity,
      selectedVariant: selectedVariant,
      selectedAddons: selectedAddons,
      selectedExclusionLabels: selectedExclusionLabels,
      selectedOptions: selectedOptions,
    );
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      product: ProductModel.fromJson(json['product']),
      storeName: json['storeName'] ?? '',
      quantity: json['quantity'] ?? 1,
      selectedVariant: json['selectedVariant'] != null
          ? ProductVariantModel.fromJson(json['selectedVariant'])
          : null,
      selectedAddons: (json['selectedAddons'] as List<dynamic>? ?? [])
          .map((a) => ProductAddonModel.fromJson(a))
          .toList(),
      selectedExclusionLabels:
          (json['selectedExclusionLabels'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList(),
      selectedOptions: (json['selectedOptions'] as List<dynamic>? ?? [])
          .map((o) => SelectedProductOption.fromJson(o))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product': product.toJson(),
      'storeName': storeName,
      'quantity': quantity,
      'selectedVariant': selectedVariant?.toJson(),
      'selectedAddons': selectedAddons.map((a) => a.toJson()).toList(),
      'selectedExclusionLabels': selectedExclusionLabels,
      'selectedOptions': selectedOptions.map((o) => o.toJson()).toList(),
    };
  }
}
