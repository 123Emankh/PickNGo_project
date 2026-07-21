// lib/data/models/product_model.dart

import 'product_variant_model.dart';
import 'product_addon_model.dart';
import 'product_exclusion_model.dart';
import 'product_option_group_model.dart';

class ProductModel {
  final String id;
  final String name;
  final String description;
  final String storeId; // نفس store_id بالـ Base44
  final String imageUrl;
  final List<String> images; // صور إضافية لمعرض المنتج
  final double price;
  final double averageRating;
  final int totalReviews;
  final bool inStock;
  final bool isActive;
  final bool isFeatured; // شارة "الأكثر مبيعاً" يحددها صاحب المتجر
  final bool isFavorited;
  final String storeName; // موجودة بس لما تيجي من GET /api/stores/popular-products
  final List<ProductVariantModel> variants; // أحجام/خيارات بأسعار مختلفة
  final List<ProductAddonModel> addons; // إضافات اختيارية بسعر
  final List<ProductExclusionModel> exclusions; // طلبات خاصة محددة سلفاً
  final List<ProductOptionGroupModel> optionGroups; // مواصفات مخصصة حسب نوع المنتج

  ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.storeId,
    required this.imageUrl,
    required this.price,
    this.images = const [],
    this.averageRating = 0.0,
    this.totalReviews = 0,
    this.inStock = true,
    this.isActive = true,
    this.isFeatured = false,
    this.isFavorited = false,
    this.storeName = '',
    this.variants = const [],
    this.addons = const [],
    this.exclusions = const [],
    this.optionGroups = const [],
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      storeId: json['store_id']?.toString() ?? '',
      imageUrl: json['image_url'] ?? '',
      images: json['images'] != null
          ? List<String>.from(json['images'] as List)
          : const [],
      price: (json['price'] ?? 0).toDouble(),
      averageRating: (json['average_rating'] ?? 0).toDouble(),
      totalReviews: json['total_reviews'] ?? 0,
      inStock: json['in_stock'] ?? true,
      isActive: json['is_active'] ?? true,
      isFeatured: json['is_featured'] ?? false,
      isFavorited: json['is_favorited'] ?? false,
      storeName: json['store_name'] ?? '',
      variants: json['variants'] != null
          ? (json['variants'] as List)
              .map((v) => ProductVariantModel.fromJson(v))
              .toList()
          : const [],
      addons: json['addons'] != null
          ? (json['addons'] as List)
              .map((a) => ProductAddonModel.fromJson(a))
              .toList()
          : const [],
      exclusions: json['exclusions'] != null
          ? (json['exclusions'] as List)
              .map((e) => ProductExclusionModel.fromJson(e))
              .toList()
          : const [],
      optionGroups: json['option_groups'] != null
          ? (json['option_groups'] as List)
              .map((g) => ProductOptionGroupModel.fromJson(g))
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'store_id': storeId,
      'image_url': imageUrl,
      'images': images,
      'price': price,
      'average_rating': averageRating,
      'total_reviews': totalReviews,
      'in_stock': inStock,
      'is_active': isActive,
      'is_featured': isFeatured,
      'is_favorited': isFavorited,
      'store_name': storeName,
      'variants': variants.map((v) => v.toJson()).toList(),
      'addons': addons.map((a) => a.toJson()).toList(),
      'exclusions': exclusions.map((e) => e.toJson()).toList(),
      'option_groups': optionGroups.map((g) => g.toJson()).toList(),
    };
  }

  ProductModel copyWith({bool? isFavorited}) {
    return ProductModel(
      id: id,
      name: name,
      description: description,
      storeId: storeId,
      imageUrl: imageUrl,
      price: price,
      images: images,
      averageRating: averageRating,
      totalReviews: totalReviews,
      inStock: inStock,
      isActive: isActive,
      isFeatured: isFeatured,
      isFavorited: isFavorited ?? this.isFavorited,
      storeName: storeName,
      variants: variants,
      addons: addons,
      exclusions: exclusions,
      optionGroups: optionGroups,
    );
  }
}
