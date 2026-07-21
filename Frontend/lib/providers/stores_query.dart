// lib/providers/stores_query.dart
//
// كائن غير قابل للتعديل يمثل حالة البحث/الفلاتر/الترتيب لقائمة المتاجر.
// يُستخدم كمفتاح/حالة لـ StoresListNotifier عشان نعرف نعيد الجلب من صفحة 1
// كل ما تغيّر أي فلتر.
class StoresQuery {
  final String? categoryId;
  final String? search;
  final double? minRating;
  final double? maxPrice;
  final String? cuisineType;
  final bool openNow;
  final bool featuredOnly;
  final String sortBy; // 'rating' | 'distance' | 'popularity' | 'newest'
  final double? lat;
  final double? lng;

  const StoresQuery({
    this.categoryId,
    this.search,
    this.minRating,
    this.maxPrice,
    this.cuisineType,
    this.openNow = false,
    this.featuredOnly = false,
    this.sortBy = 'rating',
    this.lat,
    this.lng,
  });

  StoresQuery copyWith({
    String? categoryId,
    bool clearCategoryId = false,
    String? search,
    bool clearSearch = false,
    double? minRating,
    bool clearMinRating = false,
    double? maxPrice,
    bool clearMaxPrice = false,
    String? cuisineType,
    bool clearCuisineType = false,
    bool? openNow,
    bool? featuredOnly,
    String? sortBy,
    double? lat,
    double? lng,
  }) {
    return StoresQuery(
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      search: clearSearch ? null : (search ?? this.search),
      minRating: clearMinRating ? null : (minRating ?? this.minRating),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      cuisineType: clearCuisineType ? null : (cuisineType ?? this.cuisineType),
      openNow: openNow ?? this.openNow,
      featuredOnly: featuredOnly ?? this.featuredOnly,
      sortBy: sortBy ?? this.sortBy,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StoresQuery &&
        other.categoryId == categoryId &&
        other.search == search &&
        other.minRating == minRating &&
        other.maxPrice == maxPrice &&
        other.cuisineType == cuisineType &&
        other.openNow == openNow &&
        other.featuredOnly == featuredOnly &&
        other.sortBy == sortBy &&
        other.lat == lat &&
        other.lng == lng;
  }

  @override
  int get hashCode => Object.hash(
        categoryId,
        search,
        minRating,
        maxPrice,
        cuisineType,
        openNow,
        featuredOnly,
        sortBy,
        lat,
        lng,
      );
}
