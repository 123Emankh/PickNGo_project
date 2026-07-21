// lib/data/models/user_model.dart
class UserModel {
  final int userId;
  final String fullName;
  final String email;
  final String? phone;  // ✅ nullable
  final String? profilePicture;  // ✅ nullable
  final String role;
  final String? businessType;  // ✅ Restaurant/Pharmacy/Furniture/Other لأصحاب المحلات
  final String status;
  final bool isVerified;
  final bool isActive;
  final String? locationAddress;  // ✅ nullable
  final String? city;  // ✅ nullable
  final String? region;  // ✅ nullable
  final DateTime? lastLogin;  // ✅ nullable
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? driverStatus;  // ✅ Offline/Available/Busy - للسائقين بس

  UserModel({
    required this.userId,
    required this.fullName,
    required this.email,
    this.phone,
    this.profilePicture,
    required this.role,
    this.businessType,
    required this.status,
    required this.isVerified,
    required this.isActive,
    this.locationAddress,
    this.city,
    this.region,
    this.lastLogin,
    required this.createdAt,
    required this.updatedAt,
    this.driverStatus,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['user_id'] ?? json['userId'] ?? 0,
      fullName: json['full_name'] ?? json['fullName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone']?.toString(),  // ✅ تحويل آمن
      profilePicture: json['profile_picture'] ?? json['profilePicture'],
      role: json['role'] ?? 'Customer',
      businessType: json['business_type'] ?? json['businessType'],
      status: json['status'] ?? 'Pending',
      isVerified: json['is_verified'] ?? json['isVerified'] ?? false,
      isActive: json['is_active'] ?? json['isActive'] ?? true,
      locationAddress: json['location_address'] ?? json['locationAddress'],
      city: json['city'],
      region: json['region'],
      lastLogin: json['last_login'] != null 
          ? DateTime.parse(json['last_login']) 
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      driverStatus: json['driver_status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'profile_picture': profilePicture,
      'role': role,
      'business_type': businessType,
      'status': status,
      'is_verified': isVerified,
      'is_active': isActive,
      'location_address': locationAddress,
      'city': city,
      'region': region,
      'last_login': lastLogin?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'driver_status': driverStatus,
    };
  }

  UserModel copyWith({
    int? userId,
    String? fullName,
    String? email,
    String? phone,
    String? profilePicture,
    String? role,
    String? businessType,
    String? status,
    bool? isVerified,
    bool? isActive,
    String? locationAddress,
    String? city,
    String? region,
    DateTime? lastLogin,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? driverStatus,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profilePicture: profilePicture ?? this.profilePicture,
      role: role ?? this.role,
      businessType: businessType ?? this.businessType,
      status: status ?? this.status,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      locationAddress: locationAddress ?? this.locationAddress,
      city: city ?? this.city,
      region: region ?? this.region,
      lastLogin: lastLogin ?? this.lastLogin,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      driverStatus: driverStatus ?? this.driverStatus,
    );
  }
}