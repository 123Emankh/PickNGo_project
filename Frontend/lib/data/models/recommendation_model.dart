// lib/data/models/recommendation_model.dart
//
// نماذج التوصية (Recommendation Engine) - غلاف بسيط فوق StoreModel/ProductModel
// الموجودين أصلًا، بيضيف بس سبب/درجة التوصية الراجعين من الباك إند.
import 'store_model.dart';
import 'product_model.dart';

class RecommendedStore {
  final StoreModel store;
  final double score;
  final String reason;

  RecommendedStore({required this.store, required this.score, required this.reason});

  factory RecommendedStore.fromJson(Map<String, dynamic> json) {
    return RecommendedStore(
      store: StoreModel.fromJson(json),
      score: (json['recommendation_score'] ?? 0).toDouble(),
      reason: json['recommendation_reason'] ?? '',
    );
  }
}

class RecommendedProduct {
  final ProductModel product;
  final double score;
  final String reason;

  RecommendedProduct({required this.product, required this.score, required this.reason});

  factory RecommendedProduct.fromJson(Map<String, dynamic> json) {
    return RecommendedProduct(
      product: ProductModel.fromJson(json),
      score: (json['recommendation_score'] ?? 0).toDouble(),
      reason: json['recommendation_reason'] ?? '',
    );
  }
}
