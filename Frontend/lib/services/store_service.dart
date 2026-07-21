// lib/services/store_service.dart
import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import '../data/models/store_model.dart';
import '../data/models/product_model.dart';
import '../data/models/category_model.dart';
import '../data/models/analytics_model.dart';
import 'api_service.dart';

/// نتيجة عامة لعمليات المتجر (بديل بسيط لـ AuthResponse بس لهاد الدومين)
class StoreResult {
  final bool success;
  final String message;
  final StoreModel? store;

  StoreResult({required this.success, required this.message, this.store});
}

/// نتيجة صفحة من قائمة المتاجر (بحث/فلاتر/ترتيب/ترقيم)
class StoresPageResult {
  final bool success;
  final List<StoreModel> stores;
  final int total;
  final int page;
  final int limit;
  final bool hasMore;

  StoresPageResult({
    required this.success,
    this.stores = const [],
    this.total = 0,
    this.page = 1,
    this.limit = 20,
    this.hasMore = false,
  });
}

/// نتيجة تفاصيل متجر + منتجاته (لشاشة StoreDetailScreen الخاصة بالزبون)
class StoreDetailResult {
  final bool success;
  final String message;
  final StoreModel? store;
  final List<ProductModel> products;

  StoreDetailResult({
    required this.success,
    this.message = '',
    this.store,
    this.products = const [],
  });
}

class StoreService {
  final ApiService _apiService = ApiService();

  /// جلب قائمة كل المتاجر المعتمدة والفعالة (عامة - تُستخدم بشاشات
  /// Home/Landing/Stores لتصفح الزبون). فلترة اختيارية حسب الفئة.
  Future<List<StoreModel>> listStores({String? categoryId}) async {
    try {
      final response = await _apiService.get(
        ApiConstants.stores,
        queryParameters: categoryId != null ? {'category_id': categoryId} : null,
      );
      final data = response.data;
      if (data['success'] == true && data['stores'] != null) {
        return (data['stores'] as List)
            .map((s) => StoreModel.fromJson(s))
            .toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('listStores error: $e');
      return [];
    }
  }

  /// جلب صفحة من المتاجر مع بحث/فلاتر/ترتيب/موقع - تُستخدم بشاشة StoresScreen/Home
  /// (بديل عن listStores لما نحتاج بحث/فلاتر/ترتيب/تحميل صفحات إضافية)
  Future<StoresPageResult> listStoresPaged({
    String? categoryId,
    String? search,
    double? minRating,
    double? maxPrice,
    String? cuisineType,
    bool? openNow,
    bool? featuredOnly,
    bool? freeDelivery,
    bool? hasDiscount,
    String? sortBy,
    double? lat,
    double? lng,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final query = <String, dynamic>{'page': page, 'limit': limit};
      if (categoryId != null) query['category_id'] = categoryId;
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (minRating != null) query['min_rating'] = minRating;
      if (maxPrice != null) query['max_price'] = maxPrice;
      if (cuisineType != null && cuisineType.isNotEmpty) query['cuisine_type'] = cuisineType;
      if (openNow == true) query['open_now'] = 'true';
      if (featuredOnly == true) query['featured_only'] = 'true';
      if (freeDelivery == true) query['free_delivery'] = 'true';
      if (hasDiscount == true) query['has_discount'] = 'true';
      if (sortBy != null) query['sort'] = sortBy;
      if (lat != null) query['lat'] = lat;
      if (lng != null) query['lng'] = lng;

      final response = await _apiService.get(ApiConstants.stores, queryParameters: query);
      final data = response.data;
      if (data['success'] == true) {
        return StoresPageResult(
          success: true,
          stores: (data['stores'] as List).map((s) => StoreModel.fromJson(s)).toList(),
          total: data['total'] ?? 0,
          page: data['page'] ?? page,
          limit: data['limit'] ?? limit,
          hasMore: data['has_more'] ?? false,
        );
      }
      return StoresPageResult(success: false);
    } catch (e) {
      if (kDebugMode) print('listStoresPaged error: $e');
      return StoresPageResult(success: false);
    }
  }

  /// جلب المنتجات "الأكثر رواجًا" عبر كل المتاجر (تُستخدم بقسم Trending Products بالـ Home)
  Future<List<ProductModel>> getPopularProducts({int limit = 8}) async {
    try {
      final response = await _apiService.get(
        ApiConstants.popularProducts,
        queryParameters: {'limit': limit},
      );
      final data = response.data;
      if (data['success'] == true && data['products'] != null) {
        return (data['products'] as List).map((p) => ProductModel.fromJson(p)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('getPopularProducts error: $e');
      return [];
    }
  }

  /// جلب المنتجات "وصل حديثًا" عبر كل المتاجر (الأحدث أولًا) - تُستخدم
  /// بشاشة NewArrivalsScreen (اختصار "وصل حديثًا" بالصفحة الرئيسية)
  Future<List<ProductModel>> getNewArrivals({int limit = 20}) async {
    try {
      final response = await _apiService.get(
        ApiConstants.newArrivals,
        queryParameters: {'limit': limit},
      );
      final data = response.data;
      if (data['success'] == true && data['products'] != null) {
        return (data['products'] as List).map((p) => ProductModel.fromJson(p)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('getNewArrivals error: $e');
      return [];
    }
  }

  /// جلب تفاصيل متجر معيّن (عام) + منتجاته سوا - تُستخدم بشاشة StoreDetailScreen.
  /// lat/lng اختياريين (موقع الزبون الحالي) - لو انبعتوا، الباك إند بيرجع
  /// distance_km حقيقي محسوب بالإحداثيات (haversine)، تمامًا متل getStores.
  Future<StoreDetailResult> getStoreDetail(String storeId, {double? lat, double? lng}) async {
    try {
      final query = <String, dynamic>{};
      if (lat != null) query['lat'] = lat;
      if (lng != null) query['lng'] = lng;
      final response = await _apiService.get(
        '${ApiConstants.stores}/$storeId',
        queryParameters: query.isEmpty ? null : query,
      );
      final data = response.data;
      if (data['success'] == true && data['store'] != null) {
        return StoreDetailResult(
          success: true,
          store: StoreModel.fromJson(data['store']),
          products: data['products'] != null
              ? (data['products'] as List)
                  .map((p) => ProductModel.fromJson(p))
                  .toList()
              : [],
        );
      }
      return StoreDetailResult(success: false, message: 'Store not found');
    } catch (e) {
      if (kDebugMode) print('getStoreDetail error: $e');
      return StoreDetailResult(
        success: false,
        message: 'Network error while fetching store details',
      );
    }
  }

  /// جلب قائمة الفئات الحقيقية من الباك إند (تُستخدم بفورم Create Store
  /// بدل mockCategories، لأن category_id هون Foreign Key رقمي حقيقي).
  Future<List<CategoryModel>> getCategories() async {
    try {
      final response = await _apiService.get(ApiConstants.storeCategories);
      final data = response.data;
      if (data['success'] == true && data['categories'] != null) {
        return (data['categories'] as List)
            .map((c) => CategoryModel.fromJson(c))
            .toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('getCategories error: $e');
      return [];
    }
  }

  /// جلب متجر صاحب الحساب الحالي. لو ما عندو متجر لسا -> store == null و success == true
  Future<StoreResult> getMyStore() async {
    try {
      final response = await _apiService.get(ApiConstants.myStore);
      final data = response.data;

      if (data['success'] == true && data['store'] != null) {
        return StoreResult(
          success: true,
          message: '',
          store: StoreModel.fromJson(data['store']),
        );
      }
      return StoreResult(success: true, message: 'no_store', store: null);
    } catch (e) {
      if (kDebugMode) print('getMyStore error: $e');
      return StoreResult(
        success: false,
        message: 'Network error while fetching your store',
      );
    }
  }

  /// تحليلات متجري (أكثر المنتجات مبيعًا، ساعات الذروة، متوسط قيمة الطلب،
  /// نسبة الإلغاء، العملاء المتكررون) - قائمة/رسوم بيانية بلوحة التاجر
  Future<StoreAnalyticsModel?> getMyStoreAnalytics() async {
    try {
      final response = await _apiService.get(ApiConstants.myStoreAnalytics);
      final data = response.data;
      if (data['success'] == true && data['analytics'] != null) {
        return StoreAnalyticsModel.fromJson(data['analytics']);
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('getMyStoreAnalytics error: $e');
      return null;
    }
  }

  /// إنشاء متجر جديد (خطوة Store Setup Wizard الأولى)
  Future<StoreResult> createStore({
    required String name,
    String? description,
    required String categoryId,
    String? cuisineType,
    String? imageUrl,
    required String address,
    required double locationLat,
    required double locationLng,
    required String city,
    required String region,
    required String phone,
    String? email,
    String? openingTime,
    String? closingTime,
    double? minimumOrder,
    double? deliveryFeeInsideCity,
    double? deliveryFeeOutsideCity,
    double? deliveryFeeOccupiedAreas,
    int? prepTimeMinutes,
    bool? supportsDelivery,
    bool? supportsPickup,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.stores,
        data: {
          'name': name,
          'description': description,
          'category_id': categoryId,
          'cuisine_type': cuisineType,
          'image_url': imageUrl,
          'address': address,
          'location_lat': locationLat,
          'location_lng': locationLng,
          'city': city,
          'region': region,
          'phone': phone,
          'email': email,
          'opening_time': openingTime,
          'closing_time': closingTime,
          'minimum_order': minimumOrder,
          'delivery_fee_inside_city': deliveryFeeInsideCity,
          'delivery_fee_outside_city': deliveryFeeOutsideCity,
          'delivery_fee_occupied_areas': deliveryFeeOccupiedAreas,
          'prep_time_minutes': prepTimeMinutes,
          'supports_delivery': supportsDelivery,
          'supports_pickup': supportsPickup,
        },
      );

      final data = response.data;
      return StoreResult(
        success: data['success'] ?? false,
        message: data['message'] ?? '',
        store: data['store'] != null
            ? StoreModel.fromJson(data['store'])
            : null,
      );
    } catch (e) {
      if (kDebugMode) print('createStore error: $e');
      return StoreResult(
        success: false,
        message: 'Network error while creating your store',
      );
    }
  }

  /// تعديل بيانات المتجر (تُستخدم أساسًا لإعادة التقديم بعد الرفض، وكمان من
  /// شاشة Settings بالداشبورد)
  Future<StoreResult> updateMyStore(Map<String, dynamic> fields) async {
    try {
      final response = await _apiService.put(
        ApiConstants.myStore,
        data: fields,
      );
      final data = response.data;
      return StoreResult(
        success: data['success'] ?? false,
        message: data['message'] ?? '',
        store: data['store'] != null
            ? StoreModel.fromJson(data['store'])
            : null,
      );
    } catch (e) {
      if (kDebugMode) print('updateMyStore error: $e');
      return StoreResult(
        success: false,
        message: 'Network error while updating your store',
      );
    }
  }

  /// جلب منتجات محل معيّن (تُستخدم بتبويب "المنتجات/المنيو" بالداشبورد)
  Future<List<ProductModel>> getStoreProducts(String storeId) async {
    try {
      final response = await _apiService.get('${ApiConstants.stores}/$storeId');
      final data = response.data;
      if (data['success'] == true && data['products'] != null) {
        return (data['products'] as List)
            .map((p) => ProductModel.fromJson(p))
            .toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('getStoreProducts error: $e');
      return [];
    }
  }

  /// إضافة منتج/صنف جديد لمنيو المحل
  Future<StoreResult> addProduct({
    required String storeId,
    required String name,
    String? description,
    String? imageUrl,
    required double price,
    List<String>? images,
    List<Map<String, dynamic>>? variants,
    List<Map<String, dynamic>>? addons,
    List<String>? exclusions,
    List<Map<String, dynamic>>? optionGroups,
    bool isFeatured = false,
  }) async {
    try {
      final response = await _apiService.post(
        '${ApiConstants.stores}/$storeId/products',
        data: {
          'name': name,
          'description': description,
          'image_url': imageUrl,
          'price': price,
          'is_featured': isFeatured,
          'images': ?images,
          'variants': ?variants,
          'addons': ?addons,
          'exclusions': ?exclusions,
          'option_groups': ?optionGroups,
        },
      );
      final data = response.data;
      return StoreResult(
        success: data['success'] ?? false,
        message: data['message'] ?? '',
      );
    } catch (e) {
      if (kDebugMode) print('addProduct error: $e');
      return StoreResult(
        success: false,
        message: 'Network error while adding product',
      );
    }
  }

  /// تعديل منتج موجود
  Future<StoreResult> updateProduct({
    required String storeId,
    required String productId,
    required String name,
    String? description,
    String? imageUrl,
    required double price,
    bool? inStock,
    List<String>? images,
    List<Map<String, dynamic>>? variants,
    List<Map<String, dynamic>>? addons,
    List<String>? exclusions,
    List<Map<String, dynamic>>? optionGroups,
    bool? isFeatured,
  }) async {
    try {
      final response = await _apiService.put(
        '${ApiConstants.stores}/$storeId/products/$productId',
        data: {
          'name': name,
          'description': description,
          'image_url': imageUrl,
          'price': price,
          'in_stock': ?inStock,
          'is_featured': ?isFeatured,
          'images': ?images,
          'variants': ?variants,
          'addons': ?addons,
          'exclusions': ?exclusions,
          'option_groups': ?optionGroups,
        },
      );
      final data = response.data;
      return StoreResult(
        success: data['success'] ?? false,
        message: data['message'] ?? '',
      );
    } catch (e) {
      if (kDebugMode) print('updateProduct error: $e');
      return StoreResult(
        success: false,
        message: 'Network error while updating product',
      );
    }
  }

  /// حذف منتج
  Future<StoreResult> deleteProduct({
    required String storeId,
    required String productId,
  }) async {
    try {
      final response = await _apiService.delete(
        '${ApiConstants.stores}/$storeId/products/$productId',
      );
      final data = response.data;
      return StoreResult(
        success: data['success'] ?? false,
        message: data['message'] ?? '',
      );
    } catch (e) {
      if (kDebugMode) print('deleteProduct error: $e');
      return StoreResult(
        success: false,
        message: 'Network error while deleting product',
      );
    }
  }
}
