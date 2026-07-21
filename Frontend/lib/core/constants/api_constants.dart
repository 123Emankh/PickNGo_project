// lib/core/constants/api_constants.dart
import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConstants {
  // Base URL - يتم تحديدها تلقائياً حسب البيئة
  static String get baseUrl {
    // Web - يعمل على localhost
    if (kIsWeb) {
      return 'http://localhost:5000';
    }
    
    // Mobile - كشف البيئة
    if (Platform.isAndroid) {
      // Android Emulator
      return 'http://10.0.2.2:5000';
    } else if (Platform.isIOS) {
      // iOS Emulator
      return 'http://localhost:5000';
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      // Desktop - نفس الجهاز اللي شغال عليه الباك إند
      return 'http://localhost:5000';
    }

    // Real Device (استخدمي IP جهازك)
    return 'http://192.168.1.100:5000';
  }
  
  // أو استخدمي متغير بيئة
  static const String devUrl = 'http://localhost:5000';
  static const String prodUrl = 'https://your-production-url.com';
  
  // Auth Endpoints
  static const String signup = '/api/auth/signup';
  static const String verifySignup = '/api/auth/verify-signup';
  static const String resendOtp = '/api/auth/resend-otp';
  static const String login = '/api/auth/login';
  static const String forgotPassword = '/api/auth/forgot-password';
  static const String resetPassword = '/api/auth/reset-password';
  static const String verifyOtp = '/api/auth/verify-otp';
  static const String logout = '/api/auth/logout';
  static const String profile = '/api/auth/profile';
  static const String updateProfile = '/api/auth/profile';
  static const String changePassword = '/api/auth/profile/change-password';
  static const String uploadAvatar = '/api/auth/profile/avatar';

  // Store (Business Owner) Endpoints
  static const String stores = '/api/stores';
  static const String myStore = '/api/stores/my-store';
  static const String storeCategories = '/api/stores/categories';
  static const String popularProducts = '/api/stores/popular-products';
  static const String newArrivals = '/api/stores/new-arrivals';

  // Favorites Endpoints
  static const String favorites = '/api/favorites';
  static String favoriteToggle(String storeId) => '/api/favorites/$storeId';
  static String favoriteProductToggle(String productId) => '/api/favorites/products/$productId';

  // Order Endpoints
  static const String orders = '/api/orders';
  static const String myOrders = '/api/orders/my';
  static const String availableOrders = '/api/orders/available';
  static String orderStatus(String orderId) => '/api/orders/$orderId/status';
  static String orderTracking(String orderId) => '/api/orders/$orderId/tracking';
  static String deliveryGroupDetail(String groupId) => '/api/orders/groups/$groupId';
  static String deliveryGroupAccept(String groupId) => '/api/orders/groups/$groupId/accept';
  static const String myPendingOffer = '/api/orders/offers/mine';
  static String respondToOffer(String orderId) => '/api/orders/$orderId/offer/respond';
  static String respondToGroupOffer(String groupId) => '/api/orders/groups/$groupId/offer/respond';

  // Notification Endpoints (Phase 4)
  static const String notifications = '/api/notifications';
  static String notificationRead(String id) => '/api/notifications/$id/read';
  static const String notificationReadAll = '/api/notifications/read-all';

  // Payment Endpoints (HyperPay Copy&Pay)
  static const String paymentCheckout = '/api/payments/checkout';
  static String paymentStatus(String orderId) => '/api/payments/status/$orderId';

  // Delivery Company Endpoints
  static const String companyList = '/api/company/list';
  static const String companyRoster = '/api/company/roster';
  static const String companyJoinRequests = '/api/company/join-requests';
  static String companyApproveJoinRequest(String driverId) => '/api/company/join-requests/$driverId/approve';
  static String companyRejectJoinRequest(String driverId) => '/api/company/join-requests/$driverId/reject';
  static String companyRemoveDriver(String driverId) => '/api/company/roster/$driverId';
  static String companySetDriverActive(String driverId) => '/api/company/roster/$driverId/active';

  // Driver Availability Endpoints
  static const String driverStatus = '/api/drivers/status';
  static const String driverLocationPing = '/api/drivers/location';
  static const String driverPerformance = '/api/drivers/performance';

  // Recommendation Endpoints (rule/statistics-based, no ML)
  static const String recommendedStores = '/api/recommendations/stores';
  static const String recommendedProducts = '/api/recommendations/products';

  // Store Analytics
  static const String myStoreAnalytics = '/api/stores/my-store/analytics';

  // AI Chatbot Endpoints (Google Gemini)
  static const String aiChatMessage = '/api/ai/message';
  static const String aiChatHistory = '/api/ai/history';

  // Review Endpoints
  static const String reviews = '/api/reviews';
  static String reviewForOrder(String orderId) => '/api/reviews/order/$orderId';
  static String reviewById(String reviewId) => '/api/reviews/$reviewId';
  static String storeReviews(String storeId) => '/api/stores/$storeId/reviews';
  static String productReviews(String productId) => '/api/reviews/product/$productId';
  static String myReviewsForOrders(List<String> orderIds) =>
      '/api/reviews/mine?order_ids=${orderIds.join(',')}';

  // Loyalty & Rewards Endpoints
  static String myLoyalty({int page = 1, int limit = 20}) =>
      '/api/loyalty/me?page=$page&limit=$limit';
  static const String previewPointsRedemption = '/api/loyalty/preview-redemption';

  // Coupon Endpoints
  static const String couponValidate = '/api/coupons/validate';
  static const String activeCoupons = '/api/coupons/active';
  static const String coupons = '/api/coupons';
  static const String myCoupons = '/api/coupons/my';
  static String couponById(String couponId) => '/api/coupons/$couponId';
  static const String adminCoupons = '/api/admin/coupons';

  // Admin Endpoints
  static const String adminDashboard = '/api/admin/dashboard';
  static const String adminStores = '/api/admin/stores';
  static const String adminUsers = '/api/admin/users';
  static const String adminDrivers = '/api/admin/drivers';
  static const String adminCategories = '/api/admin/categories';
  static const String adminOrders = '/api/admin/orders';
  static String adminApproveStore(String storeId) => '/api/admin/stores/$storeId/approve';
  static String adminRejectStore(String storeId) => '/api/admin/stores/$storeId/reject';
  static String adminToggleFeaturedStore(String storeId) => '/api/admin/stores/$storeId/featured';
  static String adminDeleteStore(String storeId) => '/api/admin/stores/$storeId';
  static const String adminCompanies = '/api/admin/companies';
  static String adminApproveCompany(String companyId) => '/api/admin/companies/$companyId/approve';
  static String adminRejectCompany(String companyId) => '/api/admin/companies/$companyId/reject';
  static String adminUserStatus(String userId) => '/api/admin/users/$userId/status';
  static String adminOrderDetail(String orderId) => '/api/admin/orders/$orderId';
  static const String adminDeliveryGroups = '/api/admin/delivery-groups';
  static const String adminSettings = '/api/admin/settings';
  static const String adminLiveMap = '/api/admin/live-map';
  static const String adminSimulateGrouping = '/api/admin/simulate-grouping';
  static const String adminAnalytics = '/api/admin/analytics';
  static String adminDriverPerformance(String driverId) => '/api/admin/drivers/$driverId/performance';
  static String adminStoreAnalytics(String storeId) => '/api/admin/stores/$storeId/analytics';

  // بيحوّل مسار نسبي راجع من السيرفر (مثلاً /uploads/profiles/x.jpg) لرابط
  // كامل قابل للعرض بـ Image.network. لو كان أصلًا رابط كامل (http/https)
  // بيرجعه متل ما هو، ولو فاضي/null بيرجع null.
  static String? resolveImageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '$baseUrl$path';
  }

  // Headers
  static const String contentType = 'application/json';
  static const String authorization = 'Authorization';
  static const String bearer = 'Bearer';
}