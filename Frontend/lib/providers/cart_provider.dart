// lib/providers/cart_provider.dart
//
// إدارة السلة بالـ local state (Riverpod) + حفظ محلي على الجهاز
// (SharedPreferences) عشان تضل موجودة حتى لو المستخدم سكّر التطبيق أو
// سجّل خروج - بدون أي اعتماد على الباك إند حاليًا (سلة الجهاز، مش سلة
// مرتبطة بحساب معيّن).

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../data/models/cart_item_model.dart';
import '../data/models/product_model.dart';
import '../data/models/product_variant_model.dart';
import '../data/models/product_addon_model.dart';

class CartState {
  final List<CartItem> items;

  const CartState({this.items = const []});

  int get totalCount => items.fold(0, (sum, item) => sum + item.quantity);

  double get totalPrice => items.fold(0.0, (sum, item) => sum + item.subtotal);

  bool get isEmpty => items.isEmpty;

  CartState copyWith({List<CartItem>? items}) {
    return CartState(items: items ?? this.items);
  }
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState()) {
    _loadCart();
  }

  Future<void> _loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(AppConstants.cartKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw) as List<dynamic>;
      state = CartState(
        items: decoded.map((e) => CartItem.fromJson(e)).toList(),
      );
    } catch (e) {
      // سلة محفوظة تالفة/بشكل قديم غير متوافق - نتجاهلها ونبدأ بسلة فاضية
      // بدل ما نفشل بفتح التطبيق كامل
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(state.items.map((i) => i.toJson()).toList());
    await prefs.setString(AppConstants.cartKey, encoded);
  }

  void addProduct(
    ProductModel product,
    String storeName, {
    ProductVariantModel? variant,
    List<ProductAddonModel> addons = const [],
    List<String> exclusionLabels = const [],
    List<SelectedProductOption> options = const [],
    int quantity = 1,
  }) {
    final addonsKey = (addons.map((a) => a.id).toList()..sort()).join(',');
    final exclusionsKey = (List<String>.from(exclusionLabels)..sort()).join(',');
    final optionsKey = (options.map((o) => o.valueId).toList()..sort()).join(',');
    final lineKey = '${product.id}::${variant?.id ?? ''}::$addonsKey::$exclusionsKey::$optionsKey';
    final index = state.items.indexWhere((item) => item.lineKey == lineKey);
    if (index >= 0) {
      final updated = [...state.items];
      updated[index] = updated[index].copyWith(
        quantity: updated[index].quantity + quantity,
      );
      state = state.copyWith(items: updated);
    } else {
      state = state.copyWith(
        items: [
          ...state.items,
          CartItem(
            product: product,
            storeName: storeName,
            quantity: quantity,
            selectedVariant: variant,
            selectedAddons: addons,
            selectedExclusionLabels: exclusionLabels,
            selectedOptions: options,
          ),
        ],
      );
    }
    _persist();
  }

  void increment(String lineKey) {
    final updated = state.items.map((item) {
      if (item.lineKey == lineKey) {
        return item.copyWith(quantity: item.quantity + 1);
      }
      return item;
    }).toList();
    state = state.copyWith(items: updated);
    _persist();
  }

  void decrement(String lineKey) {
    final updated = <CartItem>[];
    for (final item in state.items) {
      if (item.lineKey == lineKey) {
        if (item.quantity > 1) {
          updated.add(item.copyWith(quantity: item.quantity - 1));
        }
        // إذا الكمية 1 وبدك تنقص، بيتحذف العنصر بالكامل (ما بينضاف لـ updated)
      } else {
        updated.add(item);
      }
    }
    state = state.copyWith(items: updated);
    _persist();
  }

  void removeItem(String lineKey) {
    final updated = state.items
        .where((item) => item.lineKey != lineKey)
        .toList();
    state = state.copyWith(items: updated);
    _persist();
  }

  void clear() {
    state = const CartState();
    _persist();
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>(
  (ref) => CartNotifier(),
);
