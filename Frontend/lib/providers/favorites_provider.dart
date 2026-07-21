// lib/providers/favorites_provider.dart
//
// مجموعة معرّفات المتاجر المفضلة لدى المستخدم الحالي (Set<storeId>) - محدثة
// تفاؤليًا (optimistic) عند التبديل، مع تراجع (rollback) لو فشل الطلب.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/favorite_service.dart';

final favoriteServiceProvider = Provider<FavoriteService>((ref) => FavoriteService());

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, Set<String>>((ref) {
  return FavoritesNotifier(ref.read(favoriteServiceProvider));
});

class FavoritesNotifier extends StateNotifier<Set<String>> {
  final FavoriteService _service;
  bool _loaded = false;

  FavoritesNotifier(this._service) : super(<String>{});

  /// يجيب قائمة المفضلة الحقيقية من الباك إند (يُستدعى مرة وحدة بعد تسجيل
  /// الدخول أو أول ما تنفتح شاشة تصفح للمستخدم المسجل).
  Future<void> loadInitial() async {
    if (_loaded) return;
    _loaded = true;
    final stores = await _service.listFavorites();
    state = stores.map((s) => s.id).toSet();
  }

  void reset() {
    _loaded = false;
    state = <String>{};
  }

  /// يستبدل المجموعة كاملة (تُستخدم من شاشة "مفضلتي" بعد إعادة الجلب،
  /// عشان تضل القلوب متوافقة بباقي الشاشات).
  void setAll(Set<String> ids) {
    _loaded = true;
    state = ids;
  }

  /// تبديل حالة المفضلة لمتجر معيّن - تحديث فوري بالواجهة، وتراجع لو فشل الطلب.
  Future<bool> toggle(String storeId) async {
    final wasFavorited = state.contains(storeId);
    state = wasFavorited ? ({...state}..remove(storeId)) : ({...state}..add(storeId));

    final result = wasFavorited
        ? await _service.removeFavorite(storeId)
        : await _service.addFavorite(storeId);

    if (!result.success) {
      state = wasFavorited ? ({...state}..add(storeId)) : ({...state}..remove(storeId));
      return false;
    }
    return true;
  }

  bool isFavorited(String storeId) => state.contains(storeId);
}

// ===========================
// مفضلة المنتجات (Set<productId>) - نفس منطق FavoritesNotifier، بس ما في
// "جلب كل المفضلة" لأنو ما في شاشة تعرض المنتجات المفضلة لسا؛ الحالة
// الابتدائية بتيجي من is_favorited الراجعة مع كل منتج (seed عبر setFavorited).
final favoriteProductsProvider =
    StateNotifierProvider<FavoriteProductsNotifier, Set<String>>((ref) {
  return FavoriteProductsNotifier(ref.read(favoriteServiceProvider));
});

class FavoriteProductsNotifier extends StateNotifier<Set<String>> {
  final FavoriteService _service;

  FavoriteProductsNotifier(this._service) : super(<String>{});

  /// يسجل الحالة الابتدائية لمنتج معيّن (من is_favorited الراجعة مع المنتج)
  /// بدون ما يلغي حالة بقية المنتجات المسجلة مسبقاً.
  void seed(String productId, bool isFavorited) {
    if (isFavorited && !state.contains(productId)) {
      state = {...state, productId};
    } else if (!isFavorited && state.contains(productId)) {
      state = {...state}..remove(productId);
    }
  }

  Future<bool> toggle(String productId) async {
    final wasFavorited = state.contains(productId);
    state = wasFavorited ? ({...state}..remove(productId)) : ({...state}..add(productId));

    final result = wasFavorited
        ? await _service.removeFavoriteProduct(productId)
        : await _service.addFavoriteProduct(productId);

    if (!result.success) {
      state = wasFavorited ? ({...state}..add(productId)) : ({...state}..remove(productId));
      return false;
    }
    return true;
  }

  bool isFavorited(String productId) => state.contains(productId);
}
