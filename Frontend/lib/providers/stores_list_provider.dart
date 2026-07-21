// lib/providers/stores_list_provider.dart
//
// حالة قائمة تصفح المتاجر (بحث/فلاتر/ترتيب) مع دعم "تحميل المزيد" (pagination).
// StateNotifier بدل FutureProvider.family لأنه لازم نراكم صفحات ونعرف حالة
// تحميل منفصلة لأول تحميل عن "تحميل المزيد" بالأسفل.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/store_model.dart';
import '../services/store_service.dart';
import 'store_provider.dart';
import 'stores_query.dart';

class StoresListState {
  final bool isLoading;
  final bool isLoadingMore;
  final List<StoreModel> stores;
  final int page;
  final bool hasMore;
  final String? error;
  final StoresQuery query;

  StoresListState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.stores = const [],
    this.page = 1,
    this.hasMore = true,
    this.error,
    this.query = const StoresQuery(),
  });

  StoresListState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<StoreModel>? stores,
    int? page,
    bool? hasMore,
    String? error,
    bool clearError = false,
    StoresQuery? query,
  }) {
    return StoresListState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      stores: stores ?? this.stores,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      query: query ?? this.query,
    );
  }
}

final storesListNotifierProvider =
    StateNotifierProvider<StoresListNotifier, StoresListState>((ref) {
  return StoresListNotifier(ref.read(storeServiceProvider));
});

class StoresListNotifier extends StateNotifier<StoresListState> {
  final StoreService _service;
  static const _limit = 20;

  StoresListNotifier(this._service) : super(StoresListState());

  /// يطبّق فلتر/بحث/ترتيب جديد ويعيد الجلب من الصفحة 1
  Future<void> updateQuery(StoresQuery query) async {
    state = StoresListState(isLoading: true, query: query);
    final result = await _fetch(query, page: 1);
    if (result.success) {
      state = state.copyWith(
        isLoading: false,
        stores: result.stores,
        page: 1,
        hasMore: result.hasMore,
        clearError: true,
      );
    } else {
      state = state.copyWith(isLoading: false, error: 'failed_to_load_stores');
    }
  }

  /// يحمّل الصفحة التالية ويضيفها لآخر القائمة الحالية
  Future<void> loadMore() async {
    if (state.isLoadingMore || state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    final nextPage = state.page + 1;
    final result = await _fetch(state.query, page: nextPage);
    if (result.success) {
      state = state.copyWith(
        isLoadingMore: false,
        stores: [...state.stores, ...result.stores],
        page: nextPage,
        hasMore: result.hasMore,
      );
    } else {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<StoresPageResult> _fetch(StoresQuery q, {required int page}) {
    return _service.listStoresPaged(
      categoryId: q.categoryId,
      search: q.search,
      minRating: q.minRating,
      maxPrice: q.maxPrice,
      cuisineType: q.cuisineType,
      openNow: q.openNow,
      featuredOnly: q.featuredOnly,
      sortBy: q.sortBy,
      lat: q.lat,
      lng: q.lng,
      page: page,
      limit: _limit,
    );
  }
}
