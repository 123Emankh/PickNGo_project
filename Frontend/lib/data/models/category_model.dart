// lib/data/models/category_model.dart

import 'package:flutter/material.dart';

class CategoryModel {
  final String id;
  final String name;
  final String icon; // اسم الأيقونة كما هو بالـ Base44 (مثال: "UtensilsCrossed")
  final int sortOrder;
  final int storeCount;
  final int productCount;

  CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    this.sortOrder = 0,
    this.storeCount = 0,
    this.productCount = 0,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      icon: json['icon'] ?? '',
      sortOrder: json['sort_order'] ?? 0,
      storeCount: json['store_count'] ?? 0,
      productCount: json['product_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'sort_order': sortOrder,
      'store_count': storeCount,
      'product_count': productCount,
    };
  }

  // خريطة تحويل اسم الأيقونة (نص قادم من الباك إند/Base44) إلى IconData فعلي
  // نفس فكرة ICON_MAP بكود الـ React (lucide-react)
  static const Map<String, IconData> _iconMap = {
    'UtensilsCrossed': Icons.restaurant_menu,
    'ShoppingCart': Icons.shopping_cart_outlined,
    'Pill': Icons.local_pharmacy_outlined,
    'Shirt': Icons.checkroom_outlined,
    'BookOpen': Icons.menu_book_outlined,
    'Cake': Icons.cake_outlined,
    'Smartphone': Icons.phone_android_outlined,
  };

  IconData get iconData => _iconMap[icon] ?? Icons.shopping_cart_outlined;

  // لون مميز لكل فئة (بدل لون رمادي موحّد) - يُستخدم بدوائر أيقونات الفئات
  // بالصفحة الرئيسية، نفس فكرة _iconMap بالضبط: مفتاح ثابت لكل اسم أيقونة.
  static const Map<String, Color> _colorMap = {
    'UtensilsCrossed': Color(0xFFFF7043), // مطاعم - برتقالي
    'ShoppingCart': Color(0xFF26A69A), // سوبرماركت - أخضر مزرق
    'Pill': Color(0xFF29B6F6), // صيدليات - أزرق
    'Shirt': Color(0xFFAB47BC), // ملابس - بنفسجي
    'BookOpen': Color(0xFF8D6E63), // أثاث/كتب - بني
    'Cake': Color(0xFFEC407A), // حلويات - وردي
    'Smartphone': Color(0xFF5C6BC0), // إلكترونيات - نيلي
  };

  Color get color => _colorMap[icon] ?? const Color(0xFF66BB6A);
}