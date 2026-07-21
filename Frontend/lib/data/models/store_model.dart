// lib/data/models/store_model.dart

class StoreModel {
  final String id;
  final String name;
  final String categoryId; // نفس category_id بالـ Base44
  final String imageUrl;
  final double averageRating;
  final int totalReviews;
  final bool isActive;
  final bool isApproved;
  final String deliveryTime; // مش موجودة بـ Base44 حاليًا - مضافة يدويًا
  final String deliveryFee; // مش موجودة بـ Base44 حاليًا - مضافة يدويًا

  // ✅ جديد: عشان فلو Business Owner (Store Setup Wizard / Pending Approval / Dashboard)
  final String approvalStatus; // Pending | Approved | Rejected
  final String? rejectionReason;
  final String address;
  final String phone;
  final String email;
  final String description;
  final String? openingTime;
  final String? closingTime;

  // ✅ جديد: تصفح/فلاتر/مفضلة/مميز
  final String cuisineType;
  final bool isFeatured;
  final bool isFavorited;
  final bool isOpenNow;
  final double? distanceKm;
  final double? latitude;
  final double? longitude;
  final String? discountLabel; // مثلاً "-20%"، null لو ما في كوبون فعّال

  // ✅ استكمال ربط شاشة إنشاء/إعدادات المتجر (Restaurant/Business dashboard)
  final String city;
  final String region;
  final double minimumOrder;
  final double deliveryFeeInsideCity;
  final double deliveryFeeOutsideCity;
  final double deliveryFeeOccupiedAreas;
  final int prepTimeMinutes;
  final bool supportsDelivery;
  final bool supportsPickup;
  final String? preferredCompanyId;
  final String? requiredVehicleType;

  StoreModel({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.imageUrl,
    this.averageRating = 0.0,
    this.totalReviews = 0,
    this.isActive = true,
    this.isApproved = false,
    this.deliveryTime = '',
    this.deliveryFee = '',
    this.approvalStatus = 'Pending',
    this.rejectionReason,
    this.address = '',
    this.phone = '',
    this.email = '',
    this.description = '',
    this.openingTime,
    this.closingTime,
    this.cuisineType = '',
    this.isFeatured = false,
    this.isFavorited = false,
    this.isOpenNow = true,
    this.distanceKm,
    this.latitude,
    this.longitude,
    this.discountLabel,
    this.city = '',
    this.region = '',
    this.minimumOrder = 0,
    this.deliveryFeeInsideCity = 10,
    this.deliveryFeeOutsideCity = 20,
    this.deliveryFeeOccupiedAreas = 70,
    this.prepTimeMinutes = 10,
    this.supportsDelivery = true,
    this.supportsPickup = false,
    this.preferredCompanyId,
    this.requiredVehicleType,
  });

  factory StoreModel.fromJson(Map<String, dynamic> json) {
    return StoreModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      categoryId: json['category_id']?.toString() ?? '',
      imageUrl: json['image_url'] ?? '',
      averageRating: (json['average_rating'] ?? 0).toDouble(),
      totalReviews: json['total_reviews'] ?? 0,
      isActive: json['is_active'] ?? true,
      isApproved: json['is_approved'] ?? false,
      deliveryTime: json['delivery_time'] ?? '',
      deliveryFee: json['delivery_fee'] ?? '',
      approvalStatus: json['approval_status'] ?? 'Pending',
      rejectionReason: json['rejection_reason'],
      address: json['address'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      description: json['description'] ?? '',
      openingTime: json['opening_time']?.toString(),
      closingTime: json['closing_time']?.toString(),
      cuisineType: json['cuisine_type'] ?? '',
      isFeatured: json['is_featured'] ?? false,
      isFavorited: json['is_favorited'] ?? false,
      isOpenNow: json['is_open_now'] ?? true,
      distanceKm: json['distance_km'] != null ? (json['distance_km'] as num).toDouble() : null,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      discountLabel: json['discount_label'],
      city: json['city'] ?? '',
      region: json['region'] ?? '',
      minimumOrder: double.tryParse(json['minimum_order']?.toString() ?? '') ?? 0,
      deliveryFeeInsideCity: double.tryParse(json['delivery_fee_inside_city']?.toString() ?? '') ?? 10,
      deliveryFeeOutsideCity: double.tryParse(json['delivery_fee_outside_city']?.toString() ?? '') ?? 20,
      deliveryFeeOccupiedAreas: double.tryParse(json['delivery_fee_occupied_areas']?.toString() ?? '') ?? 70,
      prepTimeMinutes: json['prep_time_minutes'] ?? 10,
      supportsDelivery: json['supports_delivery'] ?? true,
      supportsPickup: json['supports_pickup'] ?? false,
      preferredCompanyId: json['preferred_company_id']?.toString(),
      requiredVehicleType: json['required_vehicle_type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category_id': categoryId,
      'image_url': imageUrl,
      'average_rating': averageRating,
      'total_reviews': totalReviews,
      'is_active': isActive,
      'is_approved': isApproved,
      'delivery_time': deliveryTime,
      'delivery_fee': deliveryFee,
      'approval_status': approvalStatus,
      'rejection_reason': rejectionReason,
      'address': address,
      'phone': phone,
      'email': email,
      'description': description,
      'opening_time': openingTime,
      'closing_time': closingTime,
      'cuisine_type': cuisineType,
      'is_featured': isFeatured,
      'is_favorited': isFavorited,
      'is_open_now': isOpenNow,
      'distance_km': distanceKm,
      'latitude': latitude,
      'longitude': longitude,
      'discount_label': discountLabel,
      'city': city,
      'region': region,
      'minimum_order': minimumOrder,
      'delivery_fee_inside_city': deliveryFeeInsideCity,
      'delivery_fee_outside_city': deliveryFeeOutsideCity,
      'delivery_fee_occupied_areas': deliveryFeeOccupiedAreas,
      'prep_time_minutes': prepTimeMinutes,
      'supports_delivery': supportsDelivery,
      'supports_pickup': supportsPickup,
      'preferred_company_id': preferredCompanyId,
      'required_vehicle_type': requiredVehicleType,
    };
  }
}
