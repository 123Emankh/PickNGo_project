// lib/providers/store_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/store_model.dart';
import '../services/store_service.dart';

final storeServiceProvider = Provider<StoreService>((ref) => StoreService());

final storeProvider = StateNotifierProvider<StoreNotifier, StoreState>((ref) {
  return StoreNotifier(ref.read(storeServiceProvider));
});

class StoreState {
  final bool isLoading;
  final bool isInitialized; // ✅ صار عندنا أول رد فعلي من السيرفر (مو أول تحميل بس)
  final StoreModel? store; // null = المستخدم لسا ما عمل متجر
  final String? error;
  final bool actionSuccess; // ✅ للـ create/update عشان نعرف نعمل navigate

  StoreState({
    this.isLoading = false,
    this.isInitialized = false,
    this.store,
    this.error,
    this.actionSuccess = false,
  });

  StoreState copyWith({
    bool? isLoading,
    bool? isInitialized,
    StoreModel? store,
    bool clearStore = false,
    String? error,
    bool clearError = false,
    bool? actionSuccess,
  }) {
    return StoreState(
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      store: clearStore ? null : (store ?? this.store),
      error: clearError ? null : (error ?? this.error),
      actionSuccess: actionSuccess ?? this.actionSuccess,
    );
  }

  bool get hasStore => store != null;
}

class StoreNotifier extends StateNotifier<StoreState> {
  final StoreService _storeService;

  StoreNotifier(this._storeService) : super(StoreState());

  Future<void> fetchMyStore() async {
    state = state.copyWith(isLoading: true, clearError: true, actionSuccess: false);
    final result = await _storeService.getMyStore();

    if (result.success) {
      state = state.copyWith(
        isLoading: false,
        isInitialized: true,
        store: result.store,
        clearStore: result.store == null,
      );
    } else {
      state = state.copyWith(isLoading: false, isInitialized: true, error: result.message);
    }
  }

  Future<bool> createStore({
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
    state = state.copyWith(isLoading: true, clearError: true, actionSuccess: false);

    final result = await _storeService.createStore(
      name: name,
      description: description,
      categoryId: categoryId,
      cuisineType: cuisineType,
      imageUrl: imageUrl,
      address: address,
      locationLat: locationLat,
      locationLng: locationLng,
      city: city,
      region: region,
      phone: phone,
      email: email,
      openingTime: openingTime,
      closingTime: closingTime,
      minimumOrder: minimumOrder,
      deliveryFeeInsideCity: deliveryFeeInsideCity,
      deliveryFeeOutsideCity: deliveryFeeOutsideCity,
      deliveryFeeOccupiedAreas: deliveryFeeOccupiedAreas,
      prepTimeMinutes: prepTimeMinutes,
      supportsDelivery: supportsDelivery,
      supportsPickup: supportsPickup,
    );

    if (result.success) {
      state = state.copyWith(isLoading: false, store: result.store, actionSuccess: true);
      return true;
    }
    state = state.copyWith(isLoading: false, error: result.message, actionSuccess: false);
    return false;
  }

  Future<bool> updateMyStore(Map<String, dynamic> fields) async {
    state = state.copyWith(isLoading: true, clearError: true, actionSuccess: false);
    final result = await _storeService.updateMyStore(fields);

    if (result.success) {
      state = state.copyWith(isLoading: false, store: result.store, actionSuccess: true);
      return true;
    }
    state = state.copyWith(isLoading: false, error: result.message, actionSuccess: false);
    return false;
  }

  void clearError() => state = state.copyWith(clearError: true);
}
