// lib/providers/catalog_provider.dart
//
// بيانات تصفح الزبون (فئات/متاجر/تفاصيل متجر) - حقيقية من الباك إند.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/category_model.dart';
import 'store_provider.dart';
import '../services/store_service.dart';

final categoriesProvider = FutureProvider<List<CategoryModel>>((ref) {
  return ref.read(storeServiceProvider).getCategories();
});

// ملاحظة: قائمة تصفح المتاجر (بحث/فلاتر/ترتيب/تحميل صفحات) انتقلت لـ
// storesListNotifierProvider بملف stores_list_provider.dart (StateNotifier
// بيدعم "تحميل المزيد" وحالة تحميل منفصلة، شيء ما كان ممكن بـ FutureProvider.family).

/// مفتاح storeDetailProvider: storeId + موقع الزبون الحالي (اختياري) عشان
/// الباك إند يرجّع distance_km حقيقي بغض النظر عن مصدر الدخول للشاشة (من
/// قائمة عندها موقع أصلًا، أو دخول مباشر/رابط ما عنده سياق موقع).
class StoreDetailParams {
  final String storeId;
  final double? lat;
  final double? lng;

  const StoreDetailParams(this.storeId, {this.lat, this.lng});

  @override
  bool operator ==(Object other) =>
      other is StoreDetailParams &&
      other.storeId == storeId &&
      other.lat == lat &&
      other.lng == lng;

  @override
  int get hashCode => Object.hash(storeId, lat, lng);
}

final storeDetailProvider =
    FutureProvider.family<StoreDetailResult, StoreDetailParams>((ref, params) {
  return ref
      .read(storeServiceProvider)
      .getStoreDetail(params.storeId, lat: params.lat, lng: params.lng);
});
